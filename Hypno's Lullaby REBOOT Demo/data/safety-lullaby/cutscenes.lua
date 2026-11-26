local dir = 'safety_lullaby/cutscenes/intro/'
luaDebugMode = true

function onCreate()
    setProperty('camHUD.alpha', 0.0001)
    setProperty('camGame.alpha', 0.0001)

    -- opening: bf poster, gf walks in
        makeLuaSprite('sc1trees', dir..'beginning_trees', 0, 0)
        setObjectCamera('sc1trees', 'other')
        addLuaSprite('sc1trees')

        makeLuaSprite('sc1fence', dir..'beginning_fence', 0, 0)
        setObjectCamera('sc1fence', 'other')
        addLuaSprite('sc1fence')

        makeLuaSprite('sc1pole', dir..'beginning_pole', 0, 0)
        setObjectCamera('sc1pole', 'other')
        addLuaSprite('sc1pole')

        makeAnimatedLuaSprite('sc1gf', dir..'gf/walk_turn', 1200, 140)
        addAnimationByIndices('sc1gf', 'walk', 'walk', '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18', 24, false)
        addAnimationByPrefix('sc1gf', 'turn', 'turn', 24, false)
        setObjectCamera('sc1gf', 'other')
        scaleObject('sc1gf', 0.825, 0.825)
        addLuaSprite('sc1gf')

    -- poster close-up
        makeLuaSprite('postercloseup', dir..'closeup', 0, 0)
        setObjectCamera('postercloseup', 'other')
        setProperty('postercloseup.alpha', 0.0001)
        addLuaSprite('postercloseup')

    -- worried gf
        makeAnimatedLuaSprite('worriedgf', dir..'gf/look', 130, 50)
        addAnimationByPrefix('worriedgf', 'look', 'look', 24, true)
        setProperty('worriedgf.alpha', 0.0001)
        setObjectCamera('worriedgf', 'other')
        scaleObject('worriedgf', 0.95, 0.95)
        addLuaSprite('worriedgf')

    -- gf far away, hypno lurking
        makeLuaSprite('pdropsky', dir..'pendulum_drop_sky', 0, 0)
        setProperty('pdropsky.alpha', 0.0001)
        setObjectCamera('pdropsky', 'other')
        addLuaSprite('pdropsky')

        makeLuaSprite('pdropbg', dir..'pendulum_drop_bg', 0, 0)
        setProperty('pdropbg.alpha', 0.0001)
        setObjectCamera('pdropbg', 'other')
        addLuaSprite('pdropbg')

        makeAnimatedLuaSprite('pdropgf', dir..'gf/far_focus', 768, 407)
        addAnimationByIndices('pdropgf', 'idle', 'far', [['
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,
        19,20,21,22,23,24,25,26']], 24, false)
        setProperty('pdropgf.alpha', 0.0001)
        setObjectCamera('pdropgf', 'other')
        scaleObject('pdropgf', 0.88, 0.88)
        addLuaSprite('pdropgf')

        makeLuaSprite('pdroptrees', dir..'pendulum_drop_trees', 0, 0)
        setProperty('pdroptrees.alpha', 0.0001)
        setObjectCamera('pdroptrees', 'other')
        addLuaSprite('pdroptrees')

        makeLuaSprite('pdroplights', dir..'pendulum_drop_lights', 0, 0)
        setProperty('pdroplights.alpha', 0.0001)
        setObjectCamera('pdroplights', 'other')
        addLuaSprite('pdroplights')

        makeAnimatedLuaSprite('pdrophypno', dir..'hypno', -10, -140)
        addAnimationByPrefix('pdrophypno', 'idle', 'hypno', 24, true)
        setProperty('pdrophypno.alpha', 0.0001)
        setObjectCamera('pdrophypno', 'other')
        scaleObject('pdrophypno', 0.75, 0.75)
        addLuaSprite('pdrophypno')

        makeAnimatedLuaSprite('pdrop', dir..'pendulum_drop', 580, -320)
        addAnimationByPrefix('pdrop', 'drop', 'drop', 24, false)
        setProperty('pdrop.alpha', 0.0001)
        setObjectCamera('pdrop', 'other')
        scaleObject('pdrop', 0.89, 0.89)
        addLuaSprite('pdrop')

    -- gf looking confused
        makeLuaSprite('gffocusbg', dir..'gf_focus_bg', -110, -120)
        setProperty('gffocusbg.alpha', 0.0001)
        setObjectCamera('gffocusbg', 'other')
        scaleObject('gffocusbg', 1.18, 1.18)
        addLuaSprite('gffocusbg')

        makeAnimatedLuaSprite('confusedgf', dir..'gf/focus_body', 330, 105)
        addAnimationByPrefix('confusedgf', 'idle', 'focus', 24, true)
        setProperty('confusedgf.alpha', 0.0001)
        setObjectCamera('confusedgf', 'other')
        scaleObject('confusedgf', 0.95, 0.95)
        addLuaSprite('confusedgf')

        makeAnimatedLuaSprite('confusedgfface', dir..'gf/focus_face', 490, 327)
        addAnimationByPrefix('confusedgfface', 'idle', 'face', 24, false)
        setProperty('confusedgfface.alpha', 0.0001)
        setObjectCamera('confusedgfface', 'other')
        scaleObject('confusedgfface', 0.95, 0.95)
        addLuaSprite('confusedgfface')

    -- dark forest
        makeLuaSprite('introendbg', dir..'ending_bg', 0, 0)
        setObjectCamera('introendbg', 'other')
        setProperty('introendbg.color', '000000')
        addLuaSprite('introendbg')
end

local scene = -1

function onEvent(name, value1, value2)
    if name == 'intro cutscene' then
        scene = scene + 1
        debugPrint(scene)
        if scene == 0 then
            doTweenX('gfWalkIn', 'sc1gf', 625, 1.9, 'sineOut')
            playAnim('sc1gf', 'walk', true)
        end
        if scene == 1 then
            playAnim('sc1gf', 'turn', true)
        end
        if scene == 2 then
            cancelTween('zoomOut')
            cancelTween('blackOverlayOut')
            setProperty('introendbg.alpha', 0)
            setProperty('introendbg.color', getColorFromHex('FFFFFF'))
            setProperty('camOther.zoom', 1)
            setProperty('sc1trees.alpha', 0)
            removeLuaSprite('sc1fence', true)
            removeLuaSprite('sc1pole', true)
            removeLuaSprite('sc1gf', true)
            setProperty('postercloseup.alpha', 1)
        end
        if scene == 3 then
            removeLuaSprite('postercloseup', true)
            setProperty('sc1trees.scale.x', 1.2)
            setProperty('sc1trees.scale.y', 1.2)
            setProperty('sc1trees.alpha', 1)
            setProperty('worriedgf.alpha', 1)
        end
        if scene == 4 then
            setProperty('camOther.zoom', 1.25)
            removeLuaSprite('sc1trees', true)
            removeLuaSprite('worriedgf', true)
            setProperty('pdropsky.alpha', 1)
            setProperty('pdropbg.alpha', 1)
            setProperty('pdropgf.alpha', 1)
            setProperty('pdroplights.alpha', 1)
            setProperty('pdroptrees.alpha', 1)
            setProperty('pdrophypno.alpha', 1)
            doTweenZoom('pdropZoomOut', 'camOther', 1.2, 3, 'linear')
            playAnim('pdropgf', 'idle', true)
        end
        if scene == 5 then
            cancelTween('pdropZoomOut')
            doTweenZoom('pdropZoomOut2', 'camOther', 1.025, 0.2, 'linear')
            playAnim('pdrop', 'drop', true)
            setProperty('pdrop.alpha', 1)
        end
        if scene == 6 then
            cancelTween('pdropZoomOut')
            cancelTween('pdropZoomOut2')
            cancelTween('pdropZoomOut3')
            setProperty('camOther.zoom', 1)
            removeLuaSprite('pdropsky', true)
            removeLuaSprite('pdropbg', true)
            removeLuaSprite('pdropgf', true)
            removeLuaSprite('pdroplights', true)
            removeLuaSprite('pdroptrees', true)
            removeLuaSprite('pdrophypno', true)
            removeLuaSprite('pdrop', true)
            setProperty('gffocusbg.alpha', 1)
            setProperty('confusedgf.alpha', 1)
            setProperty('confusedgfface.alpha', 1)
            playAnim('confusedgfface', 'idle', true)
        end
        if scene == 7 then
            removeLuaSprite('gffocusbg', true)
            removeLuaSprite('confusedgf', true)
            removeLuaSprite('confusedgfface', true)
            setProperty('introendbg.alpha', 1)
            doTweenZoom('zoomInOnForest', 'camOther', 1.05, 3, 'linear')
        end
        if scene == 8 then
            cancelTween('zoomInOnForest')
            doTweenZoom('zoomInOnForest2', 'camOther', 1.8, 1.25, 'sineOut')
            doTweenColor('endbgout', 'introendbg', '000000', 1, 'linear')
        end
        if scene == 9 then
            setProperty('camGame.alpha', 1)
            setProperty('camHUD.alpha', 1)
            cancelTween('zoomInOnForest2')
            setProperty('camOther.zoom', 1)
            doTweenAlpha('endbgfadeout', 'introendbg', 0, 2, 'linear')
        end
    end
end

function onTweenCompleted(tag)
    if tag == 'pdropZoomOut2' then
        doTweenZoom('pdropZoomOut3', 'camOther', 1, 2.5, 'smoothStepIn')
    end
end

function onSongStart()
    setProperty('camOther.zoom', 1.7)
    doTweenZoom('zoomOut', 'camOther', 1.25, 10, 'smoothStepOut')
    doTweenAlpha('blackOverlayOut', 'introendbg', 0, 10, 'linear')
end