-- Hold-note sing-animation retrigger (prototype) for Psych Online / Psych Engine 1.0.x.
--
-- Hold pieces no longer animate the character at all. Instead, when a hold's head note is hit, a "session"
-- starts and re-plays that sing animation every INTERVAL_STEPS steps until the hold ends, so the jitter rate
-- is yours to pick (vanilla = 1 step, the old half-rate trick = 2 steps).
--
-- Dropped holds: the engine still calls opponentNoteHit/goodNoteHit once per hold piece that is really hit,
-- so a session stays alive only while pieces keep arriving. It ends when
--   * the hold's length is over, or
--   * no piece has been hit for TIMEOUT_STEPS steps (player released/missed, or an online opponent dropped it), or
--   * noteMiss fires for that lane.
-- The same logic covers the player, the CPU opponent and human opponents/other players online.

local INTERVAL_STEPS = 1.425    -- how often the sing animation restarts, in steps. 1 = vanilla, 2 = half speed
local TIMEOUT_STEPS  = 2.0    -- stop retriggering if no hold piece was hit for this long
local AFFECT_OPPONENT = true
local AFFECT_PLAYER   = true
local DEBUG = false

local FALLBACK_ANIMS = {'singLEFT', 'singDOWN', 'singUP', 'singRIGHT'}
local sessions = {}   -- key: charTag .. '#' .. lane

local function stepMs()
    local ok, v = pcall(getPropertyFromClass, 'backend.Conductor', 'stepCrochet')
    if ok and type(v) == 'number' and v > 0 then return v end
    return stepCrochet
end

local function sessionKey(charTag, dir) return charTag .. '#' .. dir end

local function currentAnim(charTag, dir)
    local name = getProperty(charTag .. '.animation.curAnim.name')
    if name == nil or name == '' or name:sub(1, 4) ~= 'sing' then
        name = FALLBACK_ANIMS[dir + 1] or 'singUP'
    end
    return name
end

-- Notes that are already noAnimation (chart/noteType "No Animation" etc.) must stay silent: a hold is skipped
-- if its head note is noAnimation, or is a 'Hey!' note. Heads are never flagged by this script, so the head's
-- flag is always the original one; pieces ask their parent head.
local function isSilent(group, id, isSus)
    local ok, v = pcall(getPropertyFromGroup, group, id, isSus and 'parent.noAnimation' or 'noAnimation')
    if not ok or v == nil then return not isSus and false or true end   -- can't tell for a piece: stay silent
    return v == true
end

-- every hold piece is flagged, so the engine never touches the animation (or sustainTimer) for pieces
function onCreatePost()
    local total = getProperty('unspawnNotes.length')
    local flagged = 0
    for i = 0, total - 1 do
        if getPropertyFromGroup('unspawnNotes', i, 'isSustainNote') and not isSilent('unspawnNotes', i, true) then
            local must = getPropertyFromGroup('unspawnNotes', i, 'mustPress')
            if (must and AFFECT_PLAYER) or (not must and AFFECT_OPPONENT) then
                setPropertyFromGroup('unspawnNotes', i, 'noAnimation', true)
                flagged = flagged + 1
            end
        end
    end
    if DEBUG then debugPrint('[hold_retrigger] hold pieces flagged noAnimation: ' .. flagged) end
end

local function onHit(id, dir, noteType, isSus, charTag, isPlayerSide)
    if (isPlayerSide and not AFFECT_PLAYER) or (not isPlayerSide and not AFFECT_OPPONENT) then return end
    if noteType == 'Hey!' or isSilent('notes', id, isSus) then
        sessions[sessionKey(charTag, dir)] = nil
        return
    end
    if getPropertyFromGroup('notes', id, 'gfNote') then charTag = 'gf' end

    local now = getSongPosition()
    local key = sessionKey(charTag, dir)
    local s = sessions[key]

    if not isSus then
        -- head note: the engine just played the sing animation itself
        local len = getPropertyFromGroup('notes', id, 'sustainLength') or 0
        if len > 0 then
            sessions[key] = {
                tag = charTag, dir = dir, anim = currentAnim(charTag, dir),
                lastPiece = now, nextPlay = now + INTERVAL_STEPS * stepMs(),
                endTime = getPropertyFromGroup('notes', id, 'strumTime') + len,
            }
            if DEBUG then debugPrint('[hold_retrigger] start ' .. key .. ' len=' .. len) end
        else
            sessions[key] = nil
        end
    else
        if s == nil then
            -- head was missed/late but pieces are being hit: pick the hold up from here
            s = {tag = charTag, dir = dir, anim = FALLBACK_ANIMS[dir + 1] or 'singUP',
                 nextPlay = now + INTERVAL_STEPS * stepMs()}
            sessions[key] = s
        end
        s.lastPiece = now
        -- pieces skip the engine's holdTimer reset (noAnimation), so keep the pose from timing out
        setProperty(charTag .. '.holdTimer', 0)
    end
end

function opponentNoteHit(id, dir, noteType, isSus, charTag) onHit(id, dir, noteType, isSus, charTag or 'dad', false) end
function goodNoteHit(id, dir, noteType, isSus, charTag) onHit(id, dir, noteType, isSus, charTag or 'boyfriend', true) end

function noteMiss(id, dir, noteType, isSus, charTag)
    sessions[sessionKey(charTag or 'boyfriend', dir)] = nil
    sessions[sessionKey('gf', dir)] = nil   -- a missed "GF Sing" hold reports the player's tag, but animates gf
end

function onUpdate(elapsed)
    if next(sessions) == nil then return end
    local now = getSongPosition()
    local step = stepMs()
    local interval = INTERVAL_STEPS * step

    for key, s in pairs(sessions) do
        local finished = (s.endTime ~= nil and now >= s.endTime)
        local dropped = (now - s.lastPiece) > TIMEOUT_STEPS * step
        if finished or dropped then
            sessions[key] = nil
            if DEBUG then debugPrint('[hold_retrigger] end ' .. key .. (finished and ' (finished)' or ' (dropped)')) end
        elseif now >= s.nextPlay then
            playAnim(s.tag, s.anim, true)
            setProperty(s.tag .. '.holdTimer', 0)
            s.nextPlay = s.nextPlay + interval
            if s.nextPlay < now then s.nextPlay = now + interval end   -- lag/seek: don't burst-catch-up
        end
    end
end

-- restarting the song / seeking backwards: drop stale sessions
function onSongStart() sessions = {} end

function onEvent(name, value1, value2)
    if name == 'Change Jitter Interval' then
        INTERVAL_STEPS = tonumber(value1)
    end
end