---@param obj string "name of the game object you want to get the current animation duration of"
local function getAnimDuration(obj)
    return getProperty(obj..'.animation.curAnim.numFrames') / getProperty(obj..'.animation.curAnim.frameRate')
end

---@param tag string "name of the timer"
---@param obj string "name of the game object you want to get the current animation duration of"
local function animEndTimer(tag, obj)
    runTimer(tag, getAnimDuration(obj))
end

local function fillScreen(object) -- to make the 1080p cutscene assets scale to 720p
    scaleObject(object, screenWidth / getProperty(object..'.width'), screenHeight / getProperty(object..'.height'))
end

-- this is cool, it tells your IDE what types these args are
---@param tag string
---@param path string
---@param fullscreen? boolean
---@param visible? boolean
---@param camera? string
local function makeCutsceneObj(tag, path, fullscreen, visible, camera)
    makeLuaSprite(tag, path, 0, 0)
    if camera == nil then
        setObjectCamera(tag, 'other')
    else
        setObjectCamera(tag, camera)
    end

    if fullscreen or fullscreen == nil then
        fillScreen(tag)
    end

    if not visible then
        setProperty(tag..'.alpha', 0.0001) -- so that it preloads
    end
    addLuaSprite(tag)
end

function onCreate()
    setProperty('camHUD.alpha', 0.0001)
    setProperty('camGame.alpha', 0.0001)
    -- intro cutscene
    for i = 0,4 do
        makeCutsceneObj('introbg' .. i, 'monochrome/cutscenes/intro/cut_mono_intro_bg_' .. i, false)
        scaleObject('introbg' .. i, 2/3, 2/3)
    end

    makeAnimatedLuaSprite('unownslift', 'monochrome/cutscenes/intro/unowns_rise', 0, -10)
    addAnimationByPrefix('unownslift', 'lift', 'lift', 6, false)
    setObjectCamera('unownslift', 'other')
    scaleObject('unownslift', 0.7, 0.7)
    setProperty('unownslift.alpha', 0.0001)
    addLuaSprite('unownslift')

    makeAnimatedLuaSprite('bflift', 'monochrome/cutscenes/intro/bf_lift', 80, 0)
    addAnimationByIndices('bflift', 'still', 'lift', '0', 12, false)
    addAnimationByPrefix('bflift', 'lift', 'lift', 4, false)
    setObjectCamera('bflift', 'other')
    scaleObject('bflift', 0.92, 0.92)
    setProperty('bflift.alpha', 0.0001)
    addLuaSprite('bflift')

    makeAnimatedLuaSprite('unownsflyby', 'monochrome/cutscenes/intro/unown_flyby', 0, 0)
    addAnimationByPrefix('unownsflyby', 'flyby', 'flyby', 24, false)
    setObjectCamera('unownsflyby', 'other')
    scaleObject('unownsflyby', 2/3, 2/3)
    setProperty('unownsflyby.alpha', 0.0001)
    addLuaSprite('unownsflyby')

    makeAnimatedLuaSprite('celebifly', 'monochrome/cutscenes/intro/celebi', 220, 220)
    addAnimationByIndices('celebifly', 'still', 'fly', '0', 12, false)
    addAnimationByPrefix('celebifly', 'lift', 'lift', 12, false)
    addAnimationByPrefix('celebifly', 'fly', 'fly', 24, false)
    setObjectCamera('celebifly', 'other')
    scaleObject('celebifly', 2/3, 2/3)
    setProperty('celebifly.alpha', 0.0001)
    addLuaSprite('celebifly')

    -- bf screamer
    makeCutsceneObj('bfbg', 'monochrome/cutscenes/bf screamer/background', true, false, 'hud')

    makeAnimatedLuaSprite('bfscream', 'monochrome/cutscenes/bf screamer/bf_scream', 0, 0)
    addAnimationByIndices('bfscream', 'still', 'scream', '0', 12, false)
    addAnimationByIndices('bfscream', 'scream', 'scream', '0,1,2,3,3,4,4,5,5,6,6,7,7,7,7', 12, false)
    setObjectCamera('bfscream', 'hud')
    fillScreen('bfscream')
    setProperty('bfscream.alpha', 0.0001)
    addLuaSprite('bfscream')
end

local scene = -1

function onEvent(name, value1, value2)
    if name == 'intro cutscene' then
        scene = scene + 1
        if scene == 0 then
            setProperty('introbg0.alpha', 1)
            triggerEvent('Alt Idle Animation', 'dad', '-backshot')
        end
        if scene == 1 then
            removeLuaSprite('introbg0')
            setProperty('introbg1.alpha', 1)
            setProperty('introbg2.alpha', 1)

            setProperty('introbg1.scale.x', 0.69)
            setProperty('introbg1.scale.y', 0.69)

            setProperty('introbg2.x', 150)
            setProperty('introbg2.y', 300)

            doTweenX('bgmoveright', 'introbg1', getProperty('introbg1.x') + 5, 2.5, 'linear')
            doTweenX('handmoveright', 'introbg2', getProperty('introbg2.x') + 10, 2.5, 'linear')
        end
        if scene == 2 then
            removeLuaSprite('introbg1')
            removeLuaSprite('introbg2')
            setProperty('introbg3.alpha', 1)
            setProperty('bflift.alpha', 1)
        end
        if scene == 3 then -- boyfriend & unowns lift off
            playAnim('bflift', 'lift', true)
            playAnim('unownslift', 'lift', true)
            setProperty('unownslift.alpha', 1)
        end
        if scene == 4 then
            removeLuaSprite('introbg3')
            removeLuaSprite('bflift')
            removeLuaSprite('unownslift')
            setProperty('introbg4.y', 190)
            setProperty('introbg4.alpha', 1)
            setProperty('unownsflyby.alpha', 1)
            playAnim('unownsflyby', 'flyby', true)
            runTimer('celebi lift', 1.8)
        end
    end

    if name == 'BF Screamer' then
        if value1 == '1' then
            setProperty('bfbg.alpha', 1)
            setProperty('bfscream.alpha', 1)
            playAnim('bfscream', 'scream', true)
            setProperty('gameHUDblurController.x', 0.035)
            doTweenX('screamerBlurUp', 'gameHUDblurController', 0.09, 1, 'cubeIn')
        elseif value1 == '0' then
            setProperty('bfbg.alpha', 0)
            setProperty('bfscream.alpha', 0)
            cancelTween('screamerBlurUp')
            setProperty('gameHUDblurController.x', 0)
        end
    end
end

function onTimerCompleted(tag)
    if tag == 'celebi lift' then
        setProperty('celebifly.alpha', 1)
        playAnim('celebifly', 'lift', true)
        runTimer('celebi fly', 1.5)
    end
    if tag == 'celebi fly' then
        playAnim('celebifly', 'fly', true)
        setProperty('celebifly.x', 0)
        setProperty('celebifly.y', 0)
        removeLuaSprite('introbg4')
        animEndTimer('celebi flown', 'celebifly')
        runTimer('gold intro sing', 1.4)
        runTimer('camGame on', 1.65)
    end
    if tag == 'camGame on' then
        setProperty('camGame.zoom', 0.2)
        setProperty('camGame.alpha', 1)
    end
    if tag == 'gold intro sing' then
        triggerEvent('Play Animation', 'sing', 'dad')
        triggerEvent('Alt Idle Animation', 'dad', '')
        setProperty('dad.alpha', 0.6)
        runTimer('gold fade in', 15)
    end
    if tag == 'gold fade in' then
        doTweenAlpha('goldIn', 'dad', 1, 0.5, 'linear')
    end
    if tag == 'celebi flown' then
        removeLuaSprite('celebifly')
        doTweenZoom('camIn1', 'camGame', 0.3, 8, 'smoothStepInOut')
    end
end

function onTweenCompleted(tag)
    if tag == 'camIn1' then
        doTweenZoom('camIn2', 'camGame', 0.66, 8, 'cubeInOut')
    end
end

function onUpdate()
    celebiLiftFrame = getProperty('celebifly.animation.curAnim.curFrame')
    if getProperty('celebifly.animation.curAnim.name') == 'lift' then
        if celebiLiftFrame >= 6 then
            setProperty('introbg4.y', 190 + ((celebiLiftFrame - 6) * 59))
        end
    end

    local bfScreamerFrame = getProperty('bfscream.animation.curAnim.curFrame')
    if flashingLights and bfScreamerFrame >= 4 and bfScreamerFrame < 14 then -- flash screen
        if bfScreamerFrame % 2 == 0 then
            setProperty('camGame.visible', false)
            setProperty('camHUD.visible', false)
        else
            setProperty('camGame.visible', true)
            setProperty('camHUD.visible', true)

            local progress = (bfScreamerFrame - 4) / (13 - 4)

            -- tint that shit orange overtime
            runHaxeCode([[
                game.getLuaObject("bfbg").color = FlxColor.fromRGB(
                    ]] .. math.floor(255 + (190 - 255) * progress) .. [[, 
                    ]] .. math.floor(255 + (81 - 255) * progress) .. [[, 
                    ]] .. math.floor(255 + (3 - 255) * progress) .. [[
                );
            ]])
        end
    end
end