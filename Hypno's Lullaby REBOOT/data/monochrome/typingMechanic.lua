-- Monochrome typing mechanic (port of typing_challenge.gd / unown_letter.gd)
--
-- Chart events:
--   "Celebi Appear"  - Celebi rises and sings the Perish Song: music notes spiral outward from one point above her head until the typing starts.
--                      (no values). Put it a few seconds before "Unown Typing". If you forget, Unown Typing makes her appear.
--   "Unown Typing"   - the typing challenge itself.
--        value1 = seconds from the event until Celebi runs out of time   (empty = 2.5 s + 0.4 s per letter)
--        value2 = which word list to use: a file name from UnownWords/ ("Normal", "Hard", ...)   (empty = Normal)
--                 or "=SOME WORDS" to force one specific word
--
-- What happens during the challenge (same order as the original):
--   1. event: a word is picked, the game darkens a bit, the Unowns fly by and the (still blank) letters pop in with a glow
--   2. PROMPT_DELAY later the letters get their faces and you can type. Celebi grows and brightens until time is up
--   3. right key -> next letter. wrong key -> the letter shakes and you lose 0.5 s (the original takes 0.25 s twice)
--   4. whole word typed = Celebi returns. time up = Celebi's head bursts and you fail:
--        1st fail -> health bar splits (split2) + the foreground Unown eyes appear,  2nd fail -> instant death
--
-- Everything lives on camGame, in front of the characters, pinned to the screen (scroll factor 0).
-- Only A-Z are typeable. Spaces and anything else (? ! ' ...) are skipped automatically.

-- ===== config =============================================================
local UI = screenWidth / 1920            -- the Godot project is 1920x1080, everything authored there is scaled by this

local WORD_DIR = 'UnownWords/'
local DEFAULT_LIST = 'Normal'
local PROMPT_DELAY = 2.0                 -- seconds between the Unown Typing event and the moment you can start typing
local TIME_BASE, TIME_PER_LETTER = 2.5, 0.4   -- time limit when the event has no value1
local MISTAKE_PENALTY = 0.5              -- time lost per wrong key (original: 0.25 + 0.25)
local MAX_FAILS = 2                      -- this many failed challenges = instant death
local RESET_UNLOCK_DELAY = 0.1           -- let the final R keypress clear before restoring quick restart

local TICK_OFFSET = 0.5                  -- Celebi ticks half a second before each whole second left
local DANGER_SECONDS = 3                 -- below this many seconds the tick gets the danger sound / strong shake

local BLOCK_STRUMS = true                -- the player's note keys do nothing while you are typing
local AUTOPLAY = false                   -- types the word for you, one letter every 0.2 s (the original's autoplay flag)

-- darkening of camGame while typing (uses the 'darkOverlay' sprite from setupAndEvents.lua)
local DARK_ALPHA, DARK_FADE = 0.45, 1.0

-- Celebi (positions are in screen pixels of a 1280x720 screen; Godot values: scale 0.7 -> 1.2, grey 0x3F -> white)
local CELEBI_X, CELEBI_Y = screenWidth * 0.18, screenHeight / 2 + 10
local CELEBI_START_SCALE, CELEBI_END_SCALE = 1.025 * UI, 1.325 * UI
local CELEBI_START_COLOR = '3F3F3F'
local CELEBI_EASE = 'quadIn'             -- the original uses a Curve resource that isn't in the repo; tweak to taste
local CELEBI_W, CELEBI_H = 407, 771      -- size of one Celebi frame in the sheet
-- Celebi is placed ONCE, the moment she appears, and this script never moves or rescales her again (the camera's own zoom
-- still carries her along like everything else on camGame). The screen-pixel values above are converted to camGame
-- coordinates at that moment from the camera zoom - or from CELEBI_REF_ZOOM if you set a number here, which makes her
-- position a pure constant that doesn't depend on what the camera is doing at all.
local CELEBI_REF_ZOOM = nil

-- Perish Song music notes: all of them start at ONE point (NOTE_ORIGIN, relative to Celebi's centre) and spiral outward,
-- each note riding its own arm of the spiral.
local NOTE_POOL = 7
local NOTE_LIFE = 1.7                    -- seconds a note lives
local NOTE_SPEED = 120                    -- outward speed, screen px per second (LINEAR, no easing)
local NOTE_SPIN = 0.80                   -- spin around the origin, radians per second (LINEAR); negative = other direction
local NOTE_FADE_IN = 0.5                -- seconds a note takes to fade in after it spawns
local NOTE_FADE_OUT = 0.8                -- seconds of fading out at the end of its life
local NOTE_SQUASH = 0.75                 -- below 1 flattens the spiral vertically, 1 = perfectly round
local NOTE_ORIGIN_X, NOTE_ORIGIN_Y = 0, -70   -- where the notes come from, relative to Celebi's centre (up = towards her head)
local NOTE_SCALE = 0.45 * UI
local NOTE_W, NOTE_H = 142, 174
local NOTE_START_COLOR = 'FF2020'        -- red, fades to white while flying

-- Unown letters
local LETTER_SPACING = 160 * UI
local LETTER_CENTER_X, LETTER_CENTER_Y = screenWidth / 2, screenHeight / 2
local LETTER_W, LETTER_H = 196, 248      -- size of one letter frame in the sheet
local WAITING_COLOR = 'BDBDBD'           -- letters you still have to type
local DONE_COLOR = '6E6E6E'              -- letters you already typed
local GLOW_SIZE = 2.6                    -- glow diameter, in letter heights
local GLOW_ALPHA = 0.65

-- fly-by that plays when a challenge starts
local FLYBY_W, FLYBY_H = 404, 934
local FLYBY_X, FLYBY_Y = screenWidth / 2, screenHeight / 2

-- sounds (put .ogg files in sounds/ with these names; missing files are simply skipped)
local SND_TICK, SND_TICK_DANGER, SND_FAIL, SND_PERISH = 'celebiTick', 'celebiTickDanger', 'celebiFail', 'celebiPerishSong'

-- ===== state ==============================================================
local lists, usedWords = {}, {}
local active, prompting, challengeOver, passed = false, false, false, false
local word, wordLen = '', 0
local letters = {}                        -- 0-based: {tag, glow, ch, x, y, cx, cy, scale}   (ch = 'A'..'Z' or false for skipped chars)
local pool = 0                            -- how many letter sprites exist
local lettersPassed = 0
local deadline, endOffset = 0, 0          -- song seconds
local lastSecond = 0
local failCount = 0
local failSoundPlayed = false
local celebiAnim = ''
local celebiOut = false
local shakes = {}
local autoTimer = 0
local prevNoReset = nil
local haveSound = {}
local viewZoom = 1                        -- camGame zoom when things were last placed (sprites are pinned, zoom still scales them)
local perishing, nextBurst = false, 0
local notes, noteActive = {}, 0
local KEYS = {}
for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ'):gmatch('.') do KEYS[#KEYS + 1] = c end

local function songSec() return getSongPosition() / 1000 end

local function rnd(a, b) return a + math.random() * (b - a) end

-- ===== screen <-> camGame =================================================
-- Sprites are pinned (scroll factor 0), so only the camera zoom matters: a sprite at world x shows up at
-- centre + (x - centre) * zoom. These two undo that, so "screen pixel" positions land where you expect.
local function refreshView()
    local z = getProperty('camGame.zoom')
    viewZoom = (type(z) == 'number' and z > 0) and z or 1
end
local function worldX(px) return screenWidth / 2 + (px - screenWidth / 2) / viewZoom end
local function worldY(py) return screenHeight / 2 + (py - screenHeight / 2) / viewZoom end
local function K() return 1 / viewZoom end   -- sizes get the same compensation

-- Celebi (and the notes that come out of her) use their OWN conversion, captured once when she appears and never refreshed.
local celebiZoom = 1
local function captureCelebiView()
    local z = CELEBI_REF_ZOOM or getProperty('camGame.zoom')
    celebiZoom = (type(z) == 'number' and z > 0) and z or 1
end
local function cWorldX(px) return screenWidth / 2 + (px - screenWidth / 2) / celebiZoom end
local function cWorldY(py) return screenHeight / 2 + (py - screenHeight / 2) / celebiZoom end
local function cK() return 1 / celebiZoom end

-- ===== helpers ============================================================
local function playSfx(name, tag)
    if haveSound[name] == nil then haveSound[name] = checkFileExists('sounds/' .. name .. '.ogg') end
    if haveSound[name] then playSound(name, 1, tag) end
end

local function stopSfx()
    for _, t in ipairs({'mechTick', 'mechTickDanger', 'mechFail', 'mechPerish'}) do stopSound(t) end
end

local function blockStrums(on)
    if not BLOCK_STRUMS then return end
    local v = on and 'true' or 'false'
    runHaxeCode('game.strumsBlocked = [' .. v .. ',' .. v .. ',' .. v .. ',' .. v .. '];')
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

local function pinned(tag, ontop)
    if ontop == nil then
        ontop = true
    end
    setObjectCamera(tag, 'game')
    setScrollFactor(tag, 0, 0)
    setProperty(tag .. '.alpha', 0)
    addLuaSprite(tag, ontop)               -- true = in front of the characters
end

local function ensureLetter(i)
    while pool <= i do
        local glow = 'mechanic_glow' .. pool
        makeLuaSprite(glow, 'monochrome/unown_particle_bloom', 0, 0)
        setBlendMode(glow, 'add')
        pinned(glow)

        local tag = 'mechanic_unown' .. pool
        makeAnimatedLuaSprite(tag, 'monochrome/UnownLetters', 0, 0)
        addAnimationByIndices(tag, 'none', 'UnownA Act_', '0', 24, false)   -- the plain orb, before it shows its letter
        playAnim(tag, 'none', true)
        pinned(tag)
        pool = pool + 1
    end
    return 'mechanic_unown' .. i, 'mechanic_glow' .. i
end

local function playCelebi(name)
    celebiAnim = name
    playAnim('mechanic_celebi', name, true)
end

local function placeCelebi()
    setProperty('mechanic_celebi.x', cWorldX(CELEBI_X) - CELEBI_W / 2)
    setProperty('mechanic_celebi.y', cWorldY(CELEBI_Y) - CELEBI_H / 2)
end

-- ===== Celebi + Perish Song ===============================================
local RISE_TIME = 26 / 24

local function celebiAppear(sing)
    captureCelebiView()                        -- the one and only time her position and scale are worked out
    celebiOut = true
    placeCelebi()
    setScale('mechanic_celebi', CELEBI_START_SCALE * cK())
    setProperty('mechanic_celebi.color', getColorFromHex(CELEBI_START_COLOR))
    setProperty('mechanic_celebi.alpha', 1)
    cancelTimer('mechCelebiHide')
    playCelebi('rise')
    runTimer('mechCelebiIdle', RISE_TIME)

    if sing then
        perishing = true
        nextBurst = RISE_TIME                  -- the song starts once she is up
        playSfx(SND_PERISH, 'mechPerish')
    end
end

local function spawnNote(angle)
    for i = 0, NOTE_POOL - 1 do
        local n = notes[i]
        if not n.on then
            n.on, n.t, n.a0 = true, 0, angle      -- angle = which arm of the spiral this note rides
            noteActive = noteActive + 1
            setProperty(n.tag .. '.alpha', 0)
            setProperty(n.tag .. '.color', getColorFromHex(NOTE_START_COLOR))
            doTweenColor('mechNoteC' .. i, n.tag, 'FFFFFF', NOTE_LIFE * 0.8, 'linear')   -- red -> white
            return
        end
    end
end

local function updateNotes(elapsed)
    local originX, originY = CELEBI_X + NOTE_ORIGIN_X, CELEBI_Y + NOTE_ORIGIN_Y
    for i = 0, NOTE_POOL - 1 do
        local n = notes[i]
        if n.on then
            n.t = n.t + elapsed
            local p = n.t / NOTE_LIFE
            if p >= 1 then
                n.on = false
                noteActive = noteActive - 1
                setProperty(n.tag .. '.alpha', 0)
            else
                local r = NOTE_SPEED * n.t                         -- linear; 0 at birth: every note leaves from the same point
                local ang = n.a0 + NOTE_SPIN * n.t                 -- linear spin
                local sx = originX + math.cos(ang) * r
                local sy = originY + math.sin(ang) * r * NOTE_SQUASH
                setProperty(n.tag .. '.x', cWorldX(sx) - NOTE_W / 2)
                setProperty(n.tag .. '.y', cWorldY(sy) - NOTE_H / 2)
                setScale(n.tag, NOTE_SCALE * cK() * (0.6 + 0.4 * math.min(1, n.t / 0.5)))
                local fadeIn = math.min(1, n.t / NOTE_FADE_IN)                          -- 0 -> 1 right after spawning
                local fadeOut = math.min(1, (NOTE_LIFE - n.t) / NOTE_FADE_OUT)       -- 1 -> 0 over the last NOTE_FADE_OUT seconds
                setProperty(n.tag .. '.alpha', math.max(0, math.min(fadeIn / 2, fadeOut / 2)))
            end
        end
    end
end

-- ===== unown_letter.gd ====================================================
local function unownEnter(i)
    local u = letters[i]
    if not u or not u.ch then return end
    setProperty(u.tag .. '.alpha', 1)
    setProperty(u.tag .. '.color', getColorFromHex(WAITING_COLOR))
    setScale(u.tag, 0)
    tweenScale(u.tag, 'u' .. i, u.scale, 0.3, 'backOut')
    doTweenAlpha('mechg' .. i, u.glow, GLOW_ALPHA, 0.4, 'quadOut')       -- the glow fades in as the letter arrives
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
    doTweenAlpha('mechg' .. i, u.glow, 0, 0.2, 'quadOut')
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
    doTweenAlpha('mechg' .. i, u.glow, 0, 0.2, 'quadIn')
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
                removeLuaSprite(u.tag, false)      -- re-adding puts it in front of the other letters (move_to_front)
                addLuaSprite(u.tag, true)
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
    callOnLuas('fgEyesNextPhase', {})          -- setupAndEvents.lua: the foreground Unown eyes appear
    if n >= MAX_FAILS then
        setHealth(0)
        return
    end
    -- the bigger penalty: health bar splits straight to the second stage
    if luaSpriteExists('mono_healthBar') then playAnim('mono_healthBar', 'split2', true) end
    if luaSpriteExists('mono_healthBarMask') then playAnim('mono_healthBarMask', 'split2', true) end
    callOnLuas('setHealthSplit', {2})          -- optional: lets setupAndEvents.lua cap the health like its Fade Out event does
end

local function finish(keepResetLocked)
    prompting = false
    active = false
    perishing = false
    blockStrums(false)
    if not keepResetLocked then lockReset(false) end
    darkTo(0)
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
    runTimer('mechUnlockReset', RESET_UNLOCK_DELAY)
    finish(true)
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
    if failCount < MAX_FAILS then runTimer('mechExitAll', 0.5) end
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
    doTweenX('mechCelebiSX', 'mechanic_celebi.scale', CELEBI_END_SCALE * cK(), timeLeft, CELEBI_EASE)
    doTweenY('mechCelebiSY', 'mechanic_celebi.scale', CELEBI_END_SCALE * cK(), timeLeft, CELEBI_EASE)
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

    -- Celebi: normally she is already out (Celebi Appear) and is NOT touched here: no re-placing, no rescaling.
    -- If the chart has no Celebi Appear before this event, she appears now.
    refreshView()                              -- the letters and the fly-by are placed from the current zoom; Celebi is not
    perishing = false                          -- the song ends where the typing begins
    if not celebiOut then
        celebiAppear(false)
    elseif celebiAnim ~= 'rise' and celebiAnim ~= 'idle' then
        playCelebi('idle')
    end
    cancelTimer('mechCelebiHide')

    darkTo(DARK_ALPHA)

    -- fly-by
    local k = K()
    setProperty('mechanic_unownflyby.x', worldX(FLYBY_X) - FLYBY_W / 2)
    setProperty('mechanic_unownflyby.y', worldY(FLYBY_Y) - FLYBY_H / 2)
    setScale('mechanic_unownflyby', UI * k)
    setProperty('mechanic_unownflyby.alpha', 1)
    playAnim('mechanic_unownflyby', 'fly', true)
    runTimer('mechFlybyHide', 32 / 24)

    -- hide leftovers from the last challenge
    for i = 0, pool - 1 do
        cancelTimer('mechExit' .. i)
        setProperty('mechanic_unown' .. i .. '.alpha', 0)
        setProperty('mechanic_glow' .. i .. '.alpha', 0)
    end

    -- lay the letters out
    local size = 1.0
    if wordLen > 10 then size = 10.0 / (wordLen - 1) end
    local offsetX = LETTER_SPACING * size * (wordLen - 1) * 0.5
    for i = 0, wordLen - 1 do
        local tag, glow = ensureLetter(i)
        local c = word:sub(i + 1, i + 1)
        local ch = c:match('%a') and c:upper() or false
        local s = rnd(0.6, 0.7) * size * UI * k
        local px = ((LETTER_SPACING * i + rnd(-20, 20) * UI) * size) - offsetX
        local py = rnd(-60, 60) * UI
        local cx, cy = worldX(LETTER_CENTER_X + px), worldY(LETTER_CENTER_Y + py)
        local u = {tag = tag, glow = glow, ch = ch, scale = s, done = false, cx = cx, cy = cy,
                   x = cx - LETTER_W / 2, y = cy - LETTER_H / 2}
        letters[i] = u
        setProperty(tag .. '.x', u.x)
        setProperty(tag .. '.y', u.y)
        playAnim(tag, 'none', true)
        setProperty(tag .. '.alpha', 0)
        setScale(tag, s)

        -- glow behind the letter (a 1280x1280 image, centred on the letter)
        local gs = (LETTER_H * s * GLOW_SIZE) / 1280
        setProperty(glow .. '.x', cx - 640)
        setProperty(glow .. '.y', cy - 640)
        setScale(glow, gs)
        setProperty(glow .. '.alpha', 0)

        if ch then
            runTimer('mechEnter' .. i, rnd(0.125, 1.0 / 3.0))
        end
    end

    runTimer('mechPrompt', PROMPT_DELAY)
end

-- ===== engine callbacks ===================================================
function onCreate()
    math.randomseed(os.time())
    precacheImage('monochrome/celebi')
    precacheImage('monochrome/celebi_note')
    precacheImage('monochrome/unownflyby')
    precacheImage('monochrome/UnownLetters')
    precacheImage('monochrome/unown_particle_bloom')

    -- Register the sprites immediately, as in the working version. This avoids
    -- depending on onCreatePost for the sprites to enter the display list.
    makeAnimatedLuaSprite('mechanic_celebi', 'monochrome/celebi', 0, 0)
    addAnimationByPrefix('mechanic_celebi', 'rise', 'rise', 24, false)
    addAnimationByPrefix('mechanic_celebi', 'idle', 'idle', 24, true)
    addAnimationByPrefix('mechanic_celebi', 'shake', 'shake0', 25, false)
    addAnimationByPrefix('mechanic_celebi', 'shakelight', 'shakelight', 25, false)
    addAnimationByPrefix('mechanic_celebi', 'pass', 'pass', 24, false)
    addAnimationByPrefix('mechanic_celebi', 'fail', 'fail', 24, false)
    pinned('mechanic_celebi', false)

    makeAnimatedLuaSprite('mechanic_unownflyby', 'monochrome/unownflyby', 0, 0)
    addAnimationByPrefix('mechanic_unownflyby', 'fly', 'unownflyby_copy', 24, false)
    pinned('mechanic_unownflyby')

    for i = 0, NOTE_POOL - 1 do
        local tag = 'mechanic_note' .. i
        makeLuaSprite(tag, 'monochrome/celebi_note', 0, 0)
        notes[i] = {tag = tag, on = false, t = 0, a0 = 0, startX = 0, startY = 0}
        pinned(tag)
    end

    -- Pre-create the letter and glow sprites here too, so all mechanic sprites
    -- exist before chart events begin.
    for i = 0, 11 do ensureLetter(i) end
end

-- Keep the mechanic above sprites created by other scripts during onCreate.
-- The sprites are already registered, so failure of this optional ordering pass
-- cannot leave Celebi or the notes missing from the display list.
function onCreatePost()
    local tags = {'mechanic_celebi', 'mechanic_unownflyby'}
    for i = 0, NOTE_POOL - 1 do tags[#tags + 1] = notes[i].tag end
    for i = 0, pool - 1 do
        tags[#tags + 1] = 'mechanic_glow' .. i
        tags[#tags + 1] = 'mechanic_unown' .. i
    end
    for _, tag in ipairs(tags) do
        if luaSpriteExists(tag) then
            removeLuaSprite(tag, false)
            addLuaSprite(tag, true)
            setObjectCamera(tag, 'game')
            setScrollFactor(tag, 0, 0)
        end
    end
end

function onEvent(name, value1, value2, strumTime)
    -- Accept both event labels used by the chart and the earlier script.
    if name == 'Celebi Appear' then
        if not celebiOut and not active then celebiAppear(true) end
        return
    elseif name == 'Unown Typing' then
        if active then return end
        local ms = tonumber(strumTime)
        if ms == nil then ms = getSongPosition() end
        initiate(ms / 1000, tonumber(value1), value2 ~= nil and value2:match('^%s*(.-)%s*$') or nil)
    end
end

function onTimerCompleted(tag)
    if tag:sub(1, 4) ~= 'mech' then return end
    if tag == 'mechPrompt' then
        startChallenge()
    elseif tag == 'mechUnlockReset' then
        lockReset(false)
    elseif tag == 'mechExitAll' then
        exitAll()
    elseif tag == 'mechCelebiIdle' then
        if celebiAnim == 'rise' then playCelebi('idle') end
    elseif tag == 'mechCelebiHide' then
        setProperty('mechanic_celebi.alpha', 0)
        celebiOut = false
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
    -- Launch all seven notes together once Celebi finishes rising.
    if perishing then
        nextBurst = nextBurst - elapsed
        if nextBurst <= 0 then
            perishing = false
            for i = 0, NOTE_POOL - 1 do
                local angle = -math.pi / 2 + i * (2 * math.pi / NOTE_POOL)
                spawnNote(angle)
            end
        end
    end
    if noteActive > 0 then updateNotes(elapsed) end

    if next(shakes) ~= nil then
        for i, t in pairs(shakes) do
            t = t + elapsed
            local u = letters[i]
            if t >= 0.3 or not u then
                shakes[i] = nil
                if u then setProperty(u.tag .. '.x', u.x) end
            else
                shakes[i] = t
                setProperty(u.tag .. '.x', u.x + math.sin(t * 70) * 14 * UI * K() * (1 - t / 0.3))
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
