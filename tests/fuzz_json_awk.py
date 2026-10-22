"""Fuzz lib/json.awk against Python's json module with every awk available.

Usage: python3 tests/fuzz_json_awk.py [iterations]
"""
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AWK_FILE = os.path.join(ROOT, "lib", "json.awk")
AWKS = [a for a in ("gawk", "mawk", "original-awk", "busybox awk") if shutil.which(a.split()[0])]
CHARS = "abc XYZ-_.:,{}[]\"\\/ü€\t"


def rand_str(r):
    return "".join(r.choice(CHARS) for _ in range(r.randint(0, 8)))


def rand_value(r, depth=0):
    kind = r.choice(["str", "num", "bool", "null", "obj", "arr"] if depth < 3 else ["str", "num", "bool", "null"])
    if kind == "str":
        return rand_str(r)
    if kind == "num":
        return r.choice([0, -1, 3.5, 1e21, 42, -0.25])
    if kind == "bool":
        return r.choice([True, False])
    if kind == "null":
        return None
    if kind == "obj":
        return {rand_str(r).replace(".", "") or "k": rand_value(r, depth + 1) for _ in range(r.randint(0, 4))}
    return [rand_value(r, depth + 1) for _ in range(r.randint(0, 4))]


def flatten(v, path=""):
    if isinstance(v, dict):
        for k, x in v.items():
            yield from flatten(x, k if path == "" else path + "." + k)
    elif isinstance(v, list):
        for i, x in enumerate(v):
            yield from flatten(x, f"{path}[{i}]")
    else:
        yield path, v


def run(awk, mode, path, env=None):
    e = dict(os.environ, **(env or {}))
    p = subprocess.run(awk.split() + ["-f", AWK_FILE, "-v", f"mode={mode}", path], capture_output=True, text=True, env=e)
    return p.returncode, p.stdout, p.stderr


def check(r, awk, tmp):
    doc = {rand_str(r).replace(".", "") or "id": rand_value(r) for _ in range(r.randint(0, 5))}
    # Top-level keys are compared as written in the file, so keep them free of escapes (like real mod ids).
    doc = {"".join(ch for ch in k if ch.isascii() and ch not in '"\\\t'): v for k, v in doc.items()}
    indent = r.choice([None, 2, 4, "\t"])
    text = json.dumps(doc, indent=indent, ensure_ascii=r.choice([True, False]))
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text + r.choice(["", "\n", "\n\n  "]))
    # flatten
    code, out, err = run(awk, "flatten", tmp)
    assert code == 0, (awk, err, text)
    got = [line.split("\t", 1) for line in out.splitlines()] if out else []
    want = list(flatten(doc))
    assert len(got) == len(want), (awk, text, out)
    for (gp, graw), (wp, wv) in zip(got, want):
        assert json.loads(graw) == wv, (awk, gp, graw, wv)
    # get / set / del on a random existing or new key
    keys = list(doc) + ["new-key"]
    key = r.choice(keys)
    code, out, err = run(awk, "get", tmp, {"ZCUB_JSON_KEY": key})
    if key in doc:
        assert code == 0 and json.loads(out) == doc[key], (awk, key, out, text)
    else:
        assert code == 1, (awk, key, out)
    newval = rand_value(r)
    raw = json.dumps(newval, indent=r.choice([None, 4]))
    code, out, err = run(awk, "set", tmp, {"ZCUB_JSON_KEY": key, "ZCUB_JSON_VALUE": raw})
    assert code == 0, (awk, err)
    want = dict(doc)
    want.pop(key, None)
    want[key] = newval
    assert json.loads(out) == want and list(json.loads(out)) == list(want), (awk, out, want)
    code, out, err = run(awk, "del", tmp, {"ZCUB_JSON_KEY": key})
    want = dict(doc)
    want.pop(key, None)
    assert code == 0 and json.loads(out) == want, (awk, out, want)


def check_invalid(awk, tmp):
    for bad in ["[1, 2]", "{\"a\": 1,}", "{\"a\" 1}", "{\"a\": \"x}", "{} x", "{\"a\": [1, 2}"]:
        with open(tmp, "w") as fh:
            fh.write(bad)
        code, _, err = run(awk, "set", tmp, {"ZCUB_JSON_KEY": "k", "ZCUB_JSON_VALUE": "1"})
        assert code == 2 and "invalid JSON" in err, (awk, bad, code, err)
    with open(tmp, "w") as fh:
        fh.write("")
    code, out, _ = run(awk, "set", tmp, {"ZCUB_JSON_KEY": "k", "ZCUB_JSON_VALUE": "{\"x\":true}"})
    assert code == 0 and json.loads(out) == {"k": {"x": True}}, (awk, out)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    assert AWKS, "no awk found"
    with tempfile.TemporaryDirectory() as d:
        tmp = os.path.join(d, "t.json")
        for awk in AWKS:
            r = random.Random(1234)
            for _ in range(n):
                check(r, awk, tmp)
            check_invalid(awk, tmp)
            print(f"ok  {awk}: {n} random documents + invalid inputs")


if __name__ == "__main__":
    main()
