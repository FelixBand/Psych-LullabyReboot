-- Force-disables ALL skins (yours and other players'), client side only.
-- Works on Psych Online 0.14.8 and 0.14.9. Put in  scripts/  (global), NOT in data/<song>/.
-- Note: runHaxeCode returns nothing on 0.14.9, so nothing here depends on its return value.
local hiddenSids = {}

local function skinArray(sid)
    return [[
        import online.GameClient;
        var a = GameClient.room.state.players.get(']] .. sid .. [[').skin;
    ]]
end

function onCreate()
    -- your own saved skin
    runHaxeCode([[
        import backend.ClientPrefs;
        game.variables.set('__savedSkin', ClientPrefs.data.currentSkin);
        ClientPrefs.data.currentSkin = null;
    ]])

    -- multiplayer: empty every player's skin list before characters are built
    if isRoomConnected == nil or not isRoomConnected() then return end

    for _, sid in ipairs(listPlayers()) do
        if type(sid) == 'string' and sid:match('^[%w_%-]+$') then
            runHaxeCode(skinArray(sid) .. [[
                game.variables.set('__nsSkin_]] .. sid .. [[', a.items.copy());
                a.items.splice(0, a.items.length);
            ]])
            hiddenSids[#hiddenSids + 1] = sid
        end
    end
end

-- characters are built by now: put everything back
function onCreatePost()
    runHaxeCode([[
        import backend.ClientPrefs;
        ClientPrefs.data.currentSkin = game.variables.get('__savedSkin');
    ]])

    for _, sid in ipairs(hiddenSids) do
        runHaxeCode(skinArray(sid) .. [[
            var saved = game.variables.get('__nsSkin_]] .. sid .. [[');
            if (saved != null) {
                a.items.splice(0, a.items.length);
                for (s in saved)
                    a.items.push(s);
            }
        ]])
    end
end