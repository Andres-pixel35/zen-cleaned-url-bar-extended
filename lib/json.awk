# Minimal JSON helper for the scripts, so they need neither jq nor python.
# Plain POSIX awk: works with gawk, mawk and the BSD awk shipped with macOS.
#
#   awk -f json.awk -v mode=flatten FILE
#       One line per scalar: <path><TAB><raw JSON value>, e.g. `[3].defaultValue<TAB>"25px"`
#       or `my-mod.enabled<TAB>true`.
#   ZCUB_JSON_KEY=K awk -f json.awk -v mode=get FILE
#       Raw JSON value of the top-level key K (exit status 1 when it is missing).
#   ZCUB_JSON_KEY=K ZCUB_JSON_VALUE=RAW awk -f json.awk -v mode=set FILE
#       FILE with the top-level key K set to RAW, printed in compact form.
#   ZCUB_JSON_KEY=K awk -f json.awk -v mode=del FILE
#       FILE without the top-level key K, printed in compact form.
#
# Keys and values come from the environment because `awk -v` would interpret
# the backslash escapes they may contain. An empty FILE counts as `{}`.
# Invalid JSON prints an error and exits with status 2.

function fail(msg) {
    print "json.awk: invalid JSON: " msg " (at character " pos ")" > "/dev/stderr"
    exit 2
}

function skip_ws() {
    while (pos <= len && index(" \t\r\n", substr(text, pos, 1)))
        pos++
}

# Parses the string starting at pos (on its opening quote) and returns its
# content as written in the file (escapes are kept).
function parse_string(    start, c) {
    if (substr(text, pos, 1) != "\"")
        fail("expected a string")
    start = ++pos
    while (pos <= len) {
        c = substr(text, pos, 1)
        if (c == "\\")
            pos += 2
        else if (c == "\"") {
            pos++
            return substr(text, start, pos - 1 - start)
        } else
            pos++
    }
    fail("unterminated string")
}

# Parses the value starting at pos and returns its raw text. In flatten mode it
# also prints every scalar with its path.
function parse_value(path,    start, c, key, n) {
    skip_ws()
    start = pos
    c = substr(text, pos, 1)
    if (c == "{") {
        pos++
        skip_ws()
        if (substr(text, pos, 1) == "}") {
            pos++
        } else {
            while (1) {
                skip_ws()
                key = parse_string()
                skip_ws()
                if (substr(text, pos, 1) != ":")
                    fail("expected ':'")
                pos++
                parse_value(path == "" ? key : path "." key)
                skip_ws()
                c = substr(text, pos++, 1)
                if (c == "}")
                    break
                if (c != ",")
                    fail("expected ',' or '}'")
            }
        }
    } else if (c == "[") {
        pos++
        n = 0
        skip_ws()
        if (substr(text, pos, 1) == "]") {
            pos++
        } else {
            while (1) {
                parse_value(path "[" n++ "]")
                skip_ws()
                c = substr(text, pos++, 1)
                if (c == "]")
                    break
                if (c != ",")
                    fail("expected ',' or ']'")
            }
        }
    } else {
        if (c == "\"")
            parse_string()
        else {
            while (pos <= len && !index(",:}] \t\r\n", substr(text, pos, 1)))
                pos++
            if (pos == start)
                fail("unexpected character")
        }
        if (mode == "flatten")
            print path "\t" substr(text, start, pos - start)
    }
    return substr(text, start, pos - start)
}

{ text = text $0 "\n" }

END {
    len = length(text)
    pos = 1

    if (mode == "flatten") {
        skip_ws()
        if (pos <= len)
            parse_value("")
        skip_ws()
        if (pos <= len)
            fail("unexpected data after the end")
        exit 0
    }

    # get / set / del work on the members of the top-level object.
    count = 0
    skip_ws()
    if (pos <= len) {
        if (substr(text, pos, 1) != "{")
            fail("the top level is not an object")
        pos++
        skip_ws()
        if (substr(text, pos, 1) == "}") {
            pos++
        } else {
            while (1) {
                skip_ws()
                keys[++count] = parse_string()
                skip_ws()
                if (substr(text, pos, 1) != ":")
                    fail("expected ':'")
                pos++
                values[count] = parse_value("")
                skip_ws()
                c = substr(text, pos++, 1)
                if (c == "}")
                    break
                if (c != ",")
                    fail("expected ',' or '}'")
            }
        }
        skip_ws()
        if (pos <= len)
            fail("unexpected data after the end")
    }

    key = ENVIRON["ZCUB_JSON_KEY"]
    if (mode == "get") {
        for (i = 1; i <= count; i++)
            if (keys[i] == key) {
                print values[i]
                exit 0
            }
        exit 1
    }
    if (mode != "set" && mode != "del") {
        print "json.awk: unknown mode '" mode "'" > "/dev/stderr"
        exit 2
    }
    out = "{"
    sep = ""
    for (i = 1; i <= count; i++)
        if (keys[i] != key) {
            out = out sep "\"" keys[i] "\":" values[i]
            sep = ","
        }
    if (mode == "set")
        out = out sep "\"" key "\":" ENVIRON["ZCUB_JSON_VALUE"]
    print out "}"
}
