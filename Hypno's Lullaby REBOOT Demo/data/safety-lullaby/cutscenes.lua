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
        addAnimationByIndices('sc1gf', 'walk', 'walk', '0,0,0,0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18', 24, false)
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

        makeAnimatedLuaSprite('pdrophypno', dir..'hypno', -10, -140)
        addAnimationByPrefix('pdrophypno', 'idle', 'hypno', 24, true)
        setProperty('pdrophypno.alpha', 0.0001)
        setProperty('pdrophypno.color', getColorFromHex('676767')) -- unlit in Godot, modulate 0.404 grey
        setObjectCamera('pdrophypno', 'other')
        scaleObject('pdrophypno', 0.75, 0.75)
        addLuaSprite('pdrophypno')

        makeAnimatedLuaSprite('pdrop', dir..'pendulum_drop', 580, -320)
        addAnimationByPrefix('pdrop', 'drop', 'drop', 24, false)
        setProperty('pdrop.alpha', 0.0001)
        setProperty('pdrop.color', getColorFromHex('ADADAD')) -- unlit in Godot, modulate 0.678 grey
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
        --debugPrint(scene)
        if scene == 0 then
            doTweenX('gfWalkIn', 'sc1gf', 625, 1.9, 'sineOut')
            playAnim('sc1gf', 'walk', true)
        end
        if scene == 1 then
            playAnim('sc1gf', 'turn', true)
            setProperty('sc1gf.x', getProperty('sc1gf.x') - 5)
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

local LIGHT_TIME_OFFSET = 0.0

-- Flicker of the PoleLight in the opening shot
local FLICKER = {
	{ 0, false }, { 2.375, true }, { 2.4583, false }, { 3.7083, true }, { 3.75, false }, { 3.875, true },
	{ 3.9167, false }, { 5.25, true }, { 5.2917, false }, { 6.1667, true }, { 6.25, false }, { 7.3333, true },
}

local STATES = {
	open     = { bg = { 0, 1, 1, 1 },             pole = { 365, -167, 1.5, 1.5, 0 },               flicker = true, glow = false, anchor = 'sc1trees' },
	closeup  = { bg = { 0, 1, 1, 1 },             pole = { 598, -385, 2.578, 2.383, 0 },           glow = false, anchor = 'sc1trees' },
	worried  = { bg = { 0, 1, 1, 1 },             pole = { 478, 166, 2.578, 2.383, 0.00349066 },   glow = false, anchor = 'sc1trees' },
	drop     = { bg = { 48, 66.5, 0.637, 0.784 }, pole = { 339, 78, 0.386, 0.528, 0.02443461 },    glow = true,  anchor = 'pdropsky' },
	confused = { bg = { 0, 1, 1, 1 },             pole = { 301, -252, 1.79, 1.467, 0 },            glow = false, anchor = 'gffocusbg' },
	forest   = { bg = { 0, 1, 1, 1 },             pole = { 301, -252, 1.79, 1.467, 0 },            glow = false, anchor = 'introendbg' },
}

local STATE_SHIFT = {
	open = { 0, 0 }, closeup = { 0, 0 }, worried = { 0, 0 },
	drop = { 0, 0 }, confused = { 0, 0 }, forest = { 0, 0 },
}

-- PoleLightBG (the street lights): colour * energy
local GLOW_COLOR = { 1.0 * 4.07, 1.0 * 4.07, 0.73333335 * 4.07 }

-- it's lit!
local LIT = {
	'sc1trees', 'sc1fence', 'sc1pole', 'sc1gf', 'postercloseup', 'worriedgf',
	'pdropsky', 'pdropbg', 'pdropgf', 'pdroptrees',
	'gffocusbg', 'confusedgf', 'confusedgfface', 'introendbg',
}

local lastLights = ''
local lastSprite = {}
local finished = false
local shaderReady = {}

local function stateName(scene)
	if scene <= 1 then return 'open' end
	if scene == 2 then return 'closeup' end
	if scene == 3 then return 'worried' end
	if scene <= 5 then return 'drop' end
	if scene == 6 then return 'confused' end
	return 'forest'
end

local function poleOn(st, t)
	if not st.flicker then return true end
	local on = false
	for _, k in ipairs(FLICKER) do
		if t >= k[1] then on = k[2] else break end
	end
	return on
end

local function exists(tag)
	return luaSpriteExists(tag)
end

local function setupSprite(tag)
	setSpriteShader(tag, 'cutsceneLight')
	setShaderSampler2D(tag, 'bgTex', dir .. 'darkness_gradient')
	setShaderSampler2D(tag, 'coneTex', 'safety_lullaby/alley/awesomeahhlight')
	setShaderSampler2D(tag, 'glowTex', dir .. 'pendulum_drop_lights')
	setShaderFloatArray(tag, 'uFrame', { 0, 0, 1, 1 })
	setShaderFloat(tag, 'uRot', 0)
	setShaderFloatArray(tag, 'uOrigin', { 0, 0 })
	setShaderFloatArray(tag, 'uSize', { 1280, 720 })
	setShaderFloatArray(tag, 'uOn', { 0, 0, 0 })
	setShaderFloatArray(tag, 'uGlowColor', GLOW_COLOR)
	setShaderFloatArray(tag, 'uPoleRot', { 1, 0 })
	setShaderFloatArray(tag, 'uBg', { 640, 360, 1397, 640 })
	setShaderFloatArray(tag, 'uPole', { 640, 360, 500, 370 })
	setShaderFloatArray(tag, 'uGlow', { 644, 363.33, 640, 360 })
	shaderReady[tag] = true
end

function onCreatePost()
    initLuaShader('cutsceneLight')
	for _, tag in ipairs(LIT) do
		if exists(tag) then setupSprite(tag) end
	end
end

-- Godot unit -> image px
local function gx(v) return 640 + v / 1.5 end
local function gy(v) return 360 + v / 1.5 end

local function pushLights(name, pole)
	local st = STATES[name]
	local shift = STATE_SHIFT[name] or { 0, 0 }
	local sx, sy = shift[1], shift[2]

	-- BGLight is 524x240 texture, texture_scale 8, node scale
	local bg = { gx(st.bg[1]) + sx, gy(st.bg[2]) + sy, 524 * 8 / 3 * st.bg[3], 240 * 8 / 3 * st.bg[4] }
	-- PoleLight: 921x681 texture, texture_scale 1.65, node scale, node rotation
	local p = st.pole
	local pl = { gx(p[1]) + sx, gy(p[2]) + sy, 921 * 1.65 / 3 * p[3], 681 * 1.65 / 3 * p[4] }
	-- PoleLightBG: 1280x720 texture at node scale 1.5 = exactly the 1280x720 art, at (6, 5)
	local gl = { gx(6) + sx, gy(5) + sy, 640, 360 }

	for _, tag in ipairs(LIT) do
		if exists(tag) then
			if not shaderReady[tag] then setupSprite(tag) end
			setShaderFloatArray(tag, 'uBg', bg)
			setShaderFloatArray(tag, 'uPole', pl)
			setShaderFloatArray(tag, 'uGlow', gl)
			setShaderFloatArray(tag, 'uPoleRot', { math.cos(p[5]), math.sin(p[5]) })
			setShaderFloatArray(tag, 'uOn', { 1, pole and 1 or 0, st.glow and 1 or 0 })
		end
	end
end

local function visibleTopLeft(tag, frOffX, frOffY)
	local sx, sy = getProperty(tag .. '.scale.x') or 1, getProperty(tag .. '.scale.y') or 1
	local ox, oy = getProperty(tag .. '.origin.x') or 0, getProperty(tag .. '.origin.y') or 0
	local offX, offY = getProperty(tag .. '.offset.x') or 0, getProperty(tag .. '.offset.y') or 0
	local left = getProperty(tag .. '.x') - offX + ox + (frOffX - ox) * sx
	local top = getProperty(tag .. '.y') - offY + oy + (frOffY - oy) * sy
	return left, top, sx, sy
end

local function pushSprite(tag, anchor)
	-- the anchor sprite defines image space (top-left and scale)
	local al, at, asx, asy = 0, 0, 1, 1
	if anchor and exists(anchor) then
		al, at, asx, asy = visibleTopLeft(anchor, 0, 0)
		if asx == 0 or asy == 0 then al, at, asx, asy = 0, 0, 1, 1 end
	end

	local gw, gh = getProperty(tag .. '.graphic.width'), getProperty(tag .. '.graphic.height')
	local fx, fy = getProperty(tag .. '.frame.frame.x'), getProperty(tag .. '.frame.frame.y')
	local fw, fh = getProperty(tag .. '.frame.frame.width'), getProperty(tag .. '.frame.frame.height')
	if not (gw and fx and fw and gw > 0) then return end
	local frOffX, frOffY = getProperty(tag .. '.frame.offset.x') or 0, getProperty(tag .. '.frame.offset.y') or 0
	local left, top, sx, sy = visibleTopLeft(tag, frOffX, frOffY)
	local rotated = (getProperty(tag .. '.frame.angle') or 0) ~= 0
	local dw, dh = fw, fh
	if rotated then dw, dh = fh, fw end

	local ox, oy = (left - al) / asx, (top - at) / asy
	local w, h = dw * sx / asx, dh * sy / asy
	local sig = string.format('%.2f|%.2f|%.2f|%.2f|%d|%d|%d', ox, oy, w, h, fx, fy, rotated and 1 or 0)
	if sig == lastSprite[tag] then return end
	lastSprite[tag] = sig

	setShaderFloat(tag, 'uRot', rotated and 1 or 0)
	setShaderFloatArray(tag, 'uFrame', { fx / gw, fy / gh, fw / gw, fh / gh })
	setShaderFloatArray(tag, 'uSize', { w, h })
	setShaderFloatArray(tag, 'uOrigin', { ox, oy })
end

function onUpdatePost(elapsed)
	if finished then return end

	-- the cutscene is over once the forest overlay has faded out
	if scene >= 9 and (not exists('introendbg') or (getProperty('introendbg.alpha') or 0) < 0.01) then
		finished = true
		return
	end

	local name = stateName(scene)
	local st = STATES[name]
	local t = getSongPosition() / 1000 + LIGHT_TIME_OFFSET
	local pole = poleOn(st, t)

	local key = name .. (pole and '1' or '0')
	if key ~= lastLights then
		lastLights = key
		pushLights(name, pole)
	end

	for _, tag in ipairs(LIT) do
		if exists(tag) and (getProperty(tag .. '.alpha') or 0) > 0.01 then
			pushSprite(tag, st.anchor)
		end
	end
end

function onSongStart()
    setProperty('camOther.zoom', 1.7)
    doTweenZoom('zoomOut', 'camOther', 1.25, 10, 'smoothStepOut')
    doTweenAlpha('blackOverlayOut', 'introendbg', 0, 10, 'linear')
end