function onCreate()
    setPropertyFromClass('PauseSubState', 'songName', 'pause')

    setProperty('showRating', false)
    setProperty('showComboNum', false)
end

local function setSplashOpacity(alpha)
    runHaxeCode([[
        for (s in game.grpNoteSplashes.members)
            if (s != null && s.exists && s.animation.curAnim != null && !s.animation.curAnim.finished)
                s.alpha = ]]..alpha..[[;
    ]])
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    setSplashOpacity(1)
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    setSplashOpacity(1)
end

-- Hides everything currently drawn on camOther. Call it whenever you like: hideCamOther()
function hideCamOther()
    if not defined then
        -- defined once; later calls only run it by name (no re-parsing)
        runHaxeCode([[
            function hideCamOtherIn(grp) {
                for (m in grp.members) {
                    if (m == null) continue;
                    var cams = m.cameras;
                    if (cams != null && cams.indexOf(game.camOther) != -1)
                        m.visible = false;
                    else if (m.members != null)
                        hideCamOtherIn(m);
                }
            }
            function hideCamOtherAll() {
                hideCamOtherIn(game);
            }
        ]])
        defined = true
    end
    runHaxeFunction('hideCamOtherAll', {})
end