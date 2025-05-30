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
    player.collider = world:newBSGRectangleCollider(player.x, player.y, player.animations.frame_width + 8,
        player.animations.frame_height + 5, 2)
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
            
            -- Check if the player is trying to drop through the platform
            -- Modified to only check for down key
            if love.keyboard.isDown("down") then
                -- Calculate player bottom Y position
                local playerBottomY = py + (player.animations.frame_height + 5) / 2
                local platformTopY = platformObj.topY
                
                -- Only drop through if the player's bottom is above the platform's top
                if playerBottomY <= platformTopY then
                    contact:setEnabled(false) -- Disable collision to allow dropping through
                    -- Store the platform we're dropping through to prevent re-enabling collision too soon
                    player.droppedPlatform = collider_2
                    player.dropThroughTimer = 0.3 -- Set a timeout before re-enabling collision (adjust as needed)
                    return
                end
            end
            
            -- Calculate player bottom Y position
            local playerBottomY = py + (player.animations.frame_height + 5) / 2
            local platformTopY = platformObj.topY
            
            -- If the player is coming from below or the sides, disable collision
            -- Only allow collision from above (when player is falling)
            if ny > 0 or playerBottomY > platformTopY + 2 then  -- +2 for a little buffer
                contact:setEnabled(false)
            else
                -- Player is landing on top of the platform
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
    player.wantsToDropThrough = false
    if love.keyboard.isDown("down") then
        -- Check if player is standing on a one-way platform
        local px, py = player.collider:getPosition()
        local playerBottomY = py + (player.animations.frame_height + 5) / 2
        
        -- Query area just below the player's feet
        local platformsBelow = world:queryRectangleArea(
            px - 5, playerBottomY, 10, 2, {'OneWayPlatform'}
        )
        
        -- If there's a platform below and the player presses down, enable dropping through
        if #platformsBelow > 0 then
            player.wantsToDropThrough = true
            -- player.canJump = false -- Prevent immediate jumping after dropping -- Removed this line
            -- player.jumpCooldown = player.maxJumpCooldown -- Removed this line
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
        player.animation.currentAnimation = player.animations.