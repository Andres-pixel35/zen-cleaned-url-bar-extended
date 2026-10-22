#!/usr/bin/env bash
# Asks about the URL bar's about:config preferences (floating mode, which
# suggestions appear, how many results...) and saves your answers in Zen.
#
#   curl -fsSL https://raw.githubusercontent.com/andres-pixel35/zen-cleaned-url-bar-extended/main/configure.sh | bash
#   curl -fsSL .../configure.sh | bash -s -- -p "/path/to/profile"
SCRIPT_NAME=configure.sh

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
Usage: configure.sh [options]

Walks you through the URL bar's about:config preferences and saves your answers
in your Zen profile. Works whether or not the mod is installed. Zen must be
closed while the answers are saved.

Options:
  -p, --profile PATH  Zen profile folder (about:support > Profile Directory), or
                      the Zen folder that contains profiles.ini. Without it the
                      profile Zen opens by default is used.
  -l, --list          Only show the current values, change nothing.
      --ref REF       Use the questions from another branch or tag.
  -h, --help          Show this help.
EOF
}

main() {
    bootstrap "$@"
    local profile_arg="" list=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -p | --profile)
                [ $# -ge 2 ] || die "$1 needs a path."
                profile_arg=$2
                shift
                ;;
            --profile=*) profile_arg=${1#--profile=} ;;
            -l | --list) list=1 ;;
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
    # shellcheck source=lib/configure.sh
    . "$LIB_DIR/configure.sh"
    if [ -n "$list" ]; then
        configure_list
        return 0
    fi
    require_zen_closed
    configure_interactive
}

main "$@"
