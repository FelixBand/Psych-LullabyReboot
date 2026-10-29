function onCreate()
    prevPref = getPropertyFromClass('backend.ClientPrefs', 'data.middleScroll')
    if prevPref then
        setPropertyFromClass('backend.ClientPrefs', 'data.middleScroll', false)
    end

    makeAnimatedLuaSprite('mono_healthBar', 'monochrome/health', screenWidth - 600, 500)
    addAnimationByPrefix('mono_healthBar', 'full', 'bar_full', 1, false)
    addAnimationByPrefix('mono_healthBar', 'split1', 'bar_split_first', 8, false)
    addAnimationByPrefix('mono_healthBar', 'split1', 'bar_split_second', 8, false)

    makeAnimatedLuaSprite('mono_healthBarMask', 'monochrome/health', screenWidth - 600, 500)
    addAnimationByPrefix('mono_healthBarMask', 'full', 'mask_full', 1, false)
    addAnimationByPrefix('mono_healthBarMask', 'split1', 'mask_split_first', 8, false)
    addAnimationByPrefix('mono_healthBarMask', 'split1', 'mask_split_second', 8, false)
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

function onUpdate(elapsed)
    runHaxeCode([[
        var spr = game.getLuaObject('mono_healthBarMask');
        if (spr != null) {
            spr.clipRect = new flixel.math.FlxRect(
                0, 0, spr.frameWidth * ]] .. getHealth() / 2 .. [[, spr.frameHeight
            );
        }
    ]])
end

function onDestroy()
    setPropertyFromClass('backend.ClientPrefs', 'data.middleScroll', prevPref)
end