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

-- Health only changes on note hits/misses, so the clip rect is only rebuilt then.
-- (Parsing a Haxe string and allocating a new FlxRect every frame was very expensive.)
local lastHealth = nil

local function updateMask(health)
    runHaxeCode([[
        var spr = game.getLuaObject('mono_healthBarMask');
        if (spr != null) {
            spr.clipRect = new flixel.math.FlxRect(
                0, 0, spr.frameWidth * ]] .. health / 2 .. [[, spr.frameHeight
            );
        }
    ]])
end

local lastAnim = nil

function onUpdate(elapsed)
    local health = getHealth()
    -- a new animation (split1/split2) swaps the frame, so re-apply the clip then too
    local anim = getProperty('mono_healthBarMask.animation.curAnim.name')
    if health ~= lastHealth or anim ~= lastAnim then
        lastHealth = health
        lastAnim = anim
        updateMask(health)
    end
end

function onDestroy()
    setPropertyFromClass('backend.ClientPrefs', 'data.middleScroll', prevPref)
end