-- Safety Lullaby alley. Lighting follows the Godot scene: no ambient CanvasModulate, the darkness IS the
-- "BgLight" (Mix blend, darkness_gradient). Lamp lights and Hypno's vignette light then ADD on top, and each
-- light only affects the sprites on its cull-mask layers (sky and clouds are never lit).
-- Needs Psych Engine 1.0+ (setShaderSampler2D).

local sceneScale = (2 / 3) * 1.3333333
local sceneOffsetX = -216
local sceneOffsetY = -23
local cloudSpeed = -25 * sceneScale
local cloudWidth = 1848 * 2.25 * sceneScale

-- Godot light parameters (alley.tscn / sng_safety_lullaby.tscn / chr_hypno_safety.tscn)
local bgEnergy = 0.75
local lampStatic = { 1.0, 1.2, 0.8 }  -- node energies, used when "flashing lights" is off (lamp_flicker.gd stops)
local hypnoLightScale = 2 * 1.25 * sceneScale
local hypnoLightW = 195 * hypnoLightScale
local hypnoLightH = 290 * hypnoLightScale
local mainBaseEnergy = 0.31
local mainBaseColor = { 0.961983, 0.8266328, 0.884364 }
local subEnergy = 0.08

-- ===== Hypno's MainLight position ========================================================================
-- Godot moves MainLight per animation (and per frame for laugh / step) with the AnimationPlayer in
-- chr_hypno_safety.tscn. The values are in Hypno-local units; the port's sprite canvas is Hypno-local + CANVAS.
-- Keys are { frame (24fps), x, y } and stay active until the next key (stepped, like the Godot tracks).
local CANVAS_X, CANVAS_Y = 446, 713

local LIGHT_KEYS = {
	['idle'] = { { 0, 356.92, -253.08 } },
	['singLEFT'] = { { 0, 253.08, -276.15 } },
	['singDOWN'] = { { 0, 318.46, -231.54 } },
	['singUP'] = { { 0, 265.38, -303.85 } },
	['singRIGHT'] = { { 0, 340.0, -235.38 } },
	['idle-alt'] = { { 0, 356.92, -253.08 } },
	['singLEFT-alt'] = { { 0, 90.0, -339.23 } },
	['singDOWN-alt'] = { { 0, 289.23, -206.92 } },
	['singUP-alt'] = { { 0, 284.62, -426.15 } },
	['singRIGHT-alt'] = { { 0, 418.46, -268.46 } },
	['step'] = { { 0, 356.92, -253.08 }, { 8, 337.23, -253.08 }, { 17, 350.85, -253.08 }, { 20, 354.62, -253.08 }, { 24, 356.92, -253.08 } },
	['laugh'] = { { 0, 356.92, -253.08 }, { 45, 378.46, -245.38 }, { 50, 365.38, -245.38 }, { 55, 352.31, -266.92 }, { 60, 333.85, -253.08 }, { 64, 317.69, -245.38 }, { 73, 345.38, -253.08 }, { 75, 356.92, -253.08 } },
}

-- EASY TUNING: extra offset in Psych pixels per dad animation name, added on top (+x right, +y down).
local LIGHT_ADJUST = {
	['idle'] = { 0, 0 },
	['singLEFT'] = { 0, 0 },
	['singDOWN'] = { 0, 0 },
	['singUP'] = { 0, 0 },
	['singRIGHT'] = { 0, 0 },
	['idle-alt'] = { 0, 0 },
	['singLEFT-alt'] = { 0, 0 },
	['singDOWN-alt'] = { 0, 0 },
	['singUP-alt'] = { 0, 0 },
	['singRIGHT-alt'] = { 0, 0 },
	['step'] = { 0, 0 },
	['laugh'] = { 0, 0 },
}
local watchedChars = { dad = '', boyfriend = '' }

-- Godot timeline times read about 1 second late in Psych, so the timeline is sampled this many seconds earlier.
local SONG_TIME_OFFSET = 1.0

-- MainLight colour/energy keys from the song's AnimationPlayer: {seconds, r, g, b, energy}
local pink = { 0.9523702, 0.14184096, 0.49339223 }
local main = mainBaseColor
local mainKeys = {
	{ 0, main[1], main[2], main[3], 0.31 },
	{ 65.916664, main[1], main[2], main[3], 0.31 },
	{ 66.458336, pink[1], pink[2], pink[3], 0.31 },
	{ 67.625, pink[1], pink[2], pink[3], 0.31 },
	{ 68.25, main[1], main[2], main[3], 0.31 },
	{ 78.5, main[1], main[2], main[3], 0.31 },
	{ 78.91667, 0.978527, 0.22880149, 0.5272291, 0.31 },
	{ 90.25, pink[1], pink[2], pink[3], 0.31 },
	{ 92.541664, main[1], main[2], main[3], 0.31 },
	{ 112.666664, main[1], main[2], main[3], 0.35 },
	{ 113.16667, pink[1], pink[2], pink[3], 0.46 },
	{ 114.333336, pink[1], pink[2], pink[3], 0.46 },
	{ 117.375, main[1], main[2], main[3], 0.35 },
}

local clouds = { 'SafetyClouds', 'SafetyClouds2' }
local lit = {}          -- { tag, scrollFactor, char = bool }
local lightingOn = false
local healthTracked = 2
local timePassed = 0
local flickerTimer = 0
local flickerActive = false

local function toWorldX(x) return (x + sceneOffsetX) * sceneScale end
local function toWorldY(y) return (y + sceneOffsetY) * sceneScale end

local function addStageSprite(tag, image, x, y, width, height, scale, scrollX, scrollY, flags)
	local finalScale = scale * sceneScale
	local finalX = toWorldX(x) - width * finalScale * 0.5
	local finalY = toWorldY(y) - height * finalScale * 0.5

	makeLuaSprite(tag, 'safety_lullaby/alley/' .. image, finalX, finalY)
	scaleObject(tag, finalScale, finalScale)
	setScrollFactor(tag, scrollX, scrollY)
	addLuaSprite(tag, false)
	if flags then
		lit[#lit + 1] = { tag = tag, scroll = scrollX, flags = flags, char = false }
	end
end

-- light rects are {centreX, centreY, halfWidth, halfHeight} in world pixels
local function rect(cx, cy, w, h)
	return { toWorldX(cx), toWorldY(cy), w * sceneScale * 0.5, h * sceneScale * 0.5 }
end

local lampX, lampY, lampS = 2051.69, 214, 2.15141
local bgRect = rect(801, 449, 1049 * 4, 480 * 4)
local poleRect = rect(lampX + 5.7219 * lampS, lampY - 210.095 * lampS, 202 * 2 * 0.464811 * lampS, 114 * 2 * 0.464811 * lampS)
local cone1Rect = rect(lampX + 134.00978 * lampS, lampY + 105.51219 * lampS, 921 * 0.928031 * lampS, 681 * 1.02259 * lampS)
local cone2Rect = rect(lampX + 185.60388 * lampS, lampY + 41.183647 * lampS, 921 * 1.3687 * lampS, 681 * 1.02259 * lampS)

local function setupLitSprite(entry)
	local tag = entry.tag
	initLuaShader('lightMask')
	setSpriteShader(tag, 'lightMask')
	setShaderSampler2D(tag, 'bgTex', 'safety_lullaby/alley/darkness_gradient')
	setShaderSampler2D(tag, 'poleTex', 'safety_lullaby/alley/post_light_gradient')
	setShaderSampler2D(tag, 'coneTex', 'safety_lullaby/alley/awesomeahhlight')
	setShaderSampler2D(tag, 'hypTex', 'safety_lullaby/chr_hypno_sl_light')
	setShaderFloatArray(tag, 'uBg', bgRect)
	setShaderFloatArray(tag, 'uPole', poleRect)
	setShaderFloatArray(tag, 'uCone1', cone1Rect)
	setShaderFloatArray(tag, 'uCone2', cone2Rect)
	setShaderFloatArray(tag, 'uFlags', entry.flags)
	setShaderFloat(tag, 'uBgEnergy', bgEnergy)
	setShaderFloat(tag, 'uSubEnergy', subEnergy)
	setShaderFloatArray(tag, 'uFrame', { 0, 0, 1, 1 })
	setShaderFloat(tag, 'uRot', 0)
	if not entry.char then
		setShaderFloatArray(tag, 'uSize', { getProperty(tag .. '.width'), getProperty(tag .. '.height') })
		setShaderFloatArray(tag, 'uOrigin', { getProperty(tag .. '.x'), getProperty(tag .. '.y') })
	end
end

local function sampleMain(t)
	local a = mainKeys[1]
	for i = 1, #mainKeys - 1 do
		local k0, k1 = mainKeys[i], mainKeys[i + 1]
		if t >= k0[1] and t < k1[1] then
			local f = (t - k0[1]) / (k1[1] - k0[1])
			return k0[2] + (k1[2] - k0[2]) * f, k0[3] + (k1[3] - k0[3]) * f, k0[4] + (k1[4] - k0[4]) * f, k0[5] + (k1[5] - k0[5]) * f
		end
	end
	a = mainKeys[#mainKeys]
	return a[2], a[3], a[4], a[5]
end

local function sampleHypnoLightScale(t)
	if t < 32.375 then
		return 2
	elseif t < 72.125 then
		return 2 + (t - 32.375) / (72.125 - 32.375)
	elseif t < 109.75 then
		return 3
	elseif t < 157.625 then
		local progress = (t - 109.75) / (157.625 - 109.75)
		return 3 + 9 * progress ^ 1.624505
	end
	return 12
end

function onCreate()
	makeLuaSprite('SafetySky', nil, -1200, -900)
	makeGraphic('SafetySky', 5000, 3000, '11131D')
	setScrollFactor('SafetySky', 0.55, 0.55)
	addLuaSprite('SafetySky', false)

	addStageSprite('SafetyClouds', 'clouds', 796, 179, 1848, 415, 2.25, 0.55, 0.55)
	addStageSprite('SafetyClouds2', 'clouds', 4796, 179, 1848, 415, 2.25, 0.55, 0.55)
	setProperty('SafetyClouds.alpha', 0.75)
	setProperty('SafetyClouds2.alpha', 0.75)

	-- flags: { BgLight/Pole/PoleLight, PoleLight2, Hypno MainLight, Hypno SubLight }  (from light_mask vs cull masks)
	local layer1 = { 1, 1, 1, 0 }   -- light_mask 1
	local layer12 = { 1, 1, 1, 1 }  -- light_mask 3
	local lampOnly = { 1, 0, 0, 0 } -- light_mask 256

	addStageSprite('SafetyMountain', 'mountain', 1523, 126, 1140, 358, 2.25, 0.8, 0.8, layer1)
	addStageSprite('SafetyStreet', 'street', 936, 968, 1808, 397, 2.2, 1, 1, layer12)
	addStageSprite('SafetyTrees', 'trees', 854, 155, 1606, 541, 2.2, 1, 1, layer12)
	addStageSprite('SafetyFence', 'longfence', 1715, 532, 1117, 172, 2.2, 1, 1, layer12)
	addStageSprite('SafetyBench', 'bench', 1518, 722, 259, 118, 2.11864, 1, 1, layer12)
	addStageSprite('SafetyPokecenter', 'pokecenter', 414, 415, 529, 475, 2.2, 1, 1, layer12)
	addStageSprite('SafetyLamp1', 'lamp1', lampX, lampY, 123, 568, lampS, 1, 1, lampOnly)
	addStageSprite('SafetyLamp2', 'lampoff', 1063, 253, 88, 523, 2.2, 1, 1, layer12)
	addStageSprite('SafetyBrokenLamp', 'lampbroken', -231, 603, 94, 202, 2.2, 1, 1, layer12)

	lightingOn = shadersEnabled ~= false
	if lightingOn then
		for _, entry in ipairs(lit) do
			setupLitSprite(entry)
		end
	end
end

function onCreatePost()
	if not lightingOn then return end
	-- the characters are lit like layer-1 items (Hypno: light_mask 81)
	for _, tag in ipairs({ 'dad', 'boyfriend' }) do
		local entry = { tag = tag, scroll = 1, flags = { 1, 1, 1, 0 }, char = true }
		lit[#lit + 1] = entry
		setupLitSprite(entry)
		watchedChars[tag] = getProperty(tag .. '.curCharacter') or ''
	end
end

-- Hypno-local -> Psych world, using exactly how FlxSprite draws the current frame (x, offset, origin, scale)
local function localToWorld(lx, ly)
	local cx, cy = lx + CANVAS_X, ly + CANVAS_Y
	local ox, oy = getProperty('dad.origin.x'), getProperty('dad.origin.y')
	local sx, sy = getProperty('dad.scale.x'), getProperty('dad.scale.y')
	local x = getProperty('dad.x') - getProperty('dad.offset.x') + ox + (cx - ox) * sx
	local y = getProperty('dad.y') - getProperty('dad.offset.y') + oy + (cy - oy) * sy
	return x, y
end

local function hypnoLightWorld()
	local pose = getProperty('dad.animation.curAnim.name') or 'idle'
	local frame = getProperty('dad.animation.curAnim.curFrame') or 0
	local keys = LIGHT_KEYS[pose] or LIGHT_KEYS['idle']
	local key = keys[1]
	for _, k in ipairs(keys) do
		if k[1] <= frame then key = k end
	end

	local x, y = localToWorld(key[2], key[3])
	local adj = LIGHT_ADJUST[pose] or { 0, 0 }
	return x + adj[1], y + adj[2]
end

local function pushLightState(elapsed, energies)
	local t = (getSongPosition() or 0) / 1000 + SONG_TIME_OFFSET
	local r, g, b, e = sampleMain(t)
	local scrollX = getProperty('camGame.scroll.x') or 0
	local scrollY = getProperty('camGame.scroll.y') or 0
	local lightScale = sampleHypnoLightScale(t) / 2
	local hx, hy = hypnoLightWorld()
	local endingLightingOff = getVar('safetyLullabyEndingLightingOff') == true
	local hyp = {
		hx, hy,
		hypnoLightW * lightScale * 0.5, hypnoLightH * lightScale * 0.5,
	}

	for _, entry in ipairs(lit) do
		local tag = entry.tag
		-- Change Character swaps the Character object, which drops its shader: apply it again
		if entry.char then
			local now = getProperty(tag .. '.curCharacter') or ''
			if now ~= watchedChars[tag] then
				watchedChars[tag] = now
				setupLitSprite(entry)
			end
		end
		setShaderFloatArray(tag, 'uLampEnergy', energies)
		setShaderFloatArray(tag, 'uMainColor', { r * e, g * e, b * e })
		setShaderFloatArray(tag, 'uHyp', hyp)
		local flags = entry.flags
		if tag == 'dad' and endingLightingOff then flags = { 0, 0, 0, 0 } end
		setShaderFloatArray(tag, 'uFlags', flags)

		if tag == 'dad' then
			local bobX = getVar('pendulumBobX')
			if endingLightingOff then
				setShaderFloatArray(tag, 'uBob', { 0, 0, 0, 0 })
			elseif bobX ~= nil then
				setShaderFloatArray(tag, 'uBob', { bobX, getVar('pendulumBobY'), getVar('pendulumBobRX'), getVar('pendulumBobRY') })
				setShaderFloatArray(tag, 'uBobColor', { getVar('pendulumBobR'), getVar('pendulumBobG'), getVar('pendulumBobB') })
			end
		end

		if entry.char then
			-- Place this animation frame exactly where FlxSprite draws it (offset, origin, scale and the frame's
			-- own trim offset), so the light position stays fixed while Hypno switches poses.
			local gw, gh = getProperty(tag .. '.graphic.width'), getProperty(tag .. '.graphic.height')
			local fx, fy = getProperty(tag .. '.frame.frame.x'), getProperty(tag .. '.frame.frame.y')
			local fw, fh = getProperty(tag .. '.frame.frame.width'), getProperty(tag .. '.frame.frame.height')
			if gw and fx and fw and gw > 0 then
				local sx, sy = getProperty(tag .. '.scale.x') or 1, getProperty(tag .. '.scale.y') or 1
				local ox, oy = getProperty(tag .. '.origin.x') or 0, getProperty(tag .. '.origin.y') or 0
				local offX, offY = getProperty(tag .. '.offset.x') or 0, getProperty(tag .. '.offset.y') or 0
				local frOffX, frOffY = getProperty(tag .. '.frame.offset.x') or 0, getProperty(tag .. '.frame.offset.y') or 0
				local left = getProperty(tag .. '.x') - offX + ox + (frOffX - ox) * sx
				local top = getProperty(tag .. '.y') - offY + oy + (frOffY - oy) * sy
				-- Hypno's left/up frames are stored rotated in the atlas: swap the displayed size and tell the shader
				local rotated = (getProperty(tag .. '.frame.angle') or 0) ~= 0
				local dw, dh = fw, fh
				if rotated then dw, dh = fh, fw end
				setShaderFloat(tag, 'uRot', rotated and 1 or 0)
				setShaderFloatArray(tag, 'uFrame', { fx / gw, fy / gh, fw / gw, fh / gh })
				setShaderFloatArray(tag, 'uSize', { dw * sx, dh * sy })
				setShaderFloatArray(tag, 'uOrigin', { left, top })
			end
		elseif entry.scroll ~= 1 then
			-- parallax layers: convert the on-screen position back into scroll-factor-1 light space
			setShaderFloatArray(tag, 'uOrigin', {
				getProperty(tag .. '.x') + scrollX * (1 - entry.scroll),
				getProperty(tag .. '.y') + scrollY * (1 - entry.scroll),
			})
		end
	end
end

function onUpdatePost(elapsed)
	timePassed = timePassed + elapsed

	for _, tag in ipairs(clouds) do
		local cloudX = getProperty(tag .. '.x') + cloudSpeed * elapsed
		if cloudX < -cloudWidth then
			cloudX = cloudX + cloudWidth * 2
		end
		setProperty(tag .. '.x', cloudX)
	end

	if not lightingOn then return end

	local canFlicker = true
	local preferenceFound, flashingEnabled = pcall(function()
		return getPropertyFromClass('backend.ClientPrefs', 'data.flashing')
	end)
	if preferenceFound and flashingEnabled == false then
		canFlicker = false
	end

	local energies = { lampStatic[1], lampStatic[2], lampStatic[3] }
	if canFlicker then
		-- lamp_flicker.gd: all three lamp lights share one energy value
		local health = getProperty('health') or 2
		healthTracked = healthTracked + (health - healthTracked) * math.min(20 * elapsed, 1)
		local healthProgress = math.max(0, math.min(healthTracked / 2, 1))
		local lightStrength = 1 - (1 - healthProgress) ^ 3
		local pulse = math.sin(timePassed * math.pi)
		local energy = math.max((0.8 * lightStrength) + (pulse * 0.04) - 0.04, 0)
		local flickerEnergy = math.max(((lightStrength - 0.04) * 0.8) - 0.1, 0.1)

		if flickerActive then
			flickerTimer = flickerTimer + elapsed
			if flickerTimer < 0.083 then
				energy = flickerEnergy
			elseif flickerTimer < 0.166 then
				energy = 0.8
			else
				flickerActive = false
			end
		else
			local flickerChance = 0.05 + ((1 - healthProgress) * 2.5)
			if math.random() * 100 < flickerChance * 60 * elapsed then
				flickerActive = true
				flickerTimer = 0
				energy = flickerEnergy
			end
		end
		energies = { energy, energy, energy }
	end

	pushLightState(elapsed, energies)
end
