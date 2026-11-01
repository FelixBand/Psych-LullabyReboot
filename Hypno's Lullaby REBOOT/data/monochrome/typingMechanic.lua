-- Monochrome typing mechanic (port of typing_challenge.gd / unown_letter.gd)
--
-- Chart event "Unown Typing":
--   value1 = seconds from the event until Celebi runs out of time   (empty = 2.5 s + 0.4 s per letter)
--   value2 = which word list to use: a file name from UnownWords/ ("Normal", "Hard", ...)   (empty = Normal)
--            or "=SOME WORDS" to force one specific word
--
-- What happens (same order as the original):
--   1. event: a word is picked, Celebi appears, the Unowns fly by and the (still blank) letters pop in
--   2. PROMPT_DELAY later the letters get their faces and you can type. Celebi grows and brightens until time is up
--   3. right key -> next letter. wrong key -> the letter shakes and you lose 0.5 s (the original takes 0.25 s twice)
--   4. whole word typed = Celebi returns. time up = Celebi sings, one more fail. 1st/2nd fail split the health bar,
--      3rd fail kills you
--
-- Only A-Z are typeable. Spaces and anything else (? ! ' ...) are skipped automatically, like spaces were originally.

-- ===== config =============================================================
local UI = screenWidth / 1920            -- the Godot project is 1920x1080, everything authored there is scaled by this

local WORD_DIR = 'UnownWords/'
local DEFAULT_LIST = 'Normal'
local PROMPT_DELAY = 1.0                 -- seconds between the event and the moment you can start typing
local TIME_BASE, TIME_PER_LETTER = 2.5, 0.4   -- time limit when the event has no value1
local MISTAKE_PENALTY = 0.5              -- time lost per wrong key (original: 0.25 + 0.25)
local MAX_FAILS = 3

local TICK_OFFSET = 0.5                  -- Celebi ticks half a second before each whole second left
local DANGER_SECONDS = 3                 -- below this many seconds the tick gets the danger sound / strong shake

local BLOCK_STRUMS = true                -- the player's note keys do nothing while you are typing
local AUTOPLAY = false                   -- types the word for you, one letter every 0.2 s (the original's autoplay flag)

-- Celebi (Godot values: scale 0.7 -> 1.2, grey 0x3F -> white over the time limit)
local CELEBI_X, CELEBI_Y = screenWidth / 2, screenHeight / 2     -- centre of Celebi on screen
local CELEBI_START_SCALE, CELEBI_END_SCALE = 0.7 * UI, 1.2 * UI
local CELEBI_START_COLOR = '3F3F3F'
local CELEBI_EASE = 'quadIn'             -- the original uses a Curve resource that isn't in the repo; tweak to taste
local CELEBI_W, CELEBI_H = 407, 771      -- size of one Celebi frame in the sheet

-- Unown letters
local LETTER_SPACING = 160 * UI
local LETTER_CENTER_X, LETTER_CENTER_Y = screenWidth / 2, screenHeight / 2
local LETTER_W, LETTER_H = 196, 248      -- size of one letter frame in the sheet
local WAITING_COLOR = 'BDBDBD'           -- letters you still have to type
local DONE_COLOR = '6E6E6E'              -- letters you already typed

-- fly-by that plays when a challenge starts
local FLYBY_W, FLYBY_H = 404, 934
local FLYBY_X, FLYBY_Y = screenWidth / 2, screenHeight / 2

-- sounds (put .ogg files in sounds/ with these names; missing files are simply skipped)
local SND_TICK, SND_TICK_DANGER, SND_FAIL = 'celebiTick', 'celebiTickDanger', 'celebiFail'

-- ===== state ==============================================================
local lists, usedWords = {}, {}
local active, prompting, challengeOver, passed = false, false, false, false
local word, wordLen = '', 0
local letters = {}                        -- 0-based: {tag, ch, x, y, scale}   (ch = 'A'..'Z' or false for skipped chars)
local pool = 0                            -- how many letter sprites exist
local lettersPassed = 0
local deadline, endOffset = 0, 0          -- song seconds
local lastSecond = 0
local failCount = 0
local failSoundPlayed = false
local celebiAnim = ''
local shakes = {}
local autoTimer = 0
local prevNoReset = nil
local haveSound = {}
local KEYS = {}
for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):gmatch('.') do KEYS[#KEYS + 1] = c end

local function songSec() return getSongPosition() / 1000 end

local function rnd(a, b) return a + math.random() * (b - a) end

-- ===== helpers ============================================================
local function playSfx(name, tag)
    if haveSound[name] == nil then haveSound[name] = checkFileExists('sounds/' .. name .. '.ogg') end
    if haveSound[name] then playSound(name, 1, tag) end
end

local function stopSfx()
    for _, t in ipairs({'mechTick', 'mechTickDanger', 'mechFail'}) do stopSound(t) end
end

local function blockStrums(on)
    if not BLOCK_STRUMS then return end
    local v = on and 'true' or 'false'
    runHaxeCode('game.strumsBlocked = [' .. v .. ',' .. v .. ',' .. v .. ',' .. v .. '];')
end

-- quick restart is bound to R, which is also a letter
local function lockReset(on)
    if on then
        if prevNoReset == nil then prevNoReset = getPropertyFromClass('backend.ClientPrefs', 'data.noReset') end
        setPropertyFromClass('backend.ClientPrefs', 'data.noReset', true)
    elseif prevNoReset ~= nil then
        setPropertyFromClass('backend.ClientPrefs', 'data.noReset', prevNoReset)
        prevNoReset = nil
    end
end

-- ===== words ==============================================================
local function hasLetter(w) return w:find('%a') ~= nil end

local function loadList(name)
    if lists[name] then return lists[name] end
    local words = {}
    local txt = getTextFromFile(WORD_DIR .. name .. '.txt')
    if txt then
        for line in tostring(txt):gmatch('[^\r\n]+') do
            local w = line:upper():match('^%s*(.-)%s*$')
            if w ~= '' and hasLetter(w) then words[#words + 1] = w end
        end
    end
    if #words == 0 then words[1] = 'UNOWN' end
    lists[name] = words
    usedWords[name] = {count = 0}
    return words
end

-- same rule as the original: no repeats until every word of the list has been used
local function pickWord(name)
    local words = loadList(name)
    local used = usedWords[name]
    local w = words[math.random(#words)]
    if used.count < #words then
        while used[w] do w = words[math.random(#words)] end
    end
    if not used[w] then used[w] = true; used.count = used.count + 1 end
    return w
end

-- ===== sprites ============================================================
local function setScale(tag, s)
    setProperty(tag .. '.scale.x', s)
    setProperty(tag .. '.scale.y', s)
end

local function tweenScale(tag, key, s, dur, ease)
    doTweenX('mech' .. key .. 'X', tag .. '.scale', s, dur, ease)
    doTweenY('mech' .. key .. 'Y', tag .. '.scale', s, dur, ease)
end

local function ensureLetter(i)
    while pool <= i do
        local tag = 'mechanic_unown' .. pool
        makeAnimatedLuaSprite(tag, 'monochrome/UnownLetters', 0, 0)
        addAnimationByIndices(tag, 'none', 'UnownA Act_', '0', 24, false)   -- the plain orb, before it shows its letter
        playAnim(tag, 'none', true)
        setObjectCamera(tag, 'other')
        setProperty(tag .. '.alpha', 0)
        addLuaSprite(tag)
        pool = pool + 1
    end
    return 'mechanic_unown' .. i
end

local function playCelebi(name, fps)
    celebiAnim = name
    playAnim('mechanic_celebi', name, true)
end

-- ===== unown_letter.gd ====================================================
local function unownEnter(i)
    local u = letters[i]
    if not u or not u.ch then return end
    setProperty(u.tag .. '.alpha', 1)
    setProperty(u.tag .. '.color', getColorFromHex(WAITING_COLOR))
    setScale(u.tag, 0)
    tweenScale(u.tag, 'u' .. i, u.scale, 0.3, 'backOut')
end

local function unownActivate(i)
    local u = letters[i]
    setProperty(u.tag .. '.color', getColorFromHex('FFFFFF'))
    setProperty(u.tag .. '.alpha', 1)
    tweenScale(u.tag, 'u' .. i, u.scale * 1.15, 0.15, 'backOut')
end

local function unownSucceed(i)
    local u = letters[i]
    if u.done then return end
    u.done = true
    doTweenColor('mech' .. 'c' .. i, u.tag, DONE_COLOR, 0.2, 'quadOut')
    doTweenAlpha('mech' .. 'a' .. i, u.tag, 0.7, 0.2, 'quadOut')
    tweenScale(u.tag, 'u' .. i, u.scale * 0.9, 0.2, 'quadOut')
end

local function unownFail(i)
    local u = letters[i]
    shakes[i] = 0
    setProperty(u.tag .. '.color', getColorFromHex('333333'))
    doTweenColor('mech' .. 'c' .. i, u.tag, 'FFFFFF', 0.3, 'quadOut')
end

local function unownExit(i)
    local u = letters[i]
    doTweenAlpha('mech' .. 'a' .. i, u.tag, 0, 0.2, 'quadIn')
    tweenScale(u.tag, 'u' .. i, 0, 0.2, 'backIn')
end

-- ===== typing_challenge.gd ================================================
local function isLetter(i) return letters[i] ~= nil and letters[i].ch ~= false end

local function skipBlanks()
    while lettersPassed < wordLen and not isLetter(lettersPassed) do lettersPassed = lettersPassed + 1 end
end

local function updateUnowns()
    for i = 0, wordLen - 1 do
        local u = letters[i]
        if u.ch then
            if i == lettersPassed then
                removeLuaSprite(u.tag, false)      -- re-adding puts it in front (move_to_front)
                addLuaSprite(u.tag)
                unownActivate(i)
            elseif i < lettersPassed then
                unownSucceed(i)
            end
        end
    end
end

local function exitAll()
    for i = 0, wordLen - 1 do
        if isLetter(i) then
            local d = rnd(0.0, 0.2)
            if d > 0 then runTimer('mechExit' .. i, d) else unownExit(i) end
        end
    end
end

local function onChallengeFail(n)
    if n >= MAX_FAILS then
        setHealth(0)
        return
    end
    local anim = n == 1 and 'split1' or 'split2'
    if luaSpriteExists('mono_healthBar') then playAnim('mono_healthBar', anim, true) end
    if luaSpriteExists('mono_healthBarMask') then playAnim('mono_healthBarMask', anim, true) end
end

local function finish()
    prompting = false
    active = false
    blockStrums(false)
    lockReset(false)
end

local function succeed()
    passed = true
    challengeOver = true
    stopSfx()
    playCelebi('pass')
    runTimer('mechCelebiHide', 30 / 24)
    for i = 0, wordLen - 1 do
        if isLetter(i) then unownSucceed(i) end
    end
    runTimer('mechExitAll', 0.5)
    finish()
end

local function fail()
    challengeOver = true
    cancelTween('mechCelebiSX'); cancelTween('mechCelebiSY'); cancelTween('mechCelebiCol')
    if celebiAnim ~= 'fail' then
        if not failSoundPlayed then failSoundPlayed = true; playSfx(SND_FAIL, 'mechFail') end
        playCelebi('fail')
        runTimer('mechCelebiHide', 48 / 24)
    end
    for i = 0, wordLen - 1 do
        if isLetter(i) then unownSucceed(i) end
    end
    failCount = failCount + 1
    onChallengeFail(failCount)
    if failCount ~= MAX_FAILS then runTimer('mechExitAll', 0.5) end
    finish()
end

local function endChallenge()
    if challengeOver then return end
    if passed then succeed() else fail() end
end

local function failCurrent()
    skipBlanks()
    if lettersPassed < wordLen then unownFail(lettersPassed) end
    endOffset = endOffset - MISTAKE_PENALTY
end

local function inputLetter(ch)            -- ch = one lowercase letter
    skipBlanks()
    if lettersPassed >= wordLen then passed = true; endChallenge(); return end

    if ch ~= letters[lettersPassed].ch:lower() then
        failCurrent()
        return
    end

    lettersPassed = lettersPassed + 1
    skipBlanks()
    if lettersPassed >= wordLen then passed = true; endChallenge(); return end
    updateUnowns()
end

local function startChallenge()
    if not active or challengeOver then return end
    local timeLeft = deadline + endOffset - songSec()
    if timeLeft <= 0 then return end

    lastSecond = math.floor(timeLeft - TICK_OFFSET)

    for i = 0, wordLen - 1 do
        local u = letters[i]
        if u.ch then
            addAnimationByPrefix(u.tag, 'act', 'Unown' .. u.ch .. ' Act', 24, false)
            playAnim(u.tag, 'act', true)
        end
    end

    lettersPassed = 0
    skipBlanks()
    updateUnowns()
    prompting = true
    autoTimer = 0
    blockStrums(true)
    lockReset(true)

    -- Celebi: grows and brightens over the time limit (a fixed-length tween, like the original)
    doTweenX('mechCelebiSX', 'mechanic_celebi.scale', CELEBI_END_SCALE, timeLeft, CELEBI_EASE)
    doTweenY('mechCelebiSY', 'mechanic_celebi.scale', CELEBI_END_SCALE, timeLeft, CELEBI_EASE)
    doTweenColor('mechCelebiCol', 'mechanic_celebi', 'FFFFFF', timeLeft, CELEBI_EASE)
end

local function initiate(eventSec, duration, spec)
    if active then return end
    local w
    if spec and spec:sub(1, 1) == '=' then
        w = spec:sub(2):upper():match('^%s*(.-)%s*$')
        if w == '' or not hasLetter(w) then w = nil end
    end
    w = w or pickWord((spec and spec ~= '' and spec:sub(1, 1) ~= '=') and spec or DEFAULT_LIST)

    word, wordLen = w, #w
    active, prompting, challengeOver, passed = true, false, false, false
    lettersPassed, endOffset, failSoundPlayed = 0, 0, false
    shakes = {}
    deadline = eventSec + (duration or (TIME_BASE + TIME_PER_LETTER * wordLen))

    -- Celebi enters
    setProperty('mechanic_celebi.alpha', 1)
    setScale('mechanic_celebi', CELEBI_START_SCALE)
    setProperty('mechanic_celebi.color', getColorFromHex(CELEBI_START_COLOR))
    playCelebi('idle')
    cancelTimer('mechCelebiHide')

    -- fly-by
    setProperty('mechanic_unownflyby.alpha', 1)
    playAnim('mechanic_unownflyby', 'fly', true)
    runTimer('mechFlybyHide', 32 / 24)

    -- hide leftovers from the last challenge
    for i = 0, pool - 1 do
        cancelTimer('mechExit' .. i)
        setProperty('mechanic_unown' .. i .. '.alpha', 0)
    end

    -- lay the letters out
    local size = 1.0
    if wordLen > 10 then size = 10.0 / (wordLen - 1) end
    local offsetX = LETTER_SPACING * size * (wordLen - 1) * 0.5
    for i = 0, wordLen - 1 do
        local tag = ensureLetter(i)
        local c = word:sub(i + 1, i + 1)
        local ch = c:match('%a') and c:upper() or false
        local s = rnd(0.6, 0.7) * size * UI
        local px = ((LETTER_SPACING * i + rnd(-20, 20) * UI) * size) - offsetX
        local py = rnd(-60, 60) * UI
        local u = {tag = tag, ch = ch, scale = s, done = false,
                   x = LETTER_CENTER_X + px - LETTER_W / 2, y = LETTER_CENTER_Y + py - LETTER_H / 2}
        letters[i] = u
        setProperty(tag .. '.x', u.x)
        setProperty(tag .. '.y', u.y)
        playAnim(tag, 'none', true)
        setProperty(tag .. '.alpha', 0)
        setScale(tag, s)
        if ch then
            local d = rnd(0.125, 1.0 / 3.0)
            runTimer('mechEnter' .. i, d)
        end
    end

    runTimer('mechPrompt', PROMPT_DELAY)
end

-- ===== engine callbacks ===================================================
function onCreate()
    math.randomseed(os.time())

    precacheImage('monochrome/UnownLetters')

    makeAnimatedLuaSprite('mechanic_celebi', 'monochrome/celebi', CELEBI_X - CELEBI_W / 2, CELEBI_Y - CELEBI_H / 2)
    addAnimationByPrefix('mechanic_celebi', 'idle', 'idle', 24, true)
    addAnimationByPrefix('mechanic_celebi', 'shake', 'shake0', 25, false)
    addAnimationByPrefix('mechanic_celebi', 'shakelight', 'shakelight', 25, false)
    addAnimationByPrefix('mechanic_celebi', 'pass', 'pass', 24, false)
    addAnimationByPrefix('mechanic_celebi', 'fail', 'fail', 24, false)
    setObjectCamera('mechanic_celebi', 'other')
    setProperty('mechanic_celebi.alpha', 0)
    addLuaSprite('mechanic_celebi')

    makeAnimatedLuaSprite('mechanic_unownflyby', 'monochrome/unownflyby', FLYBY_X - FLYBY_W / 2, FLYBY_Y - FLYBY_H / 2)
    addAnimationByPrefix('mechanic_unownflyby', 'fly', 'unownflyby_copy', 24, false)
    setObjectCamera('mechanic_unownflyby', 'other')
    setProperty('mechanic_unownflyby.alpha', 0)
    setScale('mechanic_unownflyby', UI)
    addLuaSprite('mechanic_unownflyby')

    for i = 0, 11 do ensureLetter(i) end
end

function onEvent(name, value1, value2, strumTime)
    if name ~= 'Unown Typing' then return end
    if active then return end
    local ms = tonumber(strumTime)
    if ms == nil then ms = getSongPosition() end
    initiate(ms / 1000, tonumber(value1), value2 ~= nil and value2:match('^%s*(.-)%s*$') or nil)
end

function onTimerCompleted(tag)
    if tag:sub(1, 4) ~= 'mech' then return end
    if tag == 'mechPrompt' then
        startChallenge()
    elseif tag == 'mechExitAll' then
        exitAll()
    elseif tag == 'mechCelebiHide' then
        setProperty('mechanic_celebi.alpha', 0)
    elseif tag == 'mechFlybyHide' then
        setProperty('mechanic_unownflyby.alpha', 0)
    else
        local n = tag:match('^mechEnter(%d+)$')
        if n then unownEnter(tonumber(n)) return end
        n = tag:match('^mechExit(%d+)$')
        if n then unownExit(tonumber(n)) end
    end
end

function onUpdate(elapsed)
    if next(shakes) ~= nil then
        for i, t in pairs(shakes) do
            t = t + elapsed
            local u = letters[i]
            if t >= 0.3 or not u then
                shakes[i] = nil
                if u then setProperty(u.tag .. '.x', u.x) end
            else
                shakes[i] = t
                setProperty(u.tag .. '.x', u.x + math.sin(t * 70) * 14 * UI * (1 - t / 0.3))
            end
        end
    end

    if not prompting or challengeOver then return end

    local timeLeft = deadline + endOffset - songSec()
    if timeLeft <= 0 then
        endChallenge()                    -- time ran out: not passed -> fail
        return
    end

    if AUTOPLAY then
        autoTimer = autoTimer + elapsed
        if autoTimer >= 0.2 then
            autoTimer = 0
            skipBlanks()
            if lettersPassed < wordLen then inputLetter(letters[lettersPassed].ch:lower()) end
            if challengeOver then return end
        end
    else
        for k = 1, 26 do
            if keyboardJustPressed(KEYS[k]) then
                inputLetter(KEYS[k]:lower())
                if challengeOver then return end
            end
        end
    end

    -- Celebi ticks once per second, the last one is her song
    local second = math.floor(timeLeft - TICK_OFFSET)
    if second ~= lastSecond then
        if second == -1 then
            failSoundPlayed = true
            playSfx(SND_FAIL, 'mechFail')
        elseif second < DANGER_SECONDS then
            playSfx(SND_TICK_DANGER, 'mechTickDanger')
        else
            playSfx(SND_TICK, 'mechTick')
        end

        if second >= 0 then
            playCelebi(second < DANGER_SECONDS and 'shake' or 'shakelight')
        else
            playCelebi('fail')
            runTimer('mechCelebiHide', (48 / 24) + 0.5)
        end
    end
    lastSecond = second
end

function onDestroy()
    pcall(blockStrums, false)
    lockReset(false)            -- noReset is a saved preference: always give it back
end
