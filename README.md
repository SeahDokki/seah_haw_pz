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
| [ADHD](#adhd) | +4 | Hyperfocus and fast reading, paid for in stress |
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

- Reading speed ×3 on all books and magazines
- **×15 XP on one random skill at a time** — hyperfocus. The boosted skill changes at random intervals
- Stress and Boredom both climb very fast
- Past a stress threshold the character refuses certain actions: waiting, reading, sleeping

Mutually exclusive with Slow Reader and Illiterate.

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

| Piece | State |
|---|---|
| Trait definitions, costs, mutual exclusions | ✅ `SHAW/42/media/scripts/SHAW_traits.txt` |
| Trait registration | ✅ `SHAW/42/media/registries.lua` |
| Names and descriptions, EN · FR · ES · DE | ✅ `Translate/<LANG>/UI.json` |
| Namespace, context helpers, sandbox config | ✅ `lua/shared/SHAW_Core.lua`, `SHAW_Config.lua` |
| Build and deploy scripts, Workshop staging | ✅ `build.ps1`, `deploy.ps1` |
| **Trait behaviour — all thirteen** | ❌ Not started |
| **New items and their recipes** | ❌ Not started |
| **Sound assets** (asthma, tic, sneeze) | ❌ Not started |

The mod loads and the traits are selectable. Picking one currently does nothing.

---

## Open points

Carried over from the design bible, plus what surfaced while scaffolding against Build 42.20.

1. **Diabetic** — blood-sugar decay rate per activity level. Does insulin expire?
2. **Colour Blind** — is a black-and-white shader reachable from Lua at all? Confirm before building on it.
3. **ADHD** — exact stress threshold for refusing actions, and the precise list of blocked actions. Is the player told
   which skill is in hyperfocus?
4. **Allergic** — which vanilla items contain peanuts? New `ContainsNuts` tag, or new items?
5. **ADHD refusal** — refusal animation, UI message, or silent block?
6. **Bovine insulin** — exact recipe, and how much worse than pharmacy insulin.
7. **Asthmatic vs `base:asthmatic`** — currently mutually exclusive. Alternative would be to drop this trait and extend
   the vanilla one instead, which would cost the mod its +5 but avoid two similar traits in the list.
8. **Trait costs** — 80 points across 13 traits is a lot of budget. Needs playtest, not arithmetic.

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
