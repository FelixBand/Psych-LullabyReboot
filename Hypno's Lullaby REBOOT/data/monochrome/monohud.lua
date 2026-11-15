function onCreate()
    prevPref = getPropertyFromClass('backend.ClientPrefs', 'data.middleScroll')
    if prevPref then
        setPropertyFromClass('backend.ClientPrefs', 'data.middleScroll', false)
    end

    makeAnimatedLuaSprite('mono_healthBar', 'monochrome/health', screenWidth - 600, 500)
    addAnimationByPrefix('mono_healthBar', 'full', 'bar_full', 1, false)
    addAnimationByPrefix('mono_healthBar', 'split1', 'bar_split_first', 8, false)
    addAnimationByPrefix('mono_healthBar', 'split2', 'bar_split_second', 8, false)

    makeAnimatedLuaSprite('mono_healthBarMask', 'monochrome/health', screenWidth - 600, 500)
    addAnimationByPrefix('mono_healthBarMask', 'full', 'mask_full', 1, false)
    addAnimationByPrefix('mono_healthBarMask', 'split1', 'mask_split_first', 8, false)
    addAnimationByPrefix('mono_healthBarMask', 'split2', 'mask_split_second', 8, false)
    setProperty('mono_healthBarMask.color', getColorFromHex('B7AEAB'))

    setObjectCamera('mono_healthBar', 'hud')
    setObjectCamera('mono_healthBarMask', 'hud')

    if not downscroll then
        setProperty('mono_healthBar.flipY', true)
        setProperty('mono_healthBarMask.flipY', true)
        setProperty('mono_healthBar.y', 0)
        setProperty('mono_healthBarMask.y', 0)
    end
    addLuaSprite('mono_healthBar')
    addLuaSprite('mono_healthBarMask')
    playAnim('mono_healthBar', 'full', true)
    playAnim('mono_healthBarMask', 'full', true)
end

-- Health bar mask.
-- Calling runHaxeCode / runHaxeFunction repeatedly gets slower and slower on some builds (Psych Online 0.14.8),
-- so it is called ONCE here, only to create the clipRect. Every later update uses plain Lua calls:
-- resize the existing rect in place, then re-set the current frame so the engine re-applies the clip.
local fastPath = false
local validated = false

function onCreatePost()
    runHaxeCode([[
        var spr = game.getLuaObject('mono_healthBarMask');
        if (spr != null)
            spr.clipRect = new flixel.math.FlxRect(0, 0, spr.frameWidth * 0.5, spr.frameHeight);
    ]])
    -- only try the fast path if the rect really can be read from Lua on this build
    fastPath = type(getProperty('mono_healthBarMask.clipRect.width')) == 'number'
end

local function applyClip(rw, rh)
    setProperty('mono_healthBarMask.clipRect.x', 0)
    setProperty('mono_healthBarMask.clipRect.y', 0)
    setProperty('mono_healthBarMask.clipRect.width', rw)
    setProperty('mono_healthBarMask.clipRect.height', rh)
    -- re-set the same frame: this makes the sprite re-apply the (resized) clip rect
    setProperty('mono_healthBarMask.animation.frameIndex', getProperty('mono_healthBarMask.animation.frameIndex'))
end

-- the width the sprite is really drawing (can be smaller than the clip: the atlas frame is trimmed)
local function drawnWidth()
    return getProperty('mono_healthBarMask._frame.frame.width')
end

-- one-time self-check: two clearly different clip widths must give two different drawn widths
local function validateFastPath(rh)
    applyClip(200, rh)
    local a = drawnWidth()
    applyClip(20, rh)
    local b = drawnWidth()
    local ok = type(a) == 'number' and type(b) == 'number' and a > b
    if ok then
        debugPrint('[monohud] health mask: fast path OK')
    else
        debugPrint('[monohud] health mask: fast path failed (drawn ' .. tostring(a) .. ' vs ' .. tostring(b) .. '), using fallback')
    end
    return ok
end

local function fallbackMask(health)
    -- slow on some builds, but always correct
    runHaxeCode([[
        var spr = game.getLuaObject('mono_healthBarMask');
        if (spr != null) {
            spr.clipRect = new flixel.math.FlxRect(
                0, 0, spr.frameWidth * ]] .. health / 2 .. [[, spr.frameHeight
            );
        }
    ]])
end

local function updateMask(health)
    local w = getProperty('mono_healthBarMask.frameWidth') * health / 2
    local h = getProperty('mono_healthBarMask.frameHeight')
    -- the engine rounds the clip to whole pixels, so do the same
    local rw, rh = math.floor(w + 0.5), math.floor(h + 0.5)

    if fastPath and not validated then
        if validateFastPath(rh) then
            validated = true
        else
            fastPath = false
        end
    end

    if fastPath then
        applyClip(rw, rh)
    else
        fallbackMask(health)
    end
end

-- Only redo the clip when it would actually look different: the rounded width changed,
-- or a new animation (split1/split2) swapped the frame.
local lastWidth, lastAnim = nil, nil

function onUpdate(elapsed)
    local health = getHealth()
    local anim = getProperty('mono_healthBarMask.animation.curAnim.name')
    local width = math.floor(getProperty('mono_healthBarMask.frameWidth') * health / 2 + 0.5)
    if width ~= lastWidth or anim ~= lastAnim then
        lastWidth = width
        lastAnim = anim
        updateMask(health)
    end
end

function onDestroy()
    setPropertyFromClass('backend.ClientPrefs', 'data.middleScroll', prevPref)
end