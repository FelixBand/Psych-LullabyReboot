function onCreate()
    makeAnimatedLuaSprite('mono_healthBar', 'monochrome/health', screenWidth - 600, 500)
    addAnimationByPrefix('mono_healthBar', 'full', 'bar_full', 1, false)
    addAnimationByPrefix('mono_healthBar', 'split1', 'bar_split_first', 8, false)
    addAnimationByPrefix('mono_healthBar', 'split1', 'bar_split_second', 8, false)

    setObjectCamera('mono_healthBar', 'hud')

    if not downscroll then
        setProperty('mono_healthBar.flipY', true)
        setProperty('mono_healthBar.y', 0)
    end
    addLuaSprite('mono_healthBar')
    playAnim('mono_healthBar', 'full', true)
end