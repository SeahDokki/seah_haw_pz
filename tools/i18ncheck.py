"""Check the H:AW translations and option wiring.

- every locale defines the same keys as EN
- every `translation =` / `page =` in sandbox-options.txt has an EN entry
- every IGUI_SHAW_* key referenced from Lua exists in EN/IG_UI.json
- the DEFAULTS table in SHAW_Config.lua matches sandbox-options.txt
- no stray legacy .txt file is left behind (B42 loads .json only)

Run from the repo root:  python tools/i18ncheck.py
"""
import glob
import io
import json
import os
import re
import sys

ROOT = "SHAW/42/media/lua/shared/Translate"
LUA = "SHAW/42/media/lua"
OPTIONS_FILE = "SHAW/42/media/sandbox-options.txt"
CONFIG_FILE = "SHAW/42/media/lua/shared/SHAW_Config.lua"
LANGS = ("EN", "FR", "ES", "DE")

failed = False


def fail(message):
    global failed
    failed = True
    print("FAIL " + message)


# B42 dropped the .txt translation format entirely.
stale = glob.glob(os.path.join(ROOT, "*", "*.txt"))
if stale:
    fail("legacy .txt files still present: %s" % sorted(stale))

# ---------------------------------------------------------------- locales --

for name in ("Sandbox", "IG_UI", "UI"):
    keys_by_lang = {}
    for lang in LANGS:
        path = os.path.join(ROOT, lang, "%s.json" % name)
        if not os.path.exists(path):
            fail("missing %s" % path)
            continue
        try:
            data = json.load(io.open(path, encoding="utf-8"))
        except ValueError as exc:
            fail("invalid JSON in %s : %s" % (path, exc))
            continue
        keys_by_lang[lang] = set(data)

    if "EN" not in keys_by_lang:
        continue

    reference = keys_by_lang["EN"]
    for lang, keys in sorted(keys_by_lang.items()):
        missing = reference - keys
        extra = keys - reference
        if missing or extra:
            fail("%s/%s : missing=%s extra=%s"
                 % (name, lang, sorted(missing), sorted(extra)))

    print("%-8s %d keys x %d locales" % (name, len(reference), len(keys_by_lang)))

# ------------------------------------------------------- sandbox coverage --

options = io.open(OPTIONS_FILE, encoding="utf-8").read()
en_sandbox = set(json.load(io.open(os.path.join(ROOT, "EN", "Sandbox.json"), encoding="utf-8")))

OPT_TRANSLATION = re.compile(r"^\s*translation\s*=\s*(\w+)\s*,", re.M)
OPT_PAGE = re.compile(r"^\s*page\s*=\s*(\w+)\s*,", re.M)

referenced = {"Sandbox_" + n for n in OPT_TRANSLATION.findall(options)}
referenced |= {"Sandbox_" + n for n in set(OPT_PAGE.findall(options))}

undefined = referenced - en_sandbox
if undefined:
    fail("options with no translation: %s" % sorted(undefined))
else:
    print("sandbox  all %d option/page keys translated" % len(referenced))

unused = {k for k in en_sandbox if not k.endswith("_tooltip")} - referenced
if unused:
    print("note: translated but unreferenced: %s" % sorted(unused))

# ---------------------------------------------------- IGUI key coverage ---

# Any IGUI_SHAW_* string literal anywhere in the Lua, not only inside a
# getText() call: the trait modules pass keys through SHAW.sayBad/sayGood, and
# scanning only for getText() silently missed every one of them.
en_igui = set(json.load(io.open(os.path.join(ROOT, "EN", "IG_UI.json"), encoding="utf-8")))
IGUI_LITERAL = re.compile(r'"(IGUI_SHAW_\w+)"')

used = set()
for lua in glob.glob(os.path.join(LUA, "**", "*.lua"), recursive=True):
    used |= set(IGUI_LITERAL.findall(io.open(lua, encoding="utf-8").read()))

missing = used - en_igui
if missing:
    fail("IGUI keys used in Lua with no IG_UI entry: %s" % sorted(missing))
else:
    print("igui     all %d IGUI_SHAW keys used in Lua are defined" % len(used))

# ModName and Tagline are metadata, referenced from mod.info context rather
# than from Lua, so they are not expected to appear in a source file.
unused_igui = en_igui - used - {"IGUI_SHAW_ModName", "IGUI_SHAW_Tagline"}
if unused_igui:
    print("note: IGUI keys defined but unused: %s" % sorted(unused_igui))

# ------------------------------------------- sandbox option / DEFAULTS ----

# CLAUDE.md says these two must stay in step. This is the check that makes
# that true rather than aspirational.
OPTION_NAME = re.compile(r"^\s*option\s+SHAW\.(\w+)\s*$", re.M)
declared = set(OPTION_NAME.findall(options))

config = io.open(CONFIG_FILE, encoding="utf-8").read()
block = re.search(r"local DEFAULTS = \{(.*?)\n\}", config, re.S)

if not block:
    fail("could not find the DEFAULTS table in %s" % CONFIG_FILE)
elif not declared:
    fail("no `option SHAW.<Name>` lines found in %s" % OPTIONS_FILE)
else:
    defaulted = set(re.findall(r"^\s*(\w+)\s*=", block.group(1), re.M))

    missing_default = declared - defaulted
    extra_default = defaulted - declared
    if missing_default or extra_default:
        fail("DEFAULTS drift: absent from Lua=%s, absent from options=%s"
             % (sorted(missing_default), sorted(extra_default)))
    else:
        print("config   all %d options have a matching DEFAULTS entry" % len(declared))

sys.exit(1 if failed else 0)
