--[[
    Humans: Are Weak - test tooling.

    Nine of these ten traits fire on a timer measured in game hours. Waiting for
    a narcoleptic episode to prove the code works is not a test loop, so this
    adds a right-click menu that forces each one immediately and dumps the
    state the traits keep.

    Only present when the Debug sandbox option is on, so a shipped game never
    shows it. It also never grants or removes traits: a trait mod that can hand
    itself traits at runtime hides exactly the character-creation bugs worth
    finding. Make a test character with the traits picked normally.
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

local function forceAnkle()
    local p = player()
    if not p then return end
    -- Clear the once-per-sprint latch and guarantee the next roll succeeds.
    p:getModData().SHAW_edsSprintRolled = false
    print("[SHAW] debug: sprint now - the next sprint rolls at 100%")
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

local function refreshHandlers()
    SHAW.Tick.invalidate()
    print("[SHAW] debug: handler cache cleared")
end

-- ------------------------------------------------------------------- dumps --

local TRACKED = {
    "SHAW_epilepsyLastCrisis", "SHAW_epilepsyIrritation", "SHAW_epilepsyTvTimer",
    "SHAW_narcoSleepTimer", "SHAW_narcoSleepDuration",
    "SHAW_neuralgiaNext", "SHAW_touretteNext",
    "SHAW_tdahFocusSkill", "SHAW_tdahFocusTimer",
    "SHAW_lastUnhappiness", "SHAW_knoxForced", "SHAW_edsSprintRolled",
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

local function buildMenu(playerIndex, context)
    if not SHAW.Config or not SHAW.Config.get("Debug") then return end

    local root = context:addOption(getText("IGUI_SHAW_ModName") .. " (debug)")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    local trigger = ISContextMenu:getNew(menu)
    context:addSubMenu(menu:addOption("Force"), trigger)
    trigger:addOption("Seizure", nil, forceSeizure)
    trigger:addOption("Sleep attack", nil, forceSleepAttack)
    trigger:addOption("Pain spike", nil, forcePainSpike)
    trigger:addOption("Vocal tic", nil, forceTic)
    trigger:addOption("Ankle gives (next sprint)", nil, forceAnkle)
    trigger:addOption("Reroll hyperfocus", nil, rerollFocus)

    local inspect = ISContextMenu:getNew(menu)
    context:addSubMenu(menu:addOption("Inspect"), inspect)
    inspect:addOption("Dump modData and traits", nil, dumpState)
    inspect:addOption("Dump stats and moodles", nil, dumpStats)

    menu:addOption("Release from episode", nil, freeCharacter)
    menu:addOption("Rebuild handler list", nil, refreshHandlers)
end

Events.OnFillWorldObjectContextMenu.Add(buildMenu)
