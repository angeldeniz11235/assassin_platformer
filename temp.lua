function love.update(dt)
    -- Update game state
    player.isMoving = false
    -- Check for player input
    if love.keyboard.isDown("left") then
        player.x = player.x - player.speed * dt
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "left"
    elseif love.keyboard.isDown("right") then
        player.x = player.x + player.speed * dt
        player.animation.currentSpriteSheet = player.animations.spriteSheet_walk
        player.animation.currentAnimation = player.animations.animation_walk
        player.isMoving = true
        player.facing = "right"
    end
    
    if love.keyboard.isDown("up") then
        player.y = player.y - player.speed * dt
        player.animation.currentSpriteSheet = player.animations.spriteSheet_jump
        player.animation.currentAnimation = player.animations.animation_jump
        player.isMoving = true
    elseif love.keyboard.isDown("down") then
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

    -- Clamp player position to map bounds
    player.x = math.max(0 + player.animations.frame_width / 2, math.min(mapW - player.animations.frame_width / 2, player.x))
    player.y = math.max(0 + player.animations.frame_height / 2, math.min(mapH - player.animations.frame_height / 2, player.y))
    
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

    -- Update the animation
    player.animation.currentAnimation:update(dt)
end
