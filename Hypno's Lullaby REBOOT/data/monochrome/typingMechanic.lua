-- Monochrome typing mechanic (port of typing_challenge.gd / unown_letter.gd)
--
-- Chart events:
--   "Celebi Appear"  - Celebi rises and sings the Perish Song: notes spiral out of her until the typing starts.
--                      No values. Put it a few seconds before "Unown Typing" (if you forget, Unown Typing makes her appear).
--   "Unown Typing"   - the typing challenge.
--        value1 = seconds from the event until Celebi runs out of time   (empty = 2.5 s + 0.4 s per letter)
--        value2 = word list from UnownWords/ ("Normal", "Hard", ...)  (empty = Normal), or "=SOME WORDS" to force a word
--
-- Flow: event -> word picked, game darkens, Unowns fly by, blank letters pop in -> PROMPT_DELAY later you can type.
-- Right key = next letter, wrong key = shake + lose MISTAKE_PENALTY seconds. Word done = Celebi returns.
-- Time up = Celebi bursts: 1st fail splits the health bar + brings the foreground eyes, 2nd fail = instant death.
-- Everything sits on camGame, in front of the characters, pinned to the screen. Only A-Z are typeable.

-- ===== config =============================================================
local UI = screenWidth / 1920            -- the Godot project is 1920x1080
local W2, H2 = screenWidth / 2, screenHeight / 2

local WORD_DIR, DEFAULT_LIST = 'UnownWords/', 'Normal'
local PROMPT_DELAY = 2.0                 -- seconds between the event and the moment you can start typing
local TIME_BASE, TIME_PER_LETTER = 2.5, 0.4   -- time limit when the event has no value1
local MISTAKE_PENALTY = 0.5              -- seconds lost per wrong key
local MAX_FAILS = 2                      -- this many failed challenges = instant death
local TICK_OFFSET, DANGER_SECONDS = 0.5, 3    -- Celebi ticks this long before each whole second; below DANGER_SECONDS it gets scary
local AUTOPLAY = false                   -- types the word for you, one letter every 0.2 s
local DARK_ALPHA, DARK_FADE = 0.45, 1.0  -- camGame darkening ('darkOverlay' from setupAndEvents.lua)

-- Celebi (screen pixels of a 1280x720 screen). She is placed ONCE when she appears and never moved or rescaled again.
-- Set CELEBI_REF_ZOOM to a number to make her position independent of the camera zoom at that moment.
local CELEBI_X, CELEBI_Y = screenWidth * 0.18, H2 + 10
local CELEBI_START_SCALE, CELEBI_END_SCALE = 1.025 * UI, 1.425 * UI
local CELEBI_START_COLOR, CELEBI_EASE = '3F3F3F', 'quadIn'
local CELEBI_W, CELEBI_H = 407, 771
local CELEBI_REF_ZOOM = nil
local RISE_TIME = 26 / 24

-- Perish Song notes: all start at ONE point (relative to Celebi's centre) and spiral outward, linearly
local NOTE_POOL = 7
local NOTE_LIFE = 1.7                    -- seconds a note lives
local NOTE_SPEED = 120                   -- outward speed, px per second
local NOTE_SPIN = 0.80                   -- radians per second (negative = other way)
local NOTE_FADE_IN, NOTE_FADE_OUT = 0.5, 0.8
local NOTE_ALPHA = 0.5                   -- peak opacity
local NOTE_SQUASH = 0.75                 -- below 1 flattens the spiral vertically
local NOTE_ORIGIN_X, NOTE_ORIGIN_Y = 0, -70
local NOTE_SCALE = 0.45 * UI
local NOTE_W, NOTE_H = 142, 174
local NOTE_START_COLOR = 'FF2020'        -- red, fades to white

-- Unown letters
local LETTER_SPACING = 160 * UI
local LETTER_W, LETTER_H = 196, 248
local WAITING_COLOR, DONE_COLOR = 'BDBDBD', '6E6E6E'
local GLOW_SIZE, GLOW_ALPHA = 2.6, 0.65  -- glow diameter in letter heights / opacity
local FLYBY_W, FLYBY_H = 404, 934

-- sounds: .ogg files in sounds/ (missing ones are skipped)
local SND_TICK, SND_DANGER, SND_FAIL, SND_PERISH = 'celebiTick', 'celebiTickDanger', 'celebiFail', 'celebiPerishSong'

-- ===== state ==============================================================
local lists, used = {}, {}
local active, prompting, over, passed = false, false, false, false
local word, wordLen, typed = '', 0, 0
local letters, pool = {}, 0               -- letters[0-based] = {tag, glow, ch (A-Z or false), scale, x, done}
local deadline, penalty, lastSecond = 0, 0, 0
local fails, failSound = 0, false
local celebiAnim, celebiOut = '', false
local viewZoom, celebiZoom = 1, 1         -- camGame zoom when things were placed (pinned sprites are still scaled by it)
local notes, shakes = {}, {}
local autoTimer, prevNoReset = 0, nil
local KEYS = {}
for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):gmatch('.') do KEYS[#KEYS + 1] = c end

-- ===== helpers ============================================================
local function rnd(a, b) return a + math.random() * (b - a) end

local function zoomNow()
    local z = getProperty('camGame.zoom')
    return (type(z) == 'number' and z > 0) and z or 1
end

-- "screen pixel" -> camGame position, undoing the zoom that scales pinned sprites around the screen centre
local function toWorld(px, py, z) return W2 + (px - W2) / z, H2 + (py - H2) / z end

local function setScale(tag, s)
    setProperty(tag .. '.scale.x', s)
    setProperty(tag .. '.scale.y', s)
end

local function tweenScale(tag, key, s, dur, ease)
    doTweenX('mech' .. key .. 'X', tag .. '.scale', s, dur, ease)
    doTweenY('mech' .. key .. 'Y', tag .. '.scale', s, dur, ease)
end

local function pinned(tag, ontop)
    setObjectCamera(tag, 'game')
    setScrollFactor(tag, 0, 0)
    setProperty(tag .. '.alpha', 0)
    addLuaSprite(tag, ontop ~= false)      -- true = in front of the characters
end

local function sfx(name, tag)
    if checkFileExists('sounds/' .. name .. '.ogg') then playSound(name, 1, tag) end
end

-- quick restart is bound to R, which is also a letter
local function lockReset(on)
    if on then
        cancelTimer('mechUnlockReset')
        if prevNoReset == nil then prevNoReset = getPropertyFromClass('backend.ClientPrefs', 'data.noReset') end
        setPropertyFromClass('backend.ClientPrefs', 'data.noReset', true)
    elseif prevNoReset ~= nil then
        setPropertyFromClass('backend.ClientPrefs', 'data.noReset', prevNoReset)
        prevNoReset = nil
    end
end

local function darkTo(alpha)
    if luaSpriteExists('darkOverlay') then
        doTweenAlpha('mechDark', 'darkOverlay', alpha, DARK_FADE, alpha > 0 and 'quadOut' or 'quadIn')
    end
end

local function playCelebi(name)
    celebiAnim = name
    playAnim('mechanic_celebi', name, true)
end

-- ===== words ==============================================================
local function loadList(name)
    if lists[name] then return lists[name] end
    local words = {}
    for line in tostring(getTextFromFile(WORD_DIR .. name .. '.txt') or ''):gmatch('[^\r\n]+') do
        local w = line:upper():match('^%s*(.-)%s*$')
        if w:find('%a') then words[#words + 1] = w end
    end
    if #words == 0 then words[1] = 'UNOWN' end
    lists[name], used[name] = words, {count = 0}
    return words
end

-- no repeats until every word of the list has been used
local function pickWord(name)
    local words, u = loadList(name), used[name]
    local w = words[math.random(#words)]
    while u.count < #words and u[w] do w = words[math.random(#words)] end
    if not u[w] then u[w] = true; u.count = u.count + 1 end
    return w
end

-- ===== Celebi + Perish Song ===============================================
local function celebiAppear(sing)
    celebiZoom = CELEBI_REF_ZOOM or zoomNow()  -- the one and only time her position and scale are worked out
    celebiOut = true
    local x, y = toWorld(CELEBI_X, CELEBI_Y, celebiZoom)
    setProperty('mechanic_celebi.x', x - CELEBI_W / 2)
    setProperty('mechanic_celebi.y', y - CELEBI_H / 2)
    setScale('mechanic_celebi', CELEBI_START_SCALE / celebiZoom)
    setProperty('mechanic_celebi.color', getColorFromHex(CELEBI_START_COLOR))
    setProperty('mechanic_celebi.alpha', 1)
    cancelTimer('mechCelebiHide')
    playCelebi('rise')
    runTimer('mechCelebiIdle', RISE_TIME)
    if sing then
        runTimer('mechNotes', RISE_TIME - 0.5)       -- the song starts once she is up
        sfx(SND_PERISH, 'mechPerish')
    end
end

local function spawnNotes()
    for i = 0, NOTE_POOL - 1 do
        local n = notes[i]
        n.t, n.a0 = 0, -math.pi / 2 + i * 2 * math.pi / NOTE_POOL   -- each note rides its own arm of the spiral
        setProperty(n.tag .. '.alpha', 0)
        setProperty(n.tag .. '.color', getColorFromHex(NOTE_START_COLOR))
        doTweenColor('mechNoteC' .. i, n.tag, 'FFFFFF', NOTE_LIFE * 0.8, 'linear')
    end
end

local function updateNotes(dt)
    for i = 0, NOTE_POOL - 1 do
        local n = notes[i]
        if n.t then
            n.t = n.t + dt
            if n.t >= NOTE_LIFE then
                n.t = nil
                setProperty(n.tag .. '.alpha', 0)
            else
                local r, a = NOTE_SPEED * n.t, n.a0 + NOTE_SPIN * n.t
                local x, y = toWorld(CELEBI_X + NOTE_ORIGIN_X + math.cos(a) * r,
                                     CELEBI_Y + NOTE_ORIGIN_Y + math.sin(a) * r * NOTE_SQUASH, celebiZoom)
                setProperty(n.tag .. '.x', x - NOTE_W / 2)
                setProperty(n.tag .. '.y', y - NOTE_H / 2)
                setScale(n.tag, NOTE_SCALE / celebiZoom * (0.6 + 0.4 * math.min(1, n.t / 0.5)))
                local fade = math.min(n.t / NOTE_FADE_IN, (NOTE_LIFE - n.t) / NOTE_FADE_OUT, 1)
                setProperty(n.tag .. '.alpha', math.max(0, fade) * NOTE_ALPHA)
            end
        end
    end
end

-- ===== letters (unown_letter.gd) ==========================================
local function ensureLetter(i)
    while pool <= i do
        local glow, tag = 'mechanic_glow' .. pool, 'mechanic_unown' .. pool
        makeLuaSprite(glow, 'monochrome/unown_particle_bloom', 0, 0)
        setBlendMode(glow, 'add')
        pinned(glow)
        makeAnimatedLuaSprite(tag, 'monochrome/UnownLetters', 0, 0)
        addAnimationByIndices(tag, 'none', 'UnownA Act_', '0', 24, false)   -- the plain orb, before it shows its letter
        playAnim(tag, 'none', true)
        pinned(tag)
        pool = pool + 1
    end
    return 'mechanic_unown' .. i, 'mechanic_glow' .. i
end

local function unownEnter(i)
    local u = letters[i]
    if not (u and u.ch) then return end
    setProperty(u.tag .. '.alpha', 1)
    setProperty(u.tag .. '.color', getColorFromHex(WAITING_COLOR))
    setScale(u.tag, 0)
    tweenScale(u.tag, 'u' .. i, u.scale, 0.3, 'backOut')
    doTweenAlpha('mechg' .. i, u.glow, GLOW_ALPHA, 0.4, 'quadOut')
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
    doTweenColor('mechc' .. i, u.tag, DONE_COLOR, 0.2, 'quadOut')
    doTweenAlpha('mecha' .. i, u.tag, 0.7, 0.2, 'quadOut')
    doTweenAlpha('mechg' .. i, u.glow, 0, 0.2, 'quadOut')
    tweenScale(u.tag, 'u' .. i, u.scale * 0.9, 0.2, 'quadOut')
end

local function unownExit(i)
    local u = letters[i]
    doTweenAlpha('mecha' .. i, u.tag, 0, 0.2, 'quadIn')
    doTweenAlpha('mechg' .. i, u.glow, 0, 0.2, 'quadIn')
    tweenScale(u.tag, 'u' .. i, 0, 0.2, 'backIn')
end

local function exitAll()
    for i = 0, wordLen - 1 do
        if letters[i].ch then runTimer('mechExit' .. i, rnd(0.01, 0.2)) end
    end
end

-- ===== typing_challenge.gd ================================================
local function skipBlanks()
    while typed < wordLen and not letters[typed].ch do typed = typed + 1 end
end

local function updateUnowns()
    for i = 0, wordLen - 1 do
        local u = letters[i]
        if u.ch then
            if i == typed then
                removeLuaSprite(u.tag, false)      -- re-adding puts it in front of the other letters
                addLuaSprite(u.tag, true)
                unownActivate(i)
            elseif i < typed then
                unownSucceed(i)
            end
        end
    end
end

local function finish(keepResetLocked)
    prompting, active = false, false
    cancelTimer('mechNotes')
    setProperty('boyfriend.stunned', false)
    if not keepResetLocked then lockReset(false) end
    darkTo(0)
end

local function succeed()
    passed, over = true, true
    for _, t in ipairs({'mechTick', 'mechTickDanger', 'mechFail', 'mechPerish'}) do stopSound(t) end
    playCelebi('pass')
    runTimer('mechCelebiHide', 30 / 24)
    for i = 0, wordLen - 1 do if letters[i].ch then unownSucceed(i) end end
    runTimer('mechExitAll', 0.5)
    runTimer('mechUnlockReset', 0.1)           -- let the final R keypress clear before restoring quick restart
    finish(true)
end

local function fail()
    over = true
    cancelTween('mechCelebiSX'); cancelTween('mechCelebiSY'); cancelTween('mechCelebiCol')
    if celebiAnim ~= 'fail' then
        if not failSound then failSound = true; sfx(SND_FAIL, 'mechFail') end
        playCelebi('fail')
        runTimer('mechCelebiHide', 48 / 24)
    end
    for i = 0, wordLen - 1 do if letters[i].ch then unownSucceed(i) end end
    fails = fails + 1

    callOnLuas('fgEyesNextPhase', {})          -- setupAndEvents.lua: the foreground Unown eyes appear
    if fails >= MAX_FAILS then
        setHealth(0)
    else
        -- the bigger penalty: health bar splits straight to the second stage
        if luaSpriteExists('mono_healthBar') then playAnim('mono_healthBar', 'split2', true) end
        if luaSpriteExists('mono_healthBarMask') then playAnim('mono_healthBarMask', 'split2', true) end
        callOnLuas('setHealthSplit', {2})      -- optional hook: lets setupAndEvents.lua cap the health
        runTimer('mechExitAll', 0.5)
    end
    finish()
end

local function endChallenge()
    if over then return end
    if passed then succeed() else fail() end
end

local function inputLetter(ch)                 -- ch = one lowercase letter
    skipBlanks()
    if typed < wordLen and ch ~= letters[typed].ch:lower() then
        shakes[typed] = 0
        setProperty(letters[typed].tag .. '.color', getColorFromHex('333333'))
        doTweenColor('mechc' .. typed, letters[typed].tag, 'FFFFFF', 0.3, 'quadOut')
        penalty = penalty + MISTAKE_PENALTY
        return
    end
    if typed < wordLen then typed = typed + 1; skipBlanks() end
    if typed >= wordLen then passed = true; endChallenge() else updateUnowns() end
end

local function startChallenge()
    if not active or over then return end
    local timeLeft = deadline - penalty - getSongPosition() / 1000
    if timeLeft <= 0 then return end
    lastSecond = math.floor(timeLeft - TICK_OFFSET)

    for i = 0, wordLen - 1 do
        local u = letters[i]
        if u.ch then
            addAnimationByPrefix(u.tag, 'act', 'Unown' .. u.ch .. ' Act', 24, false)
            playAnim(u.tag, 'act', true)
        end
    end

    typed, autoTimer, prompting = 0, 0, true
    skipBlanks()
    updateUnowns()
    runTimer('stun player', 0.85)
    lockReset(true)

    -- Celebi grows and brightens over the time limit (a fixed-length tween, like the original)
    local s = CELEBI_END_SCALE / celebiZoom
    doTweenX('mechCelebiSX', 'mechanic_celebi.scale', s, timeLeft, CELEBI_EASE)
    doTweenY('mechCelebiSY', 'mechanic_celebi.scale', s, timeLeft, CELEBI_EASE)
    doTweenColor('mechCelebiCol', 'mechanic_celebi', 'FFFFFF', timeLeft, CELEBI_EASE)
end

local function initiate(eventSec, duration, spec)
    if active then return end
    local w
    if spec:sub(1, 1) == '=' then
        w = spec:sub(2):upper():match('^%s*(.-)%s*$')
        if not w:find('%a') then w = nil end
    end
    word = w or pickWord((spec ~= '' and spec:sub(1, 1) ~= '=') and spec or DEFAULT_LIST)
    wordLen = #word
    active, prompting, over, passed, failSound = true, false, false, false, false
    typed, penalty, shakes = 0, 0, {}
    deadline = eventSec + (duration or (TIME_BASE + TIME_PER_LETTER * wordLen))

    -- Celebi is normally already out (Celebi Appear) and is NOT touched here. Without that event she appears now.
    cancelTimer('mechNotes')                   -- the song ends where the typing begins
    if not celebiOut then celebiAppear(false)
    elseif celebiAnim ~= 'rise' and celebiAnim ~= 'idle' then playCelebi('idle') end
    cancelTimer('mechCelebiHide')
    darkTo(DARK_ALPHA)

    -- fly-by, letters and glows are placed from the current zoom
    viewZoom = zoomNow()
    local k = 1 / viewZoom
    local fx, fy = toWorld(W2, H2, viewZoom)
    setProperty('mechanic_unownflyby.x', fx - FLYBY_W / 2)
    setProperty('mechanic_unownflyby.y', fy - FLYBY_H / 2)
    setScale('mechanic_unownflyby', UI * k)
    setProperty('mechanic_unownflyby.alpha', 1)
    playAnim('mechanic_unownflyby', 'fly', true)
    runTimer('mechFlybyHide', 32 / 24)

    for i = 0, pool - 1 do                     -- hide leftovers from the last challenge
        cancelTimer('mechExit' .. i)
        setProperty('mechanic_unown' .. i .. '.alpha', 0)
        setProperty('mechanic_glow' .. i .. '.alpha', 0)
    end

    local size = wordLen > 10 and 10 / (wordLen - 1) or 1
    local offsetX = LETTER_SPACING * size * (wordLen - 1) * 0.5
    for i = 0, wordLen - 1 do
        local tag, glow = ensureLetter(i)
        local c = word:sub(i + 1, i + 1)
        local s = rnd(0.6, 0.7) * size * UI * k
        local cx, cy = toWorld(W2 + (LETTER_SPACING * i + rnd(-20, 20) * UI) * size - offsetX, H2 + rnd(-60, 60) * UI, viewZoom)
        letters[i] = {tag = tag, glow = glow, ch = c:match('%a') and c:upper() or false, scale = s, done = false, x = cx - LETTER_W / 2}
        setProperty(tag .. '.x', cx - LETTER_W / 2)
        setProperty(tag .. '.y', cy - LETTER_H / 2)
        playAnim(tag, 'none', true)
        setProperty(tag .. '.alpha', 0)
        setScale(tag, s)

        -- glow behind the letter (a 1280x1280 image, centred on the letter)
        setProperty(glow .. '.x', cx - 640)
        setProperty(glow .. '.y', cy - 640)
        setScale(glow, LETTER_H * s * GLOW_SIZE / 1280)
        setProperty(glow .. '.alpha', 0)

        if letters[i].ch then runTimer('mechEnter' .. i, rnd(0.125, 1 / 3)) end
    end
    runTimer('mechPrompt', PROMPT_DELAY)
end

-- ===== engine callbacks ===================================================
function onCreate()
    math.randomseed(os.time())
    for _, img in ipairs({'celebi', 'celebi_note', 'unownflyby', 'UnownLetters', 'unown_particle_bloom'}) do
        precacheImage('monochrome/' .. img)
    end

    makeAnimatedLuaSprite('mechanic_celebi', 'monochrome/celebi', 0, 0)
    for anim, prefix in pairs({rise = 'rise', idle = 'idle', shake = 'shake0', shakelight = 'shakelight', pass = 'pass', fail = 'fail'}) do
        addAnimationByPrefix('mechanic_celebi', anim, prefix, (anim == 'shake' or anim == 'shakelight') and 25 or 24, anim == 'idle')
    end
    pinned('mechanic_celebi', false)

    makeAnimatedLuaSprite('mechanic_unownflyby', 'monochrome/unownflyby', 0, 0)
    addAnimationByPrefix('mechanic_unownflyby', 'fly', 'unownflyby_copy', 24, false)
    pinned('mechanic_unownflyby')

    for i = 0, NOTE_POOL - 1 do
        notes[i] = {tag = 'mechanic_note' .. i}
        makeLuaSprite(notes[i].tag, 'monochrome/celebi_note', 0, 0)
        pinned(notes[i].tag)
    end
    for i = 0, 11 do ensureLetter(i) end
end

-- keep the mechanic above sprites other scripts created during onCreate
function onCreatePost()
    local tags = {'mechanic_celebi', 'mechanic_unownflyby'}
    for i = 0, NOTE_POOL - 1 do tags[#tags + 1] = notes[i].tag end
    for i = 0, pool - 1 do
        tags[#tags + 1] = 'mechanic_glow' .. i
        tags[#tags + 1] = 'mechanic_unown' .. i
    end
    for _, tag in ipairs(tags) do
        removeLuaSprite(tag, false)
        addLuaSprite(tag, true)
        setObjectCamera(tag, 'game')
        setScrollFactor(tag, 0, 0)
    end
end

function onEvent(name, value1, value2, strumTime)
    if name == 'Celebi Appear' then
        if not celebiOut and not active then celebiAppear(true) end
    elseif name == 'Set Unown Typing Delay' then
        PROMPT_DELAY = tonumber(value1)
    elseif name == 'Unown Typing' then
        local ms = tonumber(strumTime) or getSongPosition()
        initiate(ms / 1000, tonumber(value1), (value2 or ''):match('^%s*(.-)%s*$'))
    end
end

local timers = {
    mechPrompt = startChallenge,
    mechExitAll = exitAll,
    mechNotes = spawnNotes,
    mechUnlockReset = function() lockReset(false) end,
    mechCelebiIdle = function() if celebiAnim == 'rise' then playCelebi('idle') end end,
    mechCelebiHide = function() setProperty('mechanic_celebi.alpha', 0); celebiOut = false end,
    mechFlybyHide = function() setProperty('mechanic_unownflyby.alpha', 0) end,
}

function onTimerCompleted(tag)
    if tag == 'stun player' then
        setProperty('boyfriend.stunned', true)
    end
    if timers[tag] then timers[tag](); return end
    local enter, exit = tag:match('^mechEnter(%d+)$'), tag:match('^mechExit(%d+)$')
    if enter then unownEnter(tonumber(enter)) elseif exit then unownExit(tonumber(exit)) end
end

function onUpdate(elapsed)
    updateNotes(elapsed)

    for i, t in pairs(shakes) do               -- wrong-key shake
        local u = letters[i]
        t = t + elapsed
        if t >= 0.3 then
            shakes[i] = nil
            setProperty(u.tag .. '.x', u.x)
        else
            shakes[i] = t
            setProperty(u.tag .. '.x', u.x + math.sin(t * 70) * 14 * UI / viewZoom * (1 - t / 0.3))
        end
    end

    if not prompting or over then return end

    local timeLeft = deadline - penalty - getSongPosition() / 1000
    if timeLeft <= 0 then endChallenge(); return end   -- time ran out -> fail

    if AUTOPLAY then
        autoTimer = autoTimer + elapsed
        if autoTimer >= 0.2 then
            autoTimer = 0
            skipBlanks()
            if typed < wordLen then inputLetter(letters[typed].ch:lower()) end
        end
    else
        for _, key in ipairs(KEYS) do
            if keyboardJustPressed(key) then
                inputLetter(key:lower())
                if over then return end
            end
        end
    end
    if over then return end

    -- Celebi ticks once per second, the last one is her song
    local second = math.floor(timeLeft - TICK_OFFSET)
    if second ~= lastSecond then
        if second == -1 then
            failSound = true
            sfx(SND_FAIL, 'mechFail')
            playCelebi('fail')
            runTimer('mechCelebiHide', 48 / 24 + 0.5)
        else
            sfx(second < DANGER_SECONDS and SND_DANGER or SND_TICK, second < DANGER_SECONDS and 'mechTickDanger' or 'mechTick')
            playCelebi(second < DANGER_SECONDS and 'shake' or 'shakelight')
        end
    end
    lastSecond = second
end

function onDestroy()
    lockReset(false)            -- noReset is a saved preference: always give it back
end
