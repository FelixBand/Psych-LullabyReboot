-- Half-rate hold-note jitter for current Psych Online (0.14.8+).
--
-- Why the old noAnimation trick stopped working: since the "sustain anim fix", every hold piece that
-- plays an animation also sets char.sustainTimer (1.25 steps), and Character.update() then pins the
-- sing pose to frame 0 for as long as that timer runs. That freeze overrides the restart pacing the
-- noAnimation flags create. So this script does both halves of the job:
--   1. flags all but every Nth piece of each hold as noAnimation (what your old script did), and
--   2. zeroes sustainTimer after each hold piece, so the engine's freeze doesn't fight it.

local PLAY_EVERY = 2          -- 2 = half as fast, 3 = a third, 1 = vanilla restart rate (keep <= 4)
local AFFECT_OPPONENT = true
local AFFECT_PLAYER = true
local DISABLE_ENGINE_HOLD_FREEZE = true   -- the sustainTimer part; set false to keep the engine's frozen-pose holds
local DEBUG = false            -- prints a few lines to the console so we can see what is really happening

local debugHits = 0

function onCreatePost()
    local count = {}   -- hold pieces seen so far in the hold currently running on each lane
    local total = getProperty('unspawnNotes.length')
    local sustains, flagged = 0, 0

    for i = 0, total - 1 do
        local must = getPropertyFromGroup('unspawnNotes', i, 'mustPress')
        local lane = getPropertyFromGroup('unspawnNotes', i, 'noteData') + (must and 4 or 0)

        if not getPropertyFromGroup('unspawnNotes', i, 'isSustainNote') then
            count[lane] = 0                       -- a new note head starts a new hold
        else
            sustains = sustains + 1
            if (must and AFFECT_PLAYER) or (not must and AFFECT_OPPONENT) then
                count[lane] = (count[lane] or 0) + 1
                -- piece 1 plays, then every PLAY_EVERY-th piece plays; the rest don't touch the animation
                if (count[lane] - 1) % PLAY_EVERY ~= 0 then
                    setPropertyFromGroup('unspawnNotes', i, 'noAnimation', true)
                    flagged = flagged + 1
                end
            end
        end
    end

    if DEBUG then
        debugPrint('[half_hold_jitter] notes: ' .. total .. ', hold pieces: ' .. sustains .. ', flagged noAnimation: ' .. flagged)
        if total > 0 then
            debugPrint('[half_hold_jitter] read-back check, note 0 noAnimation = ' .. tostring(getPropertyFromGroup('unspawnNotes', 0, 'noAnimation')))
        end
    end
end

-- charTag is 'dad', 'boyfriend', 'gf' or 'characters[<id>]' (online), straight from the engine.
local function afterHoldPiece(id, isSus, charTag)
    if not isSus then return end
    if getPropertyFromGroup('notes', id, 'gfNote') then charTag = 'gf' end

    local skipped = getPropertyFromGroup('notes', id, 'noAnimation')
    -- if DISABLE_ENGINE_HOLD_FREEZE then
    --     setProperty(charTag .. '.sustainTimer', 0)
    -- end
    if skipped then
        setProperty(charTag .. '.holdTimer', 0)   -- skipped pieces skip the engine's holdTimer reset; keep the pose alive
    end

    if DEBUG and debugHits < 8 then
        debugHits = debugHits + 1
        debugPrint('[half_hold_jitter] hold piece on ' .. charTag .. ': noAnimation=' .. tostring(skipped))
    end
end

function opponentNoteHit(id, dir, noteType, isSus, charTag) afterHoldPiece(id, isSus, charTag or 'dad') end
function goodNoteHit(id, dir, noteType, isSus, charTag) afterHoldPiece(id, isSus, charTag or 'boyfriend') end