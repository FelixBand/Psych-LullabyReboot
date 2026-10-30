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

function onCreatePost()
    if not shadersEnabled then return end

    makeLuaSprite('swapController', '', 0, 0)
    initLuaShader('swapBehind')
    runHaxeCode([[
        var sw = game.createRuntimeShader('swapBehind');
        game.getLuaObject('swapController').shader = sw;

        var filters = [new ShaderFilter(sw)];
        var blurController = game.getLuaObject('gameHUDblurController');
        if (blurController != null && blurController.shader != null)
            filters.push(new ShaderFilter(blurController.shader));
        game.camHUD.setFilters(filters);
    ]])
    setShaderFloat('swapController', 'gain', 77 / 255)
    setShaderFloat('swapController', 'thr', 0.03)
    setShaderFloat('swapController', 'uOn', 0)

    makeLuaSprite('markController', '', 0, 0)
    initLuaShader('solidMark')
    runHaxeCode([[
        var ms = game.createRuntimeShader('solidMark');
        game.getLuaObject('markController').shader = ms;
        var saved = [];
        function markOne(o) { if (o == null) return; saved.push({o: o, s: o.shader}); o.shader = ms; }
        function markAll() {
            for (s in game.strumLineNotes.members) markOne(s);
            for (n in game.notes.members) markOne(n);
        }
        function markNewest() { markOne(game.notes.members[0]); }
        function unmarkAll() { for (e in saved) e.o.shader = e.s; saved = []; }
    ]])
    setShaderFloatArray('markController', 'uMark', {0, 0, 77 / 255})
    setShaderFloat('swapController', 'thr', 0.01)   -- replaces the old 0.03, since coverage is exact now

    local function c(r, g, b) return {r / 255, g / 255, b / 255} end

    -- backdrop colours, sorted by red
    setShaderFloatArray('swapController', 's0', c(6, 6, 6))
    setShaderFloatArray('swapController', 's1', c(81, 20, 20))
    setShaderFloatArray('swapController', 's2', c(108, 27, 27))
    setShaderFloatArray('swapController', 's3', c(166, 163, 163))
    -- mode A (before the tween)
    setShaderFloatArray('swapController', 'a0', c(108, 27, 27))
    setShaderFloatArray('swapController', 'a1', c(33, 13, 13))
    setShaderFloatArray('swapController', 'a2', c(6, 6, 6))
    setShaderFloatArray('swapController', 'a3', c(6, 6, 6))
    -- mode B (after the tween)
    setShaderFloatArray('swapController', 'b0', c(108, 27, 27))
    setShaderFloatArray('swapController', 'b1', c(193, 170, 170))
    setShaderFloatArray('swapController', 'b2', c(166, 163, 163))
    setShaderFloatArray('swapController', 'b3', c(108, 27, 27))
    setShaderFloat('swapController', 'uMix', 0)
end

function onCreate()
    setProperty('camHUD.alpha', 0.0001)
    setProperty('camGame.alpha', 0.0001)

    -- intro cutscene
    for i = 0,4 do
        makeCutsceneObj('introbg' .. i, 'monochrome/cutscenes/intro/cut_mono_intro_bg_' .. i, false)
        if i == 1 or i == 2 or i == 4 then
            scaleObject('introbg' .. i, 2/3, 2/3)
        else
            fillScreen('introbg'..i)
        end
    end

    -- intro cutscene
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
        playAnim('bflift', 'still', true)

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
        playAnim('celebifly', 'still', true)
    --

    -- bf screamer
        makeCutsceneObj('bfbg', 'monochrome/cutscenes/bf screamer/background', true, false, 'hud')

        makeAnimatedLuaSprite('bfscream', 'monochrome/cutscenes/bf screamer/bf_scream', 0, 0)
        addAnimationByIndices('bfscream', 'still', 'scream', '0', 12, false)
        addAnimationByIndices('bfscream', 'scream', 'scream', '0,1,2,3,3,4,4,5,5,6,6,7,7,7,7', 12, false)
        setObjectCamera('bfscream', 'hud')
        fillScreen('bfscream')
        setProperty('bfscream.alpha', 0.0001)
        addLuaSprite('bfscream')
        playAnim('bfscream', 'still', true)
    --

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

            makeAnimatedLuaSprite('unownreflection', 'monochrome/cutscenes/mid song/unown_reflection', 860, 240)
            addAnimationByIndices('unownreflection', 'reflect', 'reflect', '9,9,9,9,9,9,9,9,9,0,1,2,3,9,9,9,9,9,4,5,6,7,8,9', 8, false)
            setObjectCamera('unownreflection', 'other')
            setProperty('unownreflection.alpha', 0.0001)
            addLuaSprite('unownreflection')

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
            playAnim('goldlookup', 'still', true)
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
            addAnimationByPrefix('collectorhand', 'idle', 'hand', 7.5, false)
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
    --

    -- blood cutscene
        makeLuaSprite('bloodbg', '', 0, 0)
        makeGraphic('bloodbg', screenWidth, screenHeight, '060606')
        setObjectCamera('bloodbg', 'hud')
        setProperty('bloodbg.alpha', 0)
        addLuaSprite('bloodbg')

        makeAnimatedLuaSprite('handstransition', 'monochrome/cutscenes/blood/transition', 0, 0)
        addAnimationByPrefix('handstransition', 'in', 'in', 12, false)
        addAnimationByIndices('handstransition', 'out', 'out', '0,0,0,0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14', 12, false)
        setObjectCamera('handstransition', 'hud')
        setProperty('handstransition.alpha', 0.0001)
        addLuaSprite('handstransition')

        makeAnimatedLuaSprite('armfall', 'monochrome/cutscenes/blood/arm_fall', 0, 0)
        addAnimationByPrefix('armfall', 'fall', 'arm', 12, false)
        setObjectCamera('armfall', 'hud')
        setProperty('armfall.alpha', 0.0001)
        addLuaSprite('armfall')

        makeAnimatedLuaSprite('bloodcut1', 'monochrome/cutscenes/blood/blood_pour', 0, 0)
        addAnimationByPrefix('bloodcut1', 'pour', 'pour', 12, false)
        setObjectCamera('bloodcut1', 'hud')
        setProperty('bloodcut1.alpha', 0.0001)
        addLuaSprite('bloodcut1')

        makeAnimatedLuaSprite('bloodcut2', 'monochrome/cutscenes/blood/blood', 0, 0)
        addAnimationByIndices('bloodcut2', 'pour', 'atlasblood', '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,48,48,48,48,49,49,50,50,51,51,52,52,53,53,54,54,55,55,56,56,57,57,57,57,57,57,57,57,57,57,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,133,134,134,135,135,136,136,137,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158', 12, false)
        setObjectCamera('bloodcut2', 'hud')
        setProperty('bloodcut2.alpha', 0.0001)
        addLuaSprite('bloodcut2')

        makeAnimatedLuaSprite('bloodheadoff', 'monochrome/cutscenes/blood/golds_head_rips_off', 0, 0)
        addAnimationByIndices('bloodheadoff', 'rip', 'rip', '0,1,2,3,4,5,6,7,8,9,9,10,10,10,10,11,11,12,12,13,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28', 12, false)
        setObjectCamera('bloodheadoff', 'hud')
        setProperty('bloodheadoff.alpha', 0.0001)
        addLuaSprite('bloodheadoff')
    --
end

local scene = -1

local curColor = 0

function setFGeyesVisibility(state)
    for i = 0,4 do
        setProperty('fgunown' .. i .. '.visible', state)
        setProperty('fgunownbloom' .. i .. '.visible', state)
    end
end

function onEvent(name, value1, value2)
    if name == 'Swap Tween' then 
        if curColor == 0 then
            swapToWhite(tonumber(value1) or 0.6) 
            curColor = 1
        elseif curColor == 1 then
            swapToBlack(tonumber(value1) or 0.6) 
            curColor = 0
        end
    end
    if name == 'Fade In' then
        swapOff()
        setFGeyesVisibility(true)
    end
    if name == 'FG Eyes invisible' then
        setFGeyesVisibility(false)
    end

    if name == 'intro cutscene' then
        scene = scene + 1
        if scene == 0 then
            setProperty('introbg0.alpha', 1)
            --triggerEvent('Alt Idle Animation', 'dad', '-backshot')
        end
        if scene == 1 then
            removeLuaSprite('introbg0', true)
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
            removeLuaSprite('introbg1', true)
            removeLuaSprite('introbg2', true)
            setProperty('introbg3.alpha', 1)
            setProperty('bflift.alpha', 1)
        end
        if scene == 3 then -- boyfriend & unowns lift off
            playAnim('bflift', 'lift', true)
            playAnim('unownslift', 'lift', true)
            setProperty('unownslift.alpha', 1)
        end
        if scene == 4 then
            removeLuaSprite('introbg3', true)
            removeLuaSprite('bflift', true)
            removeLuaSprite('unownslift', true)
            setProperty('introbg4.y', 190)
            setProperty('introbg4.alpha', 1)
            setProperty('unownsflyby.alpha', 1)
            playAnim('unownsflyby', 'flyby', true)
            runTimer('celebi lift', 1.8)
        end
    end

    if name == 'BF Screamer' then
        if value1 == '1' then
            setFGeyesVisibility(false)
            setProperty('bfbg.alpha', 1)
            setProperty('bfscream.alpha', 1)
            playAnim('bfscream', 'scream', true)
            setProperty('gameHUDblurController.x', 0.035)
            doTweenX('screamerBlurUp', 'gameHUDblurController', 0.09, 1, 'cubeIn')
        elseif value1 == '0' then
            setProperty('bfscream.alpha', 0)
            setProperty('bfbg.alpha', 0)
            cancelTween('screamerBlurUp')
            setProperty('gameHUDblurController.x', 0)
            setFGeyesVisibility(true)
        end
    end

    if name == 'mid song cutscene' then
        scene = scene + 1
        if value1 == '0' then
            scene = 0
        end
        if scene == 0 then
            setFGeyesVisibility(false)

            setProperty('camHUD.alpha', 0)
            setProperty('mono_healthBar.visible', false)
            setProperty('mono_healthBarMask.visible', false)
            for i = 0,getProperty('playerStrums.length') - 1 do
                setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            end
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
            removeLuaSprite('approach', true)
            setProperty('closeupface.alpha', 1)
            setProperty('unownreflection.alpha', 1)
            setProperty('closeuphair.alpha', 1)
            playAnim('unownreflection', 'reflect', true)
        end
        if scene == 3 then
            removeLuaSprite('closeupface', true)
            removeLuaSprite('closeuphair', true)
            removeLuaSprite('unownreflection', true)
            setProperty('crawlbg.alpha', 1)
            setProperty('goldcrawl.alpha', 1)
            playAnim('goldcrawl', 'crawl', true)
        end
        if scene == 4 then
            removeLuaSprite('crawlbg', true)
            removeLuaSprite('goldcrawl', true)
            setProperty('crawlbgabove.alpha', 1)
            setProperty('goldcrawlabove.alpha', 1)
            setProperty('vultures.alpha', 1)
            playAnim('goldcrawlabove', 'crawl', true)
            playAnim('vultures', 'circle', true)
        end
        if scene == 5 then
            removeLuaSprite('crawlbgabove', true)
            removeLuaSprite('goldcrawlabove', true)
            removeLuaSprite('vultures')
            setProperty('redflash.alpha', 1)
        end
        if scene == 6 then
            removeLuaSprite('redflash', true)
            setProperty('goldcloseup.alpha', 1)
        end
        if scene == 7 then
            removeLuaSprite('goldcloseup', true)
            setProperty('lookupbg.alpha', 1)
            setProperty('goldlookup.alpha', 1)
            playAnim('goldlookup', 'lookup', true)
        end
        if scene == 8 then
            removeLuaSprite('lookupbg', true)
            removeLuaSprite('goldlookup', true)
            setProperty('typhoflash.alpha', 1)
        end
        if scene == 9 then
            setProperty('camOther.zoom', 1.05)
            doTweenZoom('camotherzoomout', 'camOther', 1, 5, 'linear')

            removeLuaSprite('typhoflash', true)
            setProperty('handbg.alpha', 1)
            setProperty('handfront.alpha', 1)
            setProperty('goldbehind.alpha', 1)
            playAnim('handfront', 'idle', true)
        end
        if scene == 10 then
            removeLuaSprite('handbg', true)
            removeLuaSprite('handfront', true)
            removeLuaSprite('goldbehind', true)
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

            removeLuaSprite('lookupbgside', true)
            removeLuaSprite('goldside', true)
            removeLuaSprite('handside', true)
            removeLuaSprite('unownsleave', true)
            removeLuaSprite('prebloodlight', true)
            removeLuaSprite('prebloodfog', true)

            setProperty('lightbg.alpha', 0.5)
            setProperty('collectorhand.alpha', 1)
            setProperty('reachforhand.alpha', 1)
            playAnim('collectorhand', 'idle', true)
            playAnim('reachforhand', 'reach', true)
            doTweenAlpha('lightbgIn', 'lightbg', 1, 1.5, 'linear')
        end
        if scene == 12 then
            removeLuaSprite('lightbg', true)
            removeLuaSprite('collectorhand', true)
            removeLuaSprite('reachforhand', true)
            setProperty('bloodbg.alpha', 1)
            setProperty('armfall.alpha', 1)
            playAnim('armfall', 'fall', true)
            setProperty('camHUD.alpha', 1)
            swapOn()
        end
        if scene == 13 then
            removeLuaSprite('armfall', true)
            setProperty('bloodcut1.alpha', 1)
            setProperty('bloodcut2.alpha', 1)
            playAnim('bloodcut1', 'pour', true)
            playAnim('bloodcut2', 'pour', true)
            animEndTimer('bloodcutsceneEnd', 'bloodcut2')
        end
        if scene == 14 then
            setProperty('handstransition.alpha', 1)
            playAnim('handstransition', 'in', true)
        end
        if scene == 15 then
            -- golds head rips off
            setProperty('boyfriend.visible', false)
            setProperty('gf.visible', false)
            setProperty('goldbloodsplatter.alpha', 0)
            setProperty('bfbloodsplatter.alpha', 0)
            setProperty('bloodheadoff.alpha', 1)
            playAnim('bloodheadoff', 'rip', true)
            playAnim('handstransition', 'out', true)
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
        removeLuaSprite('introbg4', true)
        animEndTimer('celebi flown', 'celebifly')
        runTimer('camGame on', 1.65)
    end
    if tag == 'camGame on' then
        setProperty('camGame.zoom', 0.2)
        setProperty('camGame.alpha', 1)
    end
    if tag == 'celebi flown' then
        removeLuaSprite('celebifly', true)
        removeLuaSprite('unownsflyby', true)
        doTweenZoom('camIn1', 'camGame', 0.3, 8, 'smoothStepInOut')
    end
    if tag == 'bloodcutsceneEnd' then
        removeLuaSprite('bloodcut1', true)
        removeLuaSprite('bloodcut2', true)
        setProperty('gf.visible', true)
        setProperty('boyfriend.visible', true)
        setObjectOrder('boyfriend', getObjectOrder('handstransition') + 1)
        setObjectOrder('gf', getObjectOrder('handstransition') + 1)

        setObjectOrder('bfbloodsplatter', getObjectOrder('boyfriend') + 1)
        setObjectOrder('goldbloodsplatter', getObjectOrder('gf') + 1)

        setProperty('goldbloodsplatter.alpha', 1)
        setProperty('bfbloodsplatter.alpha', 1)
    end
end

function onTweenCompleted(tag)
    if tag == 'swapMix' then
        local finalMix = getProperty('swapController.x')
        setShaderFloat('swapController', 'uMix', finalMix)
        mixTweening = false
    end

    if tag == 'camIn1' then
        doTweenZoom('camIn2', 'camGame', 0.66, 8, 'cubeInOut')
    end
    if tag == 'lightbgIn' then
        setProperty('lightbg.alpha', 0.4)
    end
end

function onUpdatePost()
    setShaderFloat('swapController', 'uMix', getProperty('swapController.x'))
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
        if celebiLiftFrame >= 7 then
            setProperty('introbg4.y', 190 + ((celebiLiftFrame - 7) * 55))
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

local function c(r, g, b) return {r / 255, g / 255, b / 255} end

function swapOn()
    setProperty('swapController.x', 0)
    setShaderFloat('swapController', 'uMix', 0)
    setShaderFloat('swapController', 'uOn', 1)
    markHud(true)
end

function swapToWhite(duration)
    setProperty('swapController.x', 0)
    doTweenX('swapMix', 'swapController', 1, duration or 0.6, 'sineInOut')
end
function swapToBlack(duration)
    setProperty('swapController.x', 1)
    doTweenX('swapMix', 'swapController', 0, duration or 0.6, 'sineInOut')
end

function swapOff()
    cancelTween('swapMix')
    setProperty('swapController.x', 0)
    setShaderFloat('swapController', 'uOn', 0)
    setShaderFloat('swapController', 'uMix', 0)
    markHud(false)
end

local active = false
local orig = {}
local BLUE = getColorFromHex('00004D')

function markNote(i)
    local p = 'notes.members[' .. i .. ']'
    setBlendMode(p, 'add')
    setProperty(p .. '.rgbShader.r', BLUE)
    setProperty(p .. '.rgbShader.g', BLUE)
    setProperty(p .. '.rgbShader.b', BLUE)
end

local active = false

function markHud(on)
    active = on
    local mode = on and 'add' or 'normal'
    for i = 0, 7 do setBlendMode('strumLineNotes.members[' .. i .. ']', mode) end
    for i = 0, getProperty('notes.length') - 1 do setBlendMode('notes.members[' .. i .. ']', mode) end
    runHaxeFunction(on and 'markAll' or 'unmarkAll')
end

function onSpawnNote()
    if active then
        setBlendMode('notes.members[0]', 'add')
        runHaxeFunction('markNewest')
    end
end