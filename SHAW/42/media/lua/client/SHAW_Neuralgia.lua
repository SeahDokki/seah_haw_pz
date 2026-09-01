--[[
    Humans: Are Weak - Neuralgia (SHAW:neuralgia, +5 pts)

    Design: bolts of excruciating pain, several times a game day, without
    warning.

    NO KNOCKDOWN. The first version used the shared knockdown, and in play that
    read as the character collapsing - wrong for a pain spike, which should stop
    you where you stand rather than put you on the floor. It now does what the
    design actually describes: the Pain moodle goes straight to maximum, and the
    neck takes a hard cramp.

    Maxing PAIN is not cosmetic. The engine reads it everywhere:

      - `ISBaseTimedAction:adjustMaxTime()` stretches every action by hand pain
      - high pain blocks sprinting outright
      - it degrades melee and slows movement

    So the character is genuinely crippled for the duration without any input
    lock, and can still stagger somewhere safe - which is the interesting
    decision the trait should create.

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

-- playerNum -> real ms at which the spike ends. Transient, so not in modData.
local spikes = {}

--- Roll the next spike, in game hours from now.
local function reschedule(data)
    local lowMin, highMin = SHAW.Config.range("NeuralgiaMinMinutes", "NeuralgiaMaxMinutes")
    local minutes = SHAW.randFloat(lowMin, highMin)
    data.SHAW_neuralgiaNext = SHAW.hours() + (minutes / 60)
    SHAW.log("neuralgia: next spike in %.0f game minutes", minutes)
end

local function pinPain(player)
    local _, maxPain = SHAW.statRange(CharacterStat.PAIN)
    SHAW.setStat(player, CharacterStat.PAIN, maxPain)
    return maxPain
end

local function beginSpike(player)
    spikes[player:getPlayerNum()] = getTimestampMs() + (SPIKE_SECONDS * 1000)

    -- Whatever they were doing is over.
    ISTimedActionQueue.clear(player)

    local maxPain = pinPain(player)
    SHAW.Soreness.raise(player, NECK, NECK_STIFFNESS, NECK_PAIN)

    SHAW.sayBad(player, "IGUI_SHAW_PainSpike")
    SHAW.makeNoise(player, GRUNT_RADIUS)
    SHAW.log("neuralgia: spike, PAIN pinned to %.0f for %ds", maxPain, SPIKE_SECONDS)
end

local function apply(player, data)
    local num = player:getPlayerNum()
    local endsAt = spikes[num]

    -- Mid-spike: hold PAIN at the ceiling. The engine bleeds pain away
    -- continuously, so without re-pinning the spike fades in a second or two.
    if endsAt then
        if getTimestampMs() < endsAt then
            pinPain(player)
        else
            spikes[num] = nil
            SHAW.log("neuralgia: spike over")
        end
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

Events.OnCreatePlayer.Add(function()
    spikes = {}
end)
