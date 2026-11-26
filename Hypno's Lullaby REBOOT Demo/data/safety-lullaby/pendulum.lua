-- Safety Lullaby pendulum mechanic, ported from the Godot project:
--   scripts/lullaby/mechanics/safety_lullaby/lullaby_pendulum_server.gd  (hit logic, retention, rotation)
--   scripts/lullaby/mechanics/safety_lullaby/lullaby_pendulum.gd         (HUD + in-hand pendulum visuals)
--   resources/funkin/songs/global/mechanics/mch_pendulum.tscn            (HUD layout / animations)
--   resources/funkin/songs/safety_lullaby/characters/trance.gd            (GF trance pose + overlay)
--   songs/safety_lullaby/trance_shaders.gd                                (screen effects)
--   songs/safety_lullaby/sng_safety_lullaby.tscn                          (timeline: drop / start / y offset / ratio)
-- Press SPACE when the pendulum passes the centre (every half measure).
-- Needs Psych Engine 1.0+ and stages/alley.lua (it shares the pendulum bob glow with it through setVar).
--
-- Song events (add them in the chart editor, no custom_events file needed):
--   Pendulum Drop   value1: nothing = drop the HUD pendulum in, "hide" = hide it again
--   Pendulum Start  the mechanic starts (hits count, pendulum swings)
--   Pendulum Stop   the mechanic stops (pendulum eases back to straight)
--   Water Warp      value1: wave strength (0 - 2), value2: seconds to tween there (0 = instant). The SquiggleLayer.

-- ===== tunables ==========================================================================================
local KEYS = { 'SPACE' }
local FAITHFUL_START_MISS = true  -- the Godot server counts the first half-measure after start as a miss (start at 85)
local BABY_MODE = false           -- Godot "baby mode": the game presses for you at a random offset (no voice lines)
local HAND_SCALE = 1.25           -- Psych pixels per Godot Hypno-local unit (Hypno's json scale)
local TRANCE_GF_CHARACTER = 'gf-hypno' -- Change Character event fired at retention <= 60 (nil = never change)
local NORMAL_GF_CHARACTER = 'gf'
local GF_CHAR_TYPE = 'bf'            -- the character slot GF is in (she is the player in this port)

-- Everything from the Godot timeline (squiggle keys, y offset keys, ...) reads about 1 second late in Psych, so the
-- timeline is sampled this many seconds EARLIER. Set to 0 to disable. The chart events are placed already shifted.
local SONG_TIME_OFFSET = 1.0
local STOP_EASE = 0.75               -- seconds the pendulum takes to ease back to straight after Pendulum Stop

-- ===== Godot constants ===================================================================================
local HIT_WINDOW_MS = 75.0
local RETENTION_MAX = 100
local RETENTION_GAIN = 15
local RETENTION_LOSS = -15
local ROTATION_LENGTH = 0.825

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
-- Godot works in "Hypno-local" units. The port's sprite canvas (the 1000x778 xml frame) is Hypno-local + CANVAS.
-- Anchor (Hypno-local) = SPRITE[pose] + PENDULUM_NODE + key[pose][frame]
local CANVAS_X, CANVAS_Y = 446, 713
local PENDULUM_NODE_X, PENDULUM_NODE_Y = -157.575, 175.805
local TRAIL_POS = { 10, -127 }
local ENDING_HAND_SCALE = 1.0
local ENDING_ACTIVE_NODE_POS = { 3.1579895, -5.0881042 }
local ENDING_FRAME_CENTER = { 354, 303 }
local BOB_LOCAL = { -0.9634635, 124.806694 }
local BOB_RADIUS = { 57.8, 81.4 } -- PointLight2D2 (pink glow on Hypno): radial gradient, black at 0.419 * 0.7071 of the texture
local BOB_COLOR = { 0.4, 0.4 * 0.4745098, 0.4 * 0.5176471 }

-- Godot end-character pendulum anchors, keyed by animation frame. Sprite offsets are from the source scene.
local ENDING_HAND_POSES = {
	['idle'] = {
		spriteOffset = { 0, 106 },
		keys = { { 0, -142.708, 186.858 }, { 2, -143.15, 186.15 }, { 3, -142.94, 186.43 }, { 4, -143.27, 186.96 } }
	},
	['laugh'] = {
		spriteOffset = { 0, 106 },
		keys = {
			{ 0, -143.158, 187.088 }, { 1, -142, 187 }, { 2, -133.915, 185 }, { 3, -129.005, 188.035 },
			{ 4, -135.01, 187.175 }, { 5, -136.275, 184.83 }, { 6, -136.275, 181.775 }, { 7, -136.275, 183.41 },
			{ 8, -136.275, 182.775 }, { 9, -136.275, 183.41 }, { 10, -136.275, 183.775 }, { 11, -141.005, 179.49 },
			{ 12, -143.705, 179.71 }, { 13, -145.865, 183.885 }, { 15, -150.42, 178.885 }, { 16, -154.37, 175.805 },
			{ 17, -157.575, 175.805 }
		}
	},
	['singDOWN'] = {
		spriteOffset = { 7, 106 },
		keys = { { 0, -127, 181 }, { 1, -128, 184 }, { 2, -127, 186 }, { 3, -126, 185 } }
	},
	['singLEFT'] = {
		spriteOffset = { 9, 106 },
		keys = { { 0, -99, 246 }, { 1, -93, 240 }, { 2, -91, 236 }, { 3, -91, 239 } }
	},
	['singRIGHT'] = {
		spriteOffset = { -7, 106 },
		keys = { { 0, -144, 187 }, { 1, -147, 185 }, { 2, -150, 184 }, { 3, -148, 184 } }
	},
	['singUP'] = {
		spriteOffset = { 6, 106 },
		keys = { { 0, -127, 179 }, { 1, -125, 184 }, { 2, -126, 182 }, { 3, -125, 183 } }
	}
}

-- EASY TUNING: extra Psych-pixel adjustment per end-character animation, added after the source anchor.
local ENDING_HAND_ADJUST = {
	['idle'] = { 0, 0 },
	['laugh'] = { 0, 0 },
	['singDOWN'] = { 0, 0 },
	['singLEFT'] = { 0, 0 },
	['singRIGHT'] = { 0, 0 },
	['singUP'] = { 0, 0 }
}

-- EASY TUNING: extra offset in Psych pixels per dad animation name, added on top of the computed position
-- (+x right, +y down). Edit these by eye. Animations that are not listed get {0, 0}.
local HAND_ADJUST = {
	['idle'] = { 0, 22 },
	['singLEFT'] = { -5, 22 },
	['singDOWN'] = { 10, 22 },
	['singUP'] = { -8, 22 },
	['singRIGHT'] = { -8, 22 },
	['idle-alt'] = { 60, 22 },
	['singLEFT-alt'] = { 60, 22 },
	['singDOWN-alt'] = { 60, 22 },
	['singUP-alt'] = { 60, 22 },
	['singRIGHT-alt'] = { 60, 22 },
	['step'] = { 10, 22 },
	['laugh'] = { 0, 22 },
}

-- Hypno's body walks forward INSIDE the step sprites (his upper body is 54 canvas px further right in the last frame
-- than in the first; the idle-alt / sing-alt sprites are shifted by the same amount, which is the +56 in HAND_ADJUST).
-- The Godot anchor keys don't contain that walk, so it is added back: 0 = start of the step, 1 = fully stepped.
-- Measured from the Step frames of hypno.png (upper body centre per frame).
local STEP_PROGRESS = { 0, 0, 0.04, 0.04, 0.04, 0.17, 0.17, 0.17, 0.28, 0.28, 0.28, 0.28, 0.31, 0.31, 0.31, 0.31, 0.31, 0.43, 0.43, 0.43, 0.91, 0.91, 0.91, 0.91, 1, 1, 1 }
-- Total extra Psych pixels over the whole step. nil = automatic: whatever makes the last step frame land exactly where
-- idle-alt frame 0 starts (using HAND_ADJUST), so the pendulum never jumps when the step ends. Or set { x, y } by hand.
local STEP_TRAVEL = nil

-- Sprite node position per Hypno pose (hypno_world_LIBRARY.res, track ".:position")
local SPRITE = {
	['AIdle'] = { -229.23, -537.69 }, ['Idle Pose'] = { -230, -538.46 },
	['ALeft Pose'] = { -352.31, -557.69 }, ['Left Pose'] = { -388.46, -560 },
	['ARight Pose'] = { 32.31, -508.46 }, ['Right Pose'] = { 68.46, -510 },
	['AUp Pose'] = { -100, -672.31 }, ['Up Pose'] = { -106.15, -678.46 },
	['ADown pose'] = { -33.08, -433.85 }, ['Down pose'] = { -26.15, -432.31 },
	['Step'] = { -230, -538 }, ['Laugh'] = { 29.23, -510 },
}

-- Pendulum anchor keyframes per Hypno pose, in the Pendulum control's local space: { frame (24fps), x, y }.
-- Extracted from hypno_world_LIBRARY.res. A frame's key stays active until the next key (stepped).
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
P['Laugh'] = { { 0, 481.0, 19.7 }, { 2, 481.0, 17.7 }, { 6, 479.0, 16.7 }, { 34, 479.0, 17.7 }, { 36, 476.0, 22.7 }, { 39, 482.0, 22.7 }, { 41, 485.0, 29.7 }, { 44, 498.0, 45.7 }, { 47, 492.0, 49.7 }, { 49, 487.0, 49.7 }, { 51, 485.0, 44.7 }, { 54, 473.0, 48.7 }, { 56, 457.0, 40.7 }, { 59, 453.0, 41.7 }, { 63, 436.0, 34.7 }, { 68, 436.0, 29.7 }, { 72, 446.0, 18.7 }, { 75, 464.0, 20.7 }, { 78, 472.0, 20.7 } }

-- Psych animation name -> Godot pose (A* poses = the base animations, the others = the -alt ones)
local POSE_OF = {
	['idle-alt'] = 'Idle Pose', ['idle'] = 'AIdle',
	['singLEFT'] = 'ALeft Pose', ['singLEFT-alt'] = 'Left Pose',
	['singRIGHT'] = 'ARight Pose', ['singRIGHT-alt'] = 'Right Pose',
	['singUP'] = 'AUp Pose', ['singUP-alt'] = 'Up Pose',
	['singDOWN'] = 'ADown pose', ['singDOWN-alt'] = 'Down pose',
	['step'] = 'Step', ['laugh'] = 'Laugh',
}

-- ===== state =============================================================================================
local retention = RETENTION_MAX
local started = false
local rotation = 0.0               -- visual rotation (straight until the swing eases in)
local stopRotation, stopT = 0.0, 0.0 -- rotation when the mechanic stopped, seconds since then
local nextHitMs = 0.0
local pendulumIsHit = false
local pendulumMeasure = 0
local failed = false
local timePassed = 0.0               -- only runs while the mechanic is active (anchor bob)
local shaderTime = 0.0              -- free running, drives the water noise
local babyNextHit = 0.0
local babyCooldown = 0.0

local hudDropT = nil         -- seconds since the HUD drop animation started (nil = not playing)
local hudShown = false      -- set by the Pendulum Drop song event
local hitT = 99              -- seconds since the last successful hit
local anchorX, anchorY = 0.0, 0.0

local tranceStrength = 0.0
local tranceAlpha = 0.0
local nullifyTrance = false
local filtersOn = false
local gfHypnotised = false
local squiggle, squiggleFrom, squiggleTo, squiggleDur, squiggleT = 0.0, 0.0, 0.0, 0.0, 0.0

-- ===== helpers ===========================================================================================
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function lerp(a, b, t) return a + (b - a) * t end

local function hitTrailAlpha(timeSinceHit)
	if timeSinceHit < 0.05 then return lerp(1, 0.49019608, timeSinceHit / 0.05) end
	if timeSinceHit < 0.3 then return lerp(0.49019608, 0, (timeSinceHit - 0.05) / 0.25) end
	return 0
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

local function godotRotation(ms)
	local measure = measureAtMs(ms)
	local base = math.sin(measure * 2 * math.pi)
	local normal = (base + 1) / 2
	local ratio = sampleKeys(LINEAR_RATIO_KEYS, ms / 1000 + SONG_TIME_OFFSET)
	local eased
	if normal < 0.5 then eased = 2 * normal * normal else eased = 1 - ((-2 * normal + 2) ^ 2) / 2 end
	local mixed = normal * ratio + eased * (1 - ratio)
	return -(((mixed * 2) - 1) * ROTATION_LENGTH)
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

	-- "Water Warp" song event: linear tween of the SquiggleLayer wave strength
	if squiggleT < squiggleDur then
		squiggleT = squiggleT + elapsed
		squiggle = lerp(squiggleFrom, squiggleTo, clamp(squiggleT / squiggleDur, 0, 1))
	else
		squiggle = squiggleTo
	end

	local active = tranceStrength > 0.002 or squiggle > 0.001
	setFilters(active)
	if active then
		setShaderFloat('tranceController', 'uTime', shaderTime)
		setShaderFloat('tranceController', 'uWave', wave)
		setShaderFloat('tranceController', 'uGhost', ghost)
		setShaderFloat('tranceController', 'uSaturation', saturation)
		setShaderFloat('tranceController', 'uContrast', contrast)
		setShaderFloat('tranceController', 'uBlur', blur)
		setShaderFloat('tranceController', 'uSquiggle', squiggle)
		setShaderFloat('tranceController', 'uSquiggleGhost', 0.449)
	end

	-- overlay + GF (trance.gd)
	local inTrance = retention <= 60 and retention > 0
	local overlayTarget = 0
	if inTrance then overlayTarget = clamp((60 - retention) / 60 / 2, 0, 1) end
	tranceAlpha = lerp(tranceAlpha, overlayTarget, 1 - 0.2 ^ (elapsed * 2))
	setProperty('tranceOverlay.alpha', tranceAlpha)

	-- GF becomes the hypnotised character through a normal Change Character event
	if TRANCE_GF_CHARACTER and inTrance ~= gfHypnotised then
		gfHypnotised = inTrance
		triggerEvent('Change Character', GF_CHAR_TYPE, inTrance and TRANCE_GF_CHARACTER or NORMAL_GF_CHARACTER)
	end
end

-- ===== in-hand pendulum placement ========================================================================
local function handLocal(animName, frame)
	local pose = POSE_OF[animName] or 'Idle Pose'
	local track = P[pose]
	local key = track[1]
	for _, k in ipairs(track) do
		if k[1] <= frame then key = k end
	end
	local sprite = SPRITE[pose]
	return sprite[1] + PENDULUM_NODE_X + key[2], sprite[2] + PENDULUM_NODE_Y + key[3]
end

local function endingHandLocal(animName, frame)
	local pose = ENDING_HAND_POSES[animName] or ENDING_HAND_POSES['idle']
	local keys = pose.keys
	local x, y = keys[1][2], keys[1][3]
	for i = 1, #keys - 1 do
		local current, following = keys[i], keys[i + 1]
		if frame <= following[1] then
			local t = clamp((frame - current[1]) / (following[1] - current[1]), 0, 1)
			x = current[2] + (following[2] - current[2]) * t
			y = current[3] + (following[3] - current[3]) * t
			break
		end
		x, y = following[2], following[3]
	end
	return ENDING_FRAME_CENTER[1] + x - pose.spriteOffset[1],
		ENDING_FRAME_CENTER[2] + y - pose.spriteOffset[2]
end

-- Character-local -> Psych world, using FlxSprite's current x, offset, origin, and scale.
local function localToWorld(character, lx, ly)
	local cx, cy = lx, ly
	if character == 'dad' then
		cx, cy = lx + CANVAS_X, ly + CANVAS_Y
	end
	local ox, oy = getProperty(character .. '.origin.x'), getProperty(character .. '.origin.y')
	local sx, sy = getProperty(character .. '.scale.x'), getProperty(character .. '.scale.y')
	local x = getProperty(character .. '.x') - getProperty(character .. '.offset.x') + ox + (cx - ox) * sx
	local y = getProperty(character .. '.y') - getProperty(character .. '.offset.y') + oy + (cy - oy) * sy
	return x, y
end

local function stepTravel()
	if STEP_TRAVEL then return STEP_TRAVEL[1], STEP_TRAVEL[2] end
	local ax, ay = handLocal('idle-alt', 0)
	local sx, sy = handLocal('step', 9999)
	local a, st = HAND_ADJUST['idle-alt'], HAND_ADJUST['step']
	return (a[1] - st[1]) + HAND_SCALE * (ax - sx), (a[2] - st[2]) + HAND_SCALE * (ay - sy)
end

local lastHandEnding = false

local function updateHand()
	local ending = getVar('safetyLullabyEndingActive') == true
	local character = ending and 'gf' or 'dad'
	local animName = getProperty(character .. '.animation.curAnim.name') or 'idle'
	local frame = getProperty(character .. '.animation.curAnim.curFrame') or 0
	if ending ~= lastHandEnding then
		local handScale = ending and ENDING_HAND_SCALE or HAND_SCALE
		scaleObject('pndHandActive', handScale, handScale, false)
		scaleObject('pndHandTrail', handScale, handScale, false)
		lastHandEnding = ending
	end

	local px, py, activeX, activeY, k
	local handAlpha = 1
	if ending then
		local lx, ly = endingHandLocal(animName, frame)
		local adj = ENDING_HAND_ADJUST[animName] or { 0, 0 }
		lx, ly = lx + adj[1], ly + adj[2]
		px, py = localToWorld('gf', lx, ly)
		activeX, activeY = localToWorld('gf', lx + ENDING_ACTIVE_NODE_POS[1], ly + ENDING_ACTIVE_NODE_POS[2])
		k = ENDING_HAND_SCALE

		local songTime = (getSongPosition() or 0) / 1000 + SONG_TIME_OFFSET
		handAlpha = 1 - clamp((songTime - 188.91667) / (193.04167 - 188.91667), 0, 1)
	else
		local lx, ly = handLocal(animName, frame)
		px, py = localToWorld('dad', lx, ly)
		local adj = HAND_ADJUST[animName] or { 0, 0 }
		px, py = px + adj[1], py + adj[2]
		if animName == 'step' then
			local tx, ty = stepTravel()
			local p = STEP_PROGRESS[frame + 1] or 1
			px, py = px + tx * p, py + ty * p
		end
		activeX, activeY = px, py
		k = HAND_SCALE
	end

	setProperty('pndHandActive.x', activeX - 31)
	setProperty('pndHandActive.y', activeY - 3.5)
	setProperty('pndHandActive.angle', math.deg(rotation))
	setProperty('pndHandActive.alpha', handAlpha)

	local trailRot = getVar('pendulumTrailRotation') or 0
	local trailX, trailY = activeX + TRAIL_POS[1] * k, activeY + TRAIL_POS[2] * k
	setProperty('pndHandTrail.x', trailX - 46)
	setProperty('pndHandTrail.y', trailY + 121.5)
	setProperty('pndHandTrail.angle', math.deg(trailRot))
	setProperty('pndHandTrail.alpha', hitTrailAlpha(hitT) * handAlpha)

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
		ny = ny + sampleKeys(Y_OFFSET_KEYS, t + SONG_TIME_OFFSET) + math.random() * 0.5
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

	local trailA = hitTrailAlpha(hitT)
	local shineA = 0
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

local function startMechanic(ms)
	started = true
	updateHitTime(ms)
	if not FAITHFUL_START_MISS then pendulumMeasure = math.floor(measureAtMs(ms) * 2) end
end

local function updateServer(elapsed, ms)
	hitT = hitT + elapsed

	-- swings straight away when started, eases back to straight when stopped
	if started then
		rotation = godotRotation(ms)
		stopRotation, stopT = rotation, 0.0
	else
		stopT = stopT + elapsed
		local k = clamp(stopT / STOP_EASE, 0, 1)
		rotation = stopRotation * (1 - k * k * (3 - 2 * k))
	end

	if not started then return end

	timePassed = timePassed + elapsed

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
function onEvent(name, value1, value2)
	local ms = getSongPosition()
	if name == 'Pendulum Drop' then
		if value1 == 'hide' then
			hudShown = false
			hudDropT = nil
			playAnim('pndHand', 'still', true)
		else
			hudShown = true
			hudDropT = 0
			playAnim('pndHand', 'drop', true)
			playAnim('pndDrop', 'drop', true)
		end
	elseif name == 'Pendulum Start' then
		startMechanic(ms)
	elseif name == 'Pendulum Stop' then
		started = false
	elseif name == 'Water Warp' then
		squiggleFrom = squiggle
		squiggleTo = tonumber(value1) or 0
		squiggleDur = math.max(tonumber(value2) or 0, 0)
		squiggleT = 0
		if squiggleDur <= 0 then squiggle = squiggleTo end
	end
end

function onCreatePost()
	if TRANCE_GF_CHARACTER then addCharacterToList(TRANCE_GF_CHARACTER, GF_CHAR_TYPE == 'bf' and 'boyfriend' or 'girlfriend') end
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
	shaderTime = shaderTime + elapsed
	updateServer(elapsed, ms)
	updateHud(elapsed, ms)
	updateHand()
	updateTrance(elapsed)
end
