local sceneScale = (2 / 3) * 1.3333333
local sceneOffsetX = -216
local sceneOffsetY = -23
local cloudSpeed = -25 * sceneScale
local cloudWidth = 1848 * 2.25 * sceneScale
local hypnoLightScale = 2 * 1.25 * sceneScale
local hypnoLightWidth = 195 * hypnoLightScale
local hypnoLightHeight = 290 * hypnoLightScale

local clouds = { 'SafetyClouds', 'SafetyClouds2' }
local lightTags = { 'SafetyBgLight', 'SafetyPoleGlow', 'SafetyPoleLight', 'SafetyPoleLight2' }
local healthTracked = 2
local timePassed = 0
local flickerTimer = 0
local flickerActive = false

local function addStageSprite(tag, image, x, y, width, height, scale, scrollX, scrollY)
	local finalScale = scale * sceneScale
	local finalX = (x + sceneOffsetX) * sceneScale - width * finalScale * 0.5
	local finalY = (y + sceneOffsetY) * sceneScale - height * finalScale * 0.5

	makeLuaSprite(tag, 'safety_lullaby/alley/' .. image, finalX, finalY)
	scaleObject(tag, finalScale, finalScale)
	setScrollFactor(tag, scrollX, scrollY)
	addLuaSprite(tag, false)
end

local function setLightAlpha(energy)
	setProperty('SafetyPoleGlow.alpha', math.max(energy, 0.1) * 0.2)
	setProperty('SafetyPoleLight.alpha', energy * 0.35)
	setProperty('SafetyPoleLight2.alpha', energy * 0.3)
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

	addStageSprite('SafetyMountain', 'mountain', 1523, 126, 1140, 358, 2.25, 0.8, 0.8)
	addStageSprite('SafetyStreet', 'street', 936, 968, 1808, 397, 2.2, 1, 1)
	addStageSprite('SafetyTrees', 'trees', 854, 155, 1606, 541, 2.2, 1, 1)
	addStageSprite('SafetyFence', 'longfence', 1715, 532, 1117, 172, 2.2, 1, 1)
	addStageSprite('SafetyBench', 'bench', 1518, 722, 259, 118, 2.11864, 1, 1)
	addStageSprite('SafetyPokecenter', 'pokecenter', 414, 415, 529, 475, 2.2, 1, 1)
	addStageSprite('SafetyLamp1', 'lamp1', 2051.69, 214, 123, 568, 2.15141, 1, 1)
	addStageSprite('SafetyLamp2', 'lampoff', 1063, 253, 88, 523, 2.2, 1, 1)
	addStageSprite('SafetyBrokenLamp', 'lampbroken', -231, 603, 94, 202, 2.2, 1, 1)
	addStageSprite('SafetyBgLight', 'darkness_gradient', 801, 449, 1049, 480, 4, 1, 1)

	addStageSprite(
		'SafetyPoleGlow', 'post_light_gradient',
		2051.69 + 5.7219 * 2.15141, 214 - 210.095 * 2.15141,
		202, 114, 0.464811 * 2 * 2.15141, 1, 1
	)
	addStageSprite(
		'SafetyPoleLight', 'awesomeahhlight',
		2051.69 + 134.00978 * 2.15141, 214 + 105.51219 * 2.15141,
		921, 681, 0.928031 * 2.15141, 1, 1
	)
	addStageSprite(
		'SafetyPoleLight2', 'awesomeahhlight',
		2051.69 + 185.60388 * 2.15141, 214 + 41.183647 * 2.15141,
		921, 681, 1.3687 * 2.15141, 1, 1
	)

	makeLuaSprite(
		'HypnoLightMask',
		'safety_lullaby/characters/hypno_world/chr_hypno_sl_light',
		0, 0
	)
	scaleObject('HypnoLightMask', hypnoLightScale, hypnoLightScale)
	setScrollFactor('HypnoLightMask', 1, 1)
	setBlendMode('HypnoLightMask', 'add')
	setProperty('HypnoLightMask.alpha', 0.18)
	addLuaSprite('HypnoLightMask', true)

	for _, tag in ipairs(lightTags) do
		setBlendMode(tag, 'add')
	end
	setProperty('SafetyBgLight.alpha', 0.75)
	setLightAlpha(0.8)
end

function onCreatePost()
	local lightOrder = math.max(getObjectOrder('boyfriendGroup'), getObjectOrder('dadGroup')) + 1
	for _, tag in ipairs(lightTags) do
		setObjectOrder(tag, lightOrder)
		lightOrder = lightOrder + 1
	end
	setObjectOrder('HypnoLightMask', lightOrder)
end

function onUpdatePost()
	setProperty('HypnoLightMask.x', getMidpointX('dad') - hypnoLightWidth * 0.5)
	setProperty('HypnoLightMask.y', getMidpointY('dad') - hypnoLightHeight * 0.5)
end

function onUpdate(elapsed)
	timePassed = timePassed + elapsed

	for _, tag in ipairs(clouds) do
		local cloudX = getProperty(tag .. '.x') + cloudSpeed * elapsed
		if cloudX < -cloudWidth then
			cloudX = cloudX + cloudWidth * 2
		end
		setProperty(tag .. '.x', cloudX)
	end

	local health = getProperty('health') or 2
	healthTracked = healthTracked + (health - healthTracked) * math.min(20 * elapsed, 1)
	local healthProgress = math.max(0, math.min(healthTracked / 2, 1))

	local lightStrength = 1 - (1 - healthProgress) ^ 3
	local pulse = math.sin(timePassed * math.pi)
	local energy = math.max((0.8 * lightStrength) + (pulse * 0.04) - 0.04, 0)
	local canFlicker = true
	local preferenceFound, flashingEnabled = pcall(function()
		return getPropertyFromClass('ClientPrefs', 'flashing')
	end)
	if preferenceFound and flashingEnabled == false then
		canFlicker = false
	end

	if flickerActive then
		flickerTimer = flickerTimer + elapsed
		if flickerTimer < 0.083 then
			energy = math.max(((lightStrength - 0.04) * 0.8) - 0.1, 0.1)
		elseif flickerTimer < 0.166 then
			energy = 0.8
		else
			flickerActive = false
		end
	elseif canFlicker then
		local flickerChance = 0.05 + ((1 - healthProgress) * 2.5)
		if math.random() * 100 < flickerChance then
			flickerActive = true
			flickerTimer = 0
			energy = math.max(((lightStrength - 0.04) * 0.8) - 0.1, 0.1)
		end
	end

	setLightAlpha(energy)
end
