# shellcheck shell=bash
# Shared code for install.sh, update.sh, uninstall.sh and configure.sh.
#
# Written for bash 3.2 (the version macOS ships): no associative arrays, no
# ${var,,}, no mapfile, and no `set -u` (empty arrays break it on bash < 4.4).
# Only POSIX tools are used (awk, sed, grep, cp, mv, mktemp), and the awk code
# works with the BSD awk of macOS as well as gawk and mawk.

MOD_ID="zen-cleaned-url-bar-extended"
# shellcheck disable=SC2034 # used by the scripts that source this file
MOD_NAME="Cleaned URL Bar Extended"
# shellcheck disable=SC2034 # used by uninstall.sh
MOD_PREF_PREFIX="mod.cleanedurlbarext."
# The only files Zen reads from a mod folder (it never opens a local readme.md).
MOD_FILES="chrome.css preferences.json"
BACKUP_SUFFIX=".cleanedurlbarext.bak"

LIB_DIR="$ROOT_DIR/lib"

# ---------------------------------------------------------------- output ----

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
    C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_BLUE=$'\033[34m'
else
    # shellcheck disable=SC2034 # C_DIM is used by lib/configure.sh
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
fi

say() { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok() { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%sWarning:%s %s\n' "$C_YELLOW$C_BOLD" "$C_RESET" "$*" >&2; }
die() {
    printf '%sError:%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2
    exit 1
}

# ------------------------------------------------------- temp and cleanup ----

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cleaned-url-bar-work.XXXXXX") || die "Could not create a temporary directory."

cleanup() {
    rm -rf "$WORK_DIR"
    # Set by the curl | bash bootstrap: the downloaded copy of the project.
    case "${ZCUB_BOOTSTRAP_DIR:-}" in
        */cleaned-url-bar.*) rm -rf "$ZCUB_BOOTSTRAP_DIR" ;;
    esac
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ------------------------------------------------------------ questions ----

# Questions are read from file descriptor 3: the terminal, also when the script
# itself arrives through `curl ... | bash` (then stdin is the script, not you).
TTY_STATE=""
open_tty() {
    case "$TTY_STATE" in
        yes) return 0 ;;
        no) return 1 ;;
    esac
    if [ -t 0 ]; then
        exec 3<&0
        TTY_STATE=yes
    elif (: </dev/tty) 2>/dev/null; then
        exec 3</dev/tty
        TTY_STATE=yes
    else
        TTY_STATE=no
        return 1
    fi
}

# ask "Prompt" -> answer in $REPLY (dies when there is no terminal or input ended)
ask() {
    open_tty || die "This needs an answer, but there is no terminal to ask on."
    printf '%s' "$1"
    IFS= read -r REPLY <&3 || {
        printf '\n'
        die "No answer (input closed)."
    }
}

# ask_yes_no "Question" y|n -> status 0 for yes; Enter picks the default
ask_yes_no() {
    local hint="[y/N]"
    [ "$2" = y ] && hint="[Y/n]"
    while :; do
        ask "$1 $hint "
        case "$REPLY" in
            "") [ "$2" = y ]; return ;;
            y | Y | yes | Yes | YES) return 0 ;;
            n | N | no | No | NO) return 1 ;;
        esac
        say "Please answer y or n."
    done
}

# ------------------------------------------------------------- profiles ----

# Folders where Zen keeps profiles.ini. Zen uses the legacy ~/.zen when it
# exists and $XDG_CONFIG_HOME/zen otherwise; Flatpak keeps both inside its sandbox.
zen_roots() {
    if [ "$(uname -s)" = Darwin ]; then
        printf '%s\n' "$HOME/Library/Application Support/zen"
    else
        printf '%s\n' \
            "$HOME/.zen" \
            "${XDG_CONFIG_HOME:-$HOME/.config}/zen" \
            "$HOME/.var/app/app.zen_browser.zen/.zen" \
            "$HOME/.var/app/app.zen_browser.zen/config/zen"
    fi
}

# Prints "<absolute profile path>\037<name>\037<rank>" for every profile in a
# root folder. rank 2 = the profile an installed Zen opens by default
# ([Install...] sections / installs.ini), 1 = marked Default=1, 0 = other.
list_root_profiles() {
    local root=$1 files
    [ -f "$root/profiles.ini" ] || return 0
    files=("$root/profiles.ini")
    [ -f "$root/installs.ini" ] && files+=("$root/installs.ini")
    awk -v root="$root" '
        function flush() {
            if (sec ~ /^Profile/ && path != "") {
                n++
                ppath[n] = path; pname[n] = name; prel[n] = rel; pdef[n] = def
            }
            name = ""; path = ""; rel = "1"; def = ""
        }
        { sub(/\r$/, "") }
        /^\[.*\]$/ {
            flush()
            sec = substr($0, 2, length($0) - 2)
            isinstall = (FILENAME ~ /installs\.ini$/) || (sec ~ /^Install/)
            next
        }
        {
            eq = index($0, "=")
            if (!eq) next
            k = substr($0, 1, eq - 1); v = substr($0, eq + 1)
            if (isinstall && k == "Default") installdef[v] = 1
            else if (k == "Name") name = v
            else if (k == "Path") path = v
            else if (k == "IsRelative") rel = v
            else if (k == "Default") def = v
        }
        END {
            flush()
            for (i = 1; i <= n; i++) {
                abs = (prel[i] == "1") ? root "/" ppath[i] : ppath[i]
                rank = (ppath[i] in installdef || abs in installdef) ? 2 : (pdef[i] == "1" ? 1 : 0)
                print abs "\037" pname[i] "\037" rank
            }
        }
    ' "${files[@]}"
}

looks_like_profile() {
    [ -f "$1/prefs.js" ] || [ -f "$1/times.json" ] || [ -f "$1/compatibility.ini" ]
}

# select_profile [-p argument] -> sets PROFILE (absolute path)
select_profile() {
    local arg=$1 roots root path name rank known
    local cand_path=() cand_name=() cand_rank=()

    if [ -n "$arg" ]; then
        arg=${arg%/}
        [ -d "$arg" ] || die "'$arg' is not a folder."
        arg=$(cd "$arg" && pwd)
        if [ -f "$arg/profiles.ini" ]; then
            roots=$arg
        elif looks_like_profile "$arg"; then
            PROFILE=$arg
            return 0
        else
            die "'$arg' is neither a Zen profile folder (no prefs.js) nor a Zen folder with profiles.ini. Open about:support in Zen and use the 'Profile Directory' shown there."
        fi
    else
        roots=$(zen_roots)
    fi

    while IFS= read -r root; do
        [ -n "$root" ] || continue
        while IFS=$'\037' read -r path name rank; do
            [ -d "$path" ] || continue
            # The same profile can be listed by more than one profiles.ini.
            for known in ${cand_path[@]+"${cand_path[@]}"}; do
                [ "$known" = "$path" ] && continue 2
            done
            cand_path+=("$path")
            cand_name+=("$name")
            cand_rank+=("$rank")
        done <<EOF
$(list_root_profiles "$root")
EOF
    done <<EOF
$roots
EOF

    local count=${#cand_path[@]}
    [ "$count" -gt 0 ] || die "No Zen profile found. Start Zen once, or pass the profile folder with -p (see about:support > Profile Directory)."

    # Prefer the profile Zen opens by default; ask only when that is ambiguous.
    local best=-1 best_count=0 i
    for rank in 2 1 0; do
        best_count=0
        for ((i = 0; i < count; i++)); do
            if [ "${cand_rank[$i]}" = "$rank" ]; then
                best_count=$((best_count + 1))
                best=$i
            fi
        done
        [ "$best_count" -gt 0 ] && break
    done
    if [ "$best_count" -eq 1 ] && { [ "$rank" != 0 ] || [ "$count" -eq 1 ]; }; then
        PROFILE=${cand_path[$best]}
        info "Using Zen profile \"${cand_name[$best]}\": $PROFILE"
        [ "$count" -gt 1 ] && say "    (Other profiles exist; pass -p <folder> to use another one.)"
        return 0
    fi

    local list="" mark
    for ((i = 0; i < count; i++)); do
        mark=""
        [ "${cand_rank[$i]}" = 2 ] && mark=" (opened by default)"
        list="$list  $((i + 1))) ${cand_name[$i]}$mark"$'\n'"       ${cand_path[$i]}"$'\n'
    done
    if ! open_tty; then
        die "Several Zen profiles were found; choose one with -p <folder>:"$'\n'"$list"
    fi
    say "Several Zen profiles were found:"
    printf '%s' "$list"
    while :; do
        ask "Which one? [1-$count] "
        case "$REPLY" in
            '' | *[!0-9]*) ;;
            *)
                if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "$count" ]; then
                    PROFILE=${cand_path[$((REPLY - 1))]}
                    info "Using Zen profile \"${cand_name[$((REPLY - 1))]}\": $PROFILE"
                    return 0
                fi
                ;;
        esac
        say "Please enter a number between 1 and $count."
    done
}

# Sets the paths used by the other functions once PROFILE is known.
set_profile_paths() {
    PREFS_JS="$PROFILE/prefs.js"
    USER_JS="$PROFILE/user.js"
    THEMES_JSON="$PROFILE/zen-themes.json"
    MOD_DIR="$PROFILE/chrome/zen-themes/$MOD_ID"
}

# ------------------------------------------------------- is Zen running? ----

zen_process_exists() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -x 'zen(-bin)?' >/dev/null 2>&1
    else
        # shellcheck disable=SC2009 # fallback for systems without pgrep
        ps -A -o comm= 2>/dev/null | grep -Eq '(^|/)zen(-bin)?$'
    fi
}

# Status 0 when Zen seems to be running with the profile.
zen_running() {
    local profile=$1 target pid
    if [ -L "$profile/lock" ]; then
        # Linux: "lock" is a symlink to "<host>:+<pid>" while Zen runs.
        target=$(readlink "$profile/lock" 2>/dev/null)
        pid=${target##*+}
        case "$pid" in '' | *[!0-9]*) pid="" ;; esac
        if [ -n "$pid" ] && [ -r "/proc/$pid/comm" ]; then
            case "$(cat "/proc/$pid/comm" 2>/dev/null)" in zen | zen-bin) return 0 ;; esac
        fi
        # Flatpak runs Zen in its own PID namespace, so the pid may mean nothing
        # here. Without any Zen process the lock is a leftover from a crash.
        zen_process_exists
        return
    fi
    if [ "$(uname -s)" = Darwin ] && [ -e "$profile/.parentlock" ]; then
        # macOS: Zen keeps .parentlock open while it runs.
        if command -v lsof >/dev/null 2>&1; then
            [ -n "$(lsof -t "$profile/.parentlock" 2>/dev/null)" ]
            return
        fi
        zen_process_exists
        return
    fi
    return 1
}

# Zen rewrites prefs.js and zen-themes.json while it runs and when it quits, so
# changes made under a running Zen would be lost.
require_zen_closed() {
    zen_running "$PROFILE" || return 0
    if ! open_tty; then
        die "Zen is running with this profile. Close Zen completely and run this again. (If Zen is not running, a crash left the file '$PROFILE/lock' behind: delete it.)"
    fi
    warn "Zen is running with this profile. It rewrites its settings when it quits, so it has to be closed first."
    while zen_running "$PROFILE"; do
        ask "Close Zen completely (all windows), then press Enter. (Ctrl+C cancels) "
    done
    ok "Zen is closed."
}

# ---------------------------------------------------------- file helpers ----

BACKED_UP=""
# Copies FILE to FILE.cleanedurlbarext.bak once per run, before the first change.
backup_once() {
    case "$BACKED_UP" in *"|$1|"*) return 0 ;; esac
    BACKED_UP="$BACKED_UP|$1|"
    [ -f "$1" ] && cp -p "$1" "$1$BACKUP_SUFFIX"
}

# Removes the backups made by backup_once (only uninstall.sh does this).
# Prints what was removed.
remove_backups() {
    local f
    for f in "$PREFS_JS$BACKUP_SUFFIX" "$THEMES_JSON$BACKUP_SUFFIX"; do
        [ -f "$f" ] || continue
        rm -f "$f" || die "Cannot remove $f."
        printf '%s\n' "$f"
    done
}

# replace_file TARGET NEWFILE: atomic replacement next to the target.
replace_file() {
    local tmp
    tmp=$(mktemp "$(dirname "$1")/.cleanedurlbarext.XXXXXX") || die "Cannot write in $(dirname "$1")."
    cat "$2" >"$tmp" || {
        rm -f "$tmp"
        die "Cannot write $1."
    }
    [ -f "$1" ] && chmod "$(file_mode "$1")" "$tmp" 2>/dev/null
    mv -f "$tmp" "$1" || die "Cannot replace $1."
}

file_mode() {
    # GNU stat and BSD stat differ; ls is portable enough for rwx bits.
    # shellcheck disable=SC2012 # a single known file, not a listing
    ls -l "$1" | awk '{
        m = substr($1, 2, 9); o = 0
        for (i = 0; i < 3; i++) {
            d = 0
            if (substr(m, i * 3 + 1, 1) == "r") d += 4
            if (substr(m, i * 3 + 2, 1) == "w") d += 2
            if (substr(m, i * 3 + 3, 1) ~ /[xst]/) d += 1
            o = o * 10 + d
        }
        printf "%03d", o
    }'
}

# ------------------------------------------------------------------ json ----

# json MODE FILE [KEY [VALUE]] -- see lib/json.awk
json() {
    ZCUB_JSON_KEY=${3:-} ZCUB_JSON_VALUE=${4:-} awk -f "$LIB_DIR/json.awk" -v mode="$1" "$2"
}

# The mod's version from a theme.json-like file (empty when unknown).
json_version() {
    json flatten "$1" 2>/dev/null | awk -F'\t' '$1 == "version" { gsub(/"/, "", $2); print $2; exit }'
}

# ---------------------------------------------------------------- prefs.js ----

# Pending prefs.js edits, applied together by prefs_apply.
PREF_OPS="$WORK_DIR/pref-ops"
: >"$PREF_OPS"

pref_set() { printf 'set\t%s\t%s\n' "$1" "$2" >>"$PREF_OPS"; }        # name raw-value
pref_unset() { printf 'unset\t%s\n' "$1" >>"$PREF_OPS"; }              # name
pref_unset_prefix() { printf 'prefix\t%s\n' "$1" >>"$PREF_OPS"; }      # name prefix

# A string as a prefs.js literal: "text" with \ and " escaped.
pref_string() {
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

# Raw value of a pref in a prefs.js-style file (nothing when unset).
pref_get() {
    [ -f "$1" ] || return 0
    awk -v name="$2" '
        index($0, "user_pref(\"" name "\",") == 1 {
            v = substr($0, length(name) + 14)
            sub(/^[ \t]+/, "", v); sub(/\);[ \t\r]*$/, "", v)
            last = v; found = 1
        }
        END { if (found) print last }
    ' "$1"
}

# Human-readable form of a raw prefs.js value.
pref_display() {
    case "$1" in
        true) printf 'on' ;;
        false) printf 'off' ;;
        \"*\") printf '%s' "$1" | sed 's/^"//; s/"$//; s/\\"/"/g; s/\\\\/\\/g' ;;
        *) printf '%s' "$1" ;;
    esac
}

# Writes the queued edits to prefs.js (creates it when missing).
prefs_apply() {
    [ -s "$PREF_OPS" ] || return 0
    local new="$WORK_DIR/prefs.js.new"
    [ -f "$PREFS_JS" ] || : >"$PREFS_JS" || die "Cannot create $PREFS_JS."
    backup_once "$PREFS_JS"
    awk -F'\t' '
        NR == FNR {
            if ($1 == "set") { drop[$2] = 1; order[++n] = $2; val[$2] = $3 }
            else if ($1 == "unset") { drop[$2] = 1; delete val[$2] }
            else if ($1 == "prefix") prefixes[++np] = $2
            next
        }
        index($0, "user_pref(\"") == 1 {
            rest = substr($0, 12); name = substr(rest, 1, index(rest, "\"") - 1)
            if (name in drop) next
            for (i = 1; i <= np; i++) if (index(name, prefixes[i]) == 1 && !(name in val)) next
        }
        { print }
        END {
            for (i = 1; i <= n; i++) {
                name = order[i]
                if ((name in val) && !(name in done)) { print "user_pref(\"" name "\", " val[name] ");"; done[name] = 1 }
            }
        }
    ' "$PREF_OPS" "$PREFS_JS" >"$new" || die "Could not update $PREFS_JS."
    replace_file "$PREFS_JS" "$new"
    : >"$PREF_OPS"
}

# Warns about prefs that user.js forces at every start (they would undo our changes).
warn_user_js_overrides() {
    [ -f "$USER_JS" ] || return 0
    local name shown=""
    for name in "$@"; do
        if grep -q "^[[:space:]]*user_pref([[:space:]]*\"$(printf '%s' "$name" | sed 's/[.]/\\./g')\"" "$USER_JS"; then
            [ -n "$shown" ] || warn "Your user.js sets these preferences again at every start, overriding what was saved here:"
            shown=1
            say "    $name"
        fi
    done
}

# ------------------------------------------------------- mod installation ----

# Copies the mod into the profile and registers it with Zen, keeping whether the
# mod was enabled. The options need nothing here: when Zen rebuilds its mod
# stylesheet it first writes the default of every option that is not set yet.
install_mod_files() {
    local f entry enabled="true" current new_json="$WORK_DIR/zen-themes.json"

    mkdir -p "$MOD_DIR" || die "Cannot create $MOD_DIR."
    for f in $MOD_FILES; do
        cp "$ROOT_DIR/$f" "$MOD_DIR/$f" || die "Cannot copy $f to $MOD_DIR."
    done

    if [ -f "$THEMES_JSON" ]; then
        json flatten "$THEMES_JSON" >/dev/null 2>"$WORK_DIR/json-error" ||
            die "$THEMES_JSON is not valid JSON ($(cat "$WORK_DIR/json-error")). Fix or delete it, then run this again."
        current=$(json get "$THEMES_JSON" "$MOD_ID")
        case "$current" in *'"enabled":false'* | *'"enabled": false'*) enabled="false" ;; esac
    fi
    # theme.json is the mod's entry; Zen also expects "enabled".
    entry=$(cat "$ROOT_DIR/theme.json")
    entry="${entry%\}*},\"enabled\":$enabled}"
    if [ -f "$THEMES_JSON" ]; then
        json set "$THEMES_JSON" "$MOD_ID" "$entry" >"$new_json"
    else
        json set /dev/null "$MOD_ID" "$entry" >"$new_json"
    fi || die "Could not update $THEMES_JSON."
    backup_once "$THEMES_JSON"
    replace_file "$THEMES_JSON" "$new_json"

    request_mods_rebuild
}

# Zen only regenerates chrome/zen-themes.css when a mod changes or when its mod
# update check runs, and it runs that check at startup whenever
# zen.mods.last-update is unset. Clearing it makes the next start pick up the change.
request_mods_rebuild() {
    pref_unset "zen.mods.last-update"
}

installed_version() {
    [ -f "$THEMES_JSON" ] || return 0
    json get "$THEMES_JSON" "$MOD_ID" >"$WORK_DIR/entry" 2>/dev/null || return 0
    json_version "$WORK_DIR/entry"
}

# Status 0 when the installed mod is the same as this copy of the project.
mod_up_to_date() {
    local f
    for f in $MOD_FILES; do
        # Compared with cat rather than cmp, which minimal systems (Arch base) lack.
        [ -f "$MOD_DIR/$f" ] && [ "$(cat "$ROOT_DIR/$f")" = "$(cat "$MOD_DIR/$f")" ] || return 1
    done
    [ "$(installed_version)" = "$(json_version "$ROOT_DIR/theme.json")" ]
}

is_installed() {
    [ -d "$MOD_DIR" ] && return 0
    [ -f "$THEMES_JSON" ] && json get "$THEMES_JSON" "$MOD_ID" >/dev/null 2>&1
}

# --------------------------------------------------------------- catalogue ----

# Loads lib/catalogue.txt into parallel arrays (index = question number).
load_catalogue() {
    CAT_KIND=() CAT_PREF=() CAT_DEFAULT=() CAT_DEP=() CAT_QUESTION=() CAT_HELP=() CAT_CHOICES=() CAT_SECTION=()
    SECTION_TITLE=() SECTION_DESC=()
    local kind pref def dep question help choices
    while IFS='|' read -r kind pref def dep question help choices; do
        case "$kind" in
            '' | '#'*) continue ;;
            @section)
                SECTION_TITLE+=("$pref")
                SECTION_DESC+=("$def")
                continue
                ;;
        esac
        CAT_KIND+=("$kind")
        CAT_PREF+=("$pref")
        CAT_DEFAULT+=("$def")
        CAT_DEP+=("$dep")
        CAT_QUESTION+=("$question")
        CAT_HELP+=("$help")
        CAT_CHOICES+=("$choices")
        CAT_SECTION+=($((${#SECTION_TITLE[@]} - 1)))
    done <"$LIB_DIR/catalogue.txt"
}
