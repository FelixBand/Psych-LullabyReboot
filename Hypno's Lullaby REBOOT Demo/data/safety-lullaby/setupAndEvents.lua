luaDebugMode = true

local canRetry = false
local pressedRetry = false

local SOURCE_TIME_OFFSET = 1.0
local PS = 2 / 3

local function getPlaysAsBF() -- returns true if not playing Psych Online for PE compat :)))
    if type(_G.playsAsBF) == "function" then
        local result = _G.playsAsBF()
        if result ~= nil then
            return result
        end
    end
    
    return true
end

---@param obj string "name of the game object you want to get the current animation duration of"
local function getAnimDuration(obj)
    return getProperty(obj..'.animation.curAnim.numFrames') / getProperty(obj..'.animation.curAnim.frameRate')
end

function rgbToHex(rgb)
    return string.format('%02x%02x%02x', rgb[1], rgb[2], rgb[3])
end

function onCreate()
    setProperty('skipCountdown', true)
    makeLuaSprite('realCamFollow', '', 0, 0) -- for moving the cam during gameover substate

    makeLuaSprite('endBg', 'safety_lullaby/cutscenes/end/end_bg', 0, 0)
    setObjectCamera('endBg', 'hud')
    scaleObject('endBg', 0.39, 0.39)
    setProperty('endBg.alpha', 0.0001)
    setProperty('endBg.color', '000000')
    addLuaSprite('endBg')

    -- game over
        -- gf gets hypnotised, close up
        makeLuaSprite('go_gfbg', 'safety_lullaby/cutscenes/intro/gf_focus_bg', 0, 0)
        setProperty('go_gfbg.alpha', 0.0001)
        setObjectCamera('go_gfbg', 'other')
        scaleObject('go_gfbg', 1, 1)
        addLuaSprite('go_gfbg')

        makeAnimatedLuaSprite('go_gfcut', 'safety_lullaby/gameover/sl_gameover_gf', 287, 107)
        addAnimationByPrefix('go_gfcut', 'ohno', 'gf', 24, false)
        setObjectCamera('go_gfcut', 'other')
        scaleObject('go_gfcut', 0.89, 0.89)
        setProperty('go_gfcut.alpha', 0.0001)
        addLuaSprite('go_gfcut')

        -- actual looping game over screen
        makeAnimatedLuaSprite('go_bg', 'safety_lullaby/gameover/BG', -104, -214)
        addAnimationByPrefix('go_bg', 'idle', 'BG', 24, true)
        setObjectCamera('go_bg', 'other') 
        scaleObject('go_bg', 1.36, 1.36)
        setProperty('go_bg.alpha', 0.0001)
        addLuaSprite('go_bg')

        makeAnimatedLuaSprite('go_gfloop', 'safety_lullaby/gameover/gf_gameover_loop', 695, 150)
        addAnimationByPrefix('go_gfloop', 'quiver', 'quiver', 24, true)
        addAnimationByPrefix('go_gfloop', 'wake', 'wake', 24, false)
        setObjectCamera('go_gfloop', 'other')
        scaleObject('go_gfloop', 1.36, 1.36)
        setProperty('go_gfloop.alpha', 0.0001)
        addLuaSprite('go_gfloop')

        makeAnimatedLuaSprite('go_fg', 'safety_lullaby/gameover/FG', -312, -205)
        addAnimationByPrefix('go_fg', 'idle', 'FG', 24, true)
        setObjectCamera('go_fg', 'other') 
        scaleObject('go_fg', 1.36, 1.36)
        setProperty('go_fg.alpha', 0.0001)
        addLuaSprite('go_fg')

        makeAnimatedLuaSprite('go_hypnohand', 'safety_lullaby/gameover/hypno_hand', 75, 100)
        addAnimationByPrefix('go_hypnohand', 'idle', 'twirl', 24, true)
        addAnimationByPrefix('go_hypnohand', 'close', 'close', 24, true)
        setObjectCamera('go_hypnohand', 'other') 
        scaleObject('go_hypnohand', 1.36, 1.36)
        setProperty('go_hypnohand.alpha', 0.0001)
        addLuaSprite('go_hypnohand')

        makeLuaSprite('go_moonglow', 'safety_lullaby/gameover/MoonGlow', -104, -214)
        setObjectCamera('go_moonglow', 'other') 
        scaleObject('go_moonglow', 1.36, 1.36)
        setProperty('go_moonglow.alpha', 0.0001)
        setBlendMode('go_moonglow', 'add')
        addLuaSprite('go_moonglow')

        makeLuaSprite('go_overlay', 'safety_lullaby/gameover/Overlay', -10, -10)
        setObjectCamera('go_overlay', 'other') 
        scaleObject('go_overlay', 1.36, 1.36)
        setProperty('go_overlay.alpha', 0.0001)
        addLuaSprite('go_overlay')
end

function onCreatePost()
    setObjectCamera('gfGroup', 'hud')
    setProperty('gf.x', 310)
    setProperty('gf.y', 10)
    setProperty('gf.alpha', 0.0001)
    setVar('safetyLullabyEndingActive', false)

    if getPlaysAsBF() then -- hide opponent strums if not playing as opponent
        for i = 0,getProperty('opponentStrums.length') - 1 do
            setPropertyFromGroup('opponentStrums', i, 'x', -5000)
        end
    end
    runHaxeCode([[if (game.noteUnderlays != null) game.noteUnderlays.visible = false;]]) -- hide note underlane for aestheticsss
    setProperty('timeBar.visible', false)
    setProperty('timeTxt.visible', false)
    setProperty('scoreTxt.scale.x', getProperty('scoreTxt.scale.x') / 1.1)
    setProperty('scoreTxt.scale.y', getProperty('scoreTxt.scale.y') / 1.1)

    setProperty('camZoomingDecay', 0.25) -- slower cam zooming
    setProperty('camZoomingMult', 0)
    setProperty('camZooming', true)
    
    runHaxeCode( -- hide multiple players, only show dad
    [[
        for (m in game.dadGroup.members)
            if (m != game.dad) m.visible = false;
    ]])

    -- epic health bar
    runHaxeCode([[
        game.healthBar.bg.loadGraphic(Paths.image('safety_lullaby/bar/bar'));
    ]])
    setProperty('healthBar.bg.offset.x', 75)
    setProperty('healthBar.bg.offset.y', 35)
    setProperty('healthBar.leftBar.visible', false)
    setProperty('healthBar.rightBar.visible', false)
    makeLuaSprite('healthBarMaskRight', 'safety_lullaby/bar/barmask', getProperty('healthBar.x') - 54, getProperty('healthBar.y') - 11)
    makeLuaSprite('healthBarMaskLeft', 'safety_lullaby/bar/barmask', getProperty('healthBar.x') - 54, getProperty('healthBar.y') - 11)
    setObjectCamera('healthBarMaskRight', 'hud')
    addLuaSprite('healthBarMaskRight')
    setObjectCamera('healthBarMaskLeft', 'hud')
    addLuaSprite('healthBarMaskLeft')

    runHaxeCode([[
        var leftMask = game.getLuaObject('healthBarMaskLeft');
        var rightMask = game.getLuaObject('healthBarMaskRight');

        if (game.uiGroup != null) {
            if (leftMask != null) {
                leftMask.cameras = [game.camHUD];
                game.uiGroup.insert(0, leftMask);
            }
            if (rightMask != null) {
                rightMask.cameras = [game.camHUD];
                game.uiGroup.insert(0, rightMask);
            }
        }
        
        var hb = game.healthBar;
        if (hb != null) {
            var newWidth = 720; // Desired bar/icon travel width
            var delta = hb.barWidth - newWidth;
            hb.barWidth = newWidth;
            // Shift barOffset.x by half the difference to keep it centered
            hb.barOffset.x += delta * 0.5;
        }
    ]])
    
    addHealth(0.000000001) -- update health to apply bar width for icons

    if dadName == 'hypno' then
        runHaxeCode('game.iconP2.changeIcon("hypnoDark");')
    end

    setProperty('healthBarMaskLeft.color', getColorFromHex(rgbToHex(getProperty('dad.healthColorArray'))))
    setProperty('healthBarMaskRight.color', getColorFromHex(rgbToHex(getProperty('boyfriend.healthColorArray'))))
end

function onUpdate()
    scaleObject('healthBarMaskLeft', 1 - (getHealth() / 2), 1)
end

function onBeatHit()
    if curBeat >= 72 then        
        if curBeat % 2 == 0 then
            triggerEvent('Add Camera Zoom', '0.015', '0')
        end
    end
end

function onEvent(name, value1, value2)
    if name == 'Hypno Icon' then
        if dadName == 'hypno' then
            runHaxeCode([[game.iconP2.changeIcon("]] .. value1 .. [[");]])
            addHealth(0.0000000001) -- icon doesn't update neutral/lose state unless health changes......
        end
    end
    if name == 'Hypno Step Forward' then
        --debugPrint('walk damnit')
        triggerEvent('Play Animation', 'step', 'dad')
        runTimer('hypnoSnapForward', getAnimDuration('dad') - 0.001)
    end
    if name == 'Transition to Ending' then
        setObjectOrder('endBg', getObjectOrder('pndHand') + 1)
        setObjectOrder('gfGroup', getObjectOrder('endBg') + 1)
        setBlendMode('gf', 'add')
        doTweenAlpha('endBgIn', 'endBg', 1, 1.5, 'linear')
        doTweenZoom('camGameIn', 'camGame', 0.9, 1.4, 'smoothStepIn')

        for i = 0,getProperty('opponentStrums.length') - 1 do
            noteTweenAlpha('playerStrumOut'..i, i + 4, 0, 1, 'linear')
        end

        doTweenAlpha('scoreTxtOut', 'scoreTxt', 0, 1, 'linear')
        doTweenAlpha('healthBarOut', 'healthBar', 0, 1, 'linear')
        doTweenAlpha('healthMaskLOut', 'healthBarMaskLeft', 0, 1, 'linear')
        doTweenAlpha('healthMaskROut', 'healthBarMaskRight', 0, 1, 'linear')
        doTweenAlpha('iconP1Out', 'iconP1', 0, 1, 'linear')
        doTweenAlpha('iconP2Out', 'iconP2', 0, 1, 'linear')
    end
    if name == 'Fade In Ending' then
        setProperty('camGame.visible', false)
        setVar('safetyLullabyEndingLightingOff', true)
        setVar('safetyLullabyEndingActive', true)
        setObjectCamera('pndHandTrail', 'hud')
        setObjectCamera('pndHandActive', 'hud')
        setObjectOrder('pndHandTrail', getObjectOrder('gfGroup') + 1)
        setObjectOrder('pndHandActive', getObjectOrder('gfGroup') + 2)
        doTweenColor('endBgColor', 'endBg', getColorFromHex('FFFFFF'), 1.5, 'linear')
        doTweenAlpha('hypnoIn', 'gf', 1, 1.5, 'linear')
    end
    if name == 'Ending Move Start' then
        doTweenX('endBgZoomX', 'endBg.scale', getProperty('endBg.scale.x') * 1.5, 17, 'linear')
        doTweenY('endBgZoomY', 'endBg.scale', getProperty('endBg.scale.y') * 1.5, 17, 'linear')
        doTweenX('hypnoShrinkX', 'gf.scale', 0.65, 12, 'quadIn')
        doTweenY('hypnoShrinkY', 'gf.scale', 0.65, 12, 'quadIn')
        doTweenX('hypnoDriftX', 'gf', getProperty('gf.x') - 5 * PS, 12, 'quadIn')
        doTweenY('hypnoDriftY', 'gf', getProperty('gf.y') - 93 * PS, 12, 'quadIn')
    end
    if name == 'Hypno Fade Away' then
        doTweenAlpha('hypnoDarkFade', 'gf', 0, 5, 'quadOut')
    end
    if name == 'Ending BG Darken' then
        doTweenColor('endBgToDark', 'endBg', '000000', 5, 'quadIn')
    end
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'hypnoSnapForward' then
        triggerEvent('Play Animation', 'idle-alt', 'dad')
        setProperty('dad.x', getProperty('dad.x') + 66)
        setProperty('dad.cameraPosition[0]', getProperty('dad.cameraPosition[0]') - 66)
    end
    if name == 'gameOverScene' then
        setProperty('go_gfbg.visible', true)
        setProperty('go_gfbg.alpha', 1)
        setProperty('go_gfcut.visible', true)
        setProperty('go_gfcut.alpha', 1)
        playAnim('go_gfcut', 'ohno', true)
    end
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    triggerEvent('Play Animation', getProperty('singAnimations')[direction + 1], 'gf')
end

function onGameOver()
	openCustomSubstate('gameover', true)

	return Function_Stop
end

function onCustomSubstateCreate(name)
	if name == 'gameover' then
        callOnLuas('hideCamOther')
        runHaxeCode([[
            game.variables.set('boyfriend', game.boyfriendGroup);
            game.boyfriendGroup.cameras = [game.camGame];
            game.boyfriend.specialAnim = true;
            game.boyfriend.playAnim('game over', true);
        ]])

        insertToCustomSubstate('boyfriend')

        insertToCustomSubstate('go_gfbg')
        insertToCustomSubstate('go_gfcut')
        insertToCustomSubstate('go_bg')
        insertToCustomSubstate('go_gfloop')
        insertToCustomSubstate('go_fg')
        insertToCustomSubstate('go_hypnohand')
        insertToCustomSubstate('go_moonglow')
        insertToCustomSubstate('go_overlay')


        playSound('gameover_sl')

        runTimer('gameOverScene', 3.5)

        setProperty('realCamFollow.x', getProperty('camFollowPos.x'))
        setProperty('realCamFollow.y', getProperty('camFollowPos.y'))

        doTweenX('camX', 'realCamFollow', 530, 4, 'quintOut') 
        doTweenY('camY', 'realCamFollow', 90, 4, 'quintOut') 
        doTweenZoom('camZoom', 'camGame', 0.75, 4, 'cubeOut')
        doTweenAlpha('gameOverHudOut', 'camHUD', 0, 0.5, 'linear')
        setProperty('camGame.alpha', 1)
    end
end

function onCustomSubstateUpdatePost(name, elapsed)
	if name == 'gameover' then
        setProperty('camFollowPos.x', getProperty('realCamFollow.x'))
        setProperty('camFollowPos.y', getProperty('realCamFollow.y'))
		if not pressedRetry and canRetry and keyJustPressed('accept') then
			pressedRetry = true

			restartSong()
		end
		if keyJustPressed('back') then
			exitSong()
		end
	end
end