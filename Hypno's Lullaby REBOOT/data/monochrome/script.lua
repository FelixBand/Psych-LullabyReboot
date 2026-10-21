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

    makeAnimatedLuaSprite('jumpscareP2', 'characters/gold/jumpscarep2', 180, -40)
    addAnimationByIndices('jumpscareP2', 'buildup0', 'buildup', '0,1,2', 12, false)
    addAnimationByIndices('jumpscareP2', 'buildup1', 'buildup', '3,4,5', 12, false)
    addAnimationByIndices('jumpscareP2', 'buildup2', 'buildup', '6,7,8', 12, false)
    addAnimationByIndices('jumpscareP2', 'jump', 'jumpscare', '0,1,2,3,2,3,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17', 12, false)
    setObjectCamera('jumpscareP2', 'other')
    scaleObject('jumpscareP2', 0.9, 0.9)
    setProperty('jumpscareP2.alpha', 0.0001)
    addLuaSprite('jumpscareP2', true)
end

local PLAY_EVERY = 2          -- 2 = half as fast, 3 = a third, 1 = vanilla restart rate (keep <= 4)
local AFFECT_OPPONENT = true
local AFFECT_PLAYER = true
local DISABLE_ENGINE_HOLD_FREEZE = true   -- the sustainTimer part; set false to keep the engine's frozen-pose holds

function onCreatePost()
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

    local count = {}   -- hold pieces seen so far in the hold currently running on each lane
    local total = getProperty('unspawnNotes.length')
    local sustains, flagged = 0, 0

    for i = 0, total - 1 do
        local must = getPropertyFromGroup('unspawnNotes', i, 'mustPress')
        local lane = getPropertyFromGroup('unspawnNotes', i, 'noteData') + (must and 4 or 0)

        if not getPropertyFromGroup('unspawnNotes', i, 'isSustainNote') then
            count[lane] = 0                       -- a new note head starts a new hold
        else
            sustains = sustains + 1
            if (must and AFFECT_PLAYER) or (not must and AFFECT_OPPONENT) then
                count[lane] = (count[lane] or 0) + 1
                -- piece 1 plays, then every PLAY_EVERY-th piece plays; the rest don't touch the animation
                if (count[lane] - 1) % PLAY_EVERY ~= 0 then
                    setPropertyFromGroup('unspawnNotes', i, 'noAnimation', true)
                    flagged = flagged + 1
                end
            end
        end
    end
end

-- charTag is 'dad', 'boyfriend', 'gf' or 'characters[<id>]' (online), straight from the engine.
local function afterHoldPiece(id, isSus, charTag)
    if not isSus then return end
    if getPropertyFromGroup('notes', id, 'gfNote') then charTag = 'gf' end

    local skipped = getPropertyFromGroup('notes', id, 'noAnimation')
    if DISABLE_ENGINE_HOLD_FREEZE then
        setProperty(charTag .. '.sustainTimer', 0)
    end
    if skipped then
        setProperty(charTag .. '.holdTimer', 0)   -- skipped pieces skip the engine's holdTimer reset; keep the pose alive
    end
end

function opponentNoteHit(id, dir, noteType, isSus, charTag) afterHoldPiece(id, isSus, charTag or 'dad') end
function goodNoteHit(id, dir, noteType, isSus, charTag) afterHoldPiece(id, isSus, charTag or 'boyfriend') end

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
            runTimer('jumpscareEnd', 1.48)
        elseif type == '4' then
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
    elseif dadName == 'goldp2' then
        setProperty('jumpscareP2.alpha', 1)
        setProperty('jumpscareP2.scale.x', 0.75)
        setProperty('jumpscareP2.scale.y', 0.75)
        if type == '1' then
            setProperty('jumpscareP2.x', -100)
            setProperty('jumpscareP2.y', -40)
            playAnim('jumpscareP2', 'buildup0', true)
        elseif type == '2' then
            setProperty('jumpscareP2.x', -100)
            setProperty('jumpscareP2.y', -40)
            playAnim('jumpscareP2', 'buildup1', true)
        elseif type == '3' then
            setProperty('jumpscareP2.x', -120)
            setProperty('jumpscareP2.y', -140)
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
            runTimer('jumpscareEnd', 1.75)
            cameraShake('other', 0.005, 1.75)
        end
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
end