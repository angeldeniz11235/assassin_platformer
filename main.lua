function love.load()
    -- Load assets, initialize variables, etc.
    camera = require 'libraries/camera'
    cam = camera()

    anim8 = require 'libraries/anim8'
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Load map
    sti = require 'libraries/sti'
    gameMap = sti("maps/level1-1.lua")

    -- Debug print to check available layers
    print("Available layers in map:")
    for layerName, layer in pairs(gameMap.layers) do
        print("- " .. layerName)
    end

    -- Load animated tiles
    animatedTiles = {}
    for _, tileset in ipairs(gameMap.tilesets) do
        if tileset.tiles then
            for id, tile in pairs(tileset.tiles) do
                if tile.animation then
                    local gid = tileset.firstgid + id
                    animatedTiles[gid] = {
                        frames = tile.animation,
                        currentFrame = 1,
                        timer = 0
                    }
                end
            end
        end
    end

    -- Load Physics library
    wf = require 'libraries/windfield'
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 1100)

    love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

    -- Set up collision classes
    world:addCollisionClass('Player')
    world:addCollisionClass('Ground')
    world:addCollisionClass('Wall')
    world:addCollisionClass('Ceiling')
    world:addCollisionClass('Coin')
    -- Add a new collision class for one-way platforms
    world:addCollisionClass('OneWayPlatform')

    -- Create ground and wall colliders from map - with safety checks
    if gameMap.layers["Platform-Colliders"] and gameMap.layers["Platform-Colliders"].objects then
        for i, obj in pairs(gameMap.layers["Platform-Colliders"].objects) do
            local collider = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            collider:setType('static')
            if obj.properties and obj.properties.isWall then
                collider:setCollisionClass('Wall')
            elseif obj.properties and obj.properties.isOneWay then
                -- Set as one-way platform
                collider:setCollisionClass('OneWayPlatform')
                -- Store the top Y coordinate for collision detection
                collider:setObject({topY = obj.y})
            else
                collider:setCollisionClass('Ground')
            end
        end
    else
        print(
            "Warning: 'Platform-Colliders' layer not found or has no objects. Make sure your Tiled map has a 'Platform-Colliders' layer with objects.")
        -- Create a temporary ground platform so the game doesn't crash
        local ground = world:newRectangleCollider(0, 500, 800, 100)
        ground:setType('static')
        ground:setCollisionClass('Ground')
    end

    -- Add ceiling collider at the top of the map
    local ceilingCollider = world:newRectangleCollider(0, -10, gameMap.width * gameMap.tilewidth, 10)
    ceilingCollider:setType('static')
    ceilingCollider:setCollisionClass('Ceiling')

    player = {
        x = 260,
        y = 230,
        speed = 300,
        facing = "right",
        isMoving = false,
        isJumping = false,
        canJump = true,
        jumpForce = -300,
        jumpCooldown = 0,
        maxJumpCooldown = 0.15,
        isWallSliding = false, -- New wall sliding state
        wallDirection = nil,   -- "left" or "right"
        wallSlideSpeed = 150,  -- Speed of wall sliding (adjust as needed)
        wantsToDropThrough = false, -- Flag for dropping through platforms
        droppedPlatform = nil, -- Reference to the platform being dropped through
        dropThroughTimer = 0   -- Timer to re-enable collision after dropping
    }

    -- Initialize player animations
    player.animations = {}
    player.animations.frame_width, player.animations.frame_height = 16, 16

    -- idle animation
    player.animations.spriteSheet_idle = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_idle = anim8.newGrid(player.animations.frame_width, player.animations.frame_height,
        player.animations.spriteSheet_idle:getWidth(), player.animations.spriteSheet_idle:getHeight())
    player.animations.animation_idle = anim8.newAnimation(player.animations.grid_idle('1-4', 1), 0.2)
    -- run animation
    player.animations.spriteSheet_walk = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_walk = anim8.newGrid(player.animations.frame_width, player.animations.frame_height,
        player.animations.spriteSheet_walk:getWidth(), player.animations.spriteSheet_walk:getHeight())
    player.animations.animation_walk = anim8.newAnimation(player.animations.grid_walk('5-8', 1), 0.2)
    -- roll animation
    player.animations.spriteSheet_roll = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_roll = anim8.newGrid(player.animations.frame_width, player.animations.frame_height,
        player.animations.spriteSheet_roll:getWidth(), player.animations.spriteSheet_roll:getHeight())
    player.animations.animation_roll = anim8.newAnimation(player.animations.grid_roll('9-12', 1), 0.2)
    -- jump animation
    player.animations.spriteSheet_jump = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_jump = anim8.newGrid(player.animations.frame_width, player.animations.frame_height,
        player.animations.spriteSheet_jump:getWidth(), player.animations.spriteSheet_jump:getHeight())
    player.animations.animation_jump = anim8.newAnimation(player.animations.grid_jump('13-13', 1), 0.2)
    -- fall animation
    player.animations.spriteSheet_fall = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_fall = anim8.newGrid(player.animations.frame_width, player.animations.frame_height,
        player.animations.spriteSheet_fall:getWidth(), player.animations.spriteSheet_fall:getHeight())
    player.animations.animation_fall = anim8.newAnimation(player.animations.grid_fall('14-14', 1), 0.2)
    -- jump to fall animation
    player.animations.spriteSheet_jump_fall = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_jump_fall = anim8.newGrid(player.animations.frame_width, player.animations.frame_height,
        player.animations.spriteSheet_jump_fall:getWidth(), player.animations.spriteSheet_jump_fall:getHeight())
    player.animations.animation_jump_fall = anim8.newAnimation(player.animations.grid_jump_fall('15-15', 1), 0.2)
    -- death animation
    player.animations.spriteSheet_death = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_death = anim8.newGrid(player.animations.frame_width, player.animations.frame_height,
        player.animations.spriteSheet_death:getWidth(), player.animations.spriteSheet_death:getHeight())
    player.animations.animation_death = anim8.newAnimation(player.animations.grid_death('16-19', 1), 0.2)
    -- Set player animation
    player.animation = {}
    player.animation.currentAnimation = player.animations.animation_idle
    player.animation.currentSpriteSheet = player.animations.spriteSheet_idle

    --coin animation
    coinCollected = false
    coin_spriteSheet = love.graphics.newImage("sprites/coin-spritesheet.png")
    coin_grid = anim8.newGrid(16, 16, coin_spriteSheet:getWidth(), coin_spriteSheet:getHeight())
    coin_animation = anim8.newAnimation(coin_grid('1-4', 1), 0.2)
    -- initialize coin position
    coin_x = 300
    coin_y = 400
    -- Initialize coin collider
    coin_collider = world:newCircleCollider(coin_x, coin_y, 8)
    coin_collider:setType('static') -- Set as static collider
    coin_collider:setCollisionClass('Coin')
    coin_collider:setObject({ x = coin_x, y = coin_y })
    --coin_collider:setSensor(true) -- Set as sensor to avoid physical collisions
    coin_collider:setPreSolve(function(collider_1, collider_2, contact)
        if collider_2.collision_class == 'Player' and not coinCollected then
            -- Mark the coin as collected
            coinCollected = true
            
            -- Add some debug output
            print("Coin collision detected! coinCollected = " .. tostring(coinCollected))
            
            -- Move coin off-screen
            -- coin_x = -100
            -- coin_y = -100
            -- coin_collider:setPosition(coin_x, coin_y)
            coin_collider:setType('inactive') -- Disable the collider
            coin_collider:setSensor(true) -- Set as sensor to avoid further collisions
            print("Coin collected!")
        end
    end)

    -- Player collision
    player.collider = world:newBSGRectangleCollider(player.x, player.y, player.animations.frame_width + 8, player.animations.frame_height + 5, 2)
    player.collider:setCollisionClass('Player')
    player.collider:setFixedRotation(true)
    player.collider:setObject(player)

    -- Add ground collision detection
    player.collider:setPreSolve(function(collider_1, collider_2, contact)
        if collider_2.collision_class == 'Ground' then
            local px, py = player.collider:getPosition()
            local ox, oy = contact:getNormal()

            if oy < 0 then
                player.canJump = true
                player.isJumping = false
                player.isWallSliding = false -- Reset wall sliding when on ground
            end
        elseif collider_2.collision_class == 'Wall' then
            local nx, ny = contact:getNormal()
            local vx, vy = player.collider:getLinearVelocity()

            -- Determine if player is against a wall
            if math.abs(nx) > 0.1 then -- Checking if collision normal is horizontal
                player.isWallSliding = true

                -- Apply wall sliding
                if vy > player.wallSlideSpeed then
                    vy = player.wallSlideSpeed
                    player.collider:setLinearVelocity(0, vy)
                end
            else
                player.isWallSliding = false
            end

            contact:setEnabled(true) -- Enable collision response for walls
        elseif collider_2.collision_class == 'OneWayPlatform' then
            local px, py = player.collider:getPosition()
            local platformObj = collider_2:getObject()
            local nx, ny = contact:getNormal()
            
            -- Scenario 1: Player is actively trying to drop through (e.g., holding "down")
            if player.wantsToDropThrough then
                -- Ensure we are interacting with the platform from above or on it
                local playerColliderActualHeight = player.animations.frame_height + 5
                local playerBottomY = py + playerColliderActualHeight / 2 
                local platformTopY = platformObj.topY
                
                -- Only disable contact if player is at or above the platform's surface
                -- This prevents dropping through a platform that's far below.
                -- The check in love.update should mostly ensure this, but an extra check here is safe.
                if playerBottomY <= platformTopY + 5 then -- Allow a small tolerance
                    contact:setEnabled(false) 
                    player.droppedPlatform = collider_2 -- Store the platform we're dropping through
                    player.dropThroughTimer = 0.3      -- Set timeout to re-enable collision with this platform
                    return -- Important to return after disabling contact for this reason
                end
            end
            
            -- Scenario 2: Player is NOT actively trying to drop through,
            -- BUT this might be the platform they just dropped from.
            -- If so, keep contact disabled until the timer runs out.
            if player.droppedPlatform == collider_2 and player.dropThroughTimer > 0 then
                contact:setEnabled(false) -- Continue ignoring this specific platform
                return
            end
            
            -- Scenario 3: Standard one-way platform collision logic
            -- (Player is not trying to drop, and not currently ignoring this platform due to a recent drop)
            local playerColliderActualHeight = player.animations.frame_height + 5
            local playerBottomY = py + playerColliderActualHeight / 2 
            local platformTopY = platformObj.topY
            
            -- If the player is coming from below or is already significantly past the platform's top surface, disable collision.
            -- 'ny > 0' means the collision normal is pointing upwards (player hitting platform from below or side).
            -- 'playerBottomY > platformTopY + 2' means player's feet are already below the platform's top.
            if ny > 0 or playerBottomY > platformTopY + 2 then  -- +2 for a little buffer
                contact:setEnabled(false)
            else
                -- Player is landing on top of the platform (or walking onto it)
                player.canJump = true
                player.isJumping = false
                player.isWallSliding = false
                contact:setEnabled(true)
            end
        end
    end)
end

function love.update(dt)
    -- Update game state
    player.isMoving = false
    local vx, vy = player.collider:getLinearVelocity()

    -- Update jump cooldown
    if player.jumpCooldown > 0 then
        player.jumpCooldown = player.jumpCooldown - dt
    end
    
    -- Update drop through timer
    if player.dropThroughTimer > 0 then
        player.dropThroughTimer = player.dropThroughTimer - dt
        if player.dropThroughTimer <= 0 then
            player.droppedPlatform = nil -- Clear the reference to the platform
        end
    end

    -- Check for down to drop through platforms
    player.wantsToDropThrough = false -- Reset each frame before checking
    if love.keyboard.isDown("down") then
        local px, py = player.collider:getPosition()
        -- Use the actual width and height of the player's collider for calculations
        local playerColliderActualWidth = player.animations.frame_width + 8 
        local playerColliderActualHeight = player.animations.frame_height + 5
        
        -- Player's feet Y position (bottom edge of the collider)
        local playerFeetY = py + playerColliderActualHeight / 2 
        
        -- Define the query area parameters below the player's feet
        -- Use a significant portion of the player's width to ensure reliable detection
        local queryWidth = playerColliderActualWidth * 0.9 -- Use 90% of player's collider width for detection
        local queryX = px - queryWidth / 2 -- Centered under the player
        local queryHeight = 2 -- A small height to check for a platform immediately underfoot
        
        -- Query for OneWayPlatform(s) just below the player's feet
        local platformsPlayerIsOn = world:queryRectangleArea(
            queryX, 
            playerFeetY, -- The query rectangle's top edge starts at the player's feet level
            queryWidth, 
            queryHeight, 
            {'OneWayPlatform'}
        )
        
        -- If the player is standing on a one-way platform and presses 'down', enable dropping through
        if #platformsPlayerIsOn > 0 then
            player.wantsToDropThrough = true
            player.canJump = false -- Prevent immediate jumping after initiating a drop
            player.jumpCooldown = player.maxJumpCooldown -- Enforce jump cooldown to prevent re-jump glitches
        end
    end

    -- Handle horizontal movement with wall sliding
    if love.keyboard.isDown("left") then
        if not player.isWallSliding then
            vx = -player.speed
        else
            vx = -player.speed * 0.1 -- Reduced horizontal movement while wall sliding
        end
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "left"
    elseif love.keyboard.isDown("right") then
        if not player.isWallSliding then
            vx = player.speed
        else
            vx = player.speed * 0.1 -- Reduced horizontal movement while wall sliding
        end
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "right"
    else
        if not player.isWallSliding then
            vx = vx * 0.9 -- Normal friction when not wall sliding
        else
            vx = 0        -- Stop horizontal movement while wall sliding
        end
    end

    -- Detect wall direction
    if player.isWallSliding then
        local px, py = player.collider:getPosition()
        local colliders = world:queryRectangleArea(px - 1, py, 2, player.animations.frame_height, { 'Wall' })
        if #colliders > 0 then
            player.wallDirection = "left"
        else
            colliders = world:queryRectangleArea(px + player.animations.frame_width - 1, py, 2,
                player.animations.frame_height, { 'Wall' })
            if #colliders > 0 then
                player.wallDirection = "right"
            end
        end
    end

    -- Update animations based on vertical velocity and wall sliding
    if player.isWallSliding then
        player.animation.currentSpriteSheet = player.animations
            .spriteSheet_fall -- Use fall animation for wall slide
        player.animation.currentAnimation = player.animations.animation_fall
    elseif vy < -50 then      -- Rising
        player.animation.currentSpriteSheet = player.animations.spriteSheet_jump
        player.animation.currentAnimation = player.animations.animation_jump
    elseif vy > 50 then -- Falling
        player.animation.currentSpriteSheet = player.animations.spriteSheet_fall
        player.animation.currentAnimation = player.animations.animation_fall
    elseif not player.isMoving then -- Idle
        player.animation.currentSpriteSheet = player.animations.spriteSheet_idle
        player.animation.currentAnimation = player.animations.animation_idle
    end

    -- Handle jumping with ceiling collision
    if love.keyboard.isDown("space") and player.canJump and player.jumpCooldown <= 0 then
        local px, py = player.collider:getPosition()
        local nextY = py + player.jumpForce * dt -- Calculate next position

        -- Check if the next position would hit the ceiling
        if nextY - player.animations.frame_height / 2 > 0 then -- Ensure we stay within bounds
            vy = player.jumpForce
            player.isJumping = true
            player.canJump = false
            player.jumpCooldown = player.maxJumpCooldown

            -- Set jump animation
            player.animation.currentSpriteSheet = player.animations.spriteSheet_jump
            player.animation.currentAnimation = player.animations.animation_jump
        else
            vy = 0 -- Stop upward movement if we would hit the ceiling
        end
    end
    -- Handle wall jumping
    if love.keyboard.isDown("space") and player.isWallSliding and player.jumpCooldown <= 0 then
        local wallJumpForceX = 300  -- Horizontal force for wall jump
        local wallJumpForceY = -400 -- Vertical force for wall jump

        if player.wallDirection == "left" then
            vx = wallJumpForceX  -- Jump to the right
        elseif player.wallDirection == "right" then
            vx = -wallJumpForceX -- Jump to the left
        end

        vy = wallJumpForceY                          -- Apply upward force
        player.isWallSliding = false                 -- Stop wall sliding
        player.jumpCooldown = player.maxJumpCooldown -- Reset jump cooldown
    end

    -- Update player velocity with clamping
    local maxVelocity = 800
    vx = math.max(-maxVelocity, math.min(maxVelocity, vx))
    vy = math.max(-maxVelocity, math.min(maxVelocity, vy))
    player.collider:setLinearVelocity(vx, vy)

    -- Update animations based on vertical velocity
    if vy < -50 then -- Rising
        player.animation.currentSpriteSheet = player.animations.spriteSheet_jump
        player.animation.currentAnimation = player.animations.animation_jump
    elseif vy > 50 then -- Falling
        player.animation.currentSpriteSheet = player.animations.spriteSheet_fall
        player.animation.currentAnimation = player.animations.animation_fall
    elseif not player.isMoving then -- Idle
        player.animation.currentSpriteSheet = player.animations.spriteSheet_idle
        player.animation.currentAnimation = player.animations.animation_idle
    end

    -- Get width/height of background
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight

    -- Update wf world
    world:update(dt)

    -- Get player position from collider
    player.x, player.y = player.collider:getPosition()
    player.y = player.y - 5 -- offset for feet position

    -- Clamp player position to map bounds
    player.x = math.max(0 + player.animations.frame_width / 2,
        math.min(mapW - player.animations.frame_width / 2, player.x))
    player.y = math.max(0 + player.animations.frame_height / 2,
        math.min(mapH - player.animations.frame_height / 2, player.y))

    -- Camera updates remain the same...
    local windowW = love.graphics.getWidth()
    local windowH = love.graphics.getHeight()
    local cameraX = player.x
    local cameraY = player.y
    cameraX = math.max(windowW / 2, math.min(mapW - windowW / 2, cameraX))
    cameraY = math.max(windowH / 2, math.min(mapH - windowH / 2, cameraY))
    cam:lookAt(cameraX, cameraY)

    player.animation.currentAnimation:update(dt)

    -- update coin animation
    coin_animation:update(dt)
    -- Update coin position based on collider
    if coin_collider then
        coin_x, coin_y = coin_collider:getPosition()
    end
    -- Update coin collider position
    if coin_collider then
        coin_collider:setPosition(coin_x, coin_y)
    end

    -- Update animated tiles
    gameMap:update(dt)
    updateAnimatedTiles(dt)

    --zoom camera in onto the player
    cam:zoomTo(3)
    -- Initialize camera
    cam:lookAt(player.x, player.y)
end

function love.draw()
    cam:attach()
    -- Draw game objects with safety checks
    if gameMap.layers["Background"] then
        gameMap:drawLayer(gameMap.layers["Background"])
    end
    if gameMap.layers["Terrain"] then
        gameMap:drawLayer(gameMap.layers["Terrain"])
    end
    -- if gameMap.layers["Objects"] then
    --     gameMap:drawLayer(gameMap.layers["Objects"])
    -- end

    -- Draw player
    if player.facing == "left" then
        player.animation.currentAnimation:draw(player.animation.currentSpriteSheet, player.x, player.y, 0, -4, 2,
            player.animations.frame_width / 2, player.animations.frame_height / 2, 0, 0)
    else
        player.animation.currentAnimation:draw(player.animation.currentSpriteSheet, player.x, player.y, 0, 4, 2,
            player.animations.frame_width / 2, player.animations.frame_height / 2, 0, 0)
    end

    -- Draw coin
    -- print("Drawing coin, coinCollected = " .. tostring(coinCollected)) -- Keep for debugging if needed
    if coin_collider and not coinCollected then
        coin_animation:draw(coin_spriteSheet, coin_x, coin_y, 0, 1, 1,
            coin_spriteSheet:getHeight() / 2, coin_spriteSheet:getHeight() / 2)
    end

    -- Draw collision boxes for debugging
    --world:draw()
    cam:detach()
    
    -- Draw controls info for one-way platforms
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Press Down to drop through one-way platforms", 10, 10) -- Updated text
end

--cycle through the animated tiles in the map
function updateAnimatedTiles(dt)
    for gid, anim in pairs(animatedTiles) do
        anim.timer = anim.timer + dt
        local frame = anim.frames[anim.currentFrame]

        if anim.timer >= frame.duration / 1000 then
            anim.timer = 0
            anim.currentFrame = anim.currentFrame % #anim.frames + 1
            local newFrame = anim.frames[anim.currentFrame].tileid + 1
            for _, layer in ipairs(gameMap.layers) do
                if layer.type == "tilelayer" then
                    for y, row in ipairs(layer.data) do
                        for x, tile in ipairs(row) do
                            if tile and tile.gid == gid then
                                layer.data[y][x] = gameMap.tiles[newFrame + (gid - newFrame)]
                            end
                        end
                    end
                end
            end
        end
    end
end