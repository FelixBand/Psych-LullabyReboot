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
    -- intro cutscene
    for i = 0,4 do
        makeCutsceneObj('introbg' .. i, 'monochrome/cutscenes/intro/cut_mono_intro_bg_' .. i)
    end

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

function onEvent(name, value1, value2)
    if name == 'BF Screamer' then
        if value1 == '1' then
            setProperty('bfbg.alpha', 1)
            setProperty('bfscream.alpha', 1)
            playAnim('bfscream', 'scream', true)
            setProperty('gameHUDblurController.x', 0.05)
            doTweenX('screamerBlurUp', 'gameHUDblurController', 0.10, 1, 'cubeIn')
        elseif value1 == '0' then
            setProperty('bfbg.alpha', 0)
            setProperty('bfscream.alpha', 0)
            cancelTween('screamerBlurUp')
            setProperty('gameHUDblurController.x', 0)
        end
    end
end

function onUpdate()
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