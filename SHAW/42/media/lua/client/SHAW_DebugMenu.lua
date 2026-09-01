--[[
    Humans: Are Weak - test tooling.

    Nine of these ten traits fire on a timer measured in game hours. Waiting for
    a narcoleptic episode to prove the code works is not a test loop, so this
    adds a right-click menu that forces each one immediately and dumps the
    state the traits keep.

    Present when SHAW.isDebug() - the Debug sandbox option OR the game's -debug
    launch flag - so a shipped game never shows it, while a dev does not have to
    start a new character to get it (sandbox options cannot be changed on an
    existing save).

    It never grants or removes traits: a trait mod that can hand itself traits at
    runtime hides exactly the character-creation bugs worth finding. Make a test
    character with the traits picked normally.
]]

SHAW = SHAW or {}

local function player()
    return getSpecificPlayer(0)
end

-- ------------------------------------------------------------------ forcing --

local function forceSeizure()
    local p = player()
    if not p then return end
    local data = p:getModData()
    data.SHAW_epilepsyLastCrisis = nil
    data.SHAW_epilepsyIrritation = 10000
    print("[SHAW] debug: seizure armed, fires on the next tick")
end

local function forceSleepAttack()
    local p = player()
    if not p then return end
    p:getModData().SHAW_narcoSleepTimer = 0
    print("[SHAW] debug: sleep attack armed")
end

local function forcePainSpike()
    local p = player()
    if not p then return end
    p:getModData().SHAW_neuralgiaNext = 0
    print("[SHAW] debug: pain spike armed")
end

local function forceTic()
    local p = player()
    if not p then return end
    p:getModData().SHAW_touretteNext = 0
    print("[SHAW] debug: vocal tic armed")
end

local function forceCramp()
    local p = player()
    if not p then return end
    -- Clear the once-per-sprint latch and guarantee the next roll succeeds.
    p:getModData().SHAW_edsSprintRolled = false
    print("[SHAW] debug: sprint now - the next sprint cramps for certain")
    p:getModData().SHAW_edsForce = true
end

local function rerollFocus()
    local p = player()
    if not p then return end
    p:getModData().SHAW_tdahFocusTimer = 0
    print("[SHAW] debug: hyperfocus reroll armed")
end

local function freeCharacter()
    SHAW.Incapacitate.clearAll()
    print("[SHAW] debug: released from any episode")
end

-- ------------------------------------------------------------- conditions --

-- Four traits do not fire on a timer at all - they wait for a condition:
-- epilepsy wants high stress or fatigue, depressive wants high depression,
-- arthritis wants spent endurance, immunocompromised wants a wound or a bite.
-- Reaching those honestly takes game-hours, which is not a test loop, so these
-- put the character straight into the state under test.

local function setStatMax(stat, label)
    return function()
        local p = player()
        if not p then return end
        local _, high = SHAW.statRange(stat)
        SHAW.setStat(p, stat, high)
        print(string.format("[SHAW] debug: %s set to %.2f", label, high))
    end
end

local function drainEndurance()
    local p = player()
    if not p then return end
    SHAW.setStat(p, CharacterStat.ENDURANCE, 0)
    print("[SHAW] debug: endurance drained - arthritis should bite within a second")
end

local function calmDown()
    local p = player()
    if not p then return end
    for _, stat in ipairs({ CharacterStat.STRESS, CharacterStat.PANIC, CharacterStat.FATIGUE,
                            CharacterStat.UNHAPPINESS, CharacterStat.BOREDOM,
                            CharacterStat.PAIN, CharacterStat.SICKNESS }) do
        SHAW.setStat(p, stat, 0)
    end
    SHAW.setStat(p, CharacterStat.ENDURANCE, 1)
    print("[SHAW] debug: stats reset")
end

local function scratchArm()
    local p = player()
    if not p then return end
    local part = p:getBodyDamage():getBodyPart(BodyPartType.ForeArm_L)
    if not part then return end
    part:setScratched(true, true)
    print("[SHAW] debug: left forearm scratched - immunocompromised should turn it septic")
end

local function infectKnox()
    local p = player()
    if not p then return end
    p:getBodyDamage():setInfected(true)
    print("[SHAW] debug: Knox infection set - immunocompromised should complete it at once")
end

local function healUp()
    local p = player()
    if not p then return end
    p:getBodyDamage():RestoreToFullHealth()
    p:getModData().SHAW_knoxForced = nil
    print("[SHAW] debug: healed, Knox flag cleared")
end

local function refreshHandlers()
    SHAW.Tick.invalidate()
    print("[SHAW] debug: handler cache cleared")
end

-- ------------------------------------------------------------------- dumps --

local TRACKED = {
    "SHAW_epilepsyLastCrisis", "SHAW_epilepsyIrritation", "SHAW_epilepsyTvTimer",
    "SHAW_narcoSleepTimer", "SHAW_narcoSleepDuration",
    "SHAW_neuralgiaNext", "SHAW_touretteNext",
    "SHAW_tdahFocusIndex", "SHAW_tdahFocusTimer",
    "SHAW_lastUnhappiness", "SHAW_knoxForced", "SHAW_edsSprintRolled",
    "SHAW_arthritisAnnounced",
}

local function dumpState()
    local p = player()
    if not p then return end
    local data = p:getModData()

    print("[SHAW] ---- modData ---- (game hour " .. string.format("%.2f", SHAW.hours()) .. ")")
    for _, key in ipairs(TRACKED) do
        local value = data[key]
        if value ~= nil then
            print(string.format("[SHAW]   %-28s %s", key, tostring(value)))
        end
    end

    print("[SHAW] ---- traits ----")
    for name, id in pairs(SHAW.traitIds()) do
        local handle = SHAW.Trait[name]
        local held = handle and p:hasTrait(handle)
        print(string.format("[SHAW]   %-20s registered=%s held=%s",
              id, tostring(handle ~= nil), tostring(held or false)))
    end
end

local function dumpStats()
    local p = player()
    if not p then return end

    local rows = {
        { "STRESS", CharacterStat.STRESS }, { "PANIC", CharacterStat.PANIC },
        { "FATIGUE", CharacterStat.FATIGUE }, { "ENDURANCE", CharacterStat.ENDURANCE },
        { "PAIN", CharacterStat.PAIN }, { "UNHAPPINESS", CharacterStat.UNHAPPINESS },
        { "BOREDOM", CharacterStat.BOREDOM }, { "SICKNESS", CharacterStat.SICKNESS },
    }

    print("[SHAW] ---- stats ----")
    for _, row in ipairs(rows) do
        print(string.format("[SHAW]   %-14s %.4f", row[1], SHAW.stat(p, row[2])))
    end

    print("[SHAW] ---- moodles ----")
    local moodles = {
        { "STRESS", MoodleType.STRESS }, { "TIRED", MoodleType.TIRED },
        { "PAIN", MoodleType.PAIN }, { "UNHAPPY", MoodleType.UNHAPPY },
        { "FOOD_EATEN", MoodleType.FOOD_EATEN }, { "ENDURANCE", MoodleType.ENDURANCE },
    }
    for _, row in ipairs(moodles) do
        print(string.format("[SHAW]   %-14s %d", row[1], SHAW.moodle(p, row[2])))
    end
end

-- -------------------------------------------------------------------- menu --

--- Is the debug menu allowed right now?
---
--- Two ways in, and the second one matters. The sandbox option is the shipped
--- switch, but **sandbox options cannot be changed on an existing save** - so
--- gating on it alone meant "make a whole new character to get the test menu",
--- which is the opposite of a fast test loop.
---
--- isDebugEnabled() is the game's own -debug launch flag, the same check
--- DebugContextMenu.doDebugMenu uses. If you already have the vanilla Debug
--- menu, you get this one too, on any save.
local function allowed()
    return SHAW.isDebug()
end

--- Signature is (player, context, worldobjects, test) - `player` is the player
--- NUMBER, not the object. The `test` pass is a probe that asks whether the
--- handler would add anything; it must not build the menu, or entries are
--- duplicated. Both conventions copied from DebugContextMenu.doDebugMenu.
local function buildMenu(playerIndex, context, worldobjects, test)
    if not allowed() then return end
    if test and ISWorldObjectContextMenu.Test then return true end

    local root = context:addOption(getText("IGUI_SHAW_ModName") .. " (debug)")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    local trigger = ISContextMenu:getNew(menu)
    context:addSubMenu(menu:addOption("Force"), trigger)
    trigger:addOption("Seizure", nil, forceSeizure)
    trigger:addOption("Sleep attack", nil, forceSleepAttack)
    trigger:addOption("Pain spike", nil, forcePainSpike)
    trigger:addOption("Vocal tic", nil, forceTic)
    trigger:addOption("Severe cramp (next sprint)", nil, forceCramp)
    trigger:addOption("Reroll hyperfocus", nil, rerollFocus)

    local condition = ISContextMenu:getNew(menu)
    context:addSubMenu(menu:addOption("Set condition"), condition)
    condition:addOption("Stress to max", nil, setStatMax(CharacterStat.STRESS, "stress"))
    condition:addOption("Fatigue to max", nil, setStatMax(CharacterStat.FATIGUE, "fatigue"))
    condition:addOption("Depression to max", nil, setStatMax(CharacterStat.UNHAPPINESS, "depression"))
    condition:addOption("Drain endurance", nil, drainEndurance)
    condition:addOption("Scratch left forearm", nil, scratchArm)
    condition:addOption("Infect with Knox", nil, infectKnox)
    condition:addOption("Reset stats", nil, calmDown)
    condition:addOption("Heal everything", nil, healUp)

    local inspect = ISContextMenu:getNew(menu)
    context:addSubMenu(menu:addOption("Inspect"), inspect)
    inspect:addOption("Dump modData and traits", nil, dumpState)
    inspect:addOption("Dump stats and moodles", nil, dumpStats)

    menu:addOption("Release from episode", nil, freeCharacter)
    menu:addOption("Rebuild handler list", nil, refreshHandlers)
end

Events.OnFillWorldObjectContextMenu.Add(buildMenu)
