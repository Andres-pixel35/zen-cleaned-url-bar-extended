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

Updates the look of the URL bar (the mod's chrome.css and preferences.json) to
the latest version when it changed, keeping your settings. Nothing is touched
when it is already up to date. Zen must be closed when there is an update.

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

    local previous version
    previous=$(installed_version)
    version=$(json_version "$ROOT_DIR/theme.json")
    if mod_up_to_date; then
        ok "$MOD_NAME is already up to date ($version); nothing was changed."
        return 0
    fi
    require_zen_closed
    install_mod_files
    prefs_apply
    if [ "$previous" = "$version" ]; then
        ok "Updated the files of $MOD_NAME $version. Your settings were kept."
    else
        ok "Updated $MOD_NAME ${previous:-?} -> $version. Your settings were kept."
    fi
    say "    Start Zen: the update is applied a moment after startup."
}

main "$@"
