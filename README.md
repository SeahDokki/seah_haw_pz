# Humans: Are Weak

**A Project Zomboid mod — Build 42**

Thirteen negative traits built on real, common human conditions. Each one is a mechanical constraint that actively
changes how you play — and hands you the points to pay for something better.

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20the%20mod-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/seahworld)
[![License](https://img.shields.io/badge/License-Non--Commercial%20Source--Available-8A6C1A)](LICENSE)

> ⚑ **Design phase.** The traits are defined, costed and translated into four languages — they appear in character
> creation and can be picked. **None of their behaviour is implemented yet.** See [Status](#status).

---

## Contents

- [Concept](#concept)
- [The traits](#the-traits)
- [New items](#new-items)
- [Status](#status)
- [Testing](#testing)
- [Open points](#open-points)
- [Installing](#installing)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)
- [Project documentation](#project-documentation)

---

## Concept

Vanilla's negative traits are mostly stat penalties you stop noticing by day ten. These are not. Every trait here is a
condition that keeps making decisions for you: when you can run, when you can fight, what you have to carry, what you
have to loot before it runs out.

The points they grant can be spent on positive traits at creation, which is the whole bargain — you are buying
capability with a permanent, recurring cost.

---

## The traits

**13 traits · 80 points available**

| Trait | Points | What it does to you |
|---|---|---|
| [Epileptic](#epileptic) | +12 | Seizures triggered by stress, exhaustion, light and screens |
| [Narcoleptic](#narcoleptic) | +12 | You fall asleep where you stand, without warning |
| [Diabetic](#diabetic) | +10 | Blood sugar to manage, insulin to find |
| [Depressive](#depressive) | +6 | Depression that will not lift, and apathy in a fight |
| [Immunocompromised](#immunocompromised) | +6 | Every wound infects; Knox turns you instantly |
| [Asthmatic](#asthmatic) | +5 | Poor endurance, loud breathing, attacks under strain |
| [Ehlers-Danlos Syndrome](#ehlers-danlos-syndrome) | +5 | Sprains, hairline fractures, ankles that give out |
| [Neuralgia](#neuralgia) | +5 | Random bolts of pain that lock you up |
| [Tourette's](#tourettes) | +5 | An involuntary shout at the worst moment |
| [Allergic](#allergic) | +4 | Sneezing in spring woodland; peanuts make you sick |
| [Osteoarthritis](#osteoarthritis) | +4 | Slower swings, hands that tire, worse in the cold |
| [ADHD](#adhd) | +4 | Hyperfocus on one skill; reading takes three times as long |
| [Colour Blind](#colour-blind) | +2 | The world in greyscale |

Costs are stated the way the character sheet states them: **+N means the trait gives you N points to spend.**

---

### Epileptic

*+12 points*

Convulsive seizures brought on by specific conditions.

**Triggers:** high stress · extreme fatigue · prolonged direct light (torch, headlights) · watching TV too long. A
cooldown sits between seizures.

**During a seizure:** you drop and convulse for roughly 15–20 seconds, completely helpless. The fall makes noise, which
draws zombies. A light head injury is possible. A short confused phase follows.

---

### Narcoleptic

*+12 points*

Sudden, unpredictable sleep onset — anywhere, any time.

A base random timer runs constantly. The risk climbs after a heavy meal (the Stuffed moodle) or under deep fatigue, and
drops slightly when you are well rested. You fall asleep on the spot for 30 seconds to 2 minutes of game time. You can
be attacked while out; taking damage forces you awake.

---

### Diabetic

*+10 points*

Permanent blood-sugar management. Insulin becomes as precious as ammunition.

| Blood sugar | Effect |
|---|---|
| **Below 25** — hypoglycaemia | Faintness, blurred vision, shaking. Untreated it becomes a coma, then death |
| **25–75** — normal | No effect |
| **Above 75** — hyperglycaemia | Accelerated fatigue, extreme thirst |

Eating sugar raises it fast; insulin regulates it. Hard exertion drains it faster. **Without a glucometer you cannot see
the value at all** — you are reading your own symptoms.

---

### Depressive

*+6 points*

Depression settles in and does not let go. The moodle climbs faster and falls harder than normal. At maximum
depression the Hunger moodle is hidden — you no longer know whether you are hungry. At high depression there is a
random chance you simply do not swing when you attack.

---

### Immunocompromised

*+6 points*

A severe upgrade of Prone to Illness. A scratch can be fatal.

Every wound becomes infected without antibiotics, with no natural healing. Random illness risk is significantly
raised. And the Knox Virus is absolute: **if you are infected, zombification is immediate** — no survival window, and no
mod-added cure routes around it.

Mutually exclusive with Prone to Illness, Resilient and Fast Healer.

---

### Asthmatic

*+5 points*

The inhaler becomes a survival item.

Reduced endurance with slow regeneration. Your breathing is audible when winded and aggros zombies at short range.
Prolonged running risks an attack, which locks your actions. Going a long time without an inhaler makes attacks more
frequent and more severe.

> Build 42 ships its own `base:asthmatic`, displayed as **Short of Breath** — a plain endurance penalty. This trait is
> the fuller version, and the two are mutually exclusive.

---

### Ehlers-Danlos Syndrome

*+5 points*

Joint hypermobility. Every sprint is a gamble.

Sprain probability is significantly raised, as is hairline-fracture probability on impacts. Sprinting carries a chance
of simply going down as an ankle gives. Sprains and light fractures take longer to heal than normal.

Uses the game's *light fracture*, which exists. Dislocation does not, and is not modelled.

---

### Neuralgia

*+5 points*

Bolts of excruciating pain, without warning, several times a game day. During an attack — around 10 seconds — attacking,
running and searching are all blocked. A pain animation plays with a quiet grunt, which carries as noise. The interval
is randomised within a range.

---

### Tourette's

*+5 points*

An involuntary vocal tic, at irregular intervals, at the worst possible moment. It carries roughly 15–20 tiles, the same
as a normal human shout, and pulls in every zombie in that radius. High stress makes it more frequent.

---

### Allergic

*+4 points*

Sneezing occurs **only in woodland, and only in spring** (months 3–5). Every sneeze is noise, and noise is zombies.
Separately, eating anything containing peanuts causes food poisoning year-round. Antihistamines from pharmacies suppress
the sneezing temporarily.

---

### Osteoarthritis

*+4 points*

The joints grind. Attack speed is reduced — a longer cooldown between swings — and your hands tire faster in a
prolonged fight. Cold weather adds a further penalty.

---

### ADHD

*+4 points*

The only trait here with a real upside, and it is a double-edged one.

- **Reading takes three times as long** on every book and magazine — sitting still with a page is the hard part
- **×15 XP on one random skill at a time** — hyperfocus. The boosted skill changes at random intervals
- Stress and Boredom both climb very fast
- Past a stress threshold the character refuses certain actions: waiting, reading, sleeping

So the trait pulls in two directions on the same axis: skill books become expensive in *time*, while whichever skill
is currently in hyperfocus races ahead without them.

Mutually exclusive with Fast Reader and Illiterate.

---

### Colour Blind

*+2 points*

The world rendered in black and white — a global desaturation filter. If a full-screen shader proves impossible from
Lua, the fallback is a desaturated UI only.

---

## New items

None of these exist in vanilla; all are additions this mod must ship.

| Item | Source | Used for |
|---|---|---|
| **Glucometer** | Pharmacy / hospital loot | Reads blood sugar. Needs batteries |
| **Insulin** | Pharmacy / hospital loot (rare) | Injectable, normalises blood sugar toward 50 |
| **Bovine insulin** | Craft — bovine organs + medical kit + distillation | Home-made alternative, less effective |
| **Inhaler** | Pharmacy loot (rare) | Stops an asthma attack, boosts endurance recovery |
| **Antihistamines** | Pharmacy loot | Suppresses allergic sneezing |

---

## Status

What is in the repository today:

**Ten of the thirteen traits are implemented and awaiting in-game testing.** The three that need items the mod does
not ship yet are untouched.

| Trait | State | Notes |
|---|---|---|
| Epileptic | 🔷 Written, untested | Stress · fatigue · lit torch · nearby TV, on an accumulating trigger score |
| Narcoleptic | 🔷 Written, untested | Knockdown rather than real sleep — see below |
| Depressive | 🔶 Partial | Rise/fall rates and apathy done; hiding the Hunger moodle is **not possible** |
| Immunocompromised | 🔶 Partial | Wound sepsis and illness solid; the instant Knox turn needs a bite to confirm |
| Ehlers-Danlos | 🔶 Partial | **Sprains do not exist in B42** — built from stiffness and light fractures |
| Neuralgia | 🔷 Written, untested | |
| Tourette's | 🔶 Partial | Draws zombies correctly, but **silent** — no audio asset yet |
| Osteoarthritis | 🔶 Partial | Attack *cooldown* is not Lua-settable; uses stiffness and hand pain instead |
| ADHD | 🔶 Partial | Reading ×3, hyperfocus, stress/boredom done; refuses reading only, not waiting/sleeping |
| Colour Blind | 🔷 Written, untested | Works via the climate desaturation float — **single player only** |
| Diabetic | ❌ Not started | Blocked: needs glucometer, insulin, bovine insulin |
| Asthmatic | ❌ Not started | Blocked: needs the inhaler and a breathing sound |
| Allergic | ❌ Not started | Blocked: needs antihistamines and a sneeze sound |

Supporting pieces:

| Piece | State |
|---|---|
| Trait definitions, costs, mutual exclusions | ✅ `scripts/SHAW_traits.txt` |
| Trait registration and lazy handle lookup | ✅ `registries.lua`, `shared/SHAW_Traits.lua` |
| Names and descriptions, EN · FR · ES · DE | ✅ `Translate/<LANG>/UI.json` |
| 27 sandbox options — per-trait switches and tuning | ✅ `sandbox-options.txt` |
| Single update loop with per-trait throttling | ✅ `client/SHAW_Tick.lua` |
| Shared knockdown primitive | ✅ `client/SHAW_Incapacitate.lua` |
| In-game debug menu — force any episode, dump state | ✅ `client/SHAW_DebugMenu.lua` |
| Checks: locale parity, IGUI keys, option/DEFAULTS drift | ✅ `tools/i18ncheck.py` |
| **New items and their recipes** | ❌ Not started |
| **Sound assets** (asthma, tic, sneeze) | ❌ Not started |

Nothing here has been run in the game yet — 🔷 means the code is written and statically checked, not that it works.
Enable **Debug logging** in the sandbox options to get the right-click debug menu, which forces each timed episode
rather than making you wait game-hours for one.

---

## Testing

Run `python tools/i18ncheck.py` first — it catches locale drift, undefined `IGUI_SHAW_*` keys, and any sandbox option
whose `DEFAULTS` entry has gone missing. Then:

```powershell
.\deploy.ps1
```

Launch `ProjectZomboid64ShowConsole.bat`, enable the mod, and **make a new character** — trait changes do not apply to
an existing one. Turn on **H:AW : General → Debug logging** in the sandbox options so the debug menu and the `[SHAW]`
console lines appear.

The order below is deliberate: it front-loads the traits whose mechanism is least certain.

| # | Test | How | Pass looks like |
|---|---|---|---|
| 1 | Traits register at all | New character, right-click → *H:AW (debug)* → *Inspect* → *Dump modData and traits* | Every trait prints `registered=true`; the ones you picked print `held=true` |
| 2 | Only your traits tick | Console on character load | One `active handler(s)` line naming only the traits you picked |
| 3 | Seizure | *Force* → *Seizure* | Character drops, cannot act ~18s, zombies react to the noise, then a stress jolt |
| 4 | Sleep attack | *Force* → *Sleep attack* | Drops for 30–120s. Take a hit → wakes immediately (`woken by damage`) |
| 5 | Pain spike | *Force* → *Pain spike* | Drops ~10s, Pain moodle jumps |
| 6 | Vocal tic | *Force* → *Vocal tic*, standing near zombies | Zombies turn toward you. **No sound — expected** |
| 7 | Ankle gives | *Force* → *Ankle gives*, then sprint | Trip, leg stiffness and pain, sometimes a light fracture |
| 8 | Hyperfocus | *Force* → *Reroll hyperfocus*, then train the named skill | `+N bonus xp (x15)` in console; that skill races, others do not |
| 9 | **Reading ×3** | Time a skill book with and without ADHD | Roughly three times as long, not faster |
| 10 | ADHD refusal | Raise Stress to moodle 3+, try to read | Halo text, book does not open |
| 11 | Osteoarthritis | Fight until winded, then check *Dump stats* | Endurance drains faster; actions get slower as hand pain rises |
| 12 | Depressive | Let depression reach moodle 3–4 and swing repeatedly | Some swings do not happen, with halo text |
| 13 | **Knox instant turn** | Immunocompromised character, get bitten | Turns immediately, no multi-day window. **The least certain test** |
| 14 | Wound sepsis | Immunocompromised, take any scratch | Wound flags infected within seconds, halo text |
| 15 | Colour Blind | Single player | World goes greyscale, and stays greyscale across weather changes |
| 16 | Per-trait switches | Turn a trait off in sandbox, reload | Its handler disappears from the `active handler(s)` line |
| 17 | Nothing leaks | Character *without* any H:AW trait | Zero `[SHAW]` handler lines, no debug menu effects |

If a trait misbehaves, *Release from episode* frees a stuck character and *Rebuild handler list* re-resolves the
handlers without a reload.

---

## Open points

Carried over from the design bible, plus what surfaced while scaffolding against Build 42.20.

### Resolved while implementing

- **Colour Blind shader** — no shader needed. `ClimateManager`'s `FLOAT_DESATURATION` is reachable from Lua via the
  same admin-override path the game's own climate debug panel uses. But it is a **world** setting, not per-character,
  so the trait is disabled outside single player rather than greying the world for everyone on a shared client.
- **ADHD reading direction** — three times as *long*, not faster. Which is also why the trait is now mutually
  exclusive with Fast Reader rather than Slow Reader.

### Blocked by the engine

- **Depressive: hiding the Hunger moodle.** The moodle bar is `zombie.ui.MoodlesUI`, a Java class with no per-moodle
  Lua visibility control — it is not an ISUI panel a mod can subclass or wrap. `MoodleType.HUNGRY` exists as an enum
  value but nothing in Lua can suppress its row. Doing this means reimplementing the whole vanilla moodle widget.
- **Ehlers-Danlos: sprains.** They do not exist in 42.20 — no `setSprained`, no `isSprained`, no Sprain buff anywhere
  in the API. The bible's primary mechanic is unavailable, so the trait is built from joint stiffness (B42's
  muscle-strain value) plus light fractures, which do exist.
- **Osteoarthritis: attack cooldown.** `BodyDamage` has `getMeleeCombatMod()` with no setter, and there is no
  `setAttackSpeed`. The trait uses stiffness and hand pain instead — `adjustMaxTime` already multiplies action
  duration by hand pain, so the felt result is close and the mechanism is the engine's own.
- **Narcoleptic: real sleep.** `setAsleep(true)` fast-forwards time and restores fatigue, which would turn the trait
  into a *benefit* — free hours, free rest, and the danger skipped past. It uses the knockdown primitive instead, so
  the character is genuinely helpless in real time. Consequence: they are not "asleep" as far as the engine is
  concerned, so sleep-related moodles do not move during an episode.

### Still open

1. **Diabetic** — blood-sugar decay rate per activity level. Does insulin expire?
2. **Allergic** — which vanilla items contain peanuts? New `ContainsNuts` tag, or new items?
3. **ADHD refusal scope** — reading is refused past the stress threshold. Waiting and sleeping are not: sleep has no
   single chokepoint in 42.20, it goes through several context-menu entries and a dialog. Worth four fragile hooks?
4. **Bovine insulin** — exact recipe, and how much worse than pharmacy insulin.
5. **Asthmatic vs `base:asthmatic`** — currently mutually exclusive. Vanilla's is labelled *Short of Breath*, so the
   names do not collide, but the mechanics overlap. Alternative: drop this trait and extend the vanilla one.
6. **Immunocompromised: the instant Knox turn.** `setInfectionMortalityDuration`, `setInfectionGrowthRate` and
   `setInfectionTime` are pushed toward "finish now", but their units are undocumented and no vanilla Lua file uses
   them. Each call is guarded so a wrong signature costs the instant turn rather than crashing. **Confirm by getting
   bitten.**
7. **Tourette's and the other sounds** — the tic draws zombies but is silent to the player. Audio must be
   human-authored under [LICENSE](LICENSE) §4, so no placeholder was generated.
8. **Trait costs** — 80 points across 13 traits is a lot of budget. Needs playtest, not arithmetic.
9. **Trigger tuning** — the epilepsy irritation rates, the EDS trip chance and the ADHD stress thresholds are first
   guesses exposed as sandbox options precisely because they will be wrong.

---

## Installing

**From source, for development:**

```powershell
.\deploy.ps1            # copies SHAW\ into %USERPROFILE%\Zomboid\mods\SHAW\
.\deploy.ps1 -DryRun    # shows what it would do, writes nothing
```

Then enable **Humans: Are Weak** in the in-game Mods menu and start a save. Lua errors go to
`%USERPROFILE%\Zomboid\console.txt`.

**Staging for the Workshop:**

```powershell
.\build.ps1             # builds %USERPROFILE%\Zomboid\Workshop\SHAW\
```

`workshop.txt` is never overwritten once it exists — after the first upload it holds the published item id, and losing
it would publish a duplicate instead of an update.

---

## Contributing

Contributions are welcome — bug fixes, behaviour tuning, compatibility patches and translations.

- **Code is English-only.** Names and comments in English, no exceptions.
- **No hardcoded player-facing strings.** Everything goes through the translation files: EN, FR, ES and DE at minimum,
  all four updated in the same change. `python tools/i18ncheck.py` verifies they stay in step.
- **All identifiers are prefixed `SHAW`** — mod id, modData keys, Lua namespaces, translation keys.
- **No AI-generated assets.** AI assistance on code and translations is fine; images, textures, models, sounds and music
  must be human-authored. See [LICENSE](LICENSE) §4.

By contributing you agree to the terms in [LICENSE](LICENSE) §5.

---

## License

Humans: Are Weak is **source-available, not open source** — see [LICENSE](LICENSE) for the terms that actually apply.

**You may**, free of charge and without asking: play it on any private or public server, study and modify it for your
own use, contribute changes back, build compatibility or add-on mods, and include it in modpacks unmodified and
credited.

**You may not**: claim authorship or republish it under another name, sell it or put it behind a paywall, relicense it,
or contribute AI-generated assets.

Credit as **Humans: Are Weak by Seah (SeahDokki)** with a link back to this repository.

---

## Support

If you enjoy the mod, you can support its development on Ko-fi:

**☕ [ko-fi.com/seahworld](https://ko-fi.com/seahworld)**

---

## Project documentation

| File | Contents |
|---|---|
| `README.md` | This document — the design reference |
| [haw-design-bible.md](haw-design-bible.md) | The original design bible (French) — spec of record |
| [pz-haw-design.html](pz-haw-design.html) | Styled HTML version of the bible |
| [CLAUDE.md](CLAUDE.md) | Implementation reference: environment, Build 42 layout, conventions |
