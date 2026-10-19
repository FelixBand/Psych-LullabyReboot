flippedHealth = false

function onCreate()
    setPropertyFromClass('PauseSubState', 'songName', 'LullabyPause')
end

botplayQuotes = {
    ['safety lullaby'] = {
        'you took the safety part too seriously',
        'honkk mimimimi'
    },
    ['left unchecked'] = {
        'its not that hard anymore i fixed it',
        'the pendulums still tweened please'
    },
    ['lost cause'] = {
        'youre the lost cause',
        'i know youre in botplay to stare at her ass'
    },
    ['frostbite'] = {
        'those psych engine ports go crazy',
        'did you get a brain freeze?',
        "Freakachu's in your insides rip your skin off do it now"
    },
    ['insomnia'] = {
        'a mimir mode',
        'dont fall asleep',
        'did you fall asleep on your keyboard?',
        'you really didnt wanna wake him up'
    },
    ['monochrome'] = {
        'hes an 11 year old corpse',
        'did you need more time to type?'
    },
    ['missingno'] = {
        'mew was under the truck',
        'i hope your pc actually crashes'
    },
    ['brimstone'] = {
        'brimstone betadciu type beat',
        'you probably played the leaked build',
        "Buryman has more life than your will to fucking play",
        'ge ge ge-get your hands back on your keyboard'
    },
    ['amusia'] = {
        'i am unamused',
        'do YOU even have a sing?'
    },
    ['bygone purpose'] = {
        'scrimblini',
        'you should jump off like alexis'
    },
    ['dissension'] = {
        'why should I play fair?',
        "he's gonna strangle you next"
        -- 'you seriously gonna cheat him again??'
    },
    ['death toll'] = {
        'go to hell',
        'take a bath in the magma',
        'lmao are you scared of an old dude?',
        'i have the high ground anakin',
        'put your volume on max on hell mode and miss'
    },
    ['isotope'] = {
        'we forgot to scrap it',
        'Am I a joke to you?'
    },
    ['purin'] = {
        'hyperrealistic?!',
        'purin',
        'Hang out a bit with Nurse Joy',
        'do NOT put your dick in those holes'
    },
    ['pasta night'] = {
        'guess you got counterpicked',
        'maybe the kiddie table is for you'
    },
    ['shinto'] = {
        'peak 10/10 expreiuenc',
        "It's a her you fucking idiot"
    },
    ['shitno'] = {
        'why is it so cold',
        'you got cold feet',
        "you're only here for saster"
    },
    ['missingcraft'] = {
        'dig straight down :|',
        'how you this bad on a kids game song'
    }
}

local quotes = botplayQuotes[string.lower(songName)]

function onCreatePost()
    setBotplaySubtext(quotes[getRandomInt(1, #quotes)])
end

function setBotplaySubtext(subText)
    setTextString('botplayTxt', 'BOTPLAY\n' .. subText)
    screenCenter('botplayTxt', 'x')
end

function doFlipStage(flipHealth, flipScore)
    if flipHealth == nil then flipHealth = true end
    if flipScore == nil then flipScore = true end
    
    if flipHealth then
        flippedHealth = true
        setProperty('healthBar.flipX', true)
    end

    if flipScore then
        -- flip the online multiplayer score texts
        runHaxeCode([[
            for (t in game.scoreTxtOthers) {
                if (t.offset.x < 0) {
                    // was the left text: move it to the right edge
                    t.alignment = 'right';
                    t.offset.x = 30;
                } else {
                    // was the right text: move it to the left edge
                    t.alignment = 'left';
                    t.offset.x = -30;
                }
            }
        ]])
    end
end

function onUpdatePost()
    if flippedHealth then
        flipSide('iconP1s', true)
        flipSide('iconP2s', false)
    end
end

function flipSide(arrayName, isPlayer)
    local count = getProperty(arrayName .. '.length')
    for i = 0, count - 1 do
        local icon = arrayName .. '[' .. i .. ']'
        local scaleX = getProperty(icon .. '.scale.x')
        local barX = getProperty('healthBar.x')
            + getProperty('healthBar.width') * getProperty('healthBar.percent') * 0.01
        -- small extra spread per icon so stacked ones don't sit on top of each other
        local spread = i * 40

        if isPlayer then
            setProperty(icon .. '.x', barX + (150 * scaleX - 150) / 2 - 26 - 110 - spread)
            setProperty(icon .. '.origin.x', 240)
        else
            setProperty(icon .. '.x', barX - (150 * scaleX) / 2 - 26 * 2 + 110 + spread)
            setProperty(icon .. '.origin.x', -100)
        end
        setProperty(icon .. '.flipX', true)
    end
end