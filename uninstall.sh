#!/usr/bin/env bash
# Removes Cleaned URL Bar Extended from a Zen Browser profile.
#
#   curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/uninstall.sh | bash
#   curl -fsSL .../uninstall.sh | bash -s -- --reset-prefs
SCRIPT_NAME=uninstall.sh

# ---- bootstrap: identical in all four scripts (tests/test_scripts.sh checks it) ----
REPO_SLUG="andres-pixel35/zen-cleaned-url-bar-extended"
bootstrap() {
    local dir="" ref="${ZCUB_REF:-main}" arg prev="" tmp extracted
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    fi
    if [ -n "$dir" ] && [ -f "$dir/lib/common.sh" ]; then
        ROOT_DIR=$dir
        # shellcheck source=lib/common.sh
        . "$dir/lib/common.sh"
        return 0
    fi
    # Running through `curl ... | bash`: only this file exists, so download the
    # project and run its copy of this script with the same arguments.
    for arg in "$@"; do
        [ "$prev" = --ref ] && ref=$arg
        case "$arg" in --ref=*) ref=${arg#--ref=} ;; esac
        prev=$arg
    done
    command -v curl >/dev/null 2>&1 || { echo "Error: curl is required." >&2; exit 1; }
    command -v tar >/dev/null 2>&1 || { echo "Error: tar is required." >&2; exit 1; }
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/cleaned-url-bar.XXXXXX") || exit 1
    echo "==> Downloading $REPO_SLUG ($ref)..."
    if ! curl -fsSL "https://github.com/$REPO_SLUG/archive/$ref.tar.gz" | tar -xzf - -C "$tmp"; then
        rm -rf "$tmp"
        echo "Error: could not download https://github.com/$REPO_SLUG/archive/$ref.tar.gz" >&2
        exit 1
    fi
    for extracted in "$tmp"/*/; do break; done
    if [ ! -f "${extracted}lib/common.sh" ]; then
        rm -rf "$tmp"
        echo "Error: the download does not contain the scripts." >&2
        exit 1
    fi
    ZCUB_BOOTSTRAP_DIR=$tmp exec bash "${extracted}$SCRIPT_NAME" "$@"
}
# ---- end of bootstrap ----

usage() {
    cat <<'EOF'
Usage: uninstall.sh [options]

Removes Cleaned URL Bar Extended and its own settings from your Zen profile.
URL bar preferences you changed through the mod or configure.sh (suggestions,
floating mode...) are normal Zen settings and are kept, unless you pass
--reset-prefs. Zen must be closed while it runs.

Options:
  -p, --profile PATH  Zen profile folder (about:support > Profile Directory), or
                      the Zen folder that contains profiles.ini. Without it the
                      profile Zen opens by default is used.
      --reset-prefs   Also put every URL bar preference this project can change
                      back to Zen's default.
  -y, --yes           Do not ask for confirmation.
      --ref REF       Use the scripts from another branch or tag.
  -h, --help          Show this help.
EOF
}

main() {
    bootstrap "$@"
    local profile_arg="" reset="" yes=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -p | --profile)
                [ $# -ge 2 ] || die "$1 needs a path."
                profile_arg=$2
                shift
                ;;
            --profile=*) profile_arg=${1#--profile=} ;;
            --reset-prefs) reset=1 ;;
            -y | --yes) yes=1 ;;
            --ref) shift ;;
            --ref=*) ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) die "Unknown option: $1 (see --help)" ;;
        esac
        shift
    done

    select_profile "$profile_arg"
    set_profile_paths
    if ! is_installed && [ -z "$reset" ]; then
        ok "$MOD_NAME is not installed in this profile; nothing to do."
        return 0
    fi
    if [ -z "$yes" ]; then
        open_tty || die "Pass -y to confirm the removal when there is no terminal."
        local question="Remove $MOD_NAME from this profile?"
        [ -n "$reset" ] && question="Remove $MOD_NAME and reset the URL bar preferences to Zen's defaults?"
        ask_yes_no "$question" n || { say "Nothing was changed."; return 0; }
    fi
    require_zen_closed

    rm -rf "$MOD_DIR" || die "Cannot remove $MOD_DIR."
    if [ -f "$THEMES_JSON" ] && json get "$THEMES_JSON" "$MOD_ID" >/dev/null 2>&1; then
        json del "$THEMES_JSON" "$MOD_ID" >"$WORK_DIR/zen-themes.json" || die "Could not update $THEMES_JSON."
        backup_once "$THEMES_JSON"
        replace_file "$THEMES_JSON" "$WORK_DIR/zen-themes.json"
    fi
    pref_unset_prefix "$MOD_PREF_PREFIX"
    request_mods_rebuild

    local i reset_list=()
    if [ -n "$reset" ]; then
        load_catalogue
        for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
            if [ -n "$(pref_get "$PREFS_JS" "${CAT_PREF[$i]}")" ]; then
                pref_unset "${CAT_PREF[$i]}"
                reset_list+=("${CAT_PREF[$i]}")
            fi
        done
    fi
    prefs_apply

    ok "Removed $MOD_NAME."
    if [ -n "$reset" ]; then
        if [ ${#reset_list[@]} -gt 0 ]; then
            ok "Reset to Zen's defaults:"
            printf '    %s\n' "${reset_list[@]}"
        else
            ok "The URL bar preferences were already at Zen's defaults."
        fi
    fi
    say "    Backups of the changed files end in $BACKUP_SUFFIX in $PROFILE."
}

main "$@"
