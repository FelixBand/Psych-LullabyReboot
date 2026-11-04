-- Monochrome typing mechanic (port of typing_challenge.gd / unown_letter.gd)
--
-- Chart events:
--   "Celebi Appear"            - Celebi rises and sings the Perish Song: notes spiral out of her until the typing starts.
--                                (if you forget it, Unown Typing makes her appear)
--   "Set Unown Typing Delay"   - value1 = seconds between the Unown Typing event and the moment you can start typing
--   "Unown Typing"             - the typing challenge.
--        value1 = seconds you get to type once the letters light up   (empty = 2.5 s + 0.4 s per letter)
--        value2 = word list from UnownWords/ ("Normal", "Hard", ...)  (empty = Normal), or "=SOME WORDS" to force a word
--
-- Right key = next letter, wrong key = the letter shakes and you lose 0.5 s. Whole word = Celebi returns.
-- Time up = Celebi bursts: 1st fail splits the health bar + brings the foreground eyes, 2nd fail = instant death.

---@param obj string "name of the game object you want to get the current animation duration of"
local function getAnimDuration(obj)
    return getProperty(obj..'.animation.curAnim.numFrames') / getProperty(obj..'.animation.curAnim.frameRate')
end

---@param tag string "name of the timer"
---@param obj string "name of the game object you want to get the current animation duration of"
local function animEndTimer(tag, obj)
    runTimer(tag, getAnimDuration(obj))
end

local function setScaleXY(obj, scale)
    setProperty(obj..'.scale.x', scale)
    setProperty(obj..'.scale.y', scale)
end

local function doTweenScale(tag, obj, target, duration, ease)
    doTweenX(tag .. 'X', obj..'.scale', target, duration, ease)
    doTweenY(tag .. 'Y', obj..'.scale', target, duration, ease)
end

-- Celebi (world position of her top left corner, she grows and brightens while you type)
local celebiX, celebiY = -630, -70
local celebiW, celebiH = 407, 771
local celebiStartScale, celebiEndScale = 1, 1.39
local celebiStartColor = '3F3F3F'
local celebiOut = false
local celebiFailing = false

-- Perish Song notes: they all start at ONE point above Celebi's head and spiral outward, linearly
local noteCount = 7
local noteLife = 1.15            -- seconds a note lives
local noteSpeed = 170           -- outward speed, pixels per second
local noteSpin = 0.8            -- radians per second (negative = other way)
local noteFadeIn, noteFadeOut = 0.5, 0.5
local noteAlpha = 0.5           -- peak opacity
local noteSquash = 1         -- below 1 flattens the spiral vertically
local noteOriginX, noteOriginY = 0, -100   -- relative to Celebi's centre
local noteScale = 0.43
local noteW, noteH = 142, 174
local noteStartColor = 'FF2020' -- red, fades to white
local noteAge = {}
local noteAngle = {}

-- Unown letters
local letterspacing = 170
local letteroffset = 460
local letterscale = 0.7
local waitingColor, doneColor = 'BDBDBD', '6E6E6E'

-- the typing challenge
local actDelay = 2
local canType = false
local typingActive = false
local currentWord = ''
local currentLetterToType = nil
local typingProgress = 0
local wordLength = 0
local typingDeadline = 0
local typingPenalty = 0
local mistakePenalty = 0.5
local lastSecond = 0
local tickOffset = 0.5          -- Celebi ticks this long before each whole second left
local dangerSeconds = 3         -- below this many seconds the tick gets the danger sound
local failCount = 0
local maxFails = 2              -- this many failed challenges = instant death
local letterX = {}
local letterDone = {}
local letterShake = {}
local wordLists = {}
local usedWords = {}

function onCreate()
    makeAnimatedLuaSprite('celebi', 'monochrome/celebi', celebiX, celebiY)
    addAnimationByPrefix('celebi', 'idle', 'idle', 24, true)
    addAnimationByPrefix('celebi', 'rise', 'rise', 24, false)
    addAnimationByPrefix('celebi', 'pass', 'pass', 24, false)
    addAnimationByPrefix('celebi', 'fail', 'fail', 24, false)
    addAnimationByPrefix('celebi', 'shake', 'shake0', 25, false)    -- "shake0" so it doesn't also grab the shakelight frames
    addAnimationByPrefix('celebi', 'shakelight', 'shakelight', 25, false)
    setProperty('celebi.alpha', 0)
    addLuaSprite('celebi')

    for i = 1, noteCount do
        makeLuaSprite('perishNote'..i, 'monochrome/celebi_note', 0, 0)
        setProperty('perishNote'..i..'.alpha', 0)
        addLuaSprite('perishNote'..i)
    end

    -- the unowns that fly past when a challenge starts
    makeAnimatedLuaSprite('unownFlyby', 'monochrome/unownflyby', 438, -107)
    addAnimationByPrefix('unownFlyby', 'fly', 'unownflyby_copy', 24, false)
    setScrollFactor('unownFlyby', 0, 0)
    setScaleXY('unownFlyby', 0.95)
    setProperty('unownFlyby.alpha', 0)
    addLuaSprite('unownFlyby', true)
end

-- Celebi rises (and sings the Perish Song). She is placed once and never moved again.
local function celebiAppear(sing)
    celebiOut = true
    celebiFailing = false
    setProperty('celebi.x', celebiX)
    setProperty('celebi.y', celebiY)
    setScaleXY('celebi', celebiStartScale)
    setProperty('celebi.color', getColorFromHex(celebiStartColor))
    setProperty('celebi.alpha', 1)
    cancelTimer('celebihide')
    playAnim('celebi', 'rise', true)
    animEndTimer('celebihasrisen', 'celebi')
    if sing then
        runTimer('perish notes', getAnimDuration('celebi') - 0.5)   -- the song starts once she is up
    end
end

local function setTypingProgress(progress)
    typingProgress = progress
    -- spaces, ? ! ' and so on can't be typed, skip them
    while typingProgress <= wordLength and not string.match(string.sub(currentWord, typingProgress, typingProgress), '%a') do
        typingProgress = typingProgress + 1
    end
    currentLetterToType = string.sub(currentWord, typingProgress, typingProgress)

    if typingProgress <= wordLength then
        -- the letter to type lights up and comes to the front
        local tag = 'unownLetter'..typingProgress
        removeLuaSprite(tag, false)
        addLuaSprite(tag, true)
        setProperty(tag..'.color', getColorFromHex('FFFFFF'))
        setProperty(tag..'.alpha', 1)
        doTweenScale('letterActive'..typingProgress, tag, letterscale * 1.15, 0.15, 'backOut')
    end
end

local function letterFinished(i)
    if letterDone[i] or not luaSpriteExists('unownLetter'..i) then return end
    letterDone[i] = true
    doTweenColor('darkenLetter'..i, 'unownLetter'..i, doneColor, 0.2, 'quadOut')
    doTweenAlpha('fadeLetter'..i, 'unownLetter'..i, 0.7, 0.2, 'quadOut')
    doTweenAlpha('fadeOutBloomLetter'..i, 'unownLetterBloom'..i, 0, 0.2, 'quadOut')
    doTweenScale('letterActive'..i, 'unownLetter'..i, letterscale * 0.9, 0.2, 'quadOut')
end

local function endTyping(passed)
    canType = false
    typingActive = false
    cancelTimer('perish notes')
    cancelTimer('stun player')
    setProperty('boyfriend.stunned', false)
    doTweenAlpha('darkOut', 'darkOverlay', 0, 1, 'linear')
    for i = 1, wordLength do letterFinished(i) end
    runTimer('end typing', 0.5)

    if passed then
        stopSound('celebiTick')
        stopSound('celebiTickDanger')
        stopSound('celebiFail')
        playAnim('celebi', 'pass', true)
        animEndTimer('celebihide', 'celebi')
        return
    end

    cancelTween('celebiGrowX')
    cancelTween('celebiGrowY')
    cancelTween('celebiColor')
    if not celebiFailing then
        celebiFailing = true
        playSound('celebiFail', 1, 'celebiFail')
        playAnim('celebi', 'fail', true)
        animEndTimer('celebihide', 'celebi')
    end

    failCount = failCount + 1
    callOnLuas('fgEyesNextPhase', {})           -- setupAndEvents.lua: the foreground Unown eyes appear
    if failCount >= maxFails then
        setHealth(0)
    else
        -- the bigger penalty: the health bar splits straight to the second stage
        if luaSpriteExists('mono_healthBar') then playAnim('mono_healthBar', 'split2', true) end
        if luaSpriteExists('mono_healthBarMask') then playAnim('mono_healthBarMask', 'split2', true) end
        callOnLuas('setHealthSplit', {2})       -- optional hook: lets setupAndEvents.lua cap the health
    end
end

function onEvent(name, value1, value2)
    if name == 'Celebi Appear' then
        if not celebiOut and not typingActive then celebiAppear(true) end
    end

    if name == 'Set Unown Typing Delay' then
        actDelay = tonumber(value1)
    end

    if name == 'Unown Typing' then
        if typingActive then return end

        -- which word: "=WORD" forces one, otherwise a random one from the list (no repeats until the whole list was used)
        local spec = string.match(value2 or '', '^%s*(.-)%s*$')
        local word = nil
        if string.sub(spec, 1, 1) == '=' and getRandomBool(75) then
            word = string.upper(string.match(string.sub(spec, 2), '^%s*(.-)%s*$'))
            if not string.find(word, '%a') then word = nil end
        end
        if not word then
            local listName = 'Normal'
            if spec ~= '' and string.sub(spec, 1, 1) ~= '=' then listName = spec end

            if not wordLists[listName] then
                wordLists[listName] = {}
                usedWords[listName] = {count = 0}
                for line in string.gmatch(getTextFromFile('UnownWords/'..listName..'.txt') or '', '[^\r\n]+') do
                    line = string.upper(string.match(line, '^%s*(.-)%s*$'))
                    if string.find(line, '%a') then table.insert(wordLists[listName], line) end
                end
            end

            local words = wordLists[listName]
            if #words == 0 then
                debugPrint('No words found in UnownWords/'..listName..'.txt!')
                return
            end
            word = words[getRandomInt(1, #words)]
            while usedWords[listName].count < #words and usedWords[listName][word] do
                word = words[getRandomInt(1, #words)]
            end
            if not usedWords[listName][word] then
                usedWords[listName][word] = true
                usedWords[listName].count = usedWords[listName].count + 1
            end
        end

        -- remove what is left of the last challenge
        for i = 1, wordLength do
            cancelTimer('letterEnter'..i)
            removeLuaSprite('unownLetter'..i, true)
            removeLuaSprite('unownLetterBloom'..i, true)
        end
        cancelTimer('end typing')

        currentWord = word
        wordLength = string.len(currentWord)
        typingActive = true
        canType = false
        typingProgress = 0
        typingPenalty = 0
        letterX = {}
        letterDone = {}
        letterShake = {}
        typingLimit = tonumber(value1) or (2.5 + 0.4 * wordLength)

        setProperty('canReset', false)
        doTweenAlpha('darkIn', 'darkOverlay', 0.5, 1, 'linear')

        -- Celebi is normally already out (Celebi Appear). If not, she appears now, without the song.
        if not celebiOut then celebiAppear(false) end
        cancelTimer('perish notes')             -- the song ends where the typing begins
        cancelTimer('celebihide')

        playAnim('unownFlyby', 'fly', true)
        setProperty('unownFlyby.alpha', 1)
        animEndTimer('flybyhide', 'unownFlyby')

        letterspacing = 170
        letteroffset = 460
        letterscale = 0.7
        if wordLength > 10 then
            letterspacing = math.max(170 / (1 + (wordLength - 10) * 0.12), 85)
            letterscale = math.max(0.7 / (1 + (wordLength - 10) * 0.12), 0.35)
        end

        for i = 1, wordLength do
            local letter = string.sub(currentWord, i, i)

            if string.match(letter, '%a') then
                -- awesome formula to center the text
                local xPos = (wordLength - ((wordLength/2) + (wordLength - i))) * letterspacing + letteroffset
                local yPos = 200 + getRandomInt(
                    -math.max(75 / (1 + math.max(wordLength - 10, 0) * 0.12), 20),
                    math.max(75 / (1 + math.max(wordLength - 10, 0) * 0.12), 20)
                )
                letterX[i] = xPos

                makeLuaSprite('unownLetterBloom'..i, 'monochrome/unown_particle_bloom', xPos - 535, yPos - 525)
                setBlendMode('unownLetterBloom'..i, 'add')
                setScrollFactor('unownLetterBloom'..i, 0, 0)
                setProperty('unownLetterBloom'..i..'.scale.x', letterscale / 3)
                setProperty('unownLetterBloom'..i..'.scale.y', letterscale / 2)
                setProperty('unownLetterBloom'..i..'.alpha', 0)
                addLuaSprite('unownLetterBloom'..i, true)

                makeAnimatedLuaSprite('unownLetter'..i, 'monochrome/UnownLetters', xPos, yPos)
                addAnimationByIndices('unownLetter'..i, 'blank', 'UnownA Act_', '0', 1, true)
                addAnimationByPrefix('unownLetter'..i, 'act', 'Unown' .. letter .. ' Act_', 24, false)
                setScrollFactor('unownLetter'..i, 0, 0)
                setScaleXY('unownLetter'..i, 0)
                addLuaSprite('unownLetter'..i, true)
                playAnim('unownLetter'..i, 'blank', true)

                -- the letters pop in one after another
                runTimer('letterEnter'..i, getRandomFloat(0.125, 0.333))
            end
        end

        runTimer('letters act', actDelay)
    end
end

function onTimerCompleted(tag)
    if tag == 'celebihasrisen' then
        if not celebiFailing then playAnim('celebi', 'idle', true) end
    end
    if tag == 'celebihide' then
        setProperty('celebi.alpha', 0)
        celebiOut = false
    end
    if tag == 'flybyhide' then
        setProperty('unownFlyby.alpha', 0)
    end
    if tag == 'perish notes' then
        for i = 1, noteCount do
            noteAge[i] = 0
            noteAngle[i] = -math.pi / 2 + (i - 1) * 2 * math.pi / noteCount   -- each note rides its own arm of the spiral
            setProperty('perishNote'..i..'.color', getColorFromHex(noteStartColor))
            doTweenColor('perishNoteColor'..i, 'perishNote'..i, 'FFFFFF', noteLife * 0.8, 'linear')
        end
    end

    if string.sub(tag, 1, 11) == 'letterEnter' then
        local i = tonumber(string.sub(tag, 12))
        if luaSpriteExists('unownLetter'..i) then
            setProperty('unownLetter'..i..'.alpha', 1)
            setProperty('unownLetter'..i..'.color', getColorFromHex(waitingColor))
            doTweenScale('letterPop'..i, 'unownLetter'..i, letterscale, 0.3, 'backOut')
            doTweenAlpha('bloomIn'..i, 'unownLetterBloom'..i, 0.5, 0.4, 'quadOut')
        end
    end

    if tag == 'letters act' then
        if not typingActive then return end
        canType = true
        typingDeadline = getSongPosition() / 1000 + typingLimit
        lastSecond = math.floor(typingLimit - tickOffset)
        for i = 1, wordLength do
            if luaSpriteExists('unownLetter'..i) then -- spaces or other non-letters break it otherwise
                playAnim('unownLetter'..i, 'act', true)
                setProperty('unownLetter'..i..'.color', getColorFromHex(waitingColor))
            end
        end
        setTypingProgress(1)
        runTimer('stun player', 0.85)

        -- Celebi grows and brightens until the time is up
        doTweenScale('celebiGrow', 'celebi', celebiEndScale, typingLimit, 'quadIn')
        doTweenColor('celebiColor', 'celebi', 'FFFFFF', typingLimit, 'quadIn')
    end
    if tag == 'stun player' then
        setProperty('boyfriend.stunned', true)
    end
    if tag == 'end typing' then
        setProperty('canReset', true)
        for i = 1,wordLength + 1 do
            if luaSpriteExists('unownLetter'..i) then
                doTweenY('letterFall'..i, 'unownLetter'..i, getProperty('unownLetter'..i..'.y') + 1100, 0.9, 'expoIn')
            end
        end
    end
end

function onUpdate(elapsed)
    -- Perish Song notes
    for i = 1, noteCount do
        if noteAge[i] then
            noteAge[i] = noteAge[i] + elapsed
            local age = noteAge[i]
            if age >= noteLife then
                noteAge[i] = nil
                setProperty('perishNote'..i..'.alpha', 0)
            else
                local radius = noteSpeed * age
                local angle = noteAngle[i] + noteSpin * age
                local centerX = celebiX + celebiW / 2 + noteOriginX + math.cos(angle) * radius
                local centerY = celebiY + celebiH / 2 + noteOriginY + math.sin(angle) * radius * noteSquash
                setProperty('perishNote'..i..'.x', centerX - noteW / 2)
                setProperty('perishNote'..i..'.y', centerY - noteH / 2)
                setScaleXY('perishNote'..i, noteScale * (0.6 + 0.4 * math.min(1, age / 0.5)))
                setProperty('perishNote'..i..'.alpha', math.max(0, math.min(age / noteFadeIn, (noteLife - age) / noteFadeOut, 1)) * noteAlpha)
            end
        end
    end

    -- wrong key shake
    for i, t in pairs(letterShake) do
        t = t + elapsed
        if t >= 0.3 then
            letterShake[i] = nil
            setProperty('unownLetter'..i..'.x', letterX[i])
        else
            letterShake[i] = t
            setProperty('unownLetter'..i..'.x', letterX[i] + math.sin(t * 70) * 14 * (1 - t / 0.3))
        end
    end

    if not canType then return end

    local timeLeft = typingDeadline - typingPenalty - getSongPosition() / 1000
    if timeLeft <= 0 then
        endTyping(false)
        return
    end

    -- Celebi ticks once per second, the last one is her song
    local second = math.floor(timeLeft - tickOffset)
    if second ~= lastSecond then
        if second == -1 then
            celebiFailing = true
            playSound('celebiFail', 1, 'celebiFail')
            playAnim('celebi', 'fail', true)
            animEndTimer('celebihide', 'celebi')
        elseif second < dangerSeconds then
            playSound('celebiTickDanger', 1, 'celebiTickDanger')
            playAnim('celebi', 'shake', true)
        else
            playSound('celebiTick', 1, 'celebiTick')
            playAnim('celebi', 'shakelight', true)
        end
        lastSecond = second
    end

    -- typing (one key per frame)
    for k = 97, 122 do
        local key = string.char(k)
        if keyboardJustPressed(string.upper(key)) then
            if string.upper(key) == currentLetterToType then
                letterFinished(typingProgress)
                setTypingProgress(typingProgress + 1)
                if typingProgress > wordLength then
                    endTyping(true)
                end
            else
                letterShake[typingProgress] = 0
                setProperty('unownLetter'..typingProgress..'.color', getColorFromHex('333333'))
                doTweenColor('wrongLetter'..typingProgress, 'unownLetter'..typingProgress, 'FFFFFF', 0.3, 'quadOut')
                typingPenalty = typingPenalty + mistakePenalty
            end
            break
        end
    end
end

function onTweenCompleted(tag)
    if string.sub(tag, 1,10) == 'letterFall' then
        local i = string.sub(tag, 11)
        removeLuaSprite('unownLetter'..i, true)
        removeLuaSprite('unownLetterBloom'..i, true)
    end
end
