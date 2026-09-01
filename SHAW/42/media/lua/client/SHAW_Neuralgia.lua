--[[
    Humans: Are Weak - Neuralgia (SHAW:neuralgia, +5 pts)

    Design: bolts of excruciating pain, several times a game day, without
    warning. Roughly ten seconds of blocked actions, a pain animation and a
    quiet grunt that carries as noise.

    The countdown is stored in game hours (SHAW.hours()), not milliseconds, so
    it survives a save and does not advance while the game is paused. Real
    milliseconds would let a player skip every spike by quitting to the menu.

    The grunt is deliberately quiet: this is a noise that gives you away in a
    tense moment, not a horde magnet. Tourette's is the horde magnet.
]]

SHAW = SHAW or {}

local EPISODE_SECONDS = 10
local PAIN_SPIKE = 55        -- CharacterStat.PAIN is 0..100
local GRUNT_RADIUS = 5       -- tiles; a grunt, not a shout

--- Roll the next spike, in game hours from now.
local function reschedule(data)
    local lowMin, highMin = SHAW.Config.range("NeuralgiaMinMinutes", "NeuralgiaMaxMinutes")
    local minutes = SHAW.randFloat(lowMin, highMin)
    data.SHAW_neuralgiaNext = SHAW.hours() + (minutes / 60)
    SHAW.log("neuralgia: next spike in %.0f game minutes", minutes)
end

local function apply(player, data)
    -- Already mid-spike: hold them down until it passes.
    if SHAW.Incapacitate.reason(player) == "pain" then
        SHAW.Incapacitate.tick(player)
        return
    end

    -- Some other trait has the floor. Do not stack episodes.
    if SHAW.Incapacitate.isDown(player) then return end

    local now = SHAW.hours()

    if data.SHAW_neuralgiaNext == nil then
        reschedule(data)
        return
    end

    -- A clock that jumped backwards means a different save; re-roll rather
    -- than firing immediately.
    if data.SHAW_neuralgiaNext > now + 48 then
        reschedule(data)
        return
    end

    if now < data.SHAW_neuralgiaNext then return end

    reschedule(data)

    if SHAW.Incapacitate.begin(player, EPISODE_SECONDS, "pain", "IGUI_SHAW_PainSpike") then
        SHAW.addStat(player, CharacterStat.PAIN, PAIN_SPIKE)
        SHAW.makeNoise(player, GRUNT_RADIUS)
    end
end

SHAW.Tick.register{
    id = "neuralgia",
    trait = "NEURALGIA",
    option = "EnableNeuralgia",
    everyMs = 400,
    fn = apply,
}
