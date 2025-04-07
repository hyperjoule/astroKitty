-- astroKitty main.lua
-- by hyperjoule for hyLite studios 

import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"
import "CoreLibs/object"
import "CoreLibs/animator"

local gfx = playdate.graphics
local pd <const> = playdate

-- Game state
local state = "splash"
local score = 0
local highScore = playdate.datastore.read("highscore") or 0
local lives = 9  -- 9 lives for a cat game!
local isPaused = false
local respawnCooldown = 0
local difficulty = 0.5  

-- Load assets
local astrokittyLogo = gfx.image.new("assets/logos/astrokitty_logo.png")
local sfxShoot = playdate.sound.sampleplayer.new("assets/sounds/fire.wav")
local sfxExplosion = playdate.sound.sampleplayer.new("assets/sounds/explosion.wav")
local sfxMeow = playdate.sound.sampleplayer.new("assets/sounds/meow.wav")
local sfxYarn = playdate.sound.sampleplayer.new("assets/sounds/yarn.wav")  
local bgMusic = playdate.sound.sampleplayer.new("assets/music/music.wav")  

-- Player
local player = { x = 200, y = 120, vx = 0, vy = 0, angle = 0, radius = 8 }

-- Game objects
local bullets, asteroids, yarn, effects, stars = {}, {}, nil, {}, {}
local screenShake = { dx = 0, dy = 0, timer = 0 }

-- For game-over: cat balloons with white heads, outlines, ears, whiskers, and a little face.
local catBalloons = {}

-- Load font
local gameFont = gfx.getSystemFont(gfx.font.kVariantBold)
gfx.setFont(gameFont)

-- Define white pattern and dither patterns for different gray shades (8x8 patterns)
local whitePattern = { 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF }
local ditherPatterns = {
    { 0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA },  -- Medium gray
    { 0x44,0x88,0x44,0x88,0x44,0x88,0x44,0x88 },  -- Slight variation
    whitePattern                                    -- White (for white cats)
}

-- Cat face variants scaled by cat size

local whiteCatFace = function(x, y, r)
    r = r or 10
    local scale = r / 10
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x - 3 * scale, y - 3 * scale, scale)
    gfx.fillCircleAtPoint(x + 3 * scale, y - 3 * scale, scale)
    gfx.fillCircleAtPoint(x, y - 1 * scale, scale * 0.8)
    if r >= 15 then
        -- Draw a different mouth for larger cats
        local mouthY = y + 1 * scale
        local mouthWidth = 2 * scale
        gfx.drawLine(x - mouthWidth, mouthY, x + mouthWidth, mouthY)
        gfx.drawLine(x, mouthY, x, mouthY + 0.5 * scale)
    else
        gfx.drawArc(x, y + 1 * scale, 2 * scale, 0, 180)
    end
end

local darkCatFace = function(x, y, r)
    r = r or 10
    local scale = r / 10
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x - 3 * scale, y - 3 * scale, scale)
    gfx.fillCircleAtPoint(x + 3 * scale, y - 3 * scale, scale)
    gfx.fillCircleAtPoint(x, y - 1 * scale, scale * 0.8)
    if r >= 15 then
        local mouthY = y + 1 * scale
        local mouthWidth = 2 * scale
        gfx.drawLine(x - mouthWidth, mouthY, x + mouthWidth, mouthY)
        gfx.drawLine(x, mouthY, x, mouthY + 0.5 * scale)
    else
        gfx.drawArc(x, y + 1 * scale, 2 * scale, 0, 180)
    end
    gfx.setColor(gfx.kColorBlack)  -- Reset to black afterward
end

-- Draw a spaceship with a tail and ears, and a wiggling tail effect.
-- The tail wiggles based on the current time, creating a dynamic effect.
local function drawSpaceship(x, y, angle, flash)
    if flash and (math.floor(respawnCooldown / 5) % 2 == 0) then return end
    local rad = math.rad(angle)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local size = 10

    local frontX = x + cosA * size
    local frontY = y + sinA * size
    local leftX = x - sinA * size * 0.6
    local leftY = y + cosA * size * 0.6
    local rightX = x + sinA * size * 0.6
    local rightY = y - cosA * size * 0.6

    gfx.drawPolygon(frontX, frontY, leftX, leftY, rightX, rightY)

    local earOffset = 4
    local earRadius = 2
    local leftEarX = frontX - sinA * earOffset
    local leftEarY = frontY + cosA * earOffset
    local rightEarX = frontX + sinA * earOffset
    local rightEarY = frontY - cosA * earOffset
    gfx.fillCircleAtPoint(leftEarX, leftEarY, earRadius)
    gfx.fillCircleAtPoint(rightEarX, rightEarY, earRadius)

    local noseOffset = 2
    local noseX = frontX - cosA * noseOffset
    local noseY = frontY - sinA * noseOffset
    gfx.fillCircleAtPoint(noseX, noseY, 1)

    local backX = (leftX + rightX) / 2
    local backY = (leftY + rightY) / 2
    local time = pd.getCurrentTimeMilliseconds() / 1000
    local wiggleOffset = math.sin(time * 10) * 3
    local tailLength = 8
    local tailEndX = backX - cosA * tailLength - sinA * wiggleOffset
    local tailEndY = backY - sinA * tailLength + cosA * wiggleOffset
    gfx.drawLine(backX, backY, tailEndX, tailEndY)
end

-- Draw a cat asteroid with cute face, adjusted ears, and wiggling whiskers.
local function drawCatAsteroid(a)
    gfx.setPattern(a.dither)
    gfx.fillCircleAtPoint(a.x, a.y, a.r)
    gfx.setPattern(whitePattern)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(a.x, a.y, a.r)
    
    local earWidth = math.max(3, a.r * 0.4)
    local earHeight = math.max(5, a.r * 0.6)
    local leftEarBaseX = a.x - a.r * 0.6
    local leftEarBaseY = a.y - a.r * 0.8
    local rightEarBaseX = a.x + a.r * 0.6
    local rightEarBaseY = a.y - a.r * 0.8
    gfx.fillTriangle(
        leftEarBaseX, leftEarBaseY,
        leftEarBaseX + earWidth, leftEarBaseY,
        leftEarBaseX + earWidth / 2, leftEarBaseY - earHeight
    )
    gfx.fillTriangle(
        rightEarBaseX, rightEarBaseY,
        rightEarBaseX - earWidth, rightEarBaseY,
        rightEarBaseX - earWidth / 2, rightEarBaseY - earHeight
    )
    
    a.face(a.x, a.y, a.r)
    
    local currentTime = pd.getCurrentTimeMilliseconds() / 1000
    local ws = a.r * 0.6        
    local wl = 5 * (a.r / 20)     
    local vo = 2 * (a.r / 20)     
    gfx.drawLine(
        a.x - ws, a.y,
        a.x - ws - wl, a.y - vo + math.sin(currentTime * 3) * vo
    )
    gfx.drawLine(
        a.x - ws, a.y + vo,
        a.x - ws - wl, a.y + vo + math.sin(currentTime * 3 + math.pi/3) * vo
    )
    gfx.drawLine(
        a.x - ws, a.y - vo,
        a.x - ws - wl, a.y - (2 * vo) + math.sin(currentTime * 3 + math.pi/6) * vo
    )
    gfx.drawLine(
        a.x + ws, a.y,
        a.x + ws + wl, a.y - vo + math.sin(currentTime * 3 + math.pi/2) * vo
    )
    gfx.drawLine(
        a.x + ws, a.y + vo,
        a.x + ws + wl, a.y + vo + math.sin(currentTime * 3 + math.pi/4) * vo
    )
    gfx.drawLine(
        a.x + ws, a.y - vo,
        a.x + ws + wl, a.y - (2 * vo) + math.sin(currentTime * 3 + math.pi/8) * vo
    )
end

local function isFarEnough(x, y, minDist)
    local dx = x - player.x
    local dy = y - player.y
    return (dx * dx + dy * dy) >= (minDist * minDist)
end

function spawnAsteroid()
    local r = math.random(8, 20)
    local attempts = 10
    local x, y
    repeat
        x = math.random(20, 380)
        y = math.random(20, 220)
        attempts = attempts - 1
    until isFarEnough(x, y, 60) or attempts <= 0

    local baseSpeed = 0.5
    local speedScale = math.min(difficulty * 0.2, 2.0)
    local speed = baseSpeed + math.random() * speedScale

    local chosenDither = ditherPatterns[math.random(#ditherPatterns)]
    local faceFunction = (chosenDither == whitePattern) and whiteCatFace or darkCatFace

    table.insert(asteroids, {
        x = x, y = y,
        vx = speed * (math.random() < 0.5 and -1 or 1),
        vy = speed * (math.random() < 0.5 and -1 or 1),
        r = r,
        face = faceFunction,
        dither = chosenDither
    })
end

function resetGame()
    score, bullets, asteroids, yarn, effects, stars = 0, {}, {}, nil, {}, {}
    lives = 9
    difficulty = 0.5
    catBalloons = {}
    for i = 1, 5 do spawnAsteroid() end
    for i = 1, 30 do
        table.insert(stars, { x = math.random(0, 400), y = math.random(0, 240), size = math.random(1, 2) })
    end
    player.x, player.y, player.vx, player.vy, player.angle = 200, 120, 0, 0, 0
    playdate.display.setInverted(false)
    playdate.display.setRefreshRate(50)

    if bgMusic and not bgMusic:isPlaying() then
        bgMusic:play(0)
    end
end

-- Draw a cat balloon with a white head, black outline, ears, whiskers, and a little face.
local function drawCatBalloon(balloon)
    local headRadius = 14
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(balloon.x, balloon.y, headRadius)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(balloon.x, balloon.y, headRadius)
    local earWidth = 6
    local earHeight = 6
    local leftEarX = balloon.x - headRadius * 0.6
    local leftEarY = balloon.y - headRadius
    local rightEarX = balloon.x + headRadius * 0.6
    local rightEarY = balloon.y - headRadius
    gfx.fillTriangle(leftEarX, leftEarY, leftEarX + earWidth, leftEarY, leftEarX + earWidth/2, leftEarY - earHeight)
    gfx.fillTriangle(rightEarX, rightEarY, rightEarX - earWidth, rightEarY, rightEarX - earWidth/2, rightEarY - earHeight)
    local whiskerLength = 10
    gfx.drawLine(balloon.x - headRadius/2, balloon.y, balloon.x - headRadius/2 - whiskerLength, balloon.y - 2)
    gfx.drawLine(balloon.x - headRadius/2, balloon.y + 3, balloon.x - headRadius/2 - whiskerLength, balloon.y + 3)
    gfx.drawLine(balloon.x + headRadius/2, balloon.y, balloon.x + headRadius/2 + whiskerLength, balloon.y - 2)
    gfx.drawLine(balloon.x + headRadius/2, balloon.y + 3, balloon.x + headRadius/2 + whiskerLength, balloon.y + 3)
    gfx.fillCircleAtPoint(balloon.x - 4, balloon.y - 2, 2)
    gfx.fillCircleAtPoint(balloon.x + 4, balloon.y - 2, 2)
    gfx.drawLine(balloon.x - 2, balloon.y + 2, balloon.x + 2, balloon.y + 2)
    local tailStartX = balloon.x
    local tailStartY = balloon.y + headRadius
    local tailLength = 40
    local segments = 6
    local segmentLength = tailLength / segments
    local tailPoints = {}
    for i = 0, segments do
        local t = i / segments
        local xOffset = math.sin((pd.getCurrentTimeMilliseconds() / 500) + balloon.wigglePhase + t * math.pi * 2) * 4
        local tailPointX = tailStartX + xOffset
        local tailPointY = tailStartY + i * segmentLength
        table.insert(tailPoints, tailPointX)
        table.insert(tailPoints, tailPointY)
    end
    for i = 1, (#tailPoints/2) - 1 do
        local idx = (i-1)*2 + 1
        local ix, iy = tailPoints[idx], tailPoints[idx+1]
        local jx, jy = tailPoints[idx+2], tailPoints[idx+3]
        gfx.drawLine(ix, iy, jx, jy)
    end
end

local function drawGameOver()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("GAME OVER", 150, 100)
    gfx.drawText("Score: " .. score, 150, 120)
    gfx.drawText("High: " .. highScore, 150, 140)
    gfx.drawText("Press A to restart", 150, 170)

    if math.random() < 0.01 then
        local side = (math.random() < 0.5) and "left" or "right"
        local x
        if side == "left" then
            x = math.random(20, 140)
        else
            x = math.random(260, 380)
        end
        local newBalloon = {
            x = x,
            y = 240,
            vy = math.random(1,2),
            wigglePhase = math.random() * 2 * math.pi
        }
        table.insert(catBalloons, newBalloon)
    end
    for i = #catBalloons, 1, -1 do
        local balloon = catBalloons[i]
        balloon.y = balloon.y - balloon.vy
        if balloon.y < 80 then
            table.remove(catBalloons, i)
        else
            drawCatBalloon(balloon)
        end
    end
end

local function updateGame()
    gfx.clear()

    if isPaused then
        gfx.drawText("PAUSED", 180, 100)
        return
    end

    if pd.getElapsedTime() % 10 < 0.05 then
        difficulty = difficulty + 0.05
    end

    if respawnCooldown > 0 then
        respawnCooldown = respawnCooldown - 1
    end

    if screenShake.timer > 0 then
        screenShake.dx = math.random(-2, 2)
        screenShake.dy = math.random(-2, 2)
        screenShake.timer = screenShake.timer - 1
    else
        screenShake.dx, screenShake.dy = 0, 0
    end

    gfx.pushContext()
    gfx.setDrawOffset(screenShake.dx, screenShake.dy)

    for _, s in ipairs(stars) do
        gfx.fillRect(s.x, s.y, s.size, s.size)
    end

    player.angle = player.angle + pd.getCrankChange()
    if pd.buttonIsPressed(pd.kButtonLeft) then player.angle = player.angle - 3 end
    if pd.buttonIsPressed(pd.kButtonRight) then player.angle = player.angle + 3 end

    local rad = math.rad(player.angle)
    if pd.buttonIsPressed(pd.kButtonUp) then
        player.vx = player.vx + math.cos(rad) * 0.2
        player.vy = player.vy + math.sin(rad) * 0.2
    elseif pd.buttonIsPressed(pd.kButtonDown) then
        player.vx = player.vx - math.cos(rad) * 0.2
        player.vy = player.vy - math.sin(rad) * 0.2
    end

    player.x = player.x + player.vx
    player.y = player.y + player.vy
    player.vx = player.vx * 0.98
    player.vy = player.vy * 0.98
    if player.x < 0 then player.x = 400 elseif player.x > 400 then player.x = 0 end
    if player.y < 0 then player.y = 240 elseif player.y > 240 then player.y = 0 end
    drawSpaceship(player.x, player.y, player.angle, respawnCooldown > 0)

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx
        b.y = b.y + b.vy
        if b.x < 0 or b.x > 400 or b.y < 0 or b.y > 240 then
            table.remove(bullets, i)
        else
            gfx.fillCircleAtPoint(b.x, b.y, 2)
        end
    end

    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        a.x = a.x + a.vx
        a.y = a.y + a.vy
        if a.x < 0 or a.x > 400 then a.vx = -a.vx end
        if a.y < 0 or a.y > 240 then a.vy = -a.vy end
        drawCatAsteroid(a)

        for j = #bullets, 1, -1 do
            local b = bullets[j]
            local dx = b.x - a.x
            local dy = b.y - a.y
            if math.sqrt(dx * dx + dy * dy) < a.r then
                local volume = math.max(0.2, math.min(1, 20 / a.r))
                sfxMeow:setVolume(volume)
                sfxMeow:play()
                local points = math.ceil(25 / a.r)
                table.insert(effects, { x = a.x, y = a.y, timer = 30, type = "meow", points = points })
                for d = 1, 6 do
                    local angle = math.rad(d * 60 + math.random(-10, 10))
                    table.insert(effects, {
                        x = a.x, y = a.y,
                        dx = math.cos(angle) * 2 + math.random(),
                        dy = math.sin(angle) * 2 + math.random(),
                        timer = 20, type = "debris"
                    })
                end
                score = score + points
                table.remove(asteroids, i)
                table.remove(bullets, j)
                break
            end
        end
    end

    for i = 1, #asteroids do
        local a1 = asteroids[i]
        for j = i + 1, #asteroids do
            local a2 = asteroids[j]
            local dx = a2.x - a1.x
            local dy = a2.y - a1.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = a1.r + a2.r

            if dist < minDist and dist > 0 then
                local nx = dx / dist
                local ny = dy / dist
                local overlap = 0.5 * (minDist - dist)
                a1.x = a1.x - nx * overlap
                a1.y = a1.y - ny * overlap
                a2.x = a2.x + nx * overlap
                a2.y = a2.y + ny * overlap

                local vx1, vy1 = a1.vx, a1.vy
                a1.vx, a1.vy = a2.vx, a2.vy
                a2.vx, a2.vy = vx1, vy1
            end
        end
    end

    local spawnChance = 0.01 + (difficulty * 0.002)
    if #asteroids < math.floor(5 + difficulty) and math.random() < spawnChance then
        spawnAsteroid()
    end

    if yarn == nil and math.random() < 0.005 then
        yarn = { x = math.random(30, 370), y = math.random(30, 210), r = 6 }
    end

    if yarn then
        gfx.drawCircleAtPoint(yarn.x, yarn.y, yarn.r)
        gfx.drawArc(yarn.x, yarn.y, yarn.r - 1, 0, 270)
        local wave = math.sin(pd.getCurrentTimeMilliseconds() / 100) * 2
        gfx.drawLine(yarn.x + 4, yarn.y + 2, yarn.x + 8, yarn.y + 2 + wave)
        gfx.drawLine(yarn.x + 8, yarn.y + 2 + wave, yarn.x + 12, yarn.y + 2 - wave)
        if math.abs(player.x - yarn.x) < 10 and math.abs(player.y - yarn.y) < 10 then
            sfxYarn:play()
            score = score + 10
            table.insert(effects, { x = yarn.x, y = yarn.y, timer = 15, type = "yarn" })
            yarn = nil
        end
    end

    if yarn then
        local dir = math.random(1, 4)
        if dir == 1 then yarn.x = yarn.x + 1 elseif dir == 2 then yarn.x = yarn.x - 1 elseif dir == 3 then yarn.y = yarn.y + 1 else yarn.y = yarn.y - 1 end
        yarn.x = math.max(10, math.min(390, yarn.x))
        yarn.y = math.max(10, math.min(230, yarn.y))
    end

    for i = #effects, 1, -1 do
        local e = effects[i]
        if e.type == "yarn" then
            gfx.drawTextAligned("+10", e.x, e.y - (30 - e.timer) / 2, kTextAlignment.center)
        elseif e.type == "meow" then
            gfx.drawTextAligned("Meow! +" .. e.points, e.x, e.y - (30 - e.timer) / 2, kTextAlignment.center)
        elseif e.type == "boom" then
            gfx.drawTextAligned("BOOM!", e.x, e.y - (30 - e.timer) / 2, kTextAlignment.center)
        elseif e.type == "sparkle" then
            for j = 0, 6 do
                local angle = (j * 60) + (15 - e.timer)
                local len = 2 + e.timer / 2
                local rad = math.rad(angle)
                gfx.drawLine(e.x, e.y, e.x + math.cos(rad) * len, e.y + math.sin(rad) * len)
            end
        elseif e.type == "debris" then
            e.x = e.x + e.dx
            e.y = e.y + e.dy
            gfx.fillRect(e.x, e.y, 2, 2)
        end
        e.timer = e.timer - 1
        if e.timer <= 0 then table.remove(effects, i) end
    end

    if respawnCooldown <= 0 then
        for _, a in ipairs(asteroids) do
            local dx = player.x - a.x
            local dy = player.y - a.y
            if math.sqrt(dx * dx + dy * dy) < player.radius + a.r then
                sfxExplosion:play()
                table.insert(effects, { x = player.x, y = player.y, timer = 30, type = "boom" })
                for d = 1, 8 do
                    local angle = math.rad(d * 45 + math.random(-15, 15))
                    table.insert(effects, {
                        x = player.x, y = player.y,
                        dx = math.cos(angle) * 2 + math.random(),
                        dy = math.sin(angle) * 2 + math.random(),
                        timer = 25, type = "debris"
                    })
                end
                screenShake.timer = 10
                lives = math.max(lives - 1, 0)
                if lives == 0 then
                    playdate.display.setInverted(true)
                    playdate.display.setRefreshRate(20)
                    pd.timer.performAfterDelay(1000, function()
                        playdate.display.setInverted(false)
                        playdate.display.setRefreshRate(50)
                        if score > highScore then
                            highScore = score
                            playdate.datastore.write(score, "highscore")
                        end
                        state = "gameover"
                    end)
                    pd.timer.new(1000, function() end)
                    state = "dead"
                else
                    player.x, player.y = 200, 120
                    player.vx, player.vy = 0, 0
                    respawnCooldown = 60
                end
                return
            end
        end
    end

    gfx.drawText("Score: " .. score .. "  High: " .. highScore, 10, 10)
    gfx.drawText("Lives: " .. lives, 300, 10)
    gfx.popContext()
    pd.timer.updateTimers()
end

function playdate.update()
    if state == "splash" then
        gfx.clear()
        astrokittyLogo:drawCentered(200, 120)
        gfx.drawText("Press A to start", 10, 200)
    elseif state == "game" or state == "dead" then
        updateGame()
    elseif state == "gameover" then
        drawGameOver()
    end
    pd.timer.updateTimers()
end

function playdate.AButtonDown()
    if state == "splash" or state == "gameover" then
        state = "game"
        isPaused = false
        resetGame()
        bgMusic:play(0)  -- Start music from the beginning
    elseif state == "game" then
        isPaused = not isPaused
        if isPaused then
            bgMusic:stop()  -- Stop music when paused
        else
            bgMusic:play(0)  -- Restart music on unpause
        end
    end
end

function playdate.BButtonDown()
    if state == "game" and not isPaused then
        local rad = math.rad(player.angle)
        table.insert(bullets, {
            x = player.x + math.cos(rad) * 12,
            y = player.y + math.sin(rad) * 12,
            vx = math.cos(rad) * 5,
            vy = math.sin(rad) * 5
        })
        sfxShoot:play()
    end
end
