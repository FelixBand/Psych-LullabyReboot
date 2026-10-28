-- Recolors every strum and note to one flat colour (and back), for the blood section of Monochrome.
--   setHudColors('000000')  -> black strums/notes (use while the background behind them is red)
--   setHudColors('FF0000')  -> red strums/notes   (use while it is black)
--   setHudColors(nil)       -> vanilla colours again
-- Also usable as an event: name "Hud Colors", value 1 = hex colour (or "off").
-- Notes spawned while a colour is active are recoloured as they spawn.
--
-- Notes are colour-coded by Psych's RGB shader (fill/highlight/outline each get a channel), so giving all three
-- channels the same colour makes the whole note one flat colour. Strums get that plus a plain tint, because
-- their idle frame is drawn without the RGB shader.

local active = nil          -- FlxColor int while a colour is on
local original = {}         -- original strum palette per strum index
local STRUM_COUNT = 8

local function strumIndex(noteData, mustPress)
    return noteData + (mustPress and 4 or 0)
end

local function paintObject(path, c)
    setProperty(path .. '.rgbShader.r', c)
    setProperty(path .. '.rgbShader.g', c)
    setProperty(path .. '.rgbShader.b', c)
end

local function paintNote(index)
    local data = getPropertyFromGroup('notes', index, 'noteData')
    local must = getPropertyFromGroup('notes', index, 'mustPress')
    local path = 'notes.members[' .. index .. ']'
    if active ~= nil then
        paintObject(path, active)
    else
        local o = original[strumIndex(data, must)]
        if o then
            setProperty(path .. '.rgbShader.r', o.r)
            setProperty(path .. '.rgbShader.g', o.g)
            setProperty(path .. '.rgbShader.b', o.b)
        end
    end
end

function setHudColors(hex)
    if hex == nil or hex == 'off' or hex == '' then
        active = nil
    else
        active = getColorFromHex(hex)
    end

    for i = 0, STRUM_COUNT - 1 do
        local path = 'strumLineNotes.members[' .. i .. ']'
        if active ~= nil then
            paintObject(path, active)
            setProperty(path .. '.color', active)
        else
            local o = original[i]
            if o then
                setProperty(path .. '.rgbShader.r', o.r)
                setProperty(path .. '.rgbShader.g', o.g)
                setProperty(path .. '.rgbShader.b', o.b)
            end
            setProperty(path .. '.color', 0xFFFFFFFF)
        end
    end

    for i = 0, getProperty('notes.length') - 1 do
        paintNote(i)
    end
end

function onCreatePost()
    for i = 0, STRUM_COUNT - 1 do
        local path = 'strumLineNotes.members[' .. i .. ']'
        original[i] = {
            r = getProperty(path .. '.rgbShader.r'),
            g = getProperty(path .. '.rgbShader.g'),
            b = getProperty(path .. '.rgbShader.b'),
        }
    end
end

-- the newest note is always at index 0 of the notes group (Psych Online passes 0 as the index as well)
function onSpawnNote(index)
    if active ~= nil then paintNote(0) end
end

function onEvent(name, v1)
    if name == 'Hud Colors' then setHudColors(v1) end
end
