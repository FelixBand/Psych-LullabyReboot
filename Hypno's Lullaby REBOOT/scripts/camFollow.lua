local move = 7 --Pixel To Move

local c = {
    on = true,
    ang = false,
    n = {'GF Sing','note1','note2'},
    tar = false,
    off = move,
    a = move*0.04,
    defA = 0,
    e = 'linear',
    done = false,
    bX = 0, bY = 0, dX = 0, dY = 0
}

local conv = {
    ['true'] = true, ['false'] = false,
    ['1'] = true, ['0'] = false,
    ['t'] = true, ['f'] = false,
    ['on'] = true, ['off'] = false,
    ['yes'] = true, ['no'] = false
}

function onCreate()
    setMid('bf')
    setMid('dad')
    c.defA = getProperty('camGame.angle')
end

function setMid(ch)
    if ch == 'bf' then
        c.bX = getMidpointX('boyfriend') + getProperty('boyfriendCameraOffset[0]') - getProperty('boyfriend.cameraPosition[0]')
        c.bY = getMidpointY('boyfriend') + getProperty('boyfriendCameraOffset[1]') + getProperty('boyfriend.cameraPosition[1]')
    elseif ch == 'dad' then
        c.dX = getMidpointX('dad') + getProperty('opponentCameraOffset[0]') + getProperty('dad.cameraPosition[0]')
        c.dY = getMidpointY('dad') + getProperty('opponentCameraOffset[1]') + getProperty('dad.cameraPosition[1]')
    end
end

function goodNoteHit(_, dir, typ, sus)
    follow(dir, true, typ)
end

function opponentNoteHit(_, dir, typ, sus)
    follow(dir, false, typ)
end

function noteMiss(_, _, typ, sus)
    if not sus then
        follow(nil, false, typ)
    end
end

-- Get the sing animation corresponding to a note direction.
-- This makes the camera work with different mania/key counts.
function getSingAnimation(dir)
    if dir == nil then
        return nil
    end

    local animations = getProperty('singAnimations')

    if animations ~= nil then
        return animations[dir + 1]
    end

    return nil
end

function follow(dir, mt, typ)
    if c.on then
        for _, n in ipairs(c.n) do
            if mustHitSection == mt and typ ~= n then

                local xo = 0
                local yo = 0
                local ao = c.defA

                local anim = getSingAnimation(dir)

                if anim ~= nil then
                    -- Horizontal notes
                    if string.find(anim, 'LEFT') then
                        xo = -c.off
                        ao = c.defA - c.a

                    elseif string.find(anim, 'RIGHT') then
                        xo = c.off
                        ao = c.defA + c.a

                    -- Vertical notes
                    elseif string.find(anim, 'DOWN') then
                        yo = c.off

                    elseif string.find(anim, 'UP') then
                        yo = -c.off

                    -- ODD / center / unknown note:
                    -- leave camera centered.
                    end
                else
                    -- Fallback to the original 4K behavior.
                    if dir == 0 then
                        xo = -c.off
                        ao = c.defA - c.a
                    elseif dir == 3 then
                        xo = c.off
                        ao = c.defA + c.a
                    elseif dir == 1 then
                        yo = c.off
                    elseif dir == 2 then
                        yo = -c.off
                    end
                end

                setPos(xo, yo, ao)
            end
        end
    end
end

function onUpdate()
    sec = 1 / getProperty('cameraSpeed')

    if c.tar == 'bf' then
        cameraSetTarget('boyfriend')
    elseif c.tar == 'dad' then
        cameraSetTarget('dad')
    end
end

function onBeatHit()
    if getProperty('dad.animation.curAnim.name') == 'idle'
        and getProperty('boyfriend.animation.curAnim.name') == 'idle' then

        setPos(0, 0, c.defA)
    end
end

function onEvent(n, v1, v2)
    if n == 'camFunction' then
        if v1 == 'cam' then
            c.on = conv[v2] or false
            callMethod('camGame.targetOffset.set', {0, 0})
            doTweenAngle('camGameAngle', 'camGame', c.defA, sec, c.e)

        elseif v1 == 'offset' then
            c.off = tonumber(v2) or move

        elseif v1 == 'ag' then
            c.a = tonumber(v2) or move * 0.04

        elseif v1 == 'camAngle' then
            c.ang = conv[v2] or false
            doTweenAngle('camGameAngle', 'camGame', c.defA, sec, c.e)

        elseif v1 == 'target' then
            c.tar = v2

            if v2 == 'gf' then
                setMid('bf')
                setMid('dad')
                triggerEvent(
                    'Camera Follow Pos',
                    (c.bX < c.dX and c.bX or c.dX) + math.abs(c.bX - c.dX) / 2,
                    (c.bY < c.dY and c.bY or c.dY) + math.abs(c.bY - c.dY) / 2 - 150
                )

            elseif v2 == '' then
                triggerEvent('Camera Follow Pos', '', '')
            end
        end
    end

    if n == 'Change Character' then
        char = ''

        if tonumber(v1) == 0 then
            char = 'bf'
        elseif tonumber(v1) == 1 then
            char = 'dad'
        else
            char = v1
        end

        setMid(char)
    end
end

function setPos(x, y, a)
    callMethod('camGame.targetOffset.set', {x, y})

    if c.ang then
        doTweenAngle('camGameAngle', 'camGame', a, sec, c.e)
    end
end

function onCountdownStarted()
    if not checkFileExists('custom_events/camFunction.txt') then
        poyo = '1, t, on, yes, true     = on\n0, /f, off, no, false     = off\n\nvvv - v1\n\ncam = v2 (on or off)\ntarget = v2 (bf,dad or gf (center))\ncamAngle = v2 (on or off)\nag = v2\noffset = v2 (value - recomended = 30 or 25)'

        saveFile('mods/'..modFolder..'/custom_events/camFunction.txt', poyo, true)
        saveFile('mods/custom_events/camFunction.txt', poyo, true)
    end
end