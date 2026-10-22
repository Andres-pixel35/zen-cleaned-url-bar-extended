#!/usr/bin/env bash
# Updates Cleaned URL Bar Extended in a Zen Browser profile to the latest version,
# keeping your settings.
#
#   curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/update.sh | bash
#   curl -fsSL .../update.sh | bash -s -- -p "/path/to/profile"
SCRIPT_NAME=update.sh

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
Usage: update.sh [options]

Updates what this project keeps in your Zen profile, keeping your settings:
- the look of the URL bar (the mod's chrome.css and preferences.json), when it
  changed;
- behaviour settings saved under a name Zen has since renamed, which are moved
  to the new name;
- and it offers the behaviour questions added since you last answered them.
Nothing is touched when everything is up to date. Zen must be closed when
something is written.

Options:
  -p, --profile PATH  Zen profile folder (about:support > Profile Directory), or
                      the Zen folder that contains profiles.ini. Without it the
                      profile Zen opens by default is used.
      --ref REF       Update from another branch or tag of the repository.
  -h, --help          Show this help.
EOF
}

main() {
    bootstrap "$@"
    local profile_arg=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -p | --profile)
                [ $# -ge 2 ] || die "$1 needs a path."
                profile_arg=$2
                shift
                ;;
            --profile=*) profile_arg=${1#--profile=} ;;
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
    is_installed || die "$MOD_NAME is not installed in this profile. Use install.sh instead."

    local previous version look="" renames i seen new_questions="" new_count=0
    previous=$(installed_version)
    version=$(json_version "$ROOT_DIR/theme.json")
    load_catalogue
    mod_up_to_date || look=1
    renames=$(pending_renames)
    seen=$(questions_seen)
    for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
        if [ "${CAT_SINCE[$i]}" -gt "$seen" ]; then
            new_questions="$new_questions $i"
            new_count=$((new_count + 1))
        fi
    done
    if [ -z "$look$renames" ] && [ "$new_count" -eq 0 ]; then
        ok "$MOD_NAME is already up to date ($version); nothing was changed."
        return 0
    fi

    if [ -n "$look$renames" ]; then
        require_zen_closed
        if [ -n "$look" ]; then
            install_mod_files
        fi
        migrate_renamed_prefs
        prefs_apply
        if [ -z "$look" ]; then
            ok "The look of $MOD_NAME is already up to date ($version)."
        elif [ "$previous" = "$version" ]; then
            ok "Updated the files of $MOD_NAME $version. Your settings were kept."
        else
            ok "Updated $MOD_NAME ${previous:-?} -> $version. Your settings were kept."
        fi
        if [ ${#MIGRATED[@]} -gt 0 ]; then
            ok "Moved settings that Zen renamed:"
            printf '    %s\n' "${MIGRATED[@]}"
        fi
    else
        ok "The look of $MOD_NAME is already up to date ($version)."
    fi

    if [ "$new_count" -gt 0 ]; then
        say ""
        say "$new_count new URL bar behaviour question(s) since you last answered them:"
        for i in $new_questions; do
            say "  - ${CAT_QUESTION[$i]}"
        done
        if open_tty && ask_yes_no "Answer them now?" y; then
            require_zen_closed
            # shellcheck source=lib/configure.sh
            . "$LIB_DIR/configure.sh"
            cfg_load_state
            cfg_run_questions "$new_questions"
        else
            say "They will be offered again at the next update, or run configure.sh to answer them."
        fi
    fi
    [ -n "$look" ] && say "    Start Zen: the update is applied a moment after startup."
    return 0
}

main "$@"
