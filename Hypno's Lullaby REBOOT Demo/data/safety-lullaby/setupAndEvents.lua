luaDebugMode = true

local SOURCE_TIME_OFFSET = 1.0
local PS = 2 / 3
local ENDING_MOVE_START = 181.1
local ENDING_FADE_START = 184.1
local ENDING_DARKEN_START = 191.86667
local ENDING_ZOOM_DURATION = 198 - ENDING_MOVE_START
local ENDING_HYPNO_DURATION = 193.13333 - ENDING_MOVE_START
local endingMotionStarted = false
local endingFadeStarted = false
local endingDarkenStarted = false

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

function onCreate()
    setProperty('skipCountdown', true)

    makeLuaSprite('endBg', 'safety_lullaby/cutscenes/end/end_bg', 0, 0)
    setObjectCamera('endBg', 'hud')
    scaleObject('endBg', 0.39, 0.39)
    setProperty('endBg.alpha', 0.0001)
    setProperty('endBg.color', '000000')
    addLuaSprite('endBg')
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
    runHaxeCode([[if (game.noteUnderlays != null) game.noteUnderlays.visible = false;]])
    setProperty('timeBar.visible', false)
    setProperty('timeTxt.visible', false)
end

function onEvent(name, value1, value2)
    if name == 'Hypno Step Forward' then
        --debugPrint('walk damnit')
        triggerEvent('Play Animation', 'step', 'dad')
        runTimer('hypnoSnapForward', getAnimDuration('dad') - 0.001)
    end
    if name == 'Transition to Ending' then
        setObjectOrder('endBg', getObjectOrder('pndTrail') + 1)
        setObjectOrder('gfGroup', getObjectOrder('endBg') + 1)
        doTweenAlpha('endBgIn', 'endBg', 1, 1.5, 'linear')
        doTweenZoom('camGameIn', 'camGame', 0.9, 1.4, 'smoothStepIn')

        for i = 0,getProperty('opponentStrums.length') - 1 do
            noteTweenAlpha('playerStrumOut'..i, i + 4, 0, 1, 'linear')
        end

        doTweenAlpha('scoreTxtOut', 'scoreTxt', 0, 1, 'linear')
        doTweenAlpha('healthBarOut', 'healthBar', 0, 1, 'linear')
        doTweenAlpha('iconP1Out', 'iconP1', 0, 1, 'linear')
        doTweenAlpha('iconP2Out', 'iconP2', 0, 1, 'linear')
    end
    if name == 'Fade In Ending' then
        setProperty('camGame.visible', false)
        setVar('safetyLullabyEndingLightingOff', true)
        setVar('safetyLullabyEndingActive', true)
        setObjectCamera('pndHandTrail', 'hud')
        setObjectCamera('pndHandActive', 'hud')
        setObjectOrder('pndHandTrail', getObjectOrder('gfGroup') + 1)
        setObjectOrder('pndHandActive', getObjectOrder('gfGroup') + 2)
        doTweenColor('endBgColor', 'endBg', getColorFromHex('FFFFFF'), 1.5, 'linear')
        doTweenAlpha('hypnoIn', 'gf', 1, 1.5, 'linear')
    end
end

function onUpdatePost()
    local songTime = (getSongPosition() or 0) / 1000 + SOURCE_TIME_OFFSET

    if curBeat >= 247 then
        setProperty('camZooming', false)
    end

    if not endingMotionStarted and songTime >= ENDING_MOVE_START then
        endingMotionStarted = true

        local bgWidth = getProperty('endBg.width')
        local bgHeight = getProperty('endBg.height')
        local bgX = getProperty('endBg.x')
        local bgY = getProperty('endBg.y')
        local bgScaleX = getProperty('endBg.scale.x')
        local bgScaleY = getProperty('endBg.scale.y')
        local zoom = 1.5
        local targetBgX = bgX - bgWidth * (zoom - 1) / 2 - PS
        local targetBgY = bgY - bgHeight * (zoom - 1) / 2 + 113 * PS

        doTweenX('endBgZoomX', 'endBg.scale', bgScaleX * zoom, ENDING_ZOOM_DURATION, 'linear')
        doTweenY('endBgZoomY', 'endBg.scale', bgScaleY * zoom, ENDING_ZOOM_DURATION, 'linear')

        doTweenX('hypnoShrinkX', 'gf.scale', 0.65, ENDING_HYPNO_DURATION, 'cubeIn')
        doTweenY('hypnoShrinkY', 'gf.scale', 0.65, ENDING_HYPNO_DURATION, 'cubeIn')
        doTweenX('hypnoDriftX', 'gf', getProperty('gf.x') - 5 * PS, ENDING_HYPNO_DURATION, 'cubeIn')
        doTweenY('hypnoDriftY', 'gf', getProperty('gf.y') - 93 * PS, ENDING_HYPNO_DURATION, 'cubeIn')
    end

    if not endingFadeStarted and songTime >= ENDING_FADE_START then
        endingFadeStarted = true
        doTweenAlpha('hypnoDarkFade', 'gf', 0, 189.16667 - ENDING_FADE_START, 'quadOut')
    end

    if not endingDarkenStarted and songTime >= ENDING_DARKEN_START then
        endingDarkenStarted = true
        doTweenColor('endBgToDark', 'endBg', getColorFromHex('000000'), 197 - ENDING_DARKEN_START, 'quadIn')
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