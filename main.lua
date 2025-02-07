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

    -- Load Physics library
    wf = require 'libraries/windfield'
    world = wf.newWorld(0, 0, true)
    world:setGravity(0, 1100)

    love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

    -- Set up collision classes
    world:addCollisionClass('Player')
    world:addCollisionClass('Ground')

    -- Create ground colliders from map - with safety checks
    if gameMap.layers["Platform-Colliders"] and gameMap.layers["Platform-Colliders"].objects then
        for i, obj in pairs(gameMap.layers["Platform-Colliders"].objects) do
            local ground = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            ground:setType('static')
            ground:setCollisionClass('Ground')
        end
    else
        print(
            "Warning: 'Platform-Colliders' layer not found or has no objects. Make sure your Tiled map has a 'Platform-Colliders' layer with objects.")
        -- Create a temporary ground platform so the game doesn't crash
        local ground = world:newRectangleCollider(0, 500, 800, 100)
        ground:setType('static')
        ground:setCollisionClass('Ground')
    end

    player = {
        x = 70,
        y = 20,
        speed = 300,
        facing = "right",
        isMoving = false,
        isJumping = false,
        canJump = true,
        jumpForce = -300,  -- Adjust this value to control jump height
        jumpCooldown = 0,  -- Add cooldown to prevent double jumping
        maxJumpCooldown = 0.1  -- Maximum time between jumps
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

    -- Player collision
    player.collider = world:newBSGRectangleCollider(player.x, player.y, player.animations.frame_width + 8,
        player.animations.frame_height + 5, 2)
    player.collider:setCollisionClass('Player')
    player.collider:setFixedRotation(true)
    player.collider:setObject(player)

    -- Modify ground collision detection
    player.collider:setPreSolve(function(collider_1, collider_2, contact)
        if collider_2.collision_class == 'Ground' then
            local _, ny = contact:getNormal()
            if ny < 0 then  -- Only when colliding from above
                player.canJump = true
                player.isJumping = false
            end
        end
    end)

    -- Initialize camera
    cam:lookAt(player.x, player.y)
end

function love.update(dt)
    -- Update game state
    player.isMoving = false
    local vx, vy = player.collider:getLinearVelocity()

    -- Update jump cooldown
    if player.jumpCooldown > 0 then
        player.jumpCooldown = player.jumpCooldown - dt
    end

    -- Handle horizontal movement
    if love.keyboard.isDown("left") then
        vx = -player.speed
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "left"
    elseif love.keyboard.isDown("right") then
        vx = player.speed
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "right"
    else
        -- Apply friction when not moving
        vx = vx * 0.8
    end

    -- Handle jumping
    if love.keyboard.isDown("space") and player.canJump and player.jumpCooldown <= 0 then
        vy = player.jumpForce
        player.isJumping = true
        player.canJump = false
        player.jumpCooldown = player.maxJumpCooldown
        
        -- Set jump animation
        player.animation.currentSpriteSheet = player.animations.spriteSheet_jump
        player.animation.currentAnimation = player.animations.animation_jump
    end

    -- Apply velocities before world update
    player.collider:setLinearVelocity(vx, vy)

    -- Update physics world
    world:update(dt)

    -- Get player position from collider
    player.x, player.y = player.collider:getPosition()
    player.y = player.y - 5 -- offset for feet position

    -- Get current map dimensions
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight

    -- Clamp player position to map bounds
    local newX = math.max(0 + player.animations.frame_width / 2,
        math.min(mapW - player.animations.frame_width / 2, player.x))
    local newY = math.max(0 + player.animations.frame_height / 2,
        math.min(mapH - player.animations.frame_height / 2, player.y + 5)) - 5

    -- Update collider position if clamped
    if newX ~= player.x or newY ~= player.y then
        player.collider:setPosition(newX, newY + 5)
    end

    player.x = newX
    player.y = newY

    -- Update animations based on vertical velocity
    if vy < -50 then  -- Rising
        player.animation.currentSpriteSheet = player.animations.spriteSheet_jump
        player.animation.currentAnimation = player.animations.animation_jump
    elseif vy > 50 then  -- Falling
        player.animation.currentSpriteSheet = player.animations.spriteSheet_fall
        player.animation.currentAnimation = player.animations.animation_fall
    elseif not player.isMoving then  -- Idle
        player.animation.currentSpriteSheet = player.animations.spriteSheet_idle
        player.animation.currentAnimation = player.animations.animation_idle
    end

    -- Camera updates
    local windowW = love.graphics.getWidth()
    local windowH = love.graphics.getHeight()
    local cameraX = player.x
    local cameraY = player.y
    cameraX = math.max(windowW / 2, math.min(mapW - windowW / 2, cameraX))
    cameraY = math.max(windowH / 2, math.min(mapH - windowH / 2, cameraY))
    cam:lookAt(cameraX, cameraY)

    player.animation.currentAnimation:update(dt)
end

function love.draw()
    cam:attach()
    -- Draw game objects with safety checks
    if gameMap.layers["Background"] then
        gameMap:drawLayer(gameMap.layers["Background"])
    end
    if gameMap.layers["Platforms"] then
        gameMap:drawLayer(gameMap.layers["Platforms"])
    end
    if gameMap.layers["Items"] then
        gameMap:drawLayer(gameMap.layers["Items"])
    end

    -- Draw player
    if player.facing == "left" then
        player.animation.currentAnimation:draw(player.animation.currentSpriteSheet, player.x, player.y, 0, -4, 2,
            player.animations.frame_width / 2, player.animations.frame_height / 2, 0, 0)
    else
        player.animation.currentAnimation:draw(player.animation.currentSpriteSheet, player.x, player.y, 0, 4, 2,
            player.animations.frame_width / 2, player.animations.frame_height / 2, 0, 0)
    end

    -- Draw collision boxes for debugging
    world:draw()
    cam:detach()
end
