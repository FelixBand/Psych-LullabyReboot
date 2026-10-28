luaDebugMode = true

local function getPlaysAsBF() -- returns true if not playing Psych Online for PE compat :)))
    if type(_G.playsAsBF) == "function" then
        local result = _G.playsAsBF()
        if result ~= nil then
            return result
        end
    end
    
    return true
end

function onCreate()
    setProperty('skipCountdown', true)

    makeAnimatedLuaSprite('goldPukeBody', 'characters/gold/gold_puke', getProperty('dad.x') + 57, getProperty('dad.y') - 73)
    addAnimationByPrefix('goldPukeBody', 'puke', 'body', 24, false)
    scaleObject('goldPukeBody', 1.13, 1.13)
    setProperty('goldPukeBody.alpha', 0.0001)
    addLuaSprite('goldPukeBody', true)

    makeAnimatedLuaSprite('goldPukeHead', 'characters/gold/gold_puke', getProperty('goldPukeBody.x') - 88, getProperty('goldPukeBody.y') - 120)
    addAnimationByPrefix('goldPukeHead', 'puke', 'head0', 24, false)
    addAnimationByPrefix('goldPukeHead', 'puke-alt', 'head-alt0', 24, false)
    scaleObject('goldPukeHead', 1.13, 1.13)
    setProperty('goldPukeHead.alpha', 0.0001)
    addLuaSprite('goldPukeHead', true)

    makeAnimatedLuaSprite('headrip', 'characters/gold/head_rip', (getProperty('dad.x') - 357) + 50, getProperty('dad.y') - 370)
    addAnimationByPrefix('headrip', 'rip', 'mono_head_rip', 24, false)
    setProperty('headrip.alpha', 0.0001)
    addLuaSprite('headrip', true)

    makeAnimatedLuaSprite('jumpscareP1', 'characters/gold/jumpscarep1', 70, -60)
    addAnimationByPrefix('jumpscareP1', 'triple0', 'triple_first', 24, false)
    addAnimationByPrefix('jumpscareP1', 'triple1', 'triple_second', 24, false)
    addAnimationByPrefix('jumpscareP1', 'jumpFaster', 'jumpscare', 32, false)
    addAnimationByPrefix('jumpscareP1', 'jump', 'jumpscare', 24, false)
    setObjectCamera('jumpscareP1', 'other')
    scaleObject('jumpscareP1', 1, 1)
    setProperty('jumpscareP1.alpha', 0.0001)
    addLuaSprite('jumpscareP1', true)

    makeAnimatedLuaSprite('jumpscareP2', 'characters/gold/jumpscarep2', 180, -40)
    addAnimationByIndices('jumpscareP2', 'buildup0', 'buildup', '0,1,2', 12, false)
    addAnimationByIndices('jumpscareP2', 'buildup1', 'buildup', '3,4,5', 12, false)
    addAnimationByIndices('jumpscareP2', 'buildup2', 'buildup', '6,7,8', 12, false)
    addAnimationByIndices('jumpscareP2', 'jump', 'jumpscare', '0,1,2,3,2,3,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17', 12, false)
    setObjectCamera('jumpscareP2', 'other')
    scaleObject('jumpscareP2', 0.9, 0.9)
    setProperty('jumpscareP2.alpha', 0.0001)
    addLuaSprite('jumpscareP2', true)

    -- blood splatters on gold and bf's blood characters
    makeAnimatedLuaSprite('goldbloodsplatter', 'characters/gold/gold_blood_splatter', 100, 50)
    addAnimationByPrefix('goldbloodsplatter', 'idle', 'idle', 8, true)
    addAnimationByPrefix('goldbloodsplatter', 'singLEFT', 'left', 8, false)
    addAnimationByPrefix('goldbloodsplatter', 'singDOWN', 'down', 8, false)
    addAnimationByPrefix('goldbloodsplatter', 'singUP', 'up', 8, false)
    addAnimationByPrefix('goldbloodsplatter', 'singRIGHT', 'right', 8, false)
    setObjectCamera('goldbloodsplatter', 'hud')
    setProperty('goldbloodsplatter.alpha', 0.00001)
    addLuaSprite('goldbloodsplatter')

    makeAnimatedLuaSprite('bfbloodsplatter', 'characters/bf/bf_blood_splatter', 650, 50)
    addAnimationByPrefix('bfbloodsplatter', 'idle', 'idle', 8, true)
    addAnimationByPrefix('bfbloodsplatter', 'singLEFT', 'left', 8, false)
    addAnimationByPrefix('bfbloodsplatter', 'singDOWN', 'down', 8, false)
    addAnimationByPrefix('bfbloodsplatter', 'singUP', 'up', 8, false)
    addAnimationByPrefix('bfbloodsplatter', 'singRIGHT', 'right', 8, false)
    setObjectCamera('bfbloodsplatter', 'hud')
    setProperty('bfbloodsplatter.alpha', 0.00001)
    addLuaSprite('bfbloodsplatter')
end

function onCreatePost()
    setProperty('camFollowPos.x', -456.5)
    setProperty('camFollowPos.y', -47.25)

    setProperty('cameraSpeed', 2)

    -- blood gold and bf
        setObjectCamera('boyfriend', 'hud')
        setProperty('boyfriend.x', 620)
        setProperty('boyfriend.y', 45)

        setObjectCamera('gf', 'hud')
        setProperty('gf.x', 110)
        setProperty('gf.y', 45)
    --

    setProperty('boyfriendGroup.visible', false)
    setProperty('gfGroup.visible', false)

    setProperty('dad.color', getColorFromHex('808080'))

    triggerEvent('Camera Follow Pos', '183', '312')

    debugPrint(getPlaysAsBF())

    if getPlaysAsBF() then -- hide opponent strums if not playing as opponent
        for i = 0,getProperty('opponentStrums.length') - 1 do
            setPropertyFromGroup('opponentStrums', i, 'x', -5000)
        end
    end
    setProperty('healthBar.visible', false)
    setProperty('iconP1.visible', false)
    setProperty('iconP2.visible', false)
    setProperty('scoreTxt.visible', false)
    setProperty('timeBar.visible', false)
    setProperty('timeTxt.visible', false)
    runHaxeCode([[if (game.noteUnderlays != null) game.noteUnderlays.visible = false;]])

    setProperty('showRating', false)
    setProperty('showComboNum', false)

    for i = 0, getProperty('unspawnNotes.length') - 1 do
        local strumTime = getPropertyFromGroup('unspawnNotes', i, 'strumTime')
        local mustPress = getPropertyFromGroup('unspawnNotes', i, 'mustPress')
        if strumTime >= 363536 and not mustPress then
            setPropertyFromGroup('unspawnNotes', i, 'noAnimation', true) -- as to not interrupt the ending break animation
        end
        if strumTime >= 295818 and strumTime <= 328727 and not mustPress then
            setPropertyFromGroup('unspawnNotes', i, 'noteType', 'GF Sing') -- blood gold is gf
        end
    end
end

function onUpdate(elapsed)
    setProperty('camZooming', false)
end

local scareType = 0

local function tripleScare(which, duration)
    setProperty('camGame.visible', false)
    setProperty('camHUD.visible', false)
    setProperty('camOther.visible', false)
    scareType = which
    runTimer('darkFlashEnd', duration)
end

local function jumpBlur(amount, duration, cam)
    if cam == 'game' or cam == 'both' then
        doTweenX('gameBlurUp', 'gameHUDblurController', amount, duration, 'linear')
    end
    if cam == 'other' or cam == 'both' then
        doTweenX('otherBlurUp', 'otherBlurController', amount, duration, 'linear')
    end
end

---@param obj string "name of the game object you want to get the current animation duration of"
local function getAnimDuration(obj)
    return getProperty(obj..'.animation.curAnim.numFrames') / getProperty(obj..'.animation.curAnim.frameRate')
end

---@param tag string "name of the timer"
---@param obj string "name of the game object you want to get the current animation duration of"
local function animEndTimer(tag, obj)
    runTimer(tag, getAnimDuration(obj))
end

local function jumpscare(type)
    
    setProperty('dadGroup.visible', false)
    if dadName == 'goldp1' or dadName == 'goldp1-alt' then
        setProperty('jumpscareP1.alpha', 1)
        if type == '1' then
            setProperty('jumpscareP1.x', 680)
            setProperty('jumpscareP1.y', 50)
            playAnim('jumpscareP1', 'triple0', true)
        elseif type == '2' then
            setProperty('jumpscareP1.x', -100)
            setProperty('jumpscareP1.y', 100)
            playAnim('jumpscareP1', 'triple1', true)
        elseif type == '3' then
            setProperty('jumpscareP1.x', 70)
            setProperty('jumpscareP1.y', -60)
            playAnim('jumpscareP1', 'jumpFaster', true)
            animEndTimer('jumpscareEnd', 'jumpscareP1')
            jumpBlur(0.10, 0.1, 'both')
        elseif type == '4' then
            setProperty('jumpscareP1.x', 70)
            setProperty('jumpscareP1.y', -60)
            playAnim('jumpscareP1', 'jump', true)
            animEndTimer('startP2', 'jumpscareP1')
            jumpBlur(0.10, 0.1, 'both')
        else
            setProperty('jumpscareP1.x', 70)
            setProperty('jumpscareP1.y', -60)
            playAnim('jumpscareP1', 'jump', true)
            animEndTimer('jumpscareEnd', 'jumpscareP1')
            jumpBlur(0.10, 0.1, 'both')
        end
    elseif dadName == 'goldp2' then
        setProperty('jumpscareP2.alpha', 1)
        setProperty('jumpscareP2.scale.x', 0.5)
        setProperty('jumpscareP2.scale.y', 0.5)
        if type == '1' then
            setProperty('jumpscareP2.x', -100)
            setProperty('jumpscareP2.y', -40)
            playAnim('jumpscareP2', 'buildup0', true)
        elseif type == '2' then
            setProperty('jumpscareP2.x', -200)
            setProperty('jumpscareP2.y', -80)
            playAnim('jumpscareP2', 'buildup1', true)
        elseif type == '3' then
            setProperty('jumpscareP2.x', -195)
            setProperty('jumpscareP2.y', -130)
            playAnim('jumpscareP2', 'buildup2', true)
        elseif type == 'fakeout' then
            setProperty('jumpscareP2.alpha', 0)
            setProperty('dadGroup.visible', true)
        elseif type == '4' or type == '0' then
            setProperty('jumpscareP2.x', 212)
            setProperty('jumpscareP2.y', -33)
            setProperty('jumpscareP2.scale.x', 0.95)
            setProperty('jumpscareP2.scale.y', 0.95)
            playAnim('jumpscareP2', 'jump', true)
            --runTimer('jumpscareEnd', 1.75)
            animEndTimer('jumpscareEnd', 'jumpscareP2')
            --cameraShake('other', 0.005, 1.75)
            cameraShake('other', 0.005, getAnimDuration('jumpscareP2'))
            jumpBlur(0.15, 0.1, 'game')
        end
    end
end

function onEvent(name, value1, value2, strumTime)
    if name == 'End Intro Cutscene' then -- for debug
        cancelTween('camIn1')
        cancelTween('camIn2')
        setProperty('camGame.zoom', 0.66)
        setProperty('defaultCamZoom', 0.66)
        removeLuaSprite('celebifly')
        removeLuaSprite('introbg4')
        setProperty('camGame.alpha', 1)
    end

    if name == 'Gold Fade In' then
        doTweenColor('goldIn', 'dad', 'FFFFFF', 1, 'cubeIn')
    end
    if name == 'HUD Fade In' then
        doTweenAlpha('hudIn', 'camHUD', 1, 3, 'linear')
    end
    if name == 'Notes Fade In' then
        for i = 0,getProperty('playerStrums.length') - 1 do
            noteTweenAlpha('strumIn'..i, getProperty('playerStrums.length') + i, 1, 3, 'linear')
        end
    end
    if name == 'Game Fade In' then
        doTweenAlpha('gameIn', 'camGame', 1, 0.5, 'linear')
    end
    if name == 'Fade Out' then
        doTweenAlpha('hudOut', 'camHUD', 0, 0.5, 'linear')
    end
    if name == 'Fade In' then
        removeLuaSprite('bloodbg')
        removeLuaSprite('bloodheadoff')
        removeLuaSprite('handstransition')
        setProperty('camHUD.alpha', 1)
        setProperty('camOther.alpha', 1)
        doTweenAlpha('gameIn', 'camGame', 1, 0.6, 'cubeIn')
        setProperty('gameHUDblurController.x', 0.0175)
        setProperty('kingseye.alpha', 1)
    end
    if name == 'Puke' then
        --runTimer('pukeEnd', 2.15)
        setProperty('goldPukeBody.alpha', 1)
        setProperty('goldPukeHead.alpha', 1)
        setProperty('dadGroup.visible', false)
        playAnim('goldPukeBody', 'puke', true)
        playAnim('goldPukeHead', 'puke' .. value1, true)
        if value1 == '-alt' then
            runTimer('correctHeadY', 1.6)
            setProperty('goldPukeHead.x', getProperty('goldPukeBody.x') - 115)
        else
            setProperty('goldPukeHead.x', getProperty('goldPukeBody.x') - 88)
            setProperty('goldPukeHead.y', getProperty('goldPukeBody.y') - 120)
        end
        animEndTimer('pukeEnd', 'goldPukeBody')
    end
    if name == 'Jumpscare' then
        if value1 ~= '0' and value1 ~= '4' then
            tripleScare(value1, 0.05)
        else
            jumpscare(value1)
        end
    end

    if name == 'JumpscareP2' then
        if value1 ~= '0' then
            tripleScare(value1, 0.05)
        else
            jumpscare(value1)
        end
    end

    if name == 'start zooming' then
        setProperty('defaultCamZoom', 0.8)
        doTweenZoom('zoomIn', 'camGame', 0.8, 8, 'cubeInOut')
    end
    if name == 'undo zoom' then
        cancelTween('zoomIn')
        setProperty('defaultCamZoom', 0.64)
        setProperty('camGame.zoom', 0.64)
    end
    if name == 'Unowns Flutter' then
        local splitX, splitY = string.match(value2, "([^,]+),([^,]+)")
        local splitAngle, splitSize = string.match(value1, "([^,]+),([^,]+)")
        
        setProperty('bgunownsfly.angle', tonumber(splitAngle))
        setProperty('bgunownsfly.scale.x', tonumber(splitSize))
        setProperty('bgunownsfly.scale.y', tonumber(splitSize))
        setProperty('bgunownsfly.x', tonumber(splitX))
        setProperty('bgunownsfly.y', tonumber(splitY))
        playAnim('bgunownsfly', 'fly', true)
    end
    if name == 'open kingseye' then
        playAnim('kingseye', 'open', true)
    end
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'darkFlashEnd' then
        setProperty('camGame.visible', true)
        setProperty('camHUD.visible', true)
        setProperty('camOther.visible', true)

        jumpscare(scareType)
    end

    if tag == 'pukeEnd' then
        setProperty('dadGroup.visible', true)
        setProperty('goldPukeBody.alpha', 0)
        setProperty('goldPukeHead.alpha', 0)
    end
    if tag == 'jumpscareEnd' then
        setProperty('dadGroup.visible', true)
        triggerEvent('Play Animation', 'jumpscareEnd', 'dad')
        setProperty('jumpscareP1.alpha', 0)
        setProperty('jumpscareP2.alpha', 0)
    end
    if tag == 'startP2' then
        playAnim('headrip', 'rip')
        setProperty('headrip.alpha', 1)
        setProperty('jumpscareP1.alpha', 0)
        runTimer('showGoldP2', 4.5)
        setProperty('defaultCamZoom', 0.45)
        doTweenZoom('zoomOut', 'camGame', 0.45, 5, 'cubeInOut')
    end
    if tag == 'showGoldP2' then
        setProperty('dadGroup.visible', true)
    end
    if tag == 'correctHeadY' then
        setProperty('goldPukeHead.y', getProperty('goldPukeBody.y') - 215)
    end
end

function onTweenCompleted(tag)
    if tag == 'zoomOut' then
        setProperty('defaultCamZoom', 0.64)
        doTweenZoom('zoomIn', 'camGame', 0.64, 25, 'cubeInOut')
    end
    if tag == 'otherBlurUp' then
        doTweenX('otherBlurOff', 'otherBlurController', 0, 2, 'cubeOut')
    end
    if tag == 'gameBlurUp' then
        doTweenX('gameBlurOff', 'gameHUDblurController', 0, 2, 'cubeOut')
    end
end

local function setSplashOpacity(alpha)
    runHaxeCode([[
        for (s in game.grpNoteSplashes.members)
            if (s != null && s.exists && s.animation.curAnim != null && !s.animation.curAnim.finished)
                s.alpha = ]]..alpha..[[;
    ]])
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    setSplashOpacity(1)

    if not isSustainNote then
        playAnim('bfbloodsplatter', getProperty('singAnimations')[direction+1])
    end
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    setSplashOpacity(1)

    if not isSustainNote then
        playAnim('goldbloodsplatter', getProperty('singAnimations')[direction+1])
    end
end