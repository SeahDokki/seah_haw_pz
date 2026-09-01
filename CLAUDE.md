# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Humans: Are Weak (H:AW) is a **Project Zomboid mod in first implementation**. All thirteen traits are declared, costed
and translated. **Ten of them have behaviour written and statically checked but never run in the game** - see the
status table in [README.md](README.md). The other three (Diabetic, Asthmatic, Allergic) are blocked on items the mod
does not ship yet and have no code at all.

Treat "written" as "unverified". The README carries a numbered test plan; work through it before adding anything new,
and prefer fixing a trait that fails it over starting the item work.

[haw-design-bible.md](haw-design-bible.md) is the **spec of record**, written in French. Read it before any implementation work. Its
"Points ouverts" section lists deliberately-unresolved decisions - do not silently invent values for them; either ask,
or implement behind a clearly-marked configurable constant. [README.md](README.md) is the English version of the same
design, and carries the open points list plus what was learned while scaffolding. When a design decision changes,
update the bible and the README in the same change as the code.

## Environment (verified on this machine)

| Thing | Path |
|---|---|
| Game install | `D:\SteamLibrary\steamapps\common\ProjectZomboid` |
| Game build | **42.20.4** |
| Vanilla Lua source (best API reference) | `<game>\media\lua\{shared,client,server}` |
| Vanilla trait/profession scripts | `<game>\media\scripts\generated\characters\` |
| Java API (decompile for signatures) | `<game>\projectzomboid.jar` |
| Reference mods that add traits | `D:\SteamLibrary\steamapps\workshop\content\108600\` |
| Local mod install dir | `C:\Users\tsuyu\Zomboid\mods\` |
| Runtime log / Lua errors | `C:\Users\tsuyu\Zomboid\console.txt`, `C:\Users\tsuyu\Zomboid\Logs\` |

## Build, test, run

There is no build system, linter or test runner - Project Zomboid mods are interpreted Lua loaded directly from disk.
The full loop is:

1. `.\deploy.ps1` - copies `SHAW\` into `C:\Users\tsuyu\Zomboid\mods\SHAW\`, wiping the destination first
   so renamed and deleted files do not linger. `-DryRun` shows what it would do.
2. Launch `ProjectZomboid64ShowConsole.bat` from the game install so Lua errors surface in a console window.
3. Enable the mod in-game (Mods menu), start a new character - **trait and profession changes need a new character**,
   not just a new save.
4. Read `~\Zomboid\console.txt` for `LOG : Lua` lines and stack traces. This is the only real test feedback loop.

`python tools/i18ncheck.py` verifies the four locales define identical keys and that every sandbox option has a
translation. Run it before every commit that touches strings.

`.\build.ps1` stages the mod into `~\Zomboid\Workshop\SHAW\` for the in-game uploader. It never overwrites an
existing `workshop.txt`: after the first upload that file holds the published Steam item id, and losing it would
publish a duplicate instead of an update.

## Mod folder layout (Build 42)

The layout sketched in the design bible is the **Build 41** flat layout and is out of date for 42.20. B42 mods use
per-build subfolders under the mod id:

```
humans_are_weak/        <- repo root
  SHAW/                 <- the mod folder; this is what deploy.ps1 copies
    mod.info            <- top-level, legacy/B41 discovery
    preview.png         <- 256x256, Workshop thumbnail
    42/                 <- Build 42 content; what actually loads in 42.x
      mod.info
      media/
        registries.lua  <- trait/profession registration. NOT under lua/
        sandbox-options.txt
        scripts/        <- trait and profession definitions
        lua/
          shared/       <- constants, config, pure logic (both sides)
          client/       <- UI, sound, visual effects
          server/       <- world state
          shared/Translate/<LANG>/*.json
```

`mod.info` is flat `key=value`. The `id` is what the mods menu and save files key on, so it must never change once a
save exists.

## Build 42 traits and professions: how they actually work

This is the part that differs most from every B41 tutorial online. Verified against the installed game and against two
Workshop mods that do it correctly (`The-Only-Cure`, `Lifestyle: Hobbies`).

**Traits are not registered in Lua with `TraitFactory.addTrait` any more.** B41's `TraitFactory` /
`ProfessionFactory` API is gone. B42 declares them in **script files**, and `BaseGameCharacterDetails.DoTraits` in
`<game>\media\lua\shared\NPCs\MainCreationMethods.lua` only decorates the descriptions afterwards.

Three files have to agree, and a mistake in any one of them fails **silently**:

1. **`media/registries.lua`** - at the media root, *not* under `lua/`. Loaded before the scripts are parsed.

   ```lua
   CharacterTrait[string.upper(id)] = CharacterTrait.register("SHAW:" .. id)
   ```

   Skip this and the script file's `CharacterTrait = SHAW:<id>,` line has nothing to resolve against.

2. **`media/scripts/SHAW_traits.txt`** - `module SHAW { character_trait_definition SHAW:<id> { ... } }`.
   Ids are case-sensitive and must match `registries.lua` exactly.

3. **`media/lua/shared/Translate/<LANG>/UI.json`** - `UIName` and `UIDescription` name keys that must exist in all
   four locales, or the character sheet renders the raw key.

**`Cost` signs are inverted between traits and professions.** This is a real vanilla quirk, not a typo:

| | Spends points | Grants points |
|---|---|---|
| **Traits** | `Cost` positive (`base:brave` = 4) | `Cost` negative (`base:cowardly` = -2) |
| **Professions** | `Cost` negative (`base:veteran` = -8) | `Cost` positive (`base:unemployed` = 8) |

The design bible states points from the player's side. So a bible trait worth "+12 pts" is `Cost = -12`, while a bible
occupation at "-2 pts" is `Cost = -2` unchanged.

**Querying a trait takes the registered handle, not a string.** `player:hasTrait("epileptic")` does not work.
B42 wants `player:hasTrait(CharacterTrait.EPILEPTIC)` - lowercase `hasTrait`, and the object returned by
`register()`. `SHAW_Traits.lua` collects those handles in `SHAW.Trait` so nothing in the mod ever touches
`CharacterTrait` directly.

**Valid XPBoosts perk names** (B42.20, from the vanilla scripts): `Aiming Axe Blacksmith Blunt Butchering Carving
Cooking Doctor Electricity Farming Fishing Fitness FlintKnapping Glassmaking Husbandry Lightfoot Maintenance Masonry
Mechanics MetalWelding Nimble PlantScavenging Pottery Reloading SmallBlade SmallBlunt Sneak Sprinting Strength
Tailoring Tracking Trapping Woodwork`. There is no `LongBlade`.

## Build 42 runtime APIs the traits actually use

Verified against the installed 42.20.4 and, where the Lua files were silent, against the class constant pools in
`projectzomboid.jar`. Every B41 tutorial online is wrong about the first two.

**Stats are a keyed API now.** `getStress()`, `getFatigue()` and friends are gone. It is
`player:getStats():get/set/add/remove(CharacterStat.X, value)`, with these keys: `ANGER BOREDOM DISCOMFORT ENDURANCE
FATIGUE FITNESS FOOD_SICKNESS HUNGER IDLENESS INTOXICATION MORALE NICOTINE_WITHDRAWAL PAIN PANIC POISON SANITY
SICKNESS STRESS TEMPERATURE THIRST UNHAPPINESS WETNESS ZOMBIE_FEVER ZOMBIE_INFECTION`.

**Stat ranges are not uniform, so never hardcode one.** STRESS and PANIC run 0..1; PAIN, BOREDOM and UNHAPPINESS run
0..100. Guessing wrong makes a trait either a no-op or an instant maximum, silently. `CharacterStat` carries its own
`getMinimumValue()` / `getMaximumValue()`, which is what `SHAW.statRange()` and `SHAW.statFraction()` in
`SHAW_Core.lua` use - go through those. `Stats:add/remove` also clamp engine-side, which is why `SHAW.addStat()`
routes through them instead of doing the maths.

**Moodles are read-only from Lua.** `player:getMoodles():getMoodleLevel(MoodleType.X)` returns 0..4. There is no
setter: moodles are computed from stats, so to move a moodle you move the stat behind it. The full enum is `ANGRY
BLEEDING BORED CANT_SPRINT DEAD DRUNK ENDURANCE FOOD_EATEN HAS_A_COLD HEAVY_LOAD HUNGRY HYPERTHERMIA HYPOTHERMIA
INJURED NOXIOUS_SMELL PAIN PANIC SICK STRESS THIRST TIRED UNCOMFORTABLE UNHAPPY WET WINDCHILL ZOMBIE` - note only
eleven of those appear anywhere in vanilla Lua, so grep is not a reliable inventory here.

**Noise for the AI is `addSound`, not the sound manager.** `addSound(source, x, y, z, radius, volume)` is what zombies
hear. `character:playSound("Name")` is what the player hears. Tourette's needs the first; a trait that only calls the
second is silent to the horde. `SHAW.makeNoise()` and `SHAW.playSound()` wrap them.

**Stretching an action goes through `adjustMaxTime`.** `ISBaseTimedAction:adjustMaxTime(maxTime)` is the engine's own
hook, already applying unhappiness, drunkenness, hand pain and body temperature. Wrap the *specific* action's copy
(`ISReadABook.adjustMaxTime`), never the base class, or every action in the game changes.

**`Events.AddXP` is a notification, not a filter.** It fires after the XP has landed, with `(character, perk, amount)`.
You cannot multiply the incoming amount; you can only top up with `getXp():AddXPNoMultiplier(perk, extra)` - and that
re-raises the same event, so a re-entrancy guard is mandatory. See `SHAW_ADHD.lua`.

**Perk identity is `perk:getId()`.** `getName()` is the translated display name and must never be persisted or
compared.

**There is no way to disable player input.** `setBlockMovement` exists only on animal behaviour. The reachable
approximation is the shove the engine uses when a zombie pushes you, re-applied on a timer:

```lua
chr:setBumpType("stagger")
chr:setVariable("BumpDone", false)
chr:setVariable("BumpFall", true)
chr:setVariable("BumpFallType", "pushedFront")
```

Taken from `client/DebugUIs/DebugContextMenu.lua`, which also re-applies it periodically to hold a character down.
`SHAW_Incapacitate.lua` owns this; the three traits that drop the player share it rather than each rolling their own.

**Injuries: fractures yes, sprains no.** `BodyPart` has `setFractureTime`, `setSplint`, `setStiffness`,
`setAdditionalPain`, `setInfectedWound`, `setWoundInfectionLevel`. It has **nothing** for sprains - the concept does
not exist in 42.20, which invalidates the design bible's primary Ehlers-Danlos mechanic. `setStiffness` (B42's
muscle-strain value) is the closest substitute.

**Global desaturation is reachable.** No shader needed for Colour Blind:

```lua
local option = getClimateManager():getClimateFloat(ClimateManager.FLOAT_DESATURATION)
option:setEnableAdmin(true)
option:setAdminValue(1.0)
```

It is a **world** setting, so it is single-player only, and the weather system overwrites it - the override has to be
re-asserted periodically rather than set once.

**Timers use the game clock, never the wall clock.** `getGameTime():getWorldAgeHours()` (wrapped as `SHAW.hours()`) is
fractional, monotonic, saved with the world, and does not advance while paused. `getTimestampMs()` keeps running in the
menu, so a cooldown built on it can be skipped by quitting to the main menu. Real milliseconds are used for exactly one
thing in this mod: throttling how often a handler runs, in `SHAW_Tick.lua`.

## Naming and language conventions

**The mod id and every prefix is `SHAW`** - decided, not a placeholder. It is the `id=` in `mod.info`, the module
name in the script files, the modData key prefix, the Lua namespace, the filename prefix and the translation-key
prefix. **The design bible still writes `HAW_`** for modData keys - that form is dead, use `SHAW_`. Never
introduce a second prefix, and never rename these keys once a save exists: modData is a save-file schema.

**All code is English-only** - variable, function, table and file names, plus comments. The design documents are in
French and the user works in French, but nothing French belongs in the Lua source.

**No player-facing string is hardcoded.** Every displayed text goes through a translation file.

## Translations (i18n)

Minimum shipped locales: **EN, FR, ES, DE**. English is the reference and the fallback. All four are updated in the
same change - never English-only.

**Translations are JSON, one file per language folder, with no language suffix in the filename.** B42.20 dropped the
`.txt` format completely; vanilla `Translate/<LANG>/` contains only `.json`. Some installed B42 mods still ship
`UI_EN.txt` - that is dead weight, the loader ignores it.

```
SHAW/42/media/lua/shared/Translate/
  EN/UI.json          <- trait and profession names + descriptions
  EN/IG_UI.json       <- in-game UI strings
  EN/Sandbox.json     <- sandbox option labels and tooltips
  FR/UI.json          <- same filename; the folder carries the language
  ES/... DE/...
```

Flat `"KEY": "value"` objects, UTF-8, **no BOM**. Key naming follows the vanilla category prefix plus the mod prefix:
`UI_trait_SHAW_<Name>`, `UI_trait_SHAW_<Name>Desc`, `UI_prof_SHAW_<Name>`,
`UI_profdesc_SHAW_<Name>`, `Sandbox_SHAW_<Option>`, `IGUI_SHAW_<Thing>`. Look up the right category prefix
in the vanilla files rather than inventing one - the game resolves keys by category, and a wrong prefix silently
renders the raw key.

The four locale files are the *only* place French appears in the mod's shipped content.

## Multiplayer

The mod must work in single player, on a dedicated server, and on a co-op host.

- **Files under `server/` are loaded on multiplayer clients too.** Every file that decides world state opens with
  `if not SHAW.isAuthoritative() then return end` - the same guard the vanilla Lua uses. Without it, each client
  rolls its own answer and diverges from the server.
- **Sandbox options are replicated**, so both sides read the same config.
- `getPlayer()` does not exist on a dedicated server - iterate over connected players.

Context helpers live in `SHAW_Core.lua`: `isAuthoritative()`, `isSinglePlayer()`, `isDedicatedServer()`.

## Sandbox options

All tunables come from `42/media/sandbox-options.txt`, exposed as `SandboxVars.SHAW.<Name>`. **Never read
`SandboxVars` directly** - go through `SHAW.Config.get("Name")`, which falls back to a shipped default when an
option is missing (older save, partial server override). The `DEFAULTS` table in `SHAW_Config.lua` must stay in
sync with the `default =` lines in the options file.

Adding an option means touching four places: the options file, the `DEFAULTS` table, and the label plus tooltip in all
four `Translate/<LANG>/Sandbox.json` files. `tools/i18ncheck.py` catches the ones you forget.

## Architecture as built

**One update loop, not thirteen.** `SHAW_Tick.lua` owns the only `OnPlayerUpdate` and `EveryTenMinutes` registration.
Traits register a handler with a trait key, a sandbox option and an interval; the dispatcher resolves which handlers
apply to a character *once*, caches that list, and throttles each one. Registering a second `OnPlayerUpdate` anywhere
in this mod is a regression - it reintroduces the per-frame `hasTrait` cost the dispatcher exists to avoid. Each
handler is called inside `pcall`, so one broken trait cannot stop the other nine.

**Every trait lives in `client/`, and that is deliberate.** These traits act on the local player's own body - stats,
body damage, moodles. Project Zomboid simulates that client-side even in multiplayer and syncs the result upward, so
there is no `server/` counterpart and no command protocol. The one thing that would need `server/` is anything
deciding *world* state, and no trait here does. Colour Blind comes closest and is single-player-gated for exactly that
reason.

**Three traits share one knockdown.** Epilepsy, narcolepsy and neuralgia all mean "drop the character, stop what they
were doing, hold them there, hand control back". `SHAW_Incapacitate.lua` owns it, keyed by a `reason` string so each
trait only ticks its own episode and they cannot stack. Its state is intentionally **not** in modData: an episode lasts
seconds, so persisting it would add a throwaway timestamp to the save schema and a stale one would strand a character
on the floor after a reload.

**Persistent timers are in modData and measured in game hours.** Anything that has to survive a save - epilepsy
cooldown, the next tic, the ADHD focus - is a `SHAW_*` key holding a `SHAW.hours()` value. Every read guards against a
clock that moved backwards (a different save, a rolled-back world) by re-rolling rather than firing immediately.

**Three traits are blocked on items.** Diabetic (glucometer, insulin, bovine insulin), Asthmatic (inhaler) and
Allergic (antihistamines) have no code, because the items do not exist. Do not stub them; the item work comes first.

**Immunocompromised overrides Knox progression.** It forces instant zombification. Humans: Are Resilient's
Superimmunity blocks Knox entirely. If both mods are installed the two traits directly contradict each other. This has
to be resolved in Lua - a cross-module `MutuallyExclusiveTraits` entry would break loading when the other mod is
absent.

**Where the design could not be met exactly.** Each of these is documented at the top of its own file, and in the
README's open points. Do not "fix" one without reading the note first - they are conclusions, not omissions:

| Trait | Bible asks for | Why not, and what it does instead |
|---|---|---|
| Depressive | Hide the Hunger moodle | `MoodlesUI` is Java with no per-moodle Lua control. Not done at all |
| Ehlers-Danlos | Sprains | Sprains do not exist in 42.20. Uses stiffness + light fractures |
| Osteoarthritis | Longer attack cooldown | No attack-speed setter. Uses stiffness + hand pain via `adjustMaxTime` |
| Narcoleptic | Fall asleep | `setAsleep` fast-forwards time and restores fatigue - a *benefit*. Uses the knockdown |
| ADHD | Refuse read/wait/sleep | Only reading has a single chokepoint (`isValid`). Reading only |
| Tourette's | A vocal tic | Draws zombies via `addSound`, but silent: audio must be human-authored (LICENSE §4) |
| Colour Blind | Greyscale world | Reachable, but it is a world setting. Single player only |

## ModData schema (`player:getModData()`)

All values are game hours from `SHAW.hours()` unless noted. "Due at" keys hold an absolute hour, not a countdown, so
they need no per-tick decrement and survive a save untouched.

```lua
-- epilepsy
data.SHAW_epilepsyLastCrisis    -- hour  : when the last seizure fired (cooldown base)
data.SHAW_epilepsyIrritation    -- float : running trigger score, 0..100+
data.SHAW_epilepsyTvTimer       -- int   : consecutive seconds near a switched-on TV
data.SHAW_epilepsyLastScan      -- hour  : last light/TV world scan
data.SHAW_epilepsyLightSeen     -- bool  : cached scan result
data.SHAW_epilepsyTvSeen        -- bool  : cached scan result

-- narcolepsy
data.SHAW_narcoSleepTimer       -- hour  : next sleep attack is due at
data.SHAW_narcoSleepDuration    -- float : length of the last episode, seconds

-- neuralgia / tourette
data.SHAW_neuralgiaNext         -- hour  : next pain spike is due at
data.SHAW_touretteNext          -- hour  : next vocal tic is due at

-- adhd
data.SHAW_tdahFocusSkill        -- string: perk:getId() currently in hyperfocus
data.SHAW_tdahFocusTimer        -- hour  : focus rotates at

-- depressive / immunocompromised / ehlers-danlos
data.SHAW_lastUnhappiness       -- float : previous UNHAPPINESS, for delta scaling
data.SHAW_knoxForced            -- bool  : the Knox collapse has been applied once
data.SHAW_edsSprintRolled       -- bool  : this sprint has had its one roll
data.SHAW_edsStiffness          -- table : per-leg stiffness, for recovery drag
data.SHAW_edsForce              -- bool  : debug menu - force the next roll

-- not yet used; reserved for the item-blocked traits
-- data.SHAW_glycemia           -- float : blood sugar, 0-100        (Diabetic)
-- data.SHAW_asthmaInhalerDays  -- int   : days since last inhaler   (Asthmatic)
```

`SHAW_initialized` was in the original schema and is **not** used: every timer key self-initialises on first read, so
there is nothing a one-shot init would do. Do not reintroduce it without a reason.

## Traits

| Id | Cost | Notes |
|---|---|---|
| `SHAW:epileptic` | -12 | Needs the lock-player primitive |
| `SHAW:narcoleptic` | -12 | Needs the lock-player primitive |
| `SHAW:diabetic` | -10 | Blocked on three new items |
| `SHAW:depressive` | -6 | Needs a moodle-display hook to hide Hunger |
| `SHAW:immunocompromised` | -6 | Exclusive with `base:pronetoillness`, `base:resilient`, `base:fasthealer` |
| `SHAW:asthmatic` | -5 | Exclusive with `base:asthmatic` ("Short of Breath"). Needs the inhaler and a sound |
| `SHAW:ehlersdanlos` | -5 | Uses light fracture; dislocation does not exist in the game |
| `SHAW:neuralgia` | -5 | Needs the lock-player primitive |
| `SHAW:tourette` | -5 | Needs sound variants |
| `SHAW:allergy` | -4 | Needs a `ContainsNuts` tag or item list, and a sound |
| `SHAW:arthritis` | -4 | Pure stat modifiers - the simplest one to build first |
| `SHAW:adhd` | -4 | Exclusive with `base:fastreader`, `base:illiterate`. Needs an XP-gain hook |
| `SHAW:colorblind` | -2 | Blocked on shader feasibility |

Sound assets still to author: `asthma_breath`, `tourette_tic` (several variants), `sneeze`.
