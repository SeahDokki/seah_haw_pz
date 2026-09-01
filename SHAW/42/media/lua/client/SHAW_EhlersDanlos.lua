--[[
    Humans: Are Weak - Ehlers-Danlos Syndrome (SHAW:ehlersdanlos, +5 pts)

    Design: raised sprain probability, raised light-fracture probability on
    impacts, a chance to fall mid-sprint as an ankle gives, and slower recovery.

    A correction to the bible. It says the trait "uses light fracture (exists in
    game) - not dislocation (does not exist)". Half right for 42.20: fractures
    exist and are reachable (BodyPart:setFractureTime, :setSplint,
    :getFractureTime), but **sprains do not exist either**. There is no sprain
    anywhere in the Lua API or in BodyPart's method table - no setSprained, no
    isSprained, no Sprain buff. The bible's primary mechanic is not available.

    So the trait is built from what the engine does have:

      - joint stiffness   BodyPart:setStiffness(). B42's muscle-strain value,
                          and the closest thing to a sprain: a joint that hurts
                          and slows you down for a while. Applied to the leg the
                          ankle gave out on.
      - light fracture    setFractureTime() with a short time, for real impacts.
      - the trip          the shared knockdown, rolled once per sprint rather
                          than per frame.

    Rolled once per continuous sprint. Rolling per frame would make sprinting
    instantly fatal at any sane probability - at 60fps an 8% per-frame chance
    fires within the first stride, every time.
]]

SHAW = SHAW or {}

local TRIP_SECONDS = 4
local ANKLE_STIFFNESS = 55
local ANKLE_PAIN = 30
local ANKLE_FRACTURE_CHANCE = 0.25
local ANKLE_FRACTURE_TIME = 20

-- Recovery drag: how much of the engine's stiffness recovery is given back.
local RECOVERY_DRAG = 0.5

local LEGS = {
    { low = BodyPartType.LowerLeg_L, foot = BodyPartType.Foot_L },
    { low = BodyPartType.LowerLeg_R, foot = BodyPartType.Foot_R },
}

local function ankleGives(player)
    local leg = SHAW.pick(LEGS)
    local damage = player:getBodyDamage()
    if not damage or not leg then return end

    if not SHAW.Incapacitate.begin(player, TRIP_SECONDS, "trip", "IGUI_SHAW_AnkleGives") then
        return
    end

    for _, partType in ipairs({ leg.low, leg.foot }) do
        local part = damage:getBodyPart(partType)
        if part then
            part:setStiffness(math.max(part:getStiffness(), ANKLE_STIFFNESS))
            part:setAdditionalPain(math.max(part:getAdditionalPain(), ANKLE_PAIN))
        end
    end

    -- Sometimes the joint going is not the worst of it.
    if SHAW.chance(ANKLE_FRACTURE_CHANCE) then
        local part = damage:getBodyPart(leg.low)
        if part and part:getFractureTime() <= 0 then
            part:setFractureTime(ANKLE_FRACTURE_TIME)
            SHAW.log("eds: light fracture in the lower leg")
        end
    end

    SHAW.log("eds: ankle gave out")
end

local function apply(player, data)
    if SHAW.Incapacitate.reason(player) == "trip" then
        SHAW.Incapacitate.tick(player)
        return
    end

    if SHAW.Incapacitate.isDown(player) then return end

    local sprinting = player:isSprinting()

    if sprinting then
        -- One roll per continuous sprint. The flag clears when they stop.
        if not data.SHAW_edsSprintRolled then
            data.SHAW_edsSprintRolled = true

            -- SHAW_edsForce is set by the debug menu to make the next roll a
            -- certainty; an 8% chance is not a test loop. Consumed on use.
            local forced = data.SHAW_edsForce
            data.SHAW_edsForce = nil

            if forced or SHAW.chance(SHAW.Config.probability("EDSTripChance")) then
                ankleGives(player)
                return
            end
        end
    else
        data.SHAW_edsSprintRolled = false
    end

    -- Slower recovery: hand back part of whatever stiffness the engine just
    -- healed off the legs. Tracked per part so a limb that was never stiff is
    -- left alone.
    local damage = player:getBodyDamage()
    if not damage then return end

    data.SHAW_edsStiffness = data.SHAW_edsStiffness or {}
    local remembered = data.SHAW_edsStiffness

    for _, leg in ipairs(LEGS) do
        for _, partType in ipairs({ leg.low, leg.foot }) do
            local part = damage:getBodyPart(partType)
            if part then
                local key = BodyPartType.ToIndex(partType)
                local now = part:getStiffness()
                local before = remembered[key]

                if before ~= nil and now < before then
                    part:setStiffness(now + (before - now) * RECOVERY_DRAG)
                end

                remembered[key] = part:getStiffness()
            end
        end
    end
end

SHAW.Tick.register{
    id = "ehlersdanlos",
    trait = "EHLERSDANLOS",
    option = "EnableEhlersDanlos",
    everyMs = 500,
    fn = apply,
}
