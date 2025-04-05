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
local lives = 3
local isPaused = false
local respawnCooldown = 0
local difficulty = 1

-- Load assets
local astrokittyLogo = gfx.image.new("assets/logos/astrokitty_logo.png")
local sfxShoot = playdate.sound.sampleplayer.new("assets/sounds/fire.wav")
local sfxExplosion = playdate.sound.sampleplayer.new("assets/sounds/explosion.wav")
local sfxMeow = playdate.sound.sampleplayer.new("assets/sounds/meow.wav")
local bgMusic = playdate.sound.fileplayer.new("assets/music/music.wav")

-- Player
local player = { x = 200, y = 120, vx = 0, vy = 0, angle = 0, radius = 8 }

-- Game objects
local bullets, asteroids, yarn, effects, stars = {}, {}, nil, {}, {}
local screenShake = { dx = 0, dy = 0, timer = 0 }

-- Load font
local gameFont = gfx.getSystemFont(gfx.font.kVariantBold)
gfx.setFont(gameFont)

-- Cat face variants
local catFaces = {
    function(x, y)
        gfx.fillCircleAtPoint(x - 3, y - 3, 1)
        gfx.fillCircleAtPoint(x + 3, y - 3, 1)
        gfx.drawLine(x - 2, y + 2, x + 2, y + 2)
    end,
    function(x, y)
        gfx.fillCircleAtPoint(x - 3, y - 3, 1)
        gfx.fillCircleAtPoint(x + 3, y - 3, 1)
        gfx.drawCircleAtPoint(x, y + 2, 2)
    end
}

local function drawSpaceship(x, y, angle, flash)
    if flash and (math.floor(respawnCooldown / 5) % 2 == 0) then return end
    local rad = math.rad(angle)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local size = 10
    gfx.drawPolygon(
        x + cosA * size, y + sinA * size,
        x - sinA * size * 0.6, y + cosA * size * 0.6,
        x + sinA * size * 0.6, y - cosA * size * 0.6
    )
end

local function drawCatAsteroid(a)
    gfx.drawCircleAtPoint(a.x, a.y, a.r)
    catFaces[a.face](a.x, a.y)

    -- Whiskers and ears
    -- Ears scale with radius (larger ears for larger cats)
    local earWidth = math.max(3, a.r * 0.4)
    local earHeight = math.max(5, a.r * 0.6)

    -- Left ear
    gfx.fillTriangle(
        a.x - a.r + 2, a.y - a.r + 3,
        a.x - a.r + 2 + earWidth, a.y - a.r + 3,
        a.x - a.r + 2 + earWidth / 2, a.y - a.r - earHeight
    )

    -- Right ear
    gfx.fillTriangle(
        a.x + a.r - 2, a.y - a.r + 3,
        a.x + a.r - 2 - earWidth, a.y - a.r + 3,
        a.x + a.r - 2 - earWidth / 2, a.y - a.r - earHeight
    )

    gfx.drawLine(a.x - a.r, a.y, a.x - a.r - 4, a.y - 2)
    gfx.drawLine(a.x - a.r, a.y + 2, a.x - a.r - 4, a.y + 2)
    gfx.drawLine(a.x - a.r, a.y - 2, a.x - a.r - 4, a.y - 4)
    gfx.drawLine(a.x + a.r, a.y, a.x + a.r + 4, a.y - 2)
    gfx.drawLine(a.x + a.r, a.y + 2, a.x + a.r + 4, a.y + 2)
    gfx.drawLine(a.x + a.r, a.y - 2, a.x + a.r + 4, a.y - 4)

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
        attempts -= 1
    until isFarEnough(x, y, 60) or attempts <= 0

    local baseSpeed = 0.5
    local speedScale = math.min(difficulty * 0.2, 2.0) -- cap max added speed
    local speed = baseSpeed + math.random() * speedScale

    table.insert(asteroids, {
        x = x, y = y,
        vx = speed * (math.random() < 0.5 and -1 or 1),
        vy = speed * (math.random() < 0.5 and -1 or 1),
        r = r,
        face = math.random(1, #catFaces)
    })
end

function resetGame()
    score, bullets, asteroids, yarn, effects, stars = 0, {}, {}, nil, {}, {}
    lives = 3
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

local function drawGameOver()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("GAME OVER", 150, 100)
    gfx.drawText("Score: " .. score, 150, 120)
    gfx.drawText("High: " .. highScore, 150, 140)
    gfx.drawText("Press A to restart", 150, 170)
end

local function updateGame()
    gfx.clear()

    if isPaused then
        gfx.drawText("PAUSED", 180, 100)
        return
    end

    if pd.getElapsedTime() % 10 < 0.05 then
        difficulty += 0.1
    end

    if respawnCooldown > 0 then respawnCooldown -= 1 end

    if screenShake.timer > 0 then
        screenShake.dx = math.random(-2, 2)
        screenShake.dy = math.random(-2, 2)
        screenShake.timer -= 1
    else
        screenShake.dx, screenShake.dy = 0, 0
    end

    gfx.pushContext()
    gfx.setDrawOffset(screenShake.dx, screenShake.dy)

    for _, s in ipairs(stars) do gfx.fillRect(s.x, s.y, s.size, s.size) end

    player.angle += pd.getCrankChange()
    if pd.buttonIsPressed(pd.kButtonLeft) then player.angle -= 3 end
    if pd.buttonIsPressed(pd.kButtonRight) then player.angle += 3 end

    local rad = math.rad(player.angle)
    if pd.buttonIsPressed(pd.kButtonUp) then
        player.vx += math.cos(rad) * 0.2
        player.vy += math.sin(rad) * 0.2
    elseif pd.buttonIsPressed(pd.kButtonDown) then
        player.vx -= math.cos(rad) * 0.2
        player.vy -= math.sin(rad) * 0.2
    end

    player.x += player.vx
    player.y += player.vy
    player.vx *= 0.98
    player.vy *= 0.98
    if player.x < 0 then player.x = 400 elseif player.x > 400 then player.x = 0 end
    if player.y < 0 then player.y = 240 elseif player.y > 240 then player.y = 0 end
    drawSpaceship(player.x, player.y, player.angle, respawnCooldown > 0)

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x += b.vx
        b.y += b.vy
        if b.x < 0 or b.x > 400 or b.y < 0 or b.y > 240 then
            table.remove(bullets, i)
        else
            gfx.fillCircleAtPoint(b.x, b.y, 2)
        end
    end

    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        a.x += a.vx
        a.y += a.vy
        if a.x < 0 or a.x > 400 then a.vx = -a.vx end
        if a.y < 0 or a.y > 240 then a.vy = -a.vy end
        drawCatAsteroid(a)

        for j = #bullets, 1, -1 do
            local b = bullets[j]
            local dx, dy = b.x - a.x, b.y - a.y
            if math.sqrt(dx * dx + dy * dy) < a.r then
                local volume = math.max(0.2, math.min(1, 20 / a.r))
                sfxMeow:setVolume(volume)
                sfxMeow:play()
                table.insert(effects, { x = a.x, y = a.y, timer = 30, type = "boom" })
                for d = 1, 6 do
                    local angle = math.rad(d * 60 + math.random(-10, 10))
                    table.insert(effects, {
                        x = a.x, y = a.y,
                        dx = math.cos(angle) * 2 + math.random(),
                        dy = math.sin(angle) * 2 + math.random(),
                        timer = 20, type = "debris"
                    })
                end
                score += math.ceil(25 / a.r)
                table.remove(asteroids, i)
                table.remove(bullets, j)
                break
            end
        end
    end

    -- Asteroid-Asteroid collision
    for i = 1, #asteroids do
        local a1 = asteroids[i]
        for j = i + 1, #asteroids do
            local a2 = asteroids[j]
            local dx = a2.x - a1.x
            local dy = a2.y - a1.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = a1.r + a2.r

            if dist < minDist and dist > 0 then
                -- Normalize
                local nx = dx / dist
                local ny = dy / dist

                -- Push them apart
                local overlap = 0.5 * (minDist - dist)
                a1.x = a1.x - nx * overlap
                a1.y = a1.y - ny * overlap
                a2.x = a2.x + nx * overlap
                a2.y = a2.y + ny * overlap

                -- Swap velocities (basic elastic collision)
                local vx1, vy1 = a1.vx, a1.vy
                local vx2, vy2 = a2.vx, a2.vy
                a1.vx, a1.vy = vx2, vy2
                a2.vx, a2.vy = vx1, vy1
            end
        end
    end

    -- Increase difficulty gradually
    if pd.getElapsedTime() % 10 < 0.05 then
        difficulty += 0.1
    end

    -- Modify asteroid spawn logic
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
            score += 10
            table.insert(effects, { x = yarn.x, y = yarn.y, timer = 15, type = "sparkle" })
            yarn = nil
        end
    end

    -- Make yarn drift if not collected
    if yarn then
        local dir = math.random(1, 4)
        if dir == 1 then yarn.x += 1 elseif dir == 2 then yarn.x -= 1 elseif dir == 3 then yarn.y += 1 else yarn.y -= 1 end
        yarn.x = math.max(10, math.min(390, yarn.x))
        yarn.y = math.max(10, math.min(230, yarn.y))
    end

    for i = #effects, 1, -1 do
        local e = effects[i]
        if e.type == "sparkle" then
            for j = 0, 6 do
                local angle = (j * 60) + (15 - e.timer)
                local len = 2 + e.timer / 2
                local rad = math.rad(angle)
                gfx.drawLine(e.x, e.y, e.x + math.cos(rad) * len, e.y + math.sin(rad) * len)
            end
        elseif e.type == "boom" then
            gfx.drawTextAligned("BOOM!", e.x, e.y - (30 - e.timer) / 2, kTextAlignment.center)
        elseif e.type == "debris" then
            e.x += e.dx
            e.y += e.dy
            gfx.fillRect(e.x, e.y, 2, 2)
        end
        e.timer -= 1
        if e.timer <= 0 then table.remove(effects, i) end
    end

    if respawnCooldown <= 0 then
        for _, a in ipairs(asteroids) do
            local dx, dy = player.x - a.x, player.y - a.y
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
                lives -= 1
                if lives <= 0 then
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
    elseif state == "game" then
        isPaused = not isPaused
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
