#!/usr/bin/env bash
# Installs (or reinstalls) Cleaned URL Bar Extended into a Zen Browser profile.
#
#   curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- -p "/path/to/profile"
SCRIPT_NAME=install.sh

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
Usage: install.sh [options]

Installs Cleaned URL Bar Extended into your Zen Browser profile (or reinstalls
it, keeping your settings). Zen must be closed while it runs.

Options:
  -p, --profile PATH  Zen profile folder (about:support > Profile Directory), or
                      the Zen folder that contains profiles.ini. Without it the
                      profile Zen opens by default is used.
      --configure     Go straight to the URL bar behaviour questions afterwards.
      --no-configure  Do not offer the URL bar behaviour questions.
      --ref REF       Install from another branch or tag of the repository.
  -h, --help          Show this help.
EOF
}

main() {
    bootstrap "$@"
    local profile_arg="" configure=ask
    while [ $# -gt 0 ]; do
        case "$1" in
            -p | --profile)
                [ $# -ge 2 ] || die "$1 needs a path."
                profile_arg=$2
                shift
                ;;
            --profile=*) profile_arg=${1#--profile=} ;;
            --configure) configure=yes ;;
            --no-configure) configure=no ;;
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

    local version previous
    version=$(json_version "$ROOT_DIR/theme.json")
    info "$MOD_NAME $version"
    select_profile "$profile_arg"
    set_profile_paths
    require_zen_closed

    previous=$(installed_version)
    install_mod_files
    # Installing offers every behaviour question, so all current ones count as seen.
    load_catalogue
    migrate_renamed_prefs
    mark_questions_seen
    prefs_apply
    if [ -n "$previous" ]; then
        ok "Reinstalled $MOD_NAME ($previous -> $version). Your settings were kept."
    else
        ok "Installed $MOD_NAME $version into $MOD_DIR"
    fi
    say "    Start Zen: the mod is applied a moment after startup. Customise it in"
    say "    Settings > Zen Mods > $MOD_NAME."
    if [ ${#MIGRATED[@]} -gt 0 ]; then
        ok "Moved settings that Zen renamed:"
        printf '    %s\n' "${MIGRATED[@]}"
    fi

    if [ "$configure" = ask ] && open_tty; then
        say ""
        say "configure.sh can walk you through the URL bar's about:config options"
        say "(floating mode, which suggestions appear, how many results...)."
        ask_yes_no "Configure the URL bar behaviour now?" n && configure=yes
    fi
    if [ "$configure" = yes ]; then
        say ""
        run_configure
    fi
}

run_configure() {
    # shellcheck source=lib/configure.sh
    . "$LIB_DIR/configure.sh"
    configure_interactive
}

main "$@"
