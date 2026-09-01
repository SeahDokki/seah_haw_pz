--[[
    Humans: Are Weak - Ehlers-Danlos Syndrome (SHAW:ehlersdanlos, +5 pts)

    Design: joint hypermobility. Something gives out mid-sprint, and recovery
    from it is slower than normal.

    The bible asked for sprains. Sprains do not exist in Build 42.20 - no
    setSprained, no isSprained, no Sprain buff anywhere in BodyPart. So the
    mechanic is a **severe cramp** instead: a hard spike of stiffness and pain
    in one leg, which is what the engine does model (see SHAW_Soreness.lua).
    Same felt outcome - the leg stops cooperating and stays sore - reached
    through a real system rather than a missing one.

    The cramp drops the character once - a leg seizing at a sprint means going
    down - and pins Pain at maximum while it lasts. Both come from the shared
    knockdown primitive; see SHAW_Incapacitate.lua for why one fall plus pain
    beats re-shoving.

    Rolled on a cadence while sprinting - every ROLL_EVERY_MS - rather than once
    per frame or once per burst. Per frame at any sane chance fires within the
    first stride every time. Once per burst was the first attempt and was just
    as wrong in the other direction: a long sprint carried no more risk than a
    single stride, and a playtest sprinted to exhaustion without one roll ever
    landing. On a cadence, risk scales with how long you hold sprint, a short
    dash stays mostly safe, and jogging is never affected (isSprinting only).

    Sitting still is the other half. Hypermobile joints stiffen when held in one
    position, so a long sit builds light soreness in the hips and legs - worse on
    the ground than in a chair, where there is no back support and the hips fold
    further. It is deliberately slow and mild: a nuisance that makes you get up,
    not a second cramp.

    Still not implemented: the bible also wants raised light-fracture chance on
    impacts generally. That needs a damage hook and is tracked in the README.
]]

SHAW = SHAW or {}

local CRAMP_SECONDS = 4

-- A severe cramp. Deliberately high: this is the trait's headline event and
-- should be felt for a while afterwards, not shrugged off in ten seconds.
local CRAMP_STIFFNESS = 70
local CRAMP_PAIN = 40

-- How often the cramp is rolled while sprinting, in real milliseconds.
local ROLL_EVERY_MS = 1500

-- ------------------------------------------------------------ sitting still --
--
-- Hypermobile joints do not like being held in one position either, so sitting
-- too long stiffens them up. Light and slow - a nuisance that makes you get up
-- and move, not a second cramp. Sitting on the ground is worse than a chair,
-- because there is no back support and the hips are folded further.

local SIT_GRACE_MS = 45000       -- how long you can sit before it starts
local SIT_TO_FULL_MS = 240000    -- how long from there to the ceiling

-- Stiffness below 5 does NOTHING. ISHealthPanel labels that band
-- "Invisible Muscle Strain - HAS NO EFFECT ON THE PLAYER!" and only shows
-- "Minor Muscle Strain" from 5, "Muscle Strain" from 20. So the ramp starts at
-- the effect threshold rather than at zero - otherwise the first stretch of
-- sitting produced stiffness that was real in the data and inert in the game.
local STIFFNESS_FLOOR = 5
local SIT_STIFFNESS = 30         -- ceiling on furniture
local SIT_PAIN = 10
local GROUND_MULTIPLIER = 1.8    -- on the floor it bites harder and sooner

-- Lower back, hips and legs: what a folded seated posture actually loads.
-- Torso_Lower and Torso_Upper DO exist in Build 42 - an earlier reading of the
-- enum missed them because they carry no _L/_R suffix - so the lower back is
-- available and is the honest part for this.
local SEATED_PARTS = {
    BodyPartType.Torso_Lower,
    BodyPartType.Groin,
    BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R,
    BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R,
}

-- playerNum -> real ms when the current sit began. Transient by nature.
local satDown = {}
local satLogged = {}
local SIT_LOG_EVERY_MS = 15000

--- Stiffen up while seated; forget it the moment they stand.
local function sitting(player)
    local num = player:getPlayerNum()
    local onGround = player:isSitOnGround()
    local seated = onGround or player:isSittingOnFurniture()

    if not seated then
        satDown[num] = nil
        satLogged[num] = nil
        return
    end

    local now = getTimestampMs()
    if not satDown[num] then
        satDown[num] = now
        return
    end

    local held = now - satDown[num] - SIT_GRACE_MS
    if held <= 0 then return end

    local progress = SHAW.clamp(held / SIT_TO_FULL_MS, 0, 1)
    local scale = onGround and GROUND_MULTIPLIER or 1

    -- Ramp from the effect threshold, not from zero.
    local stiffness = (STIFFNESS_FLOOR + (SIT_STIFFNESS - STIFFNESS_FLOOR) * progress) * scale
    local pain = SIT_PAIN * progress * scale

    SHAW.Soreness.raise(player, SEATED_PARTS, stiffness, pain)

    -- Throttled so a long sit does not flood the console, but present at all -
    -- the last playtest could not distinguish "not detected as sitting" from
    -- "applied but invisible", which is the same ambiguity that cost a retest
    -- on the sprint roll.
    if not satLogged[num] or (now - satLogged[num]) >= SIT_LOG_EVERY_MS then
        satLogged[num] = now
        SHAW.log("eds: seated %ds (ground=%s) -> stiffness %.1f pain %.1f",
                 (now - satDown[num]) / 1000, tostring(onGround), stiffness, pain)
    end
end

-- How much of the engine's stiffness recovery is handed back each tick.
local RECOVERY_DRAG = 0.5

local function cramp(player, data)
    local leg = SHAW.pick(SHAW.Soreness.LEGS)
    if not leg then return end

    if not SHAW.Incapacitate.begin{
        player = player,
        seconds = CRAMP_SECONDS,
        reason = "cramp",
        announce = "IGUI_SHAW_LegCramp",
        shove = true,
        pinPain = true,
    } then
        return
    end

    SHAW.Soreness.raise(player, leg, CRAMP_STIFFNESS, CRAMP_PAIN)
    SHAW.log("eds: severe cramp in a leg")
end

local function apply(player, data)
    if SHAW.Incapacitate.reason(player) == "cramp" then
        SHAW.Incapacitate.tick(player)
        return
    end

    if SHAW.isIncapable(player) then return end

    sitting(player)

    -- The debug menu arms a guaranteed cramp for the next sprint.
    local forced = data.SHAW_edsForce

    if player:isSprinting() then
        -- Roll repeatedly while the sprint continues, not once per burst.
        --
        -- One roll per burst was wrong twice over: a long sprint was no riskier
        -- than a single stride, and at the old 8% a playtest could sprint to
        -- exhaustion without one roll ever landing. Rolling on a cadence makes
        -- the risk scale with how long you hold sprint, which is what "every
        -- sprint is a gamble" should mean - while a short dash stays mostly
        -- safe, and jogging is never affected at all (isSprinting only).
        local now = getTimestampMs()
        local due = (data.SHAW_edsNextRoll or 0)

        if forced or now >= due then
            data.SHAW_edsNextRoll = now + ROLL_EVERY_MS
            data.SHAW_edsForce = nil

            local chance = SHAW.Config.probability("EDSTripChance")
            local hit = forced or SHAW.chance(chance)

            -- Logged either way. Without this there is no way to tell "not
            -- sprinting" from "rolling and missing", which is exactly the
            -- ambiguity that made the last playtest inconclusive.
            SHAW.log("eds: sprint roll p=%.2f -> %s", chance, hit and "CRAMP" or "miss")

            if hit then
                cramp(player, data)
                return
            end
        end
    else
        -- Reset the cadence so the first roll of the next sprint is immediate.
        data.SHAW_edsNextRoll = 0
    end

    -- Slower recovery, across both legs.
    data.SHAW_edsStiffness = data.SHAW_edsStiffness or {}
    for _, leg in ipairs(SHAW.Soreness.LEGS) do
        SHAW.Soreness.dragRecovery(player, leg, data.SHAW_edsStiffness, RECOVERY_DRAG)
    end
end

Events.OnCreatePlayer.Add(function()
    satDown = {}
    satLogged = {}
end)

SHAW.Tick.register{
    id = "ehlersdanlos",
    trait = "EHLERSDANLOS",
    option = "EnableEhlersDanlos",
    everyMs = 500,
    fn = apply,
}
