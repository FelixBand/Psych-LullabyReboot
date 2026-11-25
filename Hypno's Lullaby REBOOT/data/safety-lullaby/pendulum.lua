-- Safety Lullaby pendulum mechanic, ported from the Godot project:
--   scripts/lullaby/mechanics/safety_lullaby/lullaby_pendulum_server.gd  (hit logic, retention, rotation)
--   scripts/lullaby/mechanics/safety_lullaby/lullaby_pendulum.gd         (HUD + in-hand pendulum visuals)
--   resources/funkin/songs/global/mechanics/mch_pendulum.tscn            (HUD layout / animations)
--   resources/funkin/songs/safety_lullaby/characters/trance.gd            (GF trance pose + overlay)
--   songs/safety_lullaby/trance_shaders.gd                                (screen effects)
--   songs/safety_lullaby/sng_safety_lullaby.tscn                          (timeline: drop / start / y offset / ratio)
-- Press SPACE when the pendulum passes the centre (every half measure).
-- Needs Psych Engine 1.0+ and stages/alley.lua (it shares Hypno's light position through setVar).

-- ===== tunables ==========================================================================================
local KEYS = { 'SPACE' }
local FAITHFUL_START_MISS = true  -- the Godot server counts the first half-measure after start as a miss (start at 85)
local BABY_MODE = false           -- Godot "baby mode": the game presses for you at a random offset (no voice lines)
local HAND_SCALE = 1.25           -- Psych pixels per Godot Hypno-local unit (Hypno's json scale)
local TRANCE_GF_POSE = true       -- GF switches to the -hypno poses while retention <= 60

-- ===== Godot constants ===================================================================================
local HIT_WINDOW_MS = 75.0
local RETENTION_MAX = 100
local RETENTION_GAIN = 15
local RETENTION_LOSS = -15
local ROTATION_LENGTH = 0.825
local INITIAL_ROTATION = 0.8198507336215746 -- value left in the scene; the in-hand pendulum rests here until the mechanic starts

-- song timeline (seconds): { from, to }
local DROPPED = { { 31.933332, 160.0 } }
local STARTED = { { 33.733334, 159.08333 }, { 160.04167, 194.36667 } }
-- keyframes {time, value} (linear)
local Y_OFFSET_KEYS = { { 0, 0 }, { 37, 0 }, { 40.083332, 8 }, { 123.166664, 8 }, { 125.791664, 30 }, { 159.125, 30 }, { 159.83333, 0 } }
local LINEAR_RATIO_KEYS = { { 0, 0 }, { 124, 0 }, { 124.041664, 0.4 }, { 158.08333, 0.4 }, { 158.5, 0 } }

-- time changes: measure N starts at msStart; one measure lasts msPerMeasure
local TIME_CHANGES = {
	{ measure = 0, ms = 0, per = 4 * 60000 / 132 },
	{ measure = 18, ms = 18 * 4 * 60000 / 132, per = 4 * 60000 / 85 },
}
TIME_CHANGES[3] = { measure = 50, ms = TIME_CHANGES[2].ms + 32 * TIME_CHANGES[2].per, per = 3 * 60000 / 85 }
TIME_CHANGES[4] = { measure = 66, ms = TIME_CHANGES[3].ms + 16 * TIME_CHANGES[3].per, per = 4 * 60000 / 85 }

-- ===== HUD layout (Godot 1920x1080 units -> Psych 1280x720) ==============================================
local PS = 2 / 3
local HUD_CENTER_X = 640

-- ===== in-hand pendulum (Hypno) ==========================================================================
-- Godot positions are in Hypno-local units. Sprite node (-230, -538.46) + Pendulum control (-157.575, 175.805).
local HAND_ORIGIN_X, HAND_ORIGIN_Y = -230 + -157.575, -538.46154 + 175.805
local LIGHT_LOCAL_X, LIGHT_LOCAL_Y = 356.92307, -253.07693 -- Hypno's MainLight, used to line the units up with the port's light
local TRAIL_POS = { 10, -127 }
local BOB_LOCAL = { -0.9634635, 124.806694 }
local BOB_RADIUS = { 57.8, 81.4 } -- PointLight2D2 (pink glow on Hypno): radial gradient, black at 0.419 * 0.7071 of the texture
local BOB_COLOR = { 0.4, 0.4 * 0.4745098, 0.4 * 0.5176471 }

-- Pendulum anchor keyframes per Hypno pose, in the Pendulum control's local space: { frame (24fps), x, y }.
-- Extracted from hypno_world_LIBRARY.res. Poses on the left are the Psych animation names.
local P = {}
P['Idle Pose'] = { { 0, 741.0, 53.7 }, { 2, 745.0, 57.7 }, { 5, 743.0, 58.7 }, { 9, 740.16, 55.8 }, { 13, 739.16, 50.8 }, { 14, 737.16, 52.8 }, { 16, 733.16, 60.8 }, { 19, 735.16, 58.8 }, { 23, 738.16, 52.8 }, { 27, 741.16, 47.8 } }
P['AIdle'] = { { 0, 741.0, 55.7 }, { 2, 741.0, 52.7 }, { 3, 740.0, 48.7 }, { 7, 740.16, 44.8 }, { 12, 740.16, 45.8 }, { 14, 741.16, 53.8 }, { 18, 741.16, 59.8 }, { 24, 742.16, 60.8 }, { 27, 741.16, 57.8 } }
P['Left Pose'] = { { 0, 616.0, 4.7 }, { 2, 621.0, 10.7 }, { 4, 626.0, 8.7 }, { 7, 626.0, 7.7 } }
P['ALeft Pose'] = { { 0, 718.0, -27.3 }, { 2, 711.0, -27.3 }, { 8, 724.0, -27.3 } }
P['Right Pose'] = { { 0, 502.0, 23.7 }, { 2, 507.0, 21.7 }, { 4, 502.0, 20.7 }, { 7, 498.0, 15.7 } }
P['ARight Pose'] = { { 0, 480.0, 18.7 }, { 2, 479.0, 15.7 }, { 8, 475.0, 19.7 } }
P['Up Pose'] = { { 0, 536.0, 32.7 }, { 2, 543.0, 38.7 }, { 4, 548.0, 46.7 }, { 7, 549.0, 44.7 } }
P['AUp Pose'] = { { 0, 503.0, 106.7 }, { 2, 507.0, 106.7 }, { 8, 510.0, 110.7 } }
P['Down pose'] = { { 0, 479.0, 88.7 }, { 2, 471.0, 89.7 }, { 4, 470.0, 84.7 }, { 7, 471.0, 84.7 } }
P['ADown pose'] = { { 0, 488.0, -29.3 }, { 2, 487.0, -32.3 }, { 8, 486.0, -46.3 } }
P['Step'] = { { 0, 740.0, 47.7 }, { 2, 738.0, 45.7 }, { 5, 732.0, 48.7 }, { 8, 728.0, 58.7 }, { 12, 733.0, 61.7 }, { 17, 738.0, 58.7 }, { 20, 743.0, 49.7 }, { 24, 746.0, 50.7 } }
P['Laugh'] = { { 0, 481.0, 19.7 }, { 2, 481.0, 17.7 }, { 6, 479.0, 16.7 }, { 34, 479.0, 17.7 }, { 36, 476.0, 22.7 }, { 39, 482.0, 22.7 }, { 41, 485.0, 29.7 }, { 44, 498.0, 45.7 }, { 47, 492.0, 49.7 }, { 49, 487.0, 49.7 }, { 54, 485.0, 44.7 }, { 56, 473.0, 48.7 }, { 63, 457.0, 40.7 }, { 67, 453.0, 41.7 }, { 71, 436.0, 34.7 }, { 75, 436.0, 29.7 }, { 78, 446.0, 18.7 }, { 83, 464.0, 20.7 }, { 87, 472.0, 20.7 } }

-- Psych animation name -> pose track
local POSE_OF = {
	['idle-alt'] = 'Idle Pose', ['idle'] = 'AIdle',
	['singLEFT'] = 'Left Pose', ['singLEFT-alt'] = 'ALeft Pose',
	['singRIGHT'] = 'Right Pose', ['singRIGHT-alt'] = 'ARight Pose',
	['singUP'] = 'Up Pose', ['singUP-alt'] = 'AUp Pose',
	['singDOWN'] = 'Down pose', ['singDOWN-alt'] = 'ADown pose',
	['walk'] = 'Step', ['walk2'] = 'Step', ['laugh'] = 'Laugh',
}

-- ===== state =============================================================================================
local retention = RETENTION_MAX
local started, dropped = false, false
local rotation = INITIAL_ROTATION
local nextHitMs = 0.0
local pendulumIsHit = false
local pendulumMeasure = 0
local failed = false
local timePassed = 0.0
local babyNextHit = 0.0
local babyCooldown = 0.0

local hudDropT = nil         -- seconds since the HUD drop animation started (nil = not playing)
local hudShown = false
local hitT = 99              -- seconds since the last successful hit
local anchorX, anchorY = 0.0, 0.0

local tranceStrength = 0.0
local tranceAlpha = 0.0
local nullifyTrance = false
local filtersOn = false
local playingTrancePose = false

-- ===== helpers ===========================================================================================
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function lerp(a, b, t) return a + (b - a) * t end

local function inRanges(t, ranges)
	for _, r in ipairs(ranges) do
		if t >= r[1] and t < r[2] then return true end
	end
	return false
end

local function sampleKeys(keys, t)
	if t <= keys[1][1] then return keys[1][2] end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t < b[1] then
			return lerp(a[2], b[2], (t - a[1]) / (b[1] - a[1]))
		end
	end
	return keys[#keys][2]
end

local function measureAtMs(ms)
	local tc = TIME_CHANGES[1]
	for i = #TIME_CHANGES, 1, -1 do
		if ms >= TIME_CHANGES[i].ms then tc = TIME_CHANGES[i]; break end
	end
	return tc.measure + (ms - tc.ms) / tc.per, tc
end

local function updateHitTime(ms)
	local measure, tc = measureAtMs(ms)
	local nextMeasure = math.floor((measure + 0.5) / 0.5 + 0.5) * 0.5 -- snapped(measure + 0.5, 0.5)
	nextHitMs = tc.ms + tc.per * (nextMeasure - tc.measure)
	babyNextHit = nextHitMs + (math.random() * 300 - 150)
end

local function updateRotation(ms)
	local measure = measureAtMs(ms)
	local base = math.sin(measure * 2 * math.pi)
	local normal = (base + 1) / 2
	local ratio = sampleKeys(LINEAR_RATIO_KEYS, ms / 1000)
	local eased
	if normal < 0.5 then eased = 2 * normal * normal else eased = 1 - ((-2 * normal + 2) ^ 2) / 2 end
	local mixed = normal * ratio + eased * (1 - ratio)
	rotation = -(((mixed * 2) - 1) * ROTATION_LENGTH)
end

local function isHittable(ms)
	return math.abs(nextHitMs - ms) <= HIT_WINDOW_MS
end

local function hitPendulum(ms)
	pendulumIsHit = true
	local hittable = isHittable(ms)
	retention = clamp(retention + (hittable and RETENTION_GAIN or RETENTION_LOSS), 0, RETENTION_MAX)
	if hittable then
		hitT = 0
		setVar('pendulumTrailRotation', rotation)
	end
end

local function getPlaysAsBF()
	if type(_G.playsAsBF) == 'function' then
		local result = _G.playsAsBF()
		if result ~= nil then return result end
	end
	return true
end

-- ===== sprite setup ======================================================================================
local function makeHudSprite(tag, image, animated)
	if animated then
		makeAnimatedLuaSprite(tag, image, 0, 0)
	else
		makeLuaSprite(tag, image, 0, 0)
	end
	setObjectCamera(tag, 'hud')
	addLuaSprite(tag, false)
	setProperty(tag .. '.alpha', 0)
end

local function setupHud()
	makeHudSprite('pndTrail', 'safety_lullaby/pendulum_blurred', false)
	scaleObject('pndTrail', 1.25 * PS, 1.25 * PS, false)
	setProperty('pndTrail.origin.x', 79.5)
	setProperty('pndTrail.origin.y', 0)
	setBlendMode('pndTrail', 'add')

	makeHudSprite('pndActive', 'safety_lullaby/pendulum_active', false)
	scaleObject('pndActive', PS, PS, false)
	setProperty('pndActive.origin.x', 87)
	setProperty('pndActive.origin.y', 4.5)

	makeHudSprite('pndShine', 'safety_lullaby/pendulum_active', false)
	scaleObject('pndShine', PS, PS, false)
	setProperty('pndShine.origin.x', 87)
	setProperty('pndShine.origin.y', 4.5)
	setBlendMode('pndShine', 'add') -- Godot blend mode 7 = linear dodge

	makeHudSprite('pndHand', 'safety_lullaby/hand_drop_dark', true)
	scaleObject('pndHand', PS, PS, false)
	-- frame keys from the Godot "hand drop" animation: frame i shows the last key <= i
	local handKeys = { 0, 1, 2, 3, 5, 8, 10, 13 }
	local seq = {}
	for i = 0, 13 do
		local shown = 0
		for _, k in ipairs(handKeys) do if k <= i then shown = k end end
		seq[#seq + 1] = shown
	end
	addAnimationByIndices('pndHand', 'drop', 'hand', table.concat(seq, ','), 24, false)
	addAnimationByIndices('pndHand', 'still', 'hand', '21', 24, false)
	playAnim('pndHand', 'still', true)

	makeHudSprite('pndDrop', 'safety_lullaby/pendulum_drop', true)
	scaleObject('pndDrop', PS, PS, false)
	local dropKeys = { 0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 13, 14, 16, 19, 22, 26, 31 }
	local seq2 = {}
	for i = 0, 31 do
		local shown = 0
		for _, k in ipairs(dropKeys) do if k <= i then shown = k end end
		seq2[#seq2 + 1] = shown
	end
	addAnimationByIndices('pndDrop', 'drop', 'pendulum', table.concat(seq2, ','), 24, false)
end

local function setupHand()
	makeLuaSprite('pndHandTrail', 'safety_lullaby/hypno_pendulum_blurred', 0, 0)
	scaleObject('pndHandTrail', HAND_SCALE, HAND_SCALE, false)
	setProperty('pndHandTrail.origin.x', 46)
	setProperty('pndHandTrail.origin.y', -121.5)
	setProperty('pndHandTrail.alpha', 0)
	addLuaSprite('pndHandTrail', false)

	makeLuaSprite('pndHandActive', 'safety_lullaby/hypno_pendulum', 0, 0)
	scaleObject('pndHandActive', HAND_SCALE, HAND_SCALE, false)
	setProperty('pndHandActive.origin.x', 31)
	setProperty('pndHandActive.origin.y', 3.5)
	addLuaSprite('pndHandActive', false)
	-- the pendulum sprite is lit by its own PointLight2D (colour 0.75, 0.63, 0.65) in the Godot scene
	setProperty('pndHandActive.color', getColorFromHex('C0A1A7'))
end

local function placeHud(cx, cy, tag, w, h)
	setProperty(tag .. '.x', cx - w / 2)
	setProperty(tag .. '.y', cy - h / 2)
end

-- ===== trance (screen effects, overlay, GF) ==============================================================
local function setupTrance()
	initLuaShader('tranceEffects')
	makeLuaSprite('tranceController', '', 0, 0)
	runHaxeCode([[
		var sh = game.createRuntimeShader('tranceEffects');
		game.getLuaObject('tranceController').shader = sh;
		sh.setBitmapData('noiseTex', Paths.image('safety_lullaby/trance/water_noise').bitmap);
	]])

	makeAnimatedLuaSprite('tranceOverlay', 'safety_lullaby/trance/hypnosis', 10.8, -33.3)
	addAnimationByPrefix('tranceOverlay', 'default', 'hypnosis', 5, true)
	playAnim('tranceOverlay', 'default', true)
	scaleObject('tranceOverlay', 4 / 3, 4 / 3, false) -- frames are stored at half size
	setProperty('tranceOverlay.origin.x', 0)
	setProperty('tranceOverlay.origin.y', 0)
	setProperty('tranceOverlay.alpha', 0)
	setObjectCamera('tranceOverlay', 'other')
	addLuaSprite('tranceOverlay', true)
end

local function setFilters(on)
	if on == filtersOn then return end
	filtersOn = on
	if on then
		runHaxeCode([[
			var sh = game.getLuaObject('tranceController').shader;
			game.camGame.setFilters([new ShaderFilter(sh)]);
			game.camHUD.setFilters([new ShaderFilter(sh)]);
		]])
	else
		runHaxeCode([[
			game.camGame.setFilters([]);
			game.camHUD.setFilters([]);
		]])
	end
end

local function easeSine(t) return -(math.cos(math.pi * t) - 1) / 2 end
local function easeQuad(t) if t < 0.5 then return 2 * t * t end return 1 - ((-2 * t + 2) ^ 2) / 2 end

local function updateTrance(elapsed)
	local target = nullifyTrance and 0 or (RETENTION_MAX - retention) / RETENTION_MAX
	tranceStrength = lerp(tranceStrength, target, 1 - 0.2 ^ elapsed)

	local water = clamp(tranceStrength * 0.95, 0, 1)
	local wave = math.min(easeSine(water) * 0.95, 0.65)
	local ghost = math.min(easeQuad(water) * 0.25, 0.15)
	local saturation = 1 - tranceStrength * 0.275
	local contrast = 1 + tranceStrength * 0.04575
	local blur = tranceStrength * 0.135

	local active = tranceStrength > 0.002
	setFilters(active)
	if active then
		setShaderFloat('tranceController', 'uTime', timePassed)
		setShaderFloat('tranceController', 'uWave', wave)
		setShaderFloat('tranceController', 'uGhost', ghost)
		setShaderFloat('tranceController', 'uSaturation', saturation)
		setShaderFloat('tranceController', 'uContrast', contrast)
		setShaderFloat('tranceController', 'uBlur', blur)
	end

	-- overlay + GF pose (trance.gd)
	local inTrance = retention <= 60 and retention > 0
	local overlayTarget = 0
	if inTrance then overlayTarget = clamp((60 - retention) / 60 / 2, 0, 1) end
	tranceAlpha = lerp(tranceAlpha, overlayTarget, 1 - 0.2 ^ (elapsed * 2))
	setProperty('tranceOverlay.alpha', tranceAlpha)

	if TRANCE_GF_POSE and inTrance ~= playingTrancePose then
		playingTrancePose = inTrance
		setProperty('boyfriend.idleSuffix', inTrance and '-alt' or '') -- "hypnotised idle" is the idle-alt animation
		if getProperty('boyfriend.animation.curAnim.name') == 'idle' or getProperty('boyfriend.animation.curAnim.name') == 'idle-alt' then
			triggerEvent('Play Animation', inTrance and 'idle-alt' or 'idle', 'bf')
		end
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if not (TRANCE_GF_POSE and playingTrancePose) then return end
	local dirs = { 'singLEFT', 'singDOWN', 'singUP', 'singRIGHT' }
	triggerEvent('Play Animation', dirs[direction + 1] .. '-hypno', 'bf')
end

-- ===== in-hand pendulum placement ========================================================================
local function poseKey(animName, frame)
	local track = P[POSE_OF[animName] or 'Idle Pose'] or P['Idle Pose']
	local key = track[1]
	for _, k in ipairs(track) do
		if k[1] <= frame then key = k end
	end
	return key[2], key[3]
end

local function updateHand()
	local restX, restY = getVar('hypnoLightRestX'), getVar('hypnoLightRestY')
	if restX == nil then return end

	local k = HAND_SCALE
	local originX = getProperty('dad.x') + restX - LIGHT_LOCAL_X * k
	local originY = getProperty('dad.y') + restY - LIGHT_LOCAL_Y * k

	local animName = getProperty('dad.animation.curAnim.name') or 'idle'
	local frame = getProperty('dad.animation.curAnim.curFrame') or 0
	local ax, ay = poseKey(animName, frame)
	local px = originX + (HAND_ORIGIN_X + ax) * k
	local py = originY + (HAND_ORIGIN_Y + ay) * k

	setProperty('pndHandActive.x', px - 31)
	setProperty('pndHandActive.y', py - 3.5)
	setProperty('pndHandActive.angle', math.deg(rotation))

	local trailRot = getVar('pendulumTrailRotation') or 0
	local tx, ty = px + TRAIL_POS[1] * k, py + TRAIL_POS[2] * k
	setProperty('pndHandTrail.x', tx - 46)
	setProperty('pndHandTrail.y', ty + 121.5)
	setProperty('pndHandTrail.angle', math.deg(trailRot))
	local a = 0
	if hitT < 0.1667 then a = 0.49019608 elseif hitT < 0.6667 then a = 0.49019608 * (1 - (hitT - 0.1667) / 0.5) end
	setProperty('pndHandTrail.alpha', a)

	-- glow on Hypno that follows the pendulum bob (PointLight2D2, read by stages/alley.lua)
	local c, s = math.cos(rotation), math.sin(rotation)
	local bx = px + (BOB_LOCAL[1] * c - BOB_LOCAL[2] * s) * k
	local by = py + (BOB_LOCAL[1] * s + BOB_LOCAL[2] * c) * k
	setVar('pendulumBobX', bx)
	setVar('pendulumBobY', by)
	setVar('pendulumBobRX', BOB_RADIUS[1] * k)
	setVar('pendulumBobRY', BOB_RADIUS[2] * k)
	setVar('pendulumBobR', BOB_COLOR[1])
	setVar('pendulumBobG', BOB_COLOR[2])
	setVar('pendulumBobB', BOB_COLOR[3])
end

-- ===== HUD update ========================================================================================
local function updateHud(elapsed, ms)
	local t = ms / 1000
	local shouldDrop = inRanges(t, DROPPED)

	if shouldDrop and not hudShown then
		hudShown = true
		hudDropT = 0
		playAnim('pndHand', 'drop', true)
		playAnim('pndDrop', 'drop', true)
	elseif not shouldDrop and hudShown then
		hudShown = false
		hudDropT = nil
		playAnim('pndHand', 'still', true)
	end

	if not hudShown then
		for _, tag in ipairs({ 'pndTrail', 'pndActive', 'pndShine', 'pndHand', 'pndDrop' }) do
			setProperty(tag .. '.alpha', 0)
		end
		return
	end

	local anchorAlpha, activeAlpha, dropAlpha = 1, 1, 0
	if hudDropT ~= nil then
		hudDropT = hudDropT + elapsed
		anchorAlpha = clamp(hudDropT / 0.1666667, 0, 1)
		if hudDropT < 1.1666666 then
			activeAlpha, dropAlpha = 0, 1
		elseif hudDropT < 1.4583 then
			local f = (hudDropT - 1.1666666) / (1.4583 - 1.1666666)
			activeAlpha, dropAlpha = f, 1 - f
		else
			hudDropT = nil
		end
	end

	-- anchor bob (only while the mechanic is running, like _process in lullaby_pendulum.gd)
	if started then
		local measure = measureAtMs(ms)
		local strength = 4.0
		local nx = math.sin(measure * 2 * math.pi) * (strength * 0.75) + math.random() * 0.5
		local ny = math.cos(timePassed) * (strength * 0.8) + math.sin(timePassed) * (strength * 0.8)
		ny = ny + sampleKeys(Y_OFFSET_KEYS, t) + math.random() * 0.5
		local ratio = 1 - 0.1 ^ elapsed
		anchorX = lerp(anchorX, nx, ratio)
		anchorY = lerp(anchorY, ny, ratio)
	end

	local ax = HUD_CENTER_X + anchorX * PS
	local ay = anchorY * PS
	local angle = math.deg(rotation) -- pendulum_strength 4 -> factor 1
	local pivotX, pivotY = ax + 2 * PS, ay + 60 * PS

	setProperty('pndActive.x', pivotX - 87)
	setProperty('pndActive.y', pivotY - 4.5)
	setProperty('pndActive.angle', hudDropT ~= nil and 0 or angle)
	setProperty('pndShine.x', pivotX - 87)
	setProperty('pndShine.y', pivotY - 4.5)
	setProperty('pndShine.angle', hudDropT ~= nil and 0 or angle)

	setProperty('pndTrail.x', pivotX + 3 * PS - 79.5)
	setProperty('pndTrail.y', pivotY + 3 * PS)
	setProperty('pndTrail.angle', math.deg(getVar('pendulumTrailRotation') or 0))

	placeHud(ax + 0 * PS, ay - 76 * PS, 'pndHand', 310, 433)
	placeHud(ax + 36 * PS, ay + 227 * PS, 'pndDrop', 252, 624)

	hitT = hitT + elapsed
	local trailA, shineA = 0, 0
	if hitT < 0.05 then trailA = lerp(1, 0.49019608, hitT / 0.05)
	elseif hitT < 0.3 then trailA = lerp(0.49019608, 0, (hitT - 0.05) / 0.25) end
	if hitT < 0.16666667 then shineA = 0.39215687
	elseif hitT < 0.375 then shineA = 0.39215687 * (1 - (hitT - 0.16666667) / 0.20833333) end

	setProperty('pndHand.alpha', anchorAlpha)
	setProperty('pndDrop.alpha', anchorAlpha * dropAlpha)
	setProperty('pndActive.alpha', anchorAlpha * activeAlpha)
	setProperty('pndTrail.alpha', anchorAlpha * trailA)
	setProperty('pndShine.alpha', anchorAlpha * activeAlpha * shineA)
end

-- ===== server update =====================================================================================
local function pressed()
	for _, key in ipairs(KEYS) do
		if keyboardJustPressed(key) then return true end
	end
	return false
end

local function updateServer(elapsed, ms)
	local t = ms / 1000
	local nowStarted = inRanges(t, STARTED)

	if nowStarted ~= started then
		started = nowStarted
		if started then
			updateHitTime(ms)
			updateRotation(ms)
			if not FAITHFUL_START_MISS then pendulumMeasure = math.floor(measureAtMs(ms) * 2) end
		end
	end
	if not started then return end

	timePassed = timePassed + elapsed
	updateRotation(ms)

	if retention <= 0 then
		if not failed then
			failed = true
			nullifyTrance = true
			setProperty('health', 0) -- mechanic_failed -> health_depleted
		end
		return
	end

	local autoplay = getProperty('cpuControlled') or not getPlaysAsBF()
	local hittable = isHittable(ms)
	if hittable and not pendulumIsHit and autoplay then
		hitPendulum(ms)
	end

	-- baby mode: press automatically at a random offset unless the player interrupts
	if BABY_MODE and not autoplay then
		if babyCooldown > 0 then
			babyCooldown = babyCooldown - elapsed
		elseif not pendulumIsHit and ms >= babyNextHit then
			hitPendulum(ms)
		end
	end

	if not autoplay and pressed() and not pendulumIsHit then
		if BABY_MODE then babyCooldown = 3.0 end
		hitPendulum(ms)
	end

	local currentMeasure = math.floor(measureAtMs(ms) * 2)
	if pendulumMeasure ~= currentMeasure and not hittable then
		pendulumMeasure = currentMeasure
		if not pendulumIsHit then
			retention = clamp(retention + RETENTION_LOSS, 0, RETENTION_MAX)
		end
		pendulumIsHit = false
		updateHitTime(ms)
	end
end

-- ===== callbacks =========================================================================================
function onCreatePost()
	setupHud()
	setupHand()
	setupTrance()

	-- keep the in-hand pendulum above Hypno
	local order = getObjectOrder('dadGroup')
	setObjectOrder('pndHandTrail', order + 1)
	setObjectOrder('pndHandActive', order + 2)
end

function onUpdatePost(elapsed)
	local ms = getSongPosition()
	updateServer(elapsed, ms)
	updateHud(elapsed, ms)
	updateHand()
	updateTrance(elapsed)
end
