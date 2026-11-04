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

function onEvent(name, value1, value2)
    if name == 'Celebi Appear' then
        playAnim('celebi', 'rise', true)
        animEndTimer('celebihasrisen', 'celebi')
    end

    if name == 'Unown Typing' then
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

        local randomWord = words[getRandomInt(1, #words)]

        debugPrint('Selected word: ' .. randomWord)

        wordLength = string.len(randomWord)

        for i = 1, wordLength do
            local letter = string.sub(randomWord, i, i)

            debugPrint('Letter: ' .. letter)

            if letter ~= ' ' then
                local letterspacing = 170
                local letteroffset = 460

                local xPos = (wordLength - ((wordLength/2) + (wordLength - i))) * letterspacing + letteroffset
                
                debugPrint(xPos)
                makeAnimatedLuaSprite('unownLetter'..i, 'monochrome/UnownLetters', xPos, 200 + getRandomInt(-75,75))
                addAnimationByPrefix('unownLetter'..i, 'act', 'Unown' .. letter .. ' Act_', 12, true)
                setScrollFactor('unownLetter'..i, 0, 0)
                setScaleXY('unownLetter'..i, 0.7)

                addLuaSprite('unownLetter'..i, true)
            end
        end
    end
end

function onTimerCompleted(tag)
    if tag == 'celebihasrisen' then
        playAnim('celebi', 'idle', true)
    end
end