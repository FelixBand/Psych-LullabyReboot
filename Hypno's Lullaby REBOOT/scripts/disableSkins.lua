-- Force-disables ALL skins (yours and other players'), client side only.
-- Put in  scripts/  (global), NOT in data/<song>/.
-- Set SHOW_DEBUG = false once it works to hide the on-screen log.
local SHOW_DEBUG = false

local lines = {}
local function log(s)
    lines[#lines + 1] = tostring(s)
    if SHOW_DEBUG then
        setTextString('nsDebug', table.concat(lines, '\n'))
    end
end

local hiddenSids = {}

-- Runs the Haxe statements one by one (each run = all previous steps + the next one).
-- A step that errors makes runHaxeCode return nil, so we can tell exactly which one broke.
local function runSteps(sid, steps)
    local code = [[
        import online.GameClient;
    ]]
    for i, step in ipairs(steps) do
        code = code .. step[2] .. '\n'
        local r = runHaxeCode(code .. "'ok';")
        if r ~= 'ok' then
            return false, 'step ' .. i .. ' (' .. step[1] .. ') failed'
        end
    end
    return true, 'all steps ok'
end

function onCreate()
    if SHOW_DEBUG then
        makeLuaText('nsDebug', '', 1200, 10, 10)
        setTextSize('nsDebug', 18)
        setTextAlignment('nsDebug', 'left')
        setTextBorder('nsDebug', 2, '000000')
        setObjectCamera('nsDebug', 'other')
        addLuaText('nsDebug')
    end
    log('[noskins] onCreate ran')

    -- 1) your own saved skin (offline); proven working
    local r1 = runHaxeCode([[
        import backend.ClientPrefs;
        game.variables.set('__savedSkin', ClientPrefs.data.currentSkin);
        ClientPrefs.data.currentSkin = null;
        'own pref cleared';
    ]])
    log('own skin: ' .. tostring(r1))

    -- 2) multiplayer: empty every player's skin list for the character setup (local only)
    if isRoomConnected == nil or not isRoomConnected() then
        log('online: not connected')
        return
    end

    local sids = listPlayers()
    log('online: ' .. tostring(#sids) .. ' players')

    for _, sid in ipairs(sids) do
        if type(sid) == 'string' and sid:match('^[%w_%-]+$') then
            local steps = {
                {'players map',  "var m = GameClient.room.state.players;"},
                {'get player',   "var p = m.get('" .. sid .. "');"},
                {'skin array',   "var a = p.skin;"},
                {'skin length',  "var n = a.length;"},
                {'items array',  "var b = a.items;"},
                {'save copy',    "game.variables.set('__nsSkin_" .. sid .. "', a.items.copy());"},
                {'clear items',  "a.items = [];"},
            }
            local ok, msg = runSteps(sid, steps)
            if not ok and msg:find('clear items') then
                -- fallback way of emptying the same array
                local steps2 = {}
                for i = 1, 6 do steps2[i] = steps[i] end
                steps2[7] = {'splice items', "a.items.splice(0, a.items.length);"}
                ok, msg = runSteps(sid, steps2)
            end
            if ok then hiddenSids[#hiddenSids + 1] = sid end
            log('player ' .. sid:sub(1, 4) .. ': ' .. msg)
        else
            log('skipped odd sid: ' .. tostring(sid))
        end
    end
end

-- characters are built by now: restore everything and report what actually loaded
function onCreatePost()
    local r1 = runHaxeCode([[
        import backend.ClientPrefs;
        ClientPrefs.data.currentSkin = game.variables.get('__savedSkin');
        'own pref restored';
    ]])
    log('--- onCreatePost: ' .. tostring(r1))

    for _, sid in ipairs(hiddenSids) do
        local r = runHaxeCode([[
            import online.GameClient;
            var p = GameClient.room.state.players.get(']] .. sid .. [[');
            var saved = game.variables.get('__nsSkin_]] .. sid .. [[');
            if (p != null && saved != null)
                p.skin.items = saved;
            'restored';
        ]])
        log('player ' .. sid:sub(1, 4) .. ': ' .. tostring(r))
    end

    log('bf:  ' .. tostring(getProperty('boyfriend.curCharacter')) .. '  isSkin=' .. tostring(getProperty('boyfriend.isSkin')))
    log('dad: ' .. tostring(getProperty('dad.curCharacter')) .. '  isSkin=' .. tostring(getProperty('dad.isSkin')))
end