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