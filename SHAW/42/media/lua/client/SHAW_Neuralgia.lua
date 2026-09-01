--[[
    Humans: Are Weak - Neuralgia (SHAW:neuralgia, +5 pts)

    Design: bolts of excruciating pain, several times a game day, without
    warning.

    NO KNOCKDOWN - this is the one trait of the three that uses the shared
    episode primitive with `shove = false`. A pain spike should stop you where
    you stand, not put you on the floor. The first version did knock the
    character down and it read as collapsing for no reason.

    What it does instead is pin CharacterStat.PAIN at its ceiling for the
    duration, plus a hard cramp in the neck. See SHAW_Incapacitate.lua for why
    pinned pain genuinely incapacitates without any input lock.

    Neck rather than head: BodyPartType.Head has no good "cramp" reading, while
    Neck is a real part with the same stiffness and pain fields. Cervical and
    trigeminal neuralgia also actually present there, so it happens to be the
    honest choice too.

    The countdown is stored in game hours (SHAW.hours()), not milliseconds, so
    it survives a save and does not advance while the game is paused. Real
    milliseconds would let a player skip every spike by quitting to the menu.

    The grunt is deliberately quiet: a noise that gives you away in a tense
    moment, not a horde magnet. Tourette's is the horde magnet.
]]

SHAW = SHAW or {}

local SPIKE_SECONDS = 12       -- how long PAIN is held at the ceiling
local NECK_STIFFNESS = 60
local NECK_PAIN = 45
local GRUNT_RADIUS = 5         -- tiles; a grunt, not a shout

local NECK = { BodyPartType.Neck }

--- Roll the next spike, in game hours from now.
local function reschedule(data)
    local lowMin, highMin = SHAW.Config.range("NeuralgiaMinMinutes", "NeuralgiaMaxMinutes")
    local minutes = SHAW.randFloat(lowMin, highMin)
    data.SHAW_neuralgiaNext = SHAW.hours() + (minutes / 60)
    SHAW.log("neuralgia: next spike in %.0f game minutes", minutes)
end

local function beginSpike(player)
    local started = SHAW.Incapacitate.begin{
        player = player,
        seconds = SPIKE_SECONDS,
        reason = "pain",
        announce = "IGUI_SHAW_PainSpike",
        shove = false,      -- the whole point: no collapse
        pinPain = true,
    }
    if not started then return end

    SHAW.Soreness.raise(player, NECK, NECK_STIFFNESS, NECK_PAIN)
    SHAW.makeNoise(player, GRUNT_RADIUS)
end

local function apply(player, data)
    -- Mid-spike: the primitive re-pins pain and times the episode out.
    if SHAW.Incapacitate.reason(player) == "pain" then
        SHAW.Incapacitate.tick(player)
        return
    end

    -- Asleep, or another trait has the floor.
    if SHAW.isIncapable(player) then return end

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
    beginSpike(player)
end

SHAW.Tick.register{
    id = "neuralgia",
    trait = "NEURALGIA",
    option = "EnableNeuralgia",
    everyMs = 400,
    fn = apply,
}
