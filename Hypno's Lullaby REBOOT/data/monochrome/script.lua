luaDebugMode = true

local function getPlaysAsBF()
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
    addAnimationByPrefix('jumpscareP1', 'jumpFaster', 'jumpscare', 30, false)
    addAnimationByPrefix('jumpscareP1', 'jump', 'jumpscare', 24, false)
    setObjectCamera('jumpscareP1', 'other')
    scaleObject('jumpscareP1', 1, 1)
    setProperty('jumpscareP1.alpha', 0.0001)
    addLuaSprite('jumpscareP1', true)
end

function onCreatePost()
    removeLuaScript('scripts/camFollow')

    setProperty('camFollowPos.x', -456.5)
    setProperty('camFollowPos.y', -47.25)

    setProperty('boyfriendGroup.visible', false)
    setProperty('gfGroup.visible', false)
    triggerEvent('Camera Follow Pos', '183', '312')

    debugPrint(getPlaysAsBF())

    if getPlaysAsBF() then
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

    setProperty('showRating', false)
    setProperty('showComboNum', false)

    local opponentSustainCount = 0

    for i = 0, getProperty('unspawnNotes.length') - 1 do
        local isSustain = getPropertyFromGroup('unspawnNotes', i, 'isSustainNote')
        local mustPress = getPropertyFromGroup('unspawnNotes', i, 'mustPress')

        if isSustain and not mustPress then
            if (opponentSustainCount - 1) % 2 == 0 then
                setPropertyFromGroup('unspawnNotes', i, 'noAnimation', true)
            end

            opponentSustainCount = opponentSustainCount + 1
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

local function jumpscare(type)
    setProperty('jumpscareP1.alpha', 1)
    setProperty('dadGroup.visible', false)
    if type == 1 then
        setProperty('jumpscareP1.x', 680)
        setProperty('jumpscareP1.y', 50)
        playAnim('jumpscareP1', 'triple0', true)
    elseif type == 2 then
        setProperty('jumpscareP1.x', -100)
        setProperty('jumpscareP1.y', 100)
        playAnim('jumpscareP1', 'triple1', true)
    elseif type == 3 then
        setProperty('jumpscareP1.x', 70)
        setProperty('jumpscareP1.y', -60)
        playAnim('jumpscareP1', 'jumpFaster', true)
        runTimer('jumpscareEnd', 1.48)
    elseif type == 4 then
        setProperty('jumpscareP1.x', 70)
        setProperty('jumpscareP1.y', -60)
        playAnim('jumpscareP1', 'jump', true)
        runTimer('startP2', 1.85)
    else
        setProperty('jumpscareP1.x', 70)
        setProperty('jumpscareP1.y', -60)
        playAnim('jumpscareP1', 'jump', true)
        runTimer('jumpscareEnd', 1.85)
    end
end

function onEvent(name, value1, value2, strumTime)
    if name == 'Puke' then
        runTimer('pukeEnd', 2.15)
        setProperty('goldPukeBody.alpha', 1)
        setProperty('goldPukeHead.alpha', 1)
        setProperty('dadGroup.visible', false)
        playAnim('goldPukeBody', 'puke', true)
        playAnim('goldPukeHead', 'puke' .. value1, true)
        if value1 == '-alt' then
            runTimer('correctHeadY', 1.1)
            setProperty('goldPukeHead.x', getProperty('goldPukeBody.x') - 115)
        else
            setProperty('goldPukeHead.x', getProperty('goldPukeBody.x') - 88)
            setProperty('goldPukeHead.y', getProperty('goldPukeBody.y') - 120)
        end
        debugPrint('puke' .. value1)
    end
    if name == 'Jumpscare' then
        if value1 ~= '0' and value1 ~= '4' then
            tripleScare(tonumber(value1), 0.1)
        else
            jumpscare(tonumber(value1))
        end
    end
    if name == 'no more' then
        
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
        setProperty('defaultCamZoom', 0.7)
        doTweenZoom('zoomIn', 'camGame', 0.7, 25, 'cubeInOut')
    end
end