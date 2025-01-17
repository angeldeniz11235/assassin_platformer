function love.load()
    -- Load assets, initialize variables, etc.
    camera = require 'libraries/camera'
    cam = camera()

    anim8 = require 'libraries/anim8'
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Load map
    sti = require 'libraries/sti'
    gameMap = sti("maps/level1.lua")

    love.graphics.setBackgroundColor(0.5, 0.5, 0.5)

    -- Create player object
    player = {
        x = 100,
        y = 200,
        speed = 100,
        facing = "right",
        isMoving = false,
    }
    -- Load player sprites
    player.animations = {}
    player.animations.frame_width, player.animations.frame_height  = 16, 16
    -- idle animation
    player.animations.spriteSheet_idle = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_idle = anim8.newGrid(player.animations.frame_width, player.animations.frame_height, player.animations.spriteSheet_idle:getWidth(), player.animations.spriteSheet_idle:getHeight())
    player.animations.animation_idle = anim8.newAnimation(player.animations.grid_idle('1-4', 1), 0.2)
    -- run animation
    player.animations.spriteSheet_walk = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_walk = anim8.newGrid(player.animations.frame_width, player.animations.frame_height, player.animations.spriteSheet_walk:getWidth(), player.animations.spriteSheet_walk:getHeight())
    player.animations.animation_walk = anim8.newAnimation(player.animations.grid_walk('5-8', 1), 0.2)
    -- roll animation
    player.animations.spriteSheet_roll = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_roll = anim8.newGrid(player.animations.frame_width, player.animations.frame_height, player.animations.spriteSheet_roll:getWidth(), player.animations.spriteSheet_roll:getHeight())
    player.animations.animation_roll = anim8.newAnimation(player.animations.grid_roll('9-12', 1), 0.2)
    -- jump animation
    player.animations.spriteSheet_jump = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_jump = anim8.newGrid(player.animations.frame_width, player.animations.frame_height, player.animations.spriteSheet_jump:getWidth(), player.animations.spriteSheet_jump:getHeight())
    player.animations.animation_jump = anim8.newAnimation(player.animations.grid_jump('13-13', 1), 0.2)
    -- fall animation
    player.animations.spriteSheet_fall = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_fall = anim8.newGrid(player.animations.frame_width, player.animations.frame_height, player.animations.spriteSheet_fall:getWidth(), player.animations.spriteSheet_fall:getHeight())
    player.animations.animation_fall = anim8.newAnimation(player.animations.grid_fall('14-14', 1), 0.2)
    -- jump to fall animation
    player.animations.spriteSheet_jump_fall = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_jump_fall = anim8.newGrid(player.animations.frame_width, player.animations.frame_height, player.animations.spriteSheet_jump_fall:getWidth(), player.animations.spriteSheet_jump_fall:getHeight())
    player.animations.animation_jump_fall = anim8.newAnimation(player.animations.grid_jump_fall('15-15', 1), 0.2)
    -- death animation
    player.animations.spriteSheet_death = love.graphics.newImage("sprites/assasin-spritesheet.png")
    player.animations.grid_death = anim8.newGrid(player.animations.frame_width, player.animations.frame_height, player.animations.spriteSheet_death:getWidth(), player.animations.spriteSheet_death:getHeight())
    player.animations.animation_death = anim8.newAnimation(player.animations.grid_death('16-19', 1), 0.2)
    -- Set player animation
    player.animation = {}
    player.animation.currentAnimation = player.animations.animation_idle
    player.animation.currentSpriteSheet = player.animations.spriteSheet_idle

    -- Initialize camera
    cam:lookAt(player.x, player.y)
end

function love.update(dt)
    -- Update game state
    player.isMoving = false
    -- Check for player input
    if love.keyboard.isDown("left") then
        -- Move player left
        player.x = player.x - player.speed * dt
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "left"
    elseif love.keyboard.isDown("right") then
        -- Move player right
        player.x = player.x + player.speed * dt
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "right"
    end
    
    if love.keyboard.isDown("up") then
        -- Move player up
        player.y = player.y - player.speed * dt
        player.animation.currentSpriteSheet = player.animations.spriteSheet_jump
        player.animation.currentAnimation = player.animations.animation_jump
        player.isMoving = true
    elseif love.keyboard.isDown("down") then
        -- Move player down
        --player.y = player.y + player.speed * dt -- player should not be able to move down
        player.animation.currentSpriteSheet = player.animations.spriteSheet_roll
        player.animation.currentAnimation = player.animations.animation_roll
        player.isMoving = true
    end

    if not player.isMoving then
        player.animation.currentAnimation = player.animations.animation_idle
        player.animation.currentSpriteSheet = player.animations.spriteSheet_idle
    end

    -- Get width/height of background
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight
    
    -- Get window dimensions
    local windowW = love.graphics.getWidth()
    local windowH = love.graphics.getHeight()
    
    -- Calculate camera bounds
    local cameraX = player.x
    local cameraY = player.y
    
    -- Clamp camera position to map bounds
    cameraX = math.max(windowW/2, math.min(mapW - windowW/2, cameraX))
    cameraY = math.max(windowH/2, math.min(mapH - windowH/2, cameraY))
    
    -- Update camera position to exactly follow player within bounds
    cam:lookAt(cameraX, cameraY)

    player.animation.currentAnimation:update(dt)
end

function love.draw()
    cam:attach()
        -- Draw game objects
        gameMap:drawLayer(gameMap.layers["sky"])
        gameMap:drawLayer(gameMap.layers["ocean"])
        gameMap:drawLayer(gameMap.layers["foreground"])
        -- Draw player
        if player.facing == "left" then
            player.animation.currentAnimation:draw(player.animation.currentSpriteSheet, player.x, player.y, 0, -4, 2, player.animations.frame_width/2, player.animations.frame_height/2, 0, 0)
        else
            player.animation.currentAnimation:draw(player.animation.currentSpriteSheet, player.x, player.y, 0, 4, 2, player.animations.frame_width/2, player.animations.frame_height/2, 0, 0)
        end
    cam:detach()
end