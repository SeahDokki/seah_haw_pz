# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Humans: Are Weak (H:AW) is a **Project Zomboid mod in design phase**. The traits and occupations are declared, costed and
translated; **none of their behaviour is implemented**.

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

## Architecture the design implies

**Everything is a timer, and the timers live in modData.** Nine of the thirteen traits are "something happens at a
random interval, or after a threshold is crossed". The natural shape is one `OnPlayerUpdate` dispatcher that ticks a
table of per-trait handlers, plus `EveryTenMinutes` for the slow-moving values (blood sugar, the ADHD focus skill).
Do not register thirteen separate `OnPlayerUpdate` callbacks.

**Most of this mod is client-side.** These traits act on the local player: moodles, screen effects, blocked input,
sounds. `media/lua/client/` is the default home. The exceptions are anything that writes durable state a server has to
agree with - blood sugar in particular, since it can kill you.

**Seizures, sleep attacks and pain spikes all need the same primitive:** take control away from the player for N
seconds, play an animation, emit a world sound, then give it back. Build that once and share it, rather than three
near-identical lock/unlock implementations.

**Two traits need new items, and one needs a shader.** The Diabetic (glucometer, insulin, bovine insulin), the
Asthmatic (inhaler) and the Allergic (antihistamines) all depend on items that do not exist yet - those traits cannot
be finished before the items are. Colour Blind depends on a full-screen desaturation shader whose feasibility from Lua
is **unconfirmed**; check that before building anything on it, and fall back to a desaturated UI if it does not exist.

**Immunocompromised overrides Knox progression.** It forces instant zombification. Humans: Are Resilient's
Superimmunity blocks Knox entirely. If both mods are installed the two traits directly contradict each other. This has
to be resolved in Lua - a cross-module `MutuallyExclusiveTraits` entry would break loading when the other mod is
absent.

## ModData schema (`player:getModData()`)

```lua
data.SHAW_initialized           -- bool  : character already processed
data.SHAW_epilepsyLastCrisis    -- int   : timestamp of the last seizure (cooldown)
data.SHAW_epilepsyTvTimer       -- float : cumulative time spent watching TV
data.SHAW_narcoSleepTimer       -- float : countdown to the next sleep attack
data.SHAW_glycemia              -- float : blood sugar, 0-100
data.SHAW_tdahFocusSkill        -- string: skill currently under hyperfocus (x15 XP)
data.SHAW_tdahFocusTimer        -- float : countdown to the next focus switch
data.SHAW_touretteTimer         -- float : countdown to the next vocal tic
data.SHAW_neuralgiaTimer        -- float : countdown to the next pain spike
data.SHAW_asthmaInhalerDays     -- int   : days since the last inhaler use
```

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
| `SHAW:adhd` | -4 | Exclusive with `base:slowreader`, `base:illiterate`. Needs an XP-gain hook |
| `SHAW:colorblind` | -2 | Blocked on shader feasibility |

Sound assets still to author: `asthma_breath`, `tourette_tic` (several variants), `sneeze`.
