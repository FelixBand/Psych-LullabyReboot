-- Forces shaders on even if the player disabled them in Options > Graphics ("Shaders" checkbox).
--
-- Why this works (Psych Engine 1.0 and Psych Online use the same checks): every shader entry point asks
-- ClientPrefs.data.shaders - PlayState.createRuntimeShader / initLuaShader and the Lua initLuaShader / setSpriteShader
-- return a blank shader or false when it is off - and each Lua script gets its `shadersEnabled` global copied from it
-- when the script loads. Files in the mod's scripts/ folder load before the stage and song scripts, so flipping the
-- pref at the top of this file (not inside a callback) makes everything loaded afterwards see shaders as enabled.
--
-- The pref is only changed in memory for the duration of the song and put back in onDestroy, so the player's saved
-- setting is never overwritten.

local originalValue = true

local function setShaderPref(value)
	runHaxeCode('ClientPrefs.data.shaders = ' .. tostring(value) .. ';')
end

if not shadersEnabled then
	originalValue = false
	setShaderPref(true)
	shadersEnabled = true -- this script's own copy
	debugPrint('forceShaders: shaders were disabled in the options, forced on for this song')
end

function onCreate()
	-- in case anything reset it during loading
	if originalValue == false then setShaderPref(true) end
end

function onDestroy()
	if originalValue == false then setShaderPref(false) end
end
