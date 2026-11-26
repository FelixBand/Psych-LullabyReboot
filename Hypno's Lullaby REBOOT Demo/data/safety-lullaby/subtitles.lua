-- Safety Lullaby flying lyrics, ported from songs/safety_lullaby/lyrics.gd and the
-- "play" animation in songs/safety_lullaby/sng_safety_lullaby.tscn.

local SCALE = 2/3 -- Godot 1920x1080 to Psych 1280x720
local SONG_TIME_OFFSET = 1.0 -- Godot timeline values read one second late in this port
local POSITION_OFFSET_X = 175 -- Psych pixels, applied to every subtitle
local POSITION_OFFSET_Y = 150 -- Psych pixels, applied to every subtitle
local LABEL_WIDTH = 1221 * SCALE
local FONT_SIZE = 80 -- Godot's 100px font scaled to Psych
local FONT_SIZE_ADJUSTMENT = 0.2
local FONT_SCALE = (FONT_SIZE + FONT_SIZE_ADJUSTMENT) / FONT_SIZE
local FADE_IN = 0.3
local FADE_OUT = 1.0
local DEFAULT_ALPHA = 127 / 255
local LAST_WAVE_CUE = 47
local WAVE_FREQUENCY = 3.5
local WAVE_AMPLITUDE = 70 / 10 * SCALE
local WAVE_LENGTH = 50
local ENDING_SHAKE_RATE = 35
local ENDING_SHAKE_AMPLITUDE = 15 / 10 * SCALE
local MEASURE_TAG = 'safetyLyricMeasure'
local ENDING_BOTTOM_MARGIN = 24

-- { time, y, text, color, alpha }; positions and text come from the source AnimationPlayer.
local CUES = {
	{ 33.625, 470, "Come little Girlfriend" },
	{ 35.125, 650, "Come with me" },
	{ 36.5, 470, "Your friend is waiting" },
	{ 37.833332, 650, "Steadily..." },
	{ 39.208332, 470, "The night has come" },
	{ 40.416668, 650, "What's left is me" },
	{ 42.208332, 470, "To show how happy" },
	{ 43.708332, 470, "You " },
	{ 44.25, 650, " can be." },
	{ 56.3, 470, "You and I" },
	{ 57.375, 650, "Yes, let us run..." },
	{ 58.666668, 470, "With Hypno" },
	{ 59.708332, 650, "You will have such" },
	{ 61.156487, 470, "fun!", "F98D97", 1 },
	{ 61.708332, 650, "Now come along" },
	{ 63.041668, 470, "Come, little one" },
	{ 64.458336, 650, "Just gaze into my" },
	{ 66.08333, 470, "PENDULUM...", "FF0065" },
	{ 78.66706, 470, "Now now, little Girlfriend", "FF0065" },
	{ 80.291664, 650, "Why do you fight me?", "FF0065" },
	{ 81.708336, 470, "Hypno only wants this", "FF0065" },
	{ 82.66668, 650, "night,", "FF0065" },
	{ 83.25, 470, "One night,", "FF0065" },
	{ 84.083336, 650, "please...", "FF0065" },
	{ 84.875, 470, "I mean no harm,", "FF0065" },
	{ 85.62499, 650, "No intention to be frightening,", "FF0065" },
	{ 87.083336, 470, "You'll find that the pendulum,", "FF0065" },
	{ 88.458336, 650, "Can be quite" },
	{ 89.291664, 470, "ENLIGHTENING...", "FF0065" },
	{ 101.541664, 470, "You prickle upon Hypno's resolve," },
	{ 103.125, 650, "Yes, it's true." },
	{ 104, 470, "As did your little friend," },
	{ 105.375, 650, "I spoke to him too." },
	{ 107, 470, "I led him away, far away," },
	{ 108.708336, 650, "He never knew..." },
	{ 109.583336, 470, "That Hypno ultimately led him," },
	{ 111.958336, 470, "To his..." },
	{ 112.791664, 650, "DOOM.", "FF0065" },
	{ 124.12015, 650, "So, little Girlfriend," },
	{ 125.833336, 650, "Please do not squirm," },
	{ 128.125, 470, "Soon now, it may be," },
	{ 130.125, 650, "You'll just have to learn:" },
	{ 132.25, 470, "That resisting the power" },
	{ 134.5, 650, "Of Hypno's great force," },
	{ 136.54167, 470, "Is the quickest of ways" },
	{ 138.20833, 650, "To know just" },
	{ 139.75, 534.345, "remorse..." },
	{ 159.95833, 3450, "And finally,", "FFFFFF", DEFAULT_ALPHA, 2.5, 395, true, 0 },
	{ 162.45833, 3450, "Now we're together,", "FFFFFF", DEFAULT_ALPHA, 3.75, 395, true, 0 },
	{ 166.25, 3450, "Your mind unraveling,", "FFFFFF", DEFAULT_ALPHA, 2.5, 395, true, 0 },
	{ 168.875, 3450, "At its seams...", "FFFFFF", DEFAULT_ALPHA, 2.0, 395, true, 0 },
	{ 171.20833, 3450, "You shall stay with me forever,", "FFFFFF", DEFAULT_ALPHA, 5.0, 395, true, 0 },
	{ 176.70833, 3450, "Allowing me,", "FFFFFF", DEFAULT_ALPHA, 1.75, 395, true, 0 },
	{ 178.58333, 3450, "To haunt,", "FFFFFF", DEFAULT_ALPHA, 1.75, 395, true, 0 },
	{ 180.33333, 3450, "Your,", "FFFFFF", DEFAULT_ALPHA, 1.4, 395, true, 0 },
	{ 181.58333, 3450, "DREAMS...", "FF0065", DEFAULT_ALPHA, 3.0, 395, true, 0 },
}

local active = {}
local spawned = {}
local nextTag = 0
local previousTime = nil

local function cueLifetime(cue)
	return cue[6] or 2.5
end

local function cueX(cue)
	return cue[7] or 168
end

local function cueCentered(cue)
	return cue[8] == true
end

local function cueTravelX(cue)
	return cue[9] == nil and 400 or cue[9]
end

local function measureText(text)
	setTextString(MEASURE_TAG, text)
	return getProperty(MEASURE_TAG .. '.textField.textWidth')
end

-- Keep each glyph's shake sequence independent without consuming Lua's global RNG.
local function shakeAngle(cueIndex, glyphIndex, step)
	if step <= 0 then
		return 0
	end
	local seed = cueIndex * 12.9898 + glyphIndex * 78.233 + step * 37.719
	local value = math.sin(seed) * 43758.5453
	return (value - math.floor(value)) * 2 * math.pi
end

local function getShakeOffset(cueIndex, glyphIndex, age)
	local step = math.floor(age * ENDING_SHAKE_RATE)
	local previousAngle = shakeAngle(cueIndex, glyphIndex, step - 1)
	local currentAngle = shakeAngle(cueIndex, glyphIndex, step)
	local stepTime = age - step / ENDING_SHAKE_RATE
	local blend = math.min(stepTime / (0.5 / ENDING_SHAKE_RATE), 1)
	local x = math.sin(previousAngle) + (math.sin(currentAngle) - math.sin(previousAngle)) * blend
	local y = math.cos(previousAngle) + (math.cos(currentAngle) - math.cos(previousAngle)) * blend
	return x * ENDING_SHAKE_AMPLITUDE, y * ENDING_SHAKE_AMPLITUDE
end

local function removeEntry(entry)
	if entry.glyphs then
		for _, glyph in ipairs(entry.glyphs) do
			removeLuaText(glyph.tag)
		end
	else
		removeLuaText(entry.tag)
	end
end

local function removeActive()
	for _, entry in ipairs(active) do
		removeEntry(entry)
	end
	active = {}
end

local function spawnCue(index, cue, age)
	nextTag = nextTag + 1
	local text = cue[3]
	local x = (cueX(cue) + cueTravelX(cue) * age / cueLifetime(cue)) * SCALE + POSITION_OFFSET_X
	local y = cue[2] * SCALE + POSITION_OFFSET_Y

	if index <= LAST_WAVE_CUE then
		local glyphs = {}
		local prefix = ''
		for charIndex = 1, #text do
			local char = text:sub(charIndex, charIndex)
			local offsetX = (measureText(prefix .. char) - measureText(char)) * FONT_SCALE
			local tag = 'safetyLyric' .. nextTag .. 'Char' .. charIndex
			makeLuaText(tag, char, 0, x + offsetX, y)
			setTextFont(tag, 'hypnosis.ttf')
			setTextSize(tag, FONT_SIZE)
			scaleObject(tag, FONT_SCALE, FONT_SCALE)
			setTextAlignment(tag, 'left')
			setTextBorder(tag, 0, '000000')
			setProperty(tag .. '.wordWrap', false)
			setProperty(tag .. '.autoSize', true)
			setProperty(tag .. '.color', getColorFromHex(cue[4] or 'FFFFFF'))
			setProperty(tag .. '.alpha', 0)
			setObjectCamera(tag, 'game')
			setScrollFactor(tag, 1, 1)
			addLuaText(tag)
			glyphs[#glyphs + 1] = { tag = tag, offsetX = offsetX }
			prefix = prefix .. char
		end
		active[#active + 1] = { index = index, glyphs = glyphs, cue = cue }
	else
		local glyphs = {}
		local prefix = ''
		local startX = (screenWidth - measureText(text) * FONT_SCALE) * 0.5
		for charIndex = 1, #text do
			local char = text:sub(charIndex, charIndex)
			local offsetX = (measureText(prefix .. char) - measureText(char)) * FONT_SCALE
			local tag = 'safetyLyric' .. nextTag .. 'Char' .. charIndex
			makeLuaText(tag, char, 0, startX + offsetX, 0)
			setTextFont(tag, 'hypnosis.ttf')
			setTextSize(tag, FONT_SIZE)
			scaleObject(tag, FONT_SCALE, FONT_SCALE)
			setTextAlignment(tag, 'left')
			setTextBorder(tag, 0, '000000')
			setProperty(tag .. '.wordWrap', false)
			setProperty(tag .. '.autoSize', true)
			setProperty(tag .. '.color', getColorFromHex(cue[4] or 'FFFFFF'))
			setProperty(tag .. '.alpha', 0)
			setObjectCamera(tag, 'other')
			setScrollFactor(tag, 0, 0)
			addLuaText(tag)
			setObjectOrder(tag, getObjectOrder('gfGroup') + 3)
			glyphs[#glyphs + 1] = { tag = tag, x = startX + offsetX, index = charIndex }
			prefix = prefix .. char
		end
		local overlayY = screenHeight - getProperty(glyphs[1].tag .. '.height') - ENDING_BOTTOM_MARGIN
		for _, glyph in ipairs(glyphs) do
			glyph.y = overlayY
			setProperty(glyph.tag .. '.y', overlayY)
		end
		active[#active + 1] = { index = index, glyphs = glyphs, cue = cue, shake = true }
	end
end

local function updateActive(songTime)
	for i = #active, 1, -1 do
		local entry = active[i]
		local cue = entry.cue
		local age = songTime - cue[1]
		local lifetime = cueLifetime(cue)
		if age >= lifetime then
			removeEntry(entry)
			table.remove(active, i)
		else
			local fadeIn = math.min(age / FADE_IN, 1)
			local fadeOut = math.min((lifetime - age) / FADE_OUT, 1)
			local x = (cueX(cue) + cueTravelX(cue) * age / lifetime) * SCALE + POSITION_OFFSET_X
			local y = cue[2] * SCALE + POSITION_OFFSET_Y
			local alpha = (cue[5] or DEFAULT_ALPHA) * fadeIn * fadeOut
			if entry.shake then
				for _, glyph in ipairs(entry.glyphs) do
					local shakeX, shakeY = getShakeOffset(entry.index, glyph.index, age)
					setProperty(glyph.tag .. '.x', glyph.x + shakeX)
					setProperty(glyph.tag .. '.y', glyph.y + shakeY)
					setProperty(glyph.tag .. '.alpha', alpha)
				end
			elseif entry.glyphs then
				for _, glyph in ipairs(entry.glyphs) do
					local phase = WAVE_FREQUENCY * age + glyph.offsetX / SCALE / WAVE_LENGTH
					setProperty(glyph.tag .. '.x', x + glyph.offsetX)
					setProperty(glyph.tag .. '.y', y + math.sin(phase) * WAVE_AMPLITUDE)
					setProperty(glyph.tag .. '.alpha', alpha)
				end
			else
				setProperty(entry.tag .. '.x', x)
				setProperty(entry.tag .. '.y', y)
				setProperty(entry.tag .. '.alpha', alpha)
			end
		end
	end
end

function onCreatePost()
	makeLuaText(MEASURE_TAG, '', LABEL_WIDTH, 0, 0)
	setTextFont(MEASURE_TAG, 'hypnosis.ttf')
	setTextSize(MEASURE_TAG, FONT_SIZE)
	setTextBorder(MEASURE_TAG, 0, '000000')
	setProperty(MEASURE_TAG .. '.wordWrap', false)
	setProperty(MEASURE_TAG .. '.alpha', 0)
	setObjectCamera(MEASURE_TAG, 'game')
	setScrollFactor(MEASURE_TAG, 1, 1)
	addLuaText(MEASURE_TAG)
end

function onSongStart()
	removeActive()
	spawned = {}
	previousTime = nil
end

function onUpdatePost()
	local songTime = (getSongPosition() or 0) / 1000 + SONG_TIME_OFFSET
	if previousTime ~= nil and songTime < previousTime then
		removeActive()
		spawned = {}
	end
	previousTime = songTime

	for i, cue in ipairs(CUES) do
		if not spawned[i] and songTime >= cue[1] then
			spawned[i] = true
			local age = songTime - cue[1]
			if age < cueLifetime(cue) then
				spawnCue(i, cue, age)
			end
		end
	end

	updateActive(songTime)
end
