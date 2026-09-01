--[[
    Humans: Are Weak - Tourette's (SHAW:tourette, +5 pts)

    Design: an involuntary vocal tic at irregular intervals, carrying as far as
    a human shout (~15-20 tiles), pulling in every zombie in that radius. More
    frequent under stress.

    This trait does not incapacitate. It shouts, and the shout is the whole
    penalty.

    It uses the engine's own shout - the same thing the Shout key does, via
    ISEmoteRadialMenu:emote(): playEmote("shout") then Callout(false). That
    gives the character's real voice clip, the correct alert radius and the
    animation, for free.

    The first version called addSound() directly instead. Mechanically it drew
    zombies, but it was completely silent to the player, so a forced tic read as
    nothing happening. Using Callout also removes the need for a custom .ogg,
    which is why Tourette's is no longer waiting on an audio asset.
]]

SHAW = SHAW or {}

-- Stress shortens the gap between tics by up to this fraction.
local STRESS_SHORTENING = 0.6

local function reschedule(player, data)
    local lowMin, highMin = SHAW.Config.range("TouretteMinMinutes", "TouretteMaxMinutes")

    -- Stress compresses the whole window rather than just the floor, so a
    -- panicking character tics noticeably more often.
    local stress = SHAW.statFraction(player, CharacterStat.STRESS)
    local compression = 1 - (STRESS_SHORTENING * stress)

    local minutes = SHAW.randFloat(lowMin, highMin) * compression
    data.SHAW_touretteNext = SHAW.hours() + (minutes / 60)
    SHAW.log("tourette: next tic in %.0f game minutes (stress %.2f)", minutes, stress)
end

local function apply(player, data)
    -- A tic still happens mid-seizure - the body does not care - but there is
    -- no point announcing it twice, so only the noise goes out.
    local now = SHAW.hours()

    if data.SHAW_touretteNext == nil then
        reschedule(player, data)
        return
    end

    if data.SHAW_touretteNext > now + 48 then
        reschedule(player, data)
        return
    end

    if now < data.SHAW_touretteNext then return end

    reschedule(player, data)

    -- Do the real shout, exactly as the Shout key does it. ISEmoteRadialMenu
    -- :emote() is the keybind's path and it is two calls:
    --
    --     character:playEmote("shout")
    --     character:Callout(false)
    --
    -- Callout is what actually vocalises and alerts zombies - the engine picks
    -- the character's own voice clip and the correct radius, so there is no
    -- custom audio to author and no addSound() to tune. This replaced a bare
    -- addSound(), which drew zombies but was silent to the player and so read
    -- as nothing happening at all.
    local ok = pcall(function()
        player:playEmote("shout")
        player:Callout(false)
    end)

    if ok then
        SHAW.log("tourette: tic - Callout fired")
    else
        -- Fall back to a plain noise so the trait still bites if either call
        -- moves in a patch.
        local radius = SHAW.Config.get("TouretteRadius") or 18
        SHAW.makeNoise(player, radius)
        SHAW.log("tourette: Callout failed, fell back to addSound(%d)", radius)
    end
end

SHAW.Tick.register{
    id = "tourette",
    trait = "TOURETTE",
    option = "EnableTourette",
    everyMs = 700,
    fn = apply,
}
