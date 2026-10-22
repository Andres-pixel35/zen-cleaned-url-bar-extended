"""Checks that the files describing the same options agree with each other.

- preferences.json  (what Zen's mod settings page shows)
- lib/catalogue.txt (what configure.sh asks)
- chrome.css        (what the options do)
- theme.json        (the mod's entry in zen-themes.json)

Usage: python3 tests/test_consistency.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREFIX = "mod.cleanedurlbarext."
errors = []


def error(msg):
    errors.append(msg)


def read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as fh:
        return fh.read()


prefs = json.loads(read("preferences.json"))
# Comments are dropped: the header explains -moz-pref() with examples.
css = re.sub(r"/\*.*?\*/", "", read("chrome.css"), flags=re.S)
theme = json.loads(read("theme.json"))
common = read("lib/common.sh")

# --- catalogue -------------------------------------------------------------
catalogue = {}
sections = 0
for n, line in enumerate(read("lib/catalogue.txt").splitlines(), 1):
    if not line or line.startswith("#"):
        continue
    fields = line.split("|")
    if fields[0] == "@section":
        sections += 1
        if len(fields) != 3:
            error(f"catalogue line {n}: a section needs 3 fields")
        continue
    if len(fields) != 7:
        error(f"catalogue line {n}: expected 7 fields, got {len(fields)}")
        continue
    kind, pref, default, dep, question, help_, choices = fields
    if kind not in ("bool", "int", "choice"):
        error(f"catalogue line {n}: unknown kind {kind}")
    if pref in catalogue:
        error(f"catalogue: {pref} listed twice")
    if kind == "bool" and default not in ("true", "false"):
        error(f"catalogue: {pref} bool default must be true/false")
    if kind == "int" and not re.fullmatch(r"-?\d+", default):
        error(f"catalogue: {pref} int default must be a number")
    values = [c.split("=", 1)[0] for c in choices.split(";")] if choices else []
    if kind == "choice" and default not in values:
        error(f"catalogue: {pref} default {default!r} is not one of its choices")
    if not question.endswith("?"):
        error(f"catalogue: question for {pref} should end with '?'")
    if not line.isascii():
        error(f"catalogue line {n}: keep it ASCII (bash 3.2 and BSD tools)")
    catalogue[pref] = dict(kind=kind, default=default, dep=dep, values=values)
    if sections == 0:
        error("catalogue: questions before the first @section")
for pref, c in catalogue.items():
    dep = c["dep"].lstrip("!")
    if dep and dep not in catalogue:
        error(f"catalogue: {pref} depends on unknown {dep}")
    elif dep and catalogue[dep]["kind"] != "bool":
        error(f"catalogue: {pref} depends on non-bool {dep}")

# --- preferences.json ------------------------------------------------------
seen = set()
real = {}
for p in prefs:
    prop = p.get("property", "")
    if prop in seen:
        error(f"preferences.json: {prop} listed twice")
    seen.add(prop)
    if p.get("type") not in ("checkbox", "dropdown", "string"):
        error(f"preferences.json: {prop} has unsupported type {p.get('type')}")
    if not p.get("label"):
        error(f"preferences.json: {prop} has no label")
    if p.get("type") == "dropdown":
        for o in p.get("options", []):
            if not isinstance(o.get("value"), str) or o["value"] in ("", "none"):
                error(f"preferences.json: {prop} option values must be non-empty strings other than 'none'")
    if prop.startswith(PREFIX):
        if "defaultValue" not in p:
            error(f"preferences.json: mod option {prop} needs a defaultValue")
        elif p["type"] == "checkbox" and not isinstance(p["defaultValue"], bool):
            error(f"preferences.json: {prop} checkbox default must be true/false")
        elif p["type"] != "checkbox" and not isinstance(p["defaultValue"], str):
            error(f"preferences.json: {prop} default must be a string")
    else:
        real[prop] = p
        # Zen writes a defaultValue as a user value when the pref is missing; the
        # mod must never change a browser preference on its own.
        if "defaultValue" in p:
            error(f"preferences.json: browser pref {prop} must not have a defaultValue")

# Real prefs <-> catalogue
for prop, p in real.items():
    c = catalogue.get(prop)
    if not c:
        error(f"preferences.json: {prop} is not in lib/catalogue.txt (uninstall --reset-prefs would miss it)")
        continue
    want = {"bool": "checkbox", "choice": "dropdown"}.get(c["kind"])
    if p["type"] != want:
        error(f"{prop}: catalogue kind {c['kind']} but preferences.json type {p['type']}")
    if p["type"] == "dropdown" and [o["value"] for o in p["options"]] != c["values"]:
        error(f"{prop}: dropdown options differ from catalogue choices")
for prop, c in catalogue.items():
    if c["kind"] in ("bool", "choice") and prop not in real:
        error(f"catalogue: {prop} ({c['kind']}) is missing from preferences.json")
    if c["kind"] == "int" and prop in real:
        error(f"preferences.json: {prop} is an integer pref; Zen's settings page cannot edit numbers")

# --- chrome.css ------------------------------------------------------------
mod_opts = {p["property"]: p for p in prefs if p["property"].startswith(PREFIX)}
css_prefs = re.findall(r'-moz-pref\("([^"]+)"(?:,\s*"([^"]*)")?\)', css)
css_vars = set(re.findall(r"var\(--(mod-cleanedurlbarext-[a-z0-9-]+)", css))
used = set()
for name, value in css_prefs:
    if not name.startswith(PREFIX):
        error(f"chrome.css: -moz-pref on a non-mod pref {name}")
        continue
    used.add(name)
    opt = mod_opts.get(name)
    if not opt:
        error(f"chrome.css: -moz-pref({name}) has no option in preferences.json")
    elif value and value not in [o["value"] for o in opt.get("options", [])]:
        error(f"chrome.css: {name} compared with {value!r}, which is not one of its dropdown values")
    elif not value and opt["type"] == "dropdown":
        error(f"chrome.css: dropdown {name} should be compared with a value")
for var in css_vars:
    prop = PREFIX + var[len("mod-cleanedurlbarext-"):].replace("-", ".")
    if prop not in mod_opts:
        error(f"chrome.css: var(--{var}) does not match any option (expected {prop})")
    elif mod_opts[prop]["type"] != "string":
        error(f"chrome.css: var(--{var}) comes from a non-text option")
for prop, opt in mod_opts.items():
    var = prop.replace(".", "-")
    if opt["type"] == "string":
        if var not in css_vars:
            error(f"chrome.css: text option {prop} is never used as var(--{var})")
        # Text options without a fallback must be guarded so an empty value keeps Zen's style.
        if prop not in used and not re.search(r"var\(--" + re.escape(var) + r",", css):
            error(f"chrome.css: {prop} is used without a -moz-pref guard or a fallback")
    elif prop not in used:
        error(f"chrome.css: option {prop} is never read with -moz-pref")
if "@-moz-document url-prefix(\"chrome:\")" not in css:
    error("chrome.css: rules must stay inside @-moz-document url-prefix(\"chrome:\") so web pages are not affected")
if re.search(r"-moz-bool-pref", css):
    error("chrome.css: use -moz-pref(), -moz-bool-pref only exists through a Zen patch")
for decl in re.findall(r"^\s*[a-z-]+:[^;{}]+;", css, re.M):
    if "!important" not in decl and not decl.strip().startswith("--"):
        error(f"chrome.css: declaration without !important (Zen's !important rules would win): {decl.strip()}")

# --- theme.json and the scripts -------------------------------------------
mod_id = re.search(r'^MOD_ID="([^"]+)"', common, re.M).group(1)
mod_name = re.search(r'^MOD_NAME="([^"]+)"', common, re.M).group(1)
slug = re.search(r'^REPO_SLUG="([^"]+)"', read("install.sh"), re.M).group(1)
if theme.get("id") != mod_id:
    error(f"theme.json id {theme.get('id')} != MOD_ID {mod_id}")
if theme.get("name") != mod_name:
    error(f"theme.json name {theme.get('name')} != MOD_NAME {mod_name}")
if "enabled" in theme:
    error("theme.json must not contain 'enabled' (the installer adds it)")
for key, fname in (("style", "chrome.css"), ("readme", "readme.md"), ("preferences", "preferences.json")):
    want = f"https://raw.githubusercontent.com/{slug}/main/{fname}"
    if theme.get(key) != want:
        error(f"theme.json {key} should be {want}")
if not re.fullmatch(r"\d+\.\d+\.\d+", theme.get("version", "")):
    error("theme.json version should look like 1.2.3")
if PREFIX not in common:
    error("lib/common.sh MOD_PREF_PREFIX does not match the options' prefix")

if errors:
    print("\n".join("FAIL: " + e for e in errors))
    sys.exit(1)
print(f"test_consistency.py: ok ({len(prefs)} settings, {len(catalogue)} catalogue questions, "
      f"{len(css_prefs)} -moz-pref checks, {len(css_vars)} CSS variables)")
