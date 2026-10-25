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

    -- mid song cutscene

    -- scary close up approach
        makeAnimatedLuaSprite('approach', 'monochrome/cutscenes/mid song/approach', 300, 0)
        addAnimationByIndices('approach', '0', 'approach', '0,2', 4) -- first frame, then blank
        addAnimationByIndices('approach', '1', 'approach', '1', 1)
        setObjectCamera('approach', 'other')
        scaleObject('approach', 1.35, 1.35)
        setProperty('approach.alpha', 0.0001)
        addLuaSprite('approach')
    --

    -- close up on Gold's face
        makeAnimatedLuaSprite('closeupface', 'monochrome/cutscenes/mid song/face', 0, 0)
        addAnimationByPrefix('closeupface', 'idle', 'face', 8, true)
        setObjectCamera('closeupface', 'other')
        scaleObject('closeupface', 2/3, 2/3)
        setProperty('closeupface.alpha', 0.0001)
        addLuaSprite('closeupface')

        makeAnimatedLuaSprite('closeuphair', 'monochrome/cutscenes/mid song/hair', 0, 0)
        addAnimationByPrefix('closeuphair', 'idle', 'hair', 8, true)
        setObjectCamera('closeuphair', 'other')
        setProperty('closeuphair.alpha', 0.0001)
        addLuaSprite('closeuphair')
    --

    -- Gold crawls - side view
        makeCutsceneObj('crawlbg', 'monochrome/cutscenes/mid song/crawl_bg')

        makeAnimatedLuaSprite('goldcrawl', 'monochrome/cutscenes/mid song/gold_crawl_side', 0, 0)
        addAnimationByPrefix('goldcrawl', 'crawl', 'crawl', 8, false)
        setObjectCamera('goldcrawl', 'other')
        scaleObject('goldcrawl', 0.9, 0.9)
        setProperty('goldcrawl.alpha', 0.0001)
        addLuaSprite('goldcrawl')
    --

    -- Gold crawls - birds eye view
        makeCutsceneObj('crawlbgabove', 'monochrome/cutscenes/mid song/crawl_bg_above')

        makeAnimatedLuaSprite('goldcrawlabove', 'monochrome/cutscenes/mid song/gold_crawl_above', 220, 385)
        addAnimationByPrefix('goldcrawlabove', 'crawl', 'crawl', 8, false)
        setObjectCamera('goldcrawlabove', 'other')
        scaleObject('goldcrawlabove', 0.69, 0.69)
        setProperty('goldcrawlabove.alpha', 0.0001)
        addLuaSprite('goldcrawlabove')

        makeAnimatedLuaSprite('vultures', 'monochrome/cutscenes/mid song/unown_vultures_circling', 0, -30)
        addAnimationByPrefix('vultures', 'circle', 'whatanindividual', 24, false)
        setObjectCamera('vultures', 'other')
        scaleObject('vultures', 0.69, 0.69)
        setProperty('vultures.alpha', 0.0001)
        addLuaSprite('vultures')
    --

    makeCutsceneObj('redflash', 'monochrome/cutscenes/mid song/red')

    -- Close-up on Gold (2 frames looping)
        makeAnimatedLuaSprite('goldcloseup', 'monochrome/cutscenes/mid song/closeup', 0, 0)
        addAnimationByPrefix('goldcloseup', 'idle', 'closeup', 4, true)
        setObjectCamera('goldcloseup', 'other')
        fillScreen('goldcloseup')
        setProperty('goldcloseup.alpha', 0.0001)
        addLuaSprite('goldcloseup')
    --

    -- Gold looks up. nani kore?!
        makeCutsceneObj('lookupbg', 'monochrome/cutscenes/mid song/looking_up_bg')

        makeAnimatedLuaSprite('goldlookup', 'monochrome/cutscenes/mid song/gold_looks_up', 0, 0)
        addAnimationByIndices('goldlookup', 'still', 'lookup', '0', 1, false)
        addAnimationByPrefix('goldlookup', 'lookup', 'lookup', 8, false)
        setObjectCamera('goldlookup', 'other')
        scaleObject('goldlookup', 2/3, 2/3)
        setProperty('goldlookup.alpha', 0.0001)
        addLuaSprite('goldlookup')
    --

    makeCutsceneObj('typhoflash', 'monochrome/cutscenes/mid song/typho')

    -- Gold from behind, looking up at the Collector's hand
        makeCutsceneObj('handbg', 'monochrome/cutscenes/mid song/hand_bg')

        makeAnimatedLuaSprite('handfront', 'monochrome/cutscenes/mid song/hand_front', 514, 50)
        addAnimationByPrefix('handfront', 'idle', 'hand', 2.5, false)
        setObjectCamera('handfront', 'other')
        scaleObject('handfront', 0.69, 0.69)
        setProperty('handfront.alpha', 0.0001)
        addLuaSprite('handfront')

        makeAnimatedLuaSprite('goldbehind', 'monochrome/cutscenes/mid song/gold_looking_at_hand', 274, 320)
        addAnimationByPrefix('goldbehind', 'idle', 'gold', 8, true)
        setObjectCamera('goldbehind', 'other')
        scaleObject('goldbehind', 0.89, 0.89)
        setProperty('goldbehind.alpha', 0.0001)
        addLuaSprite('goldbehind')
    --

    -- Gold looking up at the Collector's hand - side view
        makeCutsceneObj('lookupbgside', 'monochrome/cutscenes/mid song/cut_mono_lookingup_bg')
        makeCutsceneObj('prebloodfog', 'monochrome/cutscenes/mid song/cut_mono_pre_blood_fog')
        makeCutsceneObj('prebloodlight', 'monochrome/cutscenes/mid song/cut_mono_pre_blood_light')

        makeAnimatedLuaSprite('goldside', 'monochrome/cutscenes/mid song/gold_side_view', 257, 223)
        addAnimationByPrefix('goldside', 'idle', 'gold', 8, true)
        setObjectCamera('goldside', 'other')
        scaleObject('goldside', 0.69, 0.69)
        setProperty('goldside.alpha', 0.0001)
        addLuaSprite('goldside')

        makeAnimatedLuaSprite('handside', 'monochrome/cutscenes/mid song/hand_side', 850, 223)
        addAnimationByPrefix('handside', 'idle', 'hand', 1.1, false)
        setObjectCamera('handside', 'other')
        scaleObject('handside', 0.69, 0.69)
        setProperty('handside.alpha', 0.0001)
        addLuaSprite('handside')

        makeAnimatedLuaSprite('unownsleave', 'monochrome/cutscenes/mid song/unowns_flying_offscreen', 0, 70)
        addAnimationByPrefix('unownsleave', 'fly', 'fly', 12, false)
        setObjectCamera('unownsleave', 'other')
        scaleObject('unownsleave', 1.25, 1.25)
        setProperty('unownsleave.alpha', 0.0001)
        addLuaSprite('unownsleave')
    --

    -- Gold reaches for the Collector's hand; gets prankd
        makeCutsceneObj('lightbg', 'monochrome/cutscenes/mid song/Light_bg')

        makeAnimatedLuaSprite('collectorhand', 'monochrome/cutscenes/mid song/collector_hand', 500, 200)
        addAnimationByPrefix('collectorhand', 'idle', 'hand', 8, false)
        setObjectCamera('collectorhand', 'other')
        scaleObject('collectorhand', 0.69, 0.69)
        setProperty('collectorhand.alpha', 0.0001)
        addLuaSprite('collectorhand')

        makeAnimatedLuaSprite('reachforhand', 'monochrome/cutscenes/mid song/gold_reaches_out', 0, 0)
        addAnimationByPrefix('reachforhand', 'reach', 'reachout', 8, false)
        setObjectCamera('reachforhand', 'other')
        scaleObject('reachforhand', 0.69, 0.69)
        setProperty('reachforhand.alpha', 0.0001)
        addLuaSprite('reachforhand')
    --
end

local scene = -1

function onEvent(name, value1, value2)
    if name == 'intro cutscene' then
        scene = scene + 1
        if scene == 0 then
            setProperty('introbg0.alpha', 1)
            --triggerEvent('Alt Idle Animation', 'dad', '-backshot')
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

    if name == 'mid song cutscene' then
        scene = scene + 1
        if value1 == '0' then
            scene = 0
        end
        if scene == 0 then
            setProperty('camHUD.alpha', 0)
            setProperty('camGame.alpha', 0)
            setProperty('approach.alpha', 1)
            playAnim('approach', '0', true)
        end
        if scene == 1 then
            scaleObject('approach', 0.89, 0.89)
            setProperty('approach.x', 0)
            playAnim('approach', '1', true)
        end
        if scene == 2 then
            removeLuaSprite('approach')
            setProperty('closeupface.alpha', 1)
            setProperty('closeuphair.alpha', 1)
        end
        if scene == 3 then
            removeLuaSprite('closeupface')
            removeLuaSprite('closeuphair')
            setProperty('crawlbg.alpha', 1)
            setProperty('goldcrawl.alpha', 1)
            playAnim('goldcrawl', 'crawl', true)
        end
        if scene == 4 then
            removeLuaSprite('crawlbg')
            removeLuaSprite('goldcrawl')
            setProperty('crawlbgabove.alpha', 1)
            setProperty('goldcrawlabove.alpha', 1)
            setProperty('vultures.alpha', 1)
            playAnim('goldcrawlabove', 'crawl', true)
            playAnim('vultures', 'circle', true)
        end
        if scene == 5 then
            removeLuaSprite('crawlbgabove')
            removeLuaSprite('goldcrawlabove')
            removeLuaSprite('vultures')
            setProperty('redflash.alpha', 1)
        end
        if scene == 6 then
            removeLuaSprite('redflash')
            setProperty('goldcloseup.alpha', 1)
        end
        if scene == 7 then
            removeLuaSprite('goldcloseup')
            setProperty('lookupbg.alpha', 1)
            setProperty('goldlookup.alpha', 1)
            playAnim('goldlookup', 'lookup', true)
        end
        if scene == 8 then
            removeLuaSprite('lookupbg')
            removeLuaSprite('goldlookup')
            setProperty('typhoflash.alpha', 1)
        end
        if scene == 9 then
            setProperty('camOther.zoom', 1.05)
            doTweenZoom('camotherzoomout', 'camOther', 1, 5, 'linear')

            removeLuaSprite('typhoflash')
            setProperty('handbg.alpha', 1)
            setProperty('handfront.alpha', 1)
            setProperty('goldbehind.alpha', 1)
            playAnim('handfront', 'idle', true)
        end
        if scene == 10 then
            removeLuaSprite('handbg')
            removeLuaSprite('handfront')
            removeLuaSprite('goldbehind')
            cancelTween('camotherzoomout')
            setProperty('camOther.zoom', 1.05)
            doTweenZoom('camotherzoomout', 'camOther', 1, 5, 'linear')

            setProperty('lookupbgside.alpha', 1)
            setProperty('goldside.alpha', 1)
            setProperty('handside.alpha', 1)
            setProperty('unownsleave.alpha', 1)
            setProperty('prebloodlight.alpha', 1)
            setProperty('prebloodfog.alpha', 1)
            playAnim('handside', 'idle', true)
            playAnim('unownsleave', 'fly', true)
        end
        if scene == 11 then
            cancelTween('camotherzoomout')
            setProperty('camOther.zoom', 1)

            removeLuaSprite('lookupbgside')
            removeLuaSprite('goldside')
            removeLuaSprite('handside')
            removeLuaSprite('unownsleave')
            removeLuaSprite('prebloodlight')
            removeLuaSprite('prebloodfog')

            setProperty('lightbg.alpha', 1)
            setProperty('collectorhand.alpha', 1)
            setProperty('reachforhand.alpha', 1)
            playAnim('collectorhand', 'idle', true)
            playAnim('reachforhand', 'reach', true)
        end
        if scene == 12 then
            removeLuaSprite('lightbg')
            removeLuaSprite('collectorhand')
            removeLuaSprite('reachforhand')
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
        --triggerEvent('Alt Idle Animation', 'dad', '')
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
    goldLookUpFrame = getProperty('goldlookup.animation.curAnim.curFrame')
    if getProperty('goldlookup.animation.curAnim.name') == 'lookup' then
        if goldLookUpFrame >= 10 then
            setProperty('lookupbg.y', ((goldLookUpFrame - 10) * 15))
        end
    end

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