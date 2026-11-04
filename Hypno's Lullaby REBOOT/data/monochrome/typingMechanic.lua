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

function onCreate()
    makeAnimatedLuaSprite('celebi', 'monochrome/celebi', -630, -70)
    addAnimationByPrefix('celebi', 'idle', 'idle', 24, true)
    addAnimationByPrefix('celebi', 'rise', 'rise', 24, false)
    addAnimationByPrefix('celebi', 'pass', 'pass', 24, false)
    addAnimationByPrefix('celebi', 'fail', 'fail', 24, false)
    addAnimationByPrefix('celebi', 'shake', 'shake', 24, false)
    addAnimationByPrefix('celebi', 'shakelight', 'shakelight', 24, false)
    addLuaSprite('celebi')
    playAnim('celebi', 'pass', true)
end

local wordLength = nil
local letterspacing = 170
local letteroffset = 460
local letterscale = 0.7

local actDelay = 2
local canType = false
local currentWord = ''
local currentLetterToType = nil
local typingProgress = 0

local function setTypingProgress(progress)
    typingProgress = progress
    currentLetterToType = string.sub(currentWord, typingProgress, typingProgress)
    if currentLetterToType == ' ' or currentLetterToType == 'SPACE' then
        setTypingProgress(typingProgress + 1)
    end
end

function onEvent(name, value1, value2)
    if name == 'Celebi Appear' then
        playAnim('celebi', 'rise', true)
        animEndTimer('celebihasrisen', 'celebi')
    end

    if name == 'Set Unown Typing Delay' then
        actDelay = tonumber(value1)
    end

    if name == 'Unown Typing' then
        setProperty('canReset', false)

        doTweenAlpha('darkIn', 'darkOverlay', 0.5, 1, 'linear')

        local words = {}

        local fileContent = getTextFromFile('UnownWords/Normal.txt')

        for line in string.gmatch(fileContent, '[^\r\n]+') do
            table.insert(words, line)
        end

        if #words == 0 then
            debugPrint('No words found!')
            return
        end

        currentWord = words[getRandomInt(1, #words)]

        debugPrint('Selected word: ' .. currentWord)

        wordLength = string.len(currentWord)

        for i = 1, wordLength do
            local letter = string.sub(currentWord, i, i)

            debugPrint('Letter: ' .. letter)

            if letter ~= ' ' then
                letterspacing = 170
                letteroffset = 460
                letterscale = 0.7

                if wordLength > 10 then
                    letterspacing = math.max(170 / (1 + (wordLength - 10) * 0.12), 85)
                    letterscale = math.max(0.7 / (1 + (wordLength - 10) * 0.12), 0.35)
                end

                -- awesome formula to center the text
                local xPos = (wordLength - ((wordLength/2) + (wordLength - i))) * letterspacing + letteroffset
                local yPos = 200 + getRandomInt(
                    -math.max(75 / (1 + math.max(wordLength - 10, 0) * 0.12), 20),
                    math.max(75 / (1 + math.max(wordLength - 10, 0) * 0.12), 20)
                )
                
                debugPrint(xPos)

                makeLuaSprite('unownLetterBloom'..i, 'monochrome/unown_particle_bloom', xPos - 535, yPos - 525)
                setScrollFactor('unownLetterBloom'..i, 0, 0)
                setProperty('unownLetterBloom'..i..'.scale.x', letterscale / 3)
                setProperty('unownLetterBloom'..i..'.scale.y', letterscale / 2)
                setProperty('unownLetterBloom'..i..'.alpha', 0.5)
                addLuaSprite('unownLetterBloom'..i, true)

                makeAnimatedLuaSprite('unownLetter'..i, 'monochrome/UnownLetters', xPos, yPos)
                addAnimationByIndices('unownLetter'..i, 'blank', 'UnownA Act_', '0', 1, true)
                addAnimationByPrefix('unownLetter'..i, 'act', 'Unown' .. letter .. ' Act_', 24, false)
                setScrollFactor('unownLetter'..i, 0, 0)
                setScaleXY('unownLetter'..i, letterscale)
                addLuaSprite('unownLetter'..i, true)
                playAnim('unownLetter'..i, 'blank', true)
                runTimer('letters act', actDelay)
            end
        end
    end
end

function onTimerCompleted(tag)
    if tag == 'celebihasrisen' then
        playAnim('celebi', 'idle', true)
    end
    if tag == 'letters act' then
        canType = true
        setTypingProgress(1)
        for i = 1,wordLength do
            if luaSpriteExists('unownLetter'..i) then -- spaces or other non-letters break it otherwise
                playAnim('unownLetter'..i, 'act', true)
            end
        end
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

function onUpdate()
    if keyboardJustPressed(currentLetterToType) then
        debugPrint("that's right yeah!!! You typed: " .. currentLetterToType)
        doTweenColor('darkenLetter'..typingProgress, 'unownLetter'..typingProgress, '7F7F7F', 0.35, 'quintOut')
        doTweenAlpha('fadeOutBloomLetter'..typingProgress, 'unownLetterBloom'..typingProgress, 0, 0.35, 'quintOut')
        doTweenScale('letterShrink', 'unownLetter'..typingProgress, getProperty('unownLetter'..typingProgress..'.scale.x') / 1.25, 0.35, 'quintOut')
        setTypingProgress(typingProgress + 1)
        if typingProgress > wordLength then
            runTimer('end typing', 0.5)
            doTweenAlpha('darkOut', 'darkOverlay', 0, 1, 'linear')
        end
    end
end

function onTweenCompleted(tag)
    if string.sub(tag, 1,10) == 'letterFall' then
        debugPrint('letter fell: '..string.sub(tag, 11,11))
        removeLuaSprite('unownLetter'..string.sub(tag, 11,11), true)
    end
end