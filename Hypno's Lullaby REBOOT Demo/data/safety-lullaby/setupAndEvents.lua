luaDebugMode = true

local canRetry = false
local pressedRetry = false

local SOURCE_TIME_OFFSET = 1.0
local PS = 2 / 3

local function getPlaysAsBF() -- returns true if not playing Psych Online for PE compat :)))
    if type(_G.playsAsBF) == "function" then
        local result = _G.playsAsBF()
        if result ~= nil then
            return result
        end
    end
    
    return true
end

---@param obj string "name of the game object you want to get the current animation duration of"
local function getAnimDuration(obj)
    return getProperty(obj..'.animation.curAnim.numFrames') / getProperty(obj..'.animation.curAnim.frameRate')
end

function rgbToHex(rgb)
    return string.format('%02x%02x%02x', rgb[1], rgb[2], rgb[3])
end

local GO_CAM = { scrollX = 530, scrollY = 90, zoom = 0.75, time = 4 }
local GO_FINAL_REF = { x = -69, y = 23, zoom = 2.05 }
local GO_K = GO_FINAL_REF.zoom / 1.5
local GO_RETRY_LENGTH = 4.875
local WORLD_SPIRAL_ADJUST = { 0, 175 }
local WORLD_SPIRAL_EYES = { 177, 306 }
local WORLD_SPIRAL_SCALE = 5.6215334 / 1.3
local SPIRAL_PIVOT = { 613 / 2 - 5.54, 613 / 2 - 2.65 }

local goT = nil          -- nil = game over not open
local goStage = 0
local goRetryT = nil
local goStart = {}
local goPinkDone = false
local goLoopStarted = false
local goRetryDone = false

local function goLerp(a, b, t) return a + (b - a) * t end
local function goClamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function goQuintOut(t) return 1 - (1 - t) ^ 5 end
local function goCubeOut(t) return 1 - (1 - t) ^ 3 end
local function goInOutQuad(t) if t < 0.5 then return 2 * t * t end return 1 - ((-2 * t + 2) ^ 2) / 2 end

local function goSetupLitBackground(tag)
    -- BgLight of the closeup (Mix light, darkness_gradient at texture_scale 4) via the intro's light shader
    initLuaShader('cutsceneLight')
    setSpriteShader(tag, 'cutsceneLight')
    setShaderSampler2D(tag, 'bgTex', 'safety_lullaby/cutscenes/intro/darkness_gradient')
    setShaderSampler2D(tag, 'coneTex', 'safety_lullaby/alley/awesomeahhlight')
    setShaderSampler2D(tag, 'glowTex', 'safety_lullaby/cutscenes/intro/pendulum_drop_lights')
    setShaderFloatArray(tag, 'uOrigin', { 0, 0 })
    setShaderFloatArray(tag, 'uSize', { 1280, 720 })
    setShaderFloatArray(tag, 'uFrame', { 0, 0, 1, 1 })
    setShaderFloat(tag, 'uRot', 0)
    -- node at (960, 540) + (0, 1), 1049x480 texture * 4 = 4196x1920 Godot units, Godot units / 1.5 = image px
    setShaderFloatArray(tag, 'uBg', { 640, 360 + 1 / 1.5, 4196 / 3, 1920 / 3 })
    setShaderFloatArray(tag, 'uPole', { 640, 360, 500, 370 })
    setShaderFloatArray(tag, 'uGlow', { 644, 363.33, 640, 360 })
    setShaderFloatArray(tag, 'uPoleRot', { 1, 0 })
    setShaderFloatArray(tag, 'uGlowColor', { 1, 1, 1 })
    setShaderFloatArray(tag, 'uOn', { 1, 0, 0 })
end

-- Sprites are only created here (never added to PlayState) so they cost nothing during the song.
local function goCreateSprites()
    -- the spiral that fades in around GF in the alley (world space)
    makeLuaSprite('go_worldspiral', 'safety_lullaby/gameover/hypno_spiral', 0, 0)
    scaleObject('go_worldspiral', WORLD_SPIRAL_SCALE, WORLD_SPIRAL_SCALE, false)
    setProperty('go_worldspiral.origin.x', SPIRAL_PIVOT[1])
    setProperty('go_worldspiral.origin.y', SPIRAL_PIVOT[2])
    setProperty('go_worldspiral.alpha', 0)
    setProperty('go_worldspiral.visible', false)

    -- closeup: GF gets hypnotised
    makeLuaSprite('go_gfbg', 'safety_lullaby/cutscenes/intro/gf_focus_bg', 0, 0)
    setObjectCamera('go_gfbg', 'other')
    setProperty('go_gfbg.visible', false)
    goSetupLitBackground('go_gfbg')

    -- HypnoSpiral (screen space): node (968, 592) scale 9.86256 on the 1920x1080 layer, alpha 0.85
    makeLuaSprite('go_spiral', 'safety_lullaby/gameover/hypno_spiral', 968 / 1.5 - SPIRAL_PIVOT[1], 592 / 1.5 - SPIRAL_PIVOT[2])
    setObjectCamera('go_spiral', 'other')
    scaleObject('go_spiral', 9.86256 / 1.5, 9.86256 / 1.5, false)
    setProperty('go_spiral.origin.x', SPIRAL_PIVOT[1])
    setProperty('go_spiral.origin.y', SPIRAL_PIVOT[2])
    setProperty('go_spiral.alpha', 0.85)
    setProperty('go_spiral.visible', false)

    makeAnimatedLuaSprite('go_gfcut', 'safety_lullaby/gameover/sl_gameover_gf', 287, 107)
    addAnimationByPrefix('go_gfcut', 'ohno', 'gf', 24, false)
    setObjectCamera('go_gfcut', 'other')
    scaleObject('go_gfcut', 0.89, 0.89)
    setProperty('go_gfcut.visible', false)

    -- the actual game over screen
    makeAnimatedLuaSprite('go_bg', 'safety_lullaby/gameover/BG', -104, -214)
    addAnimationByPrefix('go_bg', 'idle', 'BG', 24, true)
    setObjectCamera('go_bg', 'other')
    scaleObject('go_bg', 1.36, 1.36)
    setProperty('go_bg.visible', false)

    makeAnimatedLuaSprite('go_gfloop', 'safety_lullaby/gameover/gf_gameover_loop', 695, 150)
    addAnimationByPrefix('go_gfloop', 'quiver', 'quiver', 24, true)
    addAnimationByPrefix('go_gfloop', 'wake', 'wake', 24, false)
    setObjectCamera('go_gfloop', 'other')
    scaleObject('go_gfloop', 1.36, 1.36)
    setProperty('go_gfloop.visible', false)

    makeAnimatedLuaSprite('go_fg', 'safety_lullaby/gameover/FG', -312, -205)
    addAnimationByPrefix('go_fg', 'idle', 'FG', 24, true)
    setObjectCamera('go_fg', 'other')
    scaleObject('go_fg', 1.36, 1.36)
    setProperty('go_fg.visible', false)

    makeAnimatedLuaSprite('go_hypnohand', 'safety_lullaby/gameover/hypno_hand', 75, 100)
    addAnimationByPrefix('go_hypnohand', 'idle', 'twirl', 24, true)
    addAnimationByPrefix('go_hypnohand', 'close', 'close', 24, false)
    setObjectCamera('go_hypnohand', 'other')
    scaleObject('go_hypnohand', 1.36, 1.36)
    setProperty('go_hypnohand.visible', false)

    makeLuaSprite('go_overlay', 'safety_lullaby/gameover/Overlay', -10, -10)
    setObjectCamera('go_overlay', 'other')
    scaleObject('go_overlay', 1.36, 1.36)
    setProperty('go_overlay.visible', false)

    makeLuaSprite('go_moonglow', 'safety_lullaby/gameover/MoonGlow', -104, -214)
    setObjectCamera('go_moonglow', 'other')
    scaleObject('go_moonglow', 1.36, 1.36)
    setBlendMode('go_moonglow', 'add')
    setProperty('go_moonglow.visible', false)

    -- full screen colour rects (Godot: DoingOnTheCalculator / IsBludEinstein / IsBludEpstein)
    local rects = { { 'go_rectPink', 'DEADDD', 0.75 }, { 'go_rectGray', '5C5C5C', 1 }, { 'go_rectBlack', '000000', 1 } }
    for _, r in ipairs(rects) do
        makeLuaSprite(r[1], '', -60, -40)
        makeGraphic(r[1], 1400, 800, r[2])
        setScrollFactor(r[1], 0, 0)
        setObjectCamera(r[1], 'other')
        setProperty(r[1] .. '.alpha', r[3])
        setProperty(r[1] .. '.visible', false)
    end
end

-- GF's face in the alley, for the world spiral
local function goWorldSpiralPosition()
    local fw, fh = 537, 545
    local ex, ey = WORLD_SPIRAL_EYES[1], WORLD_SPIRAL_EYES[2]
    if getProperty('boyfriend.flipX') then ex = fw - ex end
    local ox, oy = getProperty('boyfriend.origin.x') or fw / 2, getProperty('boyfriend.origin.y') or fh / 2
    local sx, sy = getProperty('boyfriend.scale.x') or 1, getProperty('boyfriend.scale.y') or 1
    local x = getProperty('boyfriend.x') - getProperty('boyfriend.offset.x') + ox + (ex - ox) * sx
    local y = getProperty('boyfriend.y') - getProperty('boyfriend.offset.y') + oy + (ey - oy) * sy
    return x + WORLD_SPIRAL_ADJUST[1], y + WORLD_SPIRAL_ADJUST[2]
end

-- Godot Camera2D (position in world units, zoom) -> camOther scroll / zoom for the final scene layout
local function goFinalCamera(cx, cy, zoom)
    setProperty('camOther.scroll.x', (cx - GO_FINAL_REF.x) * GO_K)
    setProperty('camOther.scroll.y', (cy - GO_FINAL_REF.y) * GO_K)
    setProperty('camOther.zoom', zoom / GO_FINAL_REF.zoom)
end

local function goAlleyCamera(t)
    -- camera moves in on GF while the HUD fades out (0.5 s, ease in)
    local k = goClamp(t / GO_CAM.time, 0, 1)
    setProperty('camGame.scroll.x', goLerp(goStart.scrollX, GO_CAM.scrollX, goQuintOut(k)))
    setProperty('camGame.scroll.y', goLerp(goStart.scrollY, GO_CAM.scrollY, goQuintOut(k)))
    setProperty('camGame.zoom', goLerp(goStart.zoom, GO_CAM.zoom, goCubeOut(k)))
    local h = goClamp(t / 0.5, 0, 1)
    setProperty('camHUD.alpha', 1 - h * h)
end

local function goTimeline(t)
    -- world spiral: fades in 0.958 -> 3.333 (ease out), spins once until the closeup
    if goStage < 1 then
        local k = goClamp((t - 0.958) / (3.333 - 0.958), 0, 1)
        local a = 0.663 * (1 - (1 - k) ^ (1 / 0.8122523))
        local x, y = goWorldSpiralPosition()
        setProperty('go_worldspiral.x', x - SPIRAL_PIVOT[1])
        setProperty('go_worldspiral.y', y - SPIRAL_PIVOT[2])
        setProperty('go_worldspiral.angle', math.deg(2 * math.pi * t / 3.5833333))
        setProperty('go_worldspiral.alpha', a)
        setProperty('go_worldspiral.visible', a > 0.001)
    end

    if goStage < 1 and t >= 3.5833333 then
        goStage = 1
        setProperty('go_worldspiral.visible', false)
        setProperty('go_gfbg.visible', true)
        setProperty('go_spiral.visible', true)
        setProperty('go_gfcut.visible', true)
        playAnim('go_gfcut', 'ohno', true)
        setProperty('camGame.visible', false)
    end
    if goStage == 1 then
        -- closeup spiral: 0 -> 2.939 rad between 3.583 and 5.917
        local k = goClamp((t - 3.5833333) / (5.9166665 - 3.5833333), 0, 1)
        setProperty('go_spiral.angle', math.deg(2.9391344 * k))
    end

    if goStage < 2 and t >= 6 then
        goStage = 2
        for _, tag in ipairs({ 'go_gfbg', 'go_spiral', 'go_gfcut' }) do setProperty(tag .. '.visible', false) end
        for _, tag in ipairs({ 'go_bg', 'go_gfloop', 'go_fg', 'go_hypnohand', 'go_overlay', 'go_moonglow', 'go_rectGray', 'go_rectBlack' }) do
            setProperty(tag .. '.visible', true)
        end
        playAnim('go_bg', 'idle', true)
        playAnim('go_gfloop', 'quiver', true)
        playAnim('go_fg', 'idle', true)
        playAnim('go_hypnohand', 'idle', true)
    end
    if goStage == 2 then
        -- black fades out 6.667 -> 8.0 over the grey, then one pink flash frame, then the scene shows
        if t < 8 then
            setProperty('go_rectBlack.alpha', 1 - goClamp((t - 6.6666665) / (8 - 6.6666665), 0, 1))
        else
            setProperty('go_rectGray.visible', false)
            setProperty('go_rectBlack.visible', false)
            if not goPinkDone then
                goPinkDone = true
                setProperty('go_rectPink.visible', true)
            elseif t >= 8.0416665 then
                setProperty('go_rectPink.visible', false)
            end
        end

        -- camera keys (constant between keys, like the Godot animation)
        if t < 9.0833 then
            goFinalCamera(63, -9, 4.5)
        elseif t < 9.1666 then
            goFinalCamera(41, 0, 4.3)
        elseif t < 9.25 then
            goFinalCamera(-65, 23, 2.05)
        else
            goFinalCamera(-69, 23, 2.1)
        end
    end

    if not goLoopStarted and t >= 9.21 then
        goLoopStarted = true
        playMusic('gameover_sl_loop', 1, true)
        canRetry = true
    end
end

local function goRetry(elapsed)
    goRetryT = goRetryT + elapsed
    local r = goRetryT

    -- camera: hold, slight zoom out, then push in and slide right (ease in-out) while fading to black
    local cx, cy, zoom = -69, 23, 2.1
    if r >= 1 then
        local k = goClamp((r - 1) / (3.4166667 - 1), 0, 1)
        local e = goInOutQuad(k)
        cx = goLerp(-69, 80, e)
        zoom = goLerp(2.05, 3.01, e)
        setProperty('go_rectBlack.visible', true)
        setProperty('go_rectBlack.alpha', k * k)
    elseif r > 0.2916667 then
        zoom = goLerp(2.1, 2.05, (r - 0.2916667) / (1 - 0.2916667))
    end
    goFinalCamera(cx, cy, zoom)

    if r >= GO_RETRY_LENGTH and not goRetryDone then
        goRetryDone = true
        restartSong()
    end
end

local function goStartRetry()
    pressedRetry = true
    goRetryT = 0
    goRetryDone = false
    playMusic('sl_retry', 1, false) -- replaces the loop
    playAnim('go_gfloop', 'wake', true)
    setProperty('go_gfloop.y', getProperty('go_gfloop.y') + 9 * GO_K) -- Godot GF:offset (0, 9) during the retry
    playAnim('go_hypnohand', 'close', true)
    setProperty('go_rectBlack.visible', false)
    setProperty('go_rectBlack.alpha', 0)
end


function onCreate()
    setProperty('skipCountdown', true)

    makeLuaSprite('endBg', 'safety_lullaby/cutscenes/end/end_bg', 0, 0)
    setObjectCamera('endBg', 'hud')
    scaleObject('endBg', 0.39, 0.39)
    setProperty('endBg.alpha', 0.0001)
    setProperty('endBg.color', '000000')
    addLuaSprite('endBg')

    setBlendMode('gf', 'add')

    goCreateSprites()
end

function onCreatePost()
    setObjectCamera('gfGroup', 'hud')
    setProperty('gf.x', 310)
    setProperty('gf.y', 10)
    setProperty('gf.alpha', 0.0001)
    setVar('safetyLullabyEndingActive', false)

    if getPlaysAsBF() then -- hide opponent strums if not playing as opponent
        for i = 0,getProperty('opponentStrums.length') - 1 do
            setPropertyFromGroup('opponentStrums', i, 'x', -5000)
        end
    end
    runHaxeCode([[if (game.noteUnderlays != null) game.noteUnderlays.visible = false;]]) -- hide note underlane for aestheticsss
    setProperty('timeBar.visible', false)
    setProperty('timeTxt.visible', false)
    setProperty('scoreTxt.scale.x', getProperty('scoreTxt.scale.x') / 1.1)
    setProperty('scoreTxt.scale.y', getProperty('scoreTxt.scale.y') / 1.1)

    setProperty('camZoomingDecay', 0.25) -- slower cam zooming
    setProperty('camZoomingMult', 0)
    setProperty('camZooming', true)
    
    runHaxeCode( -- hide multiple players, only show dad
    [[
        for (m in game.dadGroup.members)
            if (m != game.dad) m.visible = false;
    ]])

    -- epic health bar
    runHaxeCode([[
        game.healthBar.bg.loadGraphic(Paths.image('safety_lullaby/bar/bar'));
    ]])
    setProperty('healthBar.bg.offset.x', 75)
    setProperty('healthBar.bg.offset.y', 35)
    setProperty('healthBar.leftBar.visible', false)
    setProperty('healthBar.rightBar.visible', false)
    makeLuaSprite('healthBarMaskRight', 'safety_lullaby/bar/barmask', getProperty('healthBar.x') - 54, getProperty('healthBar.y') - 11)
    makeLuaSprite('healthBarMaskLeft', 'safety_lullaby/bar/barmask', getProperty('healthBar.x') - 54, getProperty('healthBar.y') - 11)
    setObjectCamera('healthBarMaskRight', 'hud')
    addLuaSprite('healthBarMaskRight')
    setObjectCamera('healthBarMaskLeft', 'hud')
    addLuaSprite('healthBarMaskLeft')

    runHaxeCode([[
        var leftMask = game.getLuaObject('healthBarMaskLeft');
        var rightMask = game.getLuaObject('healthBarMaskRight');

        if (game.uiGroup != null) {
            if (leftMask != null) {
                leftMask.cameras = [game.camHUD];
                game.uiGroup.insert(0, leftMask);
            }
            if (rightMask != null) {
                rightMask.cameras = [game.camHUD];
                game.uiGroup.insert(0, rightMask);
            }
        }
        
        var hb = game.healthBar;
        if (hb != null) {
            var newWidth = 720; // Desired bar/icon travel width
            var delta = hb.barWidth - newWidth;
            hb.barWidth = newWidth;
            // Shift barOffset.x by half the difference to keep it centered
            hb.barOffset.x += delta * 0.5;
        }
    ]])
    
    addHealth(0.000000001) -- update health to apply bar width for icons

    if dadName == 'hypno' then
        runHaxeCode('game.iconP2.changeIcon("hypnoDark");')
    end

    setProperty('healthBarMaskLeft.color', getColorFromHex(rgbToHex(getProperty('dad.healthColorArray'))))
    setProperty('healthBarMaskRight.color', getColorFromHex(rgbToHex(getProperty('boyfriend.healthColorArray'))))
end

function onUpdate()
    scaleObject('healthBarMaskLeft', 1 - (getHealth() / 2), 1)
end

function onBeatHit()
    if curBeat >= 72 then        
        if curBeat % 2 == 0 then
            triggerEvent('Add Camera Zoom', '0.015', '0')
        end
    end
end

function onEvent(name, value1, value2)
    if name == 'Hypno Icon' then
        if dadName == 'hypno' then
            runHaxeCode([[game.iconP2.changeIcon("]] .. value1 .. [[");]])
            addHealth(0.0000000001) -- icon doesn't update neutral/lose state unless health changes......
        end
    end
    if name == 'Hypno Step Forward' then
        --debugPrint('walk damnit')
        triggerEvent('Play Animation', 'step', 'dad')
        runTimer('hypnoSnapForward', getAnimDuration('dad') - 0.001)
    end
    if name == 'Transition to Ending' then
        setObjectOrder('endBg', getObjectOrder('pndHand') + 1)
        setObjectOrder('gfGroup', getObjectOrder('endBg') + 1)
        doTweenAlpha('endBgIn', 'endBg', 1, 1.5, 'linear')
        doTweenZoom('camGameIn', 'camGame', 0.9, 1.4, 'smoothStepIn')

        for i = 0,getProperty('opponentStrums.length') - 1 do
            noteTweenAlpha('playerStrumOut'..i, i + 4, 0, 1, 'linear')
        end

        doTweenAlpha('scoreTxtOut', 'scoreTxt', 0, 1, 'linear')
        doTweenAlpha('healthBarOut', 'healthBar', 0, 1, 'linear')
        doTweenAlpha('healthMaskLOut', 'healthBarMaskLeft', 0, 1, 'linear')
        doTweenAlpha('healthMaskROut', 'healthBarMaskRight', 0, 1, 'linear')
        doTweenAlpha('iconP1Out', 'iconP1', 0, 1, 'linear')
        doTweenAlpha('iconP2Out', 'iconP2', 0, 1, 'linear')
    end
    if name == 'Fade In Ending' then
        setProperty('camGame.visible', false)
        setBlendMode('endBg', 'add')
        setVar('safetyLullabyEndingLightingOff', true)
        setVar('safetyLullabyEndingActive', true)
        setObjectCamera('pndHandTrail', 'hud')
        setObjectCamera('pndHandActive', 'hud')
        setObjectOrder('pndHandTrail', getObjectOrder('gfGroup') + 1)
        setObjectOrder('pndHandActive', getObjectOrder('gfGroup') + 2)
        doTweenColor('endBgColor', 'endBg', getColorFromHex('FFFFFF'), 1.5, 'linear')
        doTweenAlpha('hypnoIn', 'gf', 1, 1.5, 'linear')
    end
    if name == 'Ending Move Start' then
        doTweenX('endBgZoomX', 'endBg.scale', getProperty('endBg.scale.x') * 1.5, 17, 'linear')
        doTweenY('endBgZoomY', 'endBg.scale', getProperty('endBg.scale.y') * 1.5, 17, 'linear')
        doTweenX('hypnoShrinkX', 'gf.scale', 0.65, 12, 'quadIn')
        doTweenY('hypnoShrinkY', 'gf.scale', 0.65, 12, 'quadIn')
        doTweenX('hypnoDriftX', 'gf', getProperty('gf.x') - 5 * PS, 12, 'quadIn')
        doTweenY('hypnoDriftY', 'gf', getProperty('gf.y') - 93 * PS, 12, 'quadIn')
    end
    if name == 'Hypno Fade Away' then
        doTweenAlpha('hypnoDarkFade', 'gf', 0, 5, 'quadOut')
    end
    if name == 'Ending BG Darken' then
        doTweenColor('endBgToDark', 'endBg', '000000', 5, 'quadIn')
    end
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'hypnoSnapForward' then
        triggerEvent('Play Animation', 'idle-alt', 'dad')
        setProperty('dad.x', getProperty('dad.x') + 66)
        setProperty('dad.cameraPosition[0]', getProperty('dad.cameraPosition[0]') - 66)
    end
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    triggerEvent('Play Animation', getProperty('singAnimations')[direction + 1], 'gf')
end

function onGameOver()
	openCustomSubstate('gameover', true)

	return Function_Stop
end

function onCustomSubstateCreate(name)
	if name == 'gameover' then
        goT, goStage, goRetryT = 0, 0, nil
        goPinkDone, goLoopStarted, goRetryDone = false, false, false
        pressedRetry, canRetry = false, false

        callOnLuas('hideCamOther')
        runHaxeCode([[
            game.variables.set('boyfriend', game.boyfriendGroup);
            game.boyfriendGroup.cameras = [game.camGame];
            game.boyfriend.specialAnim = true;
            game.boyfriend.playAnim('game over', true);
            game.camGame.target = null; // nothing may move the alley camera any more, the script drives it
        ]])

        -- draw order: world spiral behind GF, then everything on camOther
        insertToCustomSubstate('go_worldspiral')
        setObjectCamera('go_worldspiral', 'game')
        insertToCustomSubstate('boyfriend')
        for _, tag in ipairs({ 'go_gfbg', 'go_spiral', 'go_gfcut', 'go_bg', 'go_gfloop', 'go_fg', 'go_hypnohand',
            'go_overlay', 'go_moonglow', 'go_rectPink', 'go_rectGray', 'go_rectBlack' }) do
            insertToCustomSubstate(tag)
        end

        -- camOther may still carry the intro cutscene's zoom
        setProperty('camOther.zoom', 1)
        setProperty('camOther.scroll.x', 0)
        setProperty('camOther.scroll.y', 0)
        setProperty('camOther.alpha', 1)

        goStart = {
            scrollX = getProperty('camGame.scroll.x'), scrollY = getProperty('camGame.scroll.y'),
            zoom = getProperty('camGame.zoom'),
        }
        setProperty('camGame.alpha', 1)

        playSound('gameover_sl')
    end
end

function onCustomSubstateUpdatePost(name, elapsed)
    if name ~= 'gameover' or goT == nil then return end

    goT = goT + elapsed
    goAlleyCamera(goT)
    goTimeline(goT)
    if goRetryT ~= nil then goRetry(elapsed) end

    if not pressedRetry and canRetry and keyJustPressed('accept') then
        goStartRetry()
    end
    if not pressedRetry and keyJustPressed('back') then
        exitSong()
    end
end
