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
    world:addCollisionClass('OneWayPlatform')
    world:addCollisionClass('Portal')

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
            -- Store a reference to the collider in the map object for later access
            obj.collider = collider
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

    -- Coin counter variables
    coinCount = 0
    coinCounterFont = love.graphics.newFont(24)
    coinCounterScale = 1.0
    coinCounterBounce = 0
    coinCounterShake = {x = 0, y = 0}

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

    -- Coin class
    Coin = {}
    Coin.__index = Coin

    -- All coins collected boolean
    allCoinsCollected = false

    function Coin:new(world, anim8)
        local self = setmetatable({}, Coin)
        self.collected = false
        self.spriteSheet = love.graphics.newImage("sprites/coin-spritesheet.png")
        self.grid = anim8.newGrid(16, 16, self.spriteSheet:getWidth(), self.spriteSheet:getHeight())
        self.animation = anim8.newAnimation(self.grid('1-4', 1), 0.2)
        self.x = 300
        self.y = 400
        self.collider = world:newCircleCollider(self.x, self.y, 8)
        self.collider:setType('static')
        self.collider:setCollisionClass('Coin')
        self.collider:setObject({ x = self.x, y = self.y })
        self.collider:setPreSolve(function(collider_1, collider_2, contact)
            if collider_2.collision_class == 'Player' and not self.collected then
                self.collected = true
                coinCount = coinCount + 1 -- Increment coin counter
                print("Coin collision detected! coinCollected = " .. tostring(self.collected))
                print("Total coins collected: " .. coinCount)
                
                -- Add bounce effect to counter
                coinCounterScale = 1.5
                coinCounterBounce = 0.3
                coinCounterShake.x = (math.random() - 0.5) * 4
                coinCounterShake.y = (math.random() - 0.5) * 4
                
                self.collider:setType('inactive')
                self.collider:setSensor(true)
                print("Coin collected!")
                -- set 
                if coinCount == #coins then
                    allCoinsCollected = true
                    print("All coins collected!")
                end
            end
        end)
        return self
    end

    function Coin:update(dt)
        self.animation:update(dt)
        if self.collider then
            self.x, self.y = self.collider:getPosition()
            self.collider:setPosition(self.x, self.y)
        end
    end

    function Coin:draw()
        if self.collider and not self.collected then
            self.animation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1,
                self.spriteSheet:getHeight() / 2, self.spriteSheet:getHeight() / 2)
        end
    end

    -- Create coins from map objects
    coins = {} -- Change from single coin to coins table
    if gameMap.layers["Coins"] and gameMap.layers["Coins"].objects then
        print("Found Coins layer with " .. #gameMap.layers["Coins"].objects .. " objects")
        for i, obj in pairs(gameMap.layers["Coins"].objects) do
            local coin = Coin:new(world, anim8)
            -- Position coin at center of the object
            local centerX = obj.x + obj.width / 2
            local centerY = obj.y + obj.height / 2
            coin.collider:setPosition(centerX, centerY)
            coin.x, coin.y = coin.collider:getPosition()
            table.insert(coins, coin)
            print("Created coin at: " .. centerX .. ", " .. centerY)
        end
    else
        print("Warning: 'Coins' layer not found or has no objects")
    end

    -- Portal class
    Portal = {}
    Portal.__index = Portal

    function Portal:new(world, anim8)
        local self = setmetatable({}, Portal)
        self.spriteSheet = love.graphics.newImage("sprites/portal6_spritesheet.png")
        self.grid = anim8.newGrid(32, 32, self.spriteSheet:getWidth(), self.spriteSheet:getHeight())
        self.animation = anim8.newAnimation(self.grid('1-4', 1), 0.2)
        self.x = 0
        self.y = 0
        self.collider = world:newRectangleCollider(self.x, self.y, 32, 32)
        self.collider:setType('static')
        self.collider:setCollisionClass('Portal')
        return self
    end

    function Portal:update(dt)
        self.animation:update(dt)
        if self.collider then
            self.x, self.y = self.collider:getPosition()
            self.collider:setPosition(self.x, self.y)
        end
    end

    function Portal:draw()
        if self.collider then
            self.animation:draw(self.spriteSheet, self.x, self.y, 0, 1, 1,
                self.spriteSheet:getHeight() / 2, self.spriteSheet:getHeight() / 2)
        end
    end

    -- Create portal from Portal map object
    portals = {} -- Change from single portal to portals table
    if gameMap.layers["Portal"] and gameMap.layers["Portal"].objects then
        print("Found Portal layer with " .. #gameMap.layers["Portal"].objects .. " objects")
        for i, obj in pairs(gameMap.layers["Portal"].objects) do
            local portal = Portal:new(world, anim8)
            -- Position portal at center of the object
            local centerX = obj.x + obj.width / 2
            local centerY = obj.y + obj.height / 2
            portal.collider:setPosition(centerX, centerY)
            portal.x, portal.y = portal.collider:getPosition()
            table.insert(portals, portal)
            print("Created portal at: " .. centerX .. ", " .. centerY)
        end
    else
        print("Warning: 'Portal' layer not found or has no objects")
    end

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

    -- Update all coins
    for i, coin in ipairs(coins) do
        coin:update(dt)
        -- Update coin position based on collider
        if coin.collider then
            coin.x, coin.y = coin.collider:getPosition()
        end
        -- Update coin collider position
        if coin.collider then
            coin.collider:setPosition(coin.x, coin.y)
        end
    end

    -- Update portal animations
    for i, portal in ipairs(portals) do
        portal:update(dt)
        -- Update portal position based on collider
        if portal.collider then
            portal.x, portal.y = portal.collider:getPosition()
        end
        -- Update portal collider position
        if portal.collider then
            portal.collider:setPosition(portal.x, portal.y)
        end
    end

    -- Check if all coins are collected
    if allCoinsCollected then
        -- Iterate through the colliders and adjust their height
        if gameMap.layers["Platform-Colliders"] and gameMap.layers["Platform-Colliders"].objects then
            for i, obj in pairs(gameMap.layers["Platform-Colliders"].objects) do
                -- Check if portal_entry property exists and is the string "true"
                -- Also, ensure the collider exists and we haven't already modified this object
                if obj.properties and obj.properties.portal_entry == "true" and obj.collider and not obj.height_adjusted then
                    local originalHeight = obj.height
                    local newHeight = originalHeight / 2
                    local oldX, oldY, oldW, oldH = obj.collider:getDimensions()
                    local oldPosX, oldPosY = obj.collider:getPosition()

                    -- Adjust the position to keep the top edge in the same place
                    local newPosY = oldPosY + (oldH - newHeight) / 2
                    
                    obj.collider:setDimensions(oldW, newHeight)
                    obj.collider:setPosition(oldPosX, newPosY)
                    obj.height_adjusted = true -- Set a new flag to true to prevent further adjustments for this object
                    print("Adjusted collider height for portal entry!")
                end
            end
        end
        -- Reset allCoinsCollected to false to prevent repeated triggering
        allCoinsCollected = false
    end


    -- Update animated tiles
    gameMap:update(dt)
    updateAnimatedTiles(dt)

    -- Update coin counter effects
    if coinCounterScale > 1.0 then
        coinCounterScale = coinCounterScale - dt * 2
        if coinCounterScale < 1.0 then
            coinCounterScale = 1.0
        end
    end
    
    if coinCounterBounce > 0 then
        coinCounterBounce = coinCounterBounce - dt * 2
        if coinCounterBounce < 0 then
            coinCounterBounce = 0
        end
    end
    
    -- Reduce shake effect
    coinCounterShake.x = coinCounterShake.x * 0.9
    coinCounterShake.y = coinCounterShake.y * 0.9

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

    -- Draw all coins
    for i, coin in ipairs(coins) do
        coin:draw()
    end

    -- Draw portals
    for i, portal in ipairs(portals) do
        portal:draw()
    end

    -- Draw collision boxes for debugging
    --world:draw()
    cam:detach()

    -- Draw coin counter at top right
    local windowW = love.graphics.getWidth()
    local windowH = love.graphics.getHeight()

    -- Set up coin counter display
    love.graphics.setFont(coinCounterFont)
    local coinText = "x " .. coinCount
    local textWidth = coinCounterFont:getWidth(coinText)
    local textHeight = coinCounterFont:getHeight()

    -- Position at top right with some padding (extra space for coin sprite)
    local x = windowW - textWidth - 50 + coinCounterShake.x
    local y = 20 + coinCounterShake.y

    -- Add a subtle background (wider for coin sprite)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x - 10, y - 5, textWidth + 45, textHeight + 10, 5, 5)

    -- Draw a small coin sprite before the text
    if #coins > 0 then
        love.graphics.setColor(1, 1, 1, 1)
        local coinSprite = coins[1].spriteSheet -- Use the coin spritesheet
        local scale = 1.5
        
        -- Create a quad to show only the first frame (16x16 pixels at position 0,0)
        local coinQuad = love.graphics.newQuad(0, 0, 16, 16, coinSprite:getWidth(), coinSprite:getHeight())
        love.graphics.draw(coinSprite, coinQuad, x + 5, y + textHeight/2, 0, scale, scale, 8, 8)
    end

    -- Draw the coin counter with bounce effect
    love.graphics.setColor(1, 0.8, 0.2) -- Golden color
    love.graphics.push()
    love.graphics.translate(x + 30 + textWidth/2, y + textHeight/2)
    love.graphics.scale(coinCounterScale, coinCounterScale)
    love.graphics.translate(-textWidth/2, -textHeight/2)
    love.graphics.print(coinText, 0, 0)
    love.graphics.pop()

    -- Add a glowing outline effect
    if coinCounterBounce > 0 then
        love.graphics.setColor(1, 1, 0.5, coinCounterBounce)
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.push()
                    love.graphics.translate(x + 30 + textWidth/2 + dx, y + textHeight/2 + dy)
                    love.graphics.scale(coinCounterScale, coinCounterScale)
                    love.graphics.translate(-textWidth/2, -textHeight/2)
                    love.graphics.print(coinText, 0, 0)
                    love.graphics.pop()
                end
            end
        end
    end
    
    -- CRITICAL: Reset color to white for all other drawing operations
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw controls info for one-way platforms
    --love.graphics.setColor(1, 1, 1)
    --love.graphics.print("Press Down to drop through one-way platforms", 10, 10) -- Updated text
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