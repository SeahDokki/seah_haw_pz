--[[
    Humans: Are Weak - Epileptic (SHAW:epileptic, +12 pts)

    Design: seizures triggered by high stress, extreme fatigue, prolonged
    direct light, or watching TV too long, with a cooldown between them. The
    seizure drops the character for 15-20 seconds, makes noise, and can cause a
    light head injury. A short confused phase follows.

    Triggers are evaluated as a running "irritation" score rather than as
    independent dice rolls: four separate rolls per tick would make seizures
    feel random, while one accumulating score means the player can watch the
    conditions worsen and get out of the light before it fires. Stress and
    fatigue are read as moodle levels, not raw stats, because the moodle is what
    the player can actually see - the trait should be legible.

    The light and TV triggers need a world scan, so they are throttled hard
    (SCAN_INTERVAL) and wrapped: an exposed-object API that shifts in a patch
    should cost this trait its light trigger, not take the whole mod down.
]]

SHAW = SHAW or {}

local IRRITATION_TO_SEIZE = 100      -- score at which a seizure fires
local SCAN_INTERVAL_HOURS = 0.05     -- game hours between light/TV scans (~3 min)
local TV_SCAN_RADIUS = 3             -- tiles

local HEAD_INJURY_CHANCE = 0.35
local HEAD_FRACTURE_TIME = 8         -- light knock, not a skull fracture
local SEIZURE_NOISE_RADIUS = 12
local CONFUSION_STRESS = 0.25

-- Irritation gained per second, by source.
local RATE_STRESS = { [0] = 0, 0, 3, 8, 16 }    -- indexed by moodle level 0..4
local RATE_FATIGUE = { [0] = 0, 0, 2, 6, 13 }
local RATE_LIGHT = 5
local RATE_TV = 4

--- Is a lit light source in the character's hands, or a vehicle headlight on?
local function directLight(player)
    local ok, lit = pcall(function()
        for _, item in ipairs({ player:getPrimaryHandItem(), player:getSecondaryHandItem() }) do
            if item and item.isActivated and item:isActivated() then
                return true
            end
        end

        local vehicle = player:getVehicle()
        if vehicle and vehicle:getHeadlightsOn() then
            return true
        end

        return false
    end)
    return ok and lit or false
end

--- Is a switched-on television within TV_SCAN_RADIUS?
local function nearbyTelevision(player)
    local ok, found = pcall(function()
        local cell = getCell()
        local px, py, pz = player:getX(), player:getY(), player:getZ()

        for dx = -TV_SCAN_RADIUS, TV_SCAN_RADIUS do
            for dy = -TV_SCAN_RADIUS, TV_SCAN_RADIUS do
                local square = cell:getGridSquare(px + dx, py + dy, pz)
                if square then
                    local objects = square:getObjects()
                    for i = 0, objects:size() - 1 do
                        local object = objects:get(i)
                        if instanceof(object, "IsoTelevision") then
                            local device = object:getDeviceData()
                            if device and device:getIsTurnedOn() then
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end)
    return ok and found or false
end

local function seize(player, data)
    local seconds = SHAW.Config.get("EpilepsyDuration") or 18

    if not SHAW.Incapacitate.begin(player, seconds, "seizure", "IGUI_SHAW_Seizure") then
        return
    end

    data.SHAW_epilepsyLastCrisis = SHAW.hours()
    data.SHAW_epilepsyIrritation = 0
    data.SHAW_epilepsyTvTimer = 0

    -- Convulsing on a hard floor is loud.
    SHAW.makeNoise(player, SEIZURE_NOISE_RADIUS)

    -- Going down unprotected sometimes means catching your head.
    if SHAW.chance(HEAD_INJURY_CHANCE) then
        local part = player:getBodyDamage():getBodyPart(BodyPartType.Head)
        if part then
            part:setFractureTime(HEAD_FRACTURE_TIME)
            part:setAdditionalPain(25)
        end
        SHAW.log("seizure: head knock")
    end

    SHAW.log("seizure: %ds", seconds)
end

local function apply(player, data)
    -- Mid-seizure: hold them down, then leave them rattled.
    if SHAW.Incapacitate.reason(player) == "seizure" then
        if not SHAW.Incapacitate.tick(player, "IGUI_SHAW_SeizureOver") then
            -- The confused phase: a jolt of stress as they come back.
            SHAW.addStat(player, CharacterStat.STRESS, CONFUSION_STRESS)
        end
        return
    end

    if SHAW.isIncapable(player) then return end

    local now = SHAW.hours()

    -- Cooldown. Also catches a clock that moved backwards.
    local last = data.SHAW_epilepsyLastCrisis
    local cooldown = SHAW.Config.get("EpilepsyCooldown") or 10
    if last ~= nil then
        if last > now then
            data.SHAW_epilepsyLastCrisis = now
            return
        end
        if now - last < cooldown then return end
    end

    -- Accumulate irritation. This handler runs on a 1s interval, so the rates
    -- above are per second. `gain` is tracked separately from the running total
    -- so "nothing is irritating me right now" is an explicit condition rather
    -- than something inferred from the total not having moved.
    local irritation = data.SHAW_epilepsyIrritation or 0
    local gain = 0

    gain = gain + (RATE_STRESS[SHAW.moodle(player, MoodleType.STRESS)] or 0)
    gain = gain + (RATE_FATIGUE[SHAW.moodle(player, MoodleType.TIRED)] or 0)

    -- World scans are expensive; refresh them on their own slow cadence and
    -- reuse the answer in between.
    local lastScan = data.SHAW_epilepsyLastScan
    if lastScan == nil or lastScan > now or (now - lastScan) >= SCAN_INTERVAL_HOURS then
        data.SHAW_epilepsyLastScan = now
        data.SHAW_epilepsyLightSeen = directLight(player)
        data.SHAW_epilepsyTvSeen = nearbyTelevision(player)
    end

    if data.SHAW_epilepsyLightSeen then
        gain = gain + RATE_LIGHT
    end

    if data.SHAW_epilepsyTvSeen then
        -- The bible wants "watched too long", so the TV only starts counting
        -- after a sustained exposure rather than the instant one is on.
        local tvTimer = (data.SHAW_epilepsyTvTimer or 0) + 1
        data.SHAW_epilepsyTvTimer = tvTimer
        if tvTimer > 60 then
            gain = gain + RATE_TV
        end
    else
        data.SHAW_epilepsyTvTimer = 0
    end

    if gain > 0 then
        irritation = irritation + gain
    else
        -- Calm, rested and in the dark: the score bleeds away.
        irritation = math.max(0, irritation - 2)
    end

    data.SHAW_epilepsyIrritation = irritation

    if irritation >= IRRITATION_TO_SEIZE then
        seize(player, data)
    end
end

SHAW.Tick.register{
    id = "epileptic",
    trait = "EPILEPTIC",
    option = "EnableEpileptic",
    everyMs = 1000,
    fn = apply,
}
