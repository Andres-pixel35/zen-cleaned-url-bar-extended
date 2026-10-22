# shellcheck shell=bash
# The URL bar behaviour questions: the about:config preferences listed in
# lib/catalogue.txt. Used by configure.sh and, when asked, by install.sh and
# update.sh.
# Expects lib/common.sh to be loaded and PROFILE paths to be set.
# shellcheck disable=SC2153 # CAT_* and SECTION_* arrays come from load_catalogue in lib/common.sh

# Per question index:
#   CUR_RAW[i]  value saved in prefs.js ("" = not set, Zen's default applies);
#               a value still saved under an old name (@renamed) counts as saved
#   NEW_RAW[i]  answer: "" = keep, "-" = back to Zen's default, else the raw value
cfg_load_state() {
    local i j
    load_catalogue
    CUR_RAW=() NEW_RAW=()
    for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
        CUR_RAW[i]=$(pref_get "$PREFS_JS" "${CAT_PREF[$i]}")
        NEW_RAW[i]=""
        for ((j = 0; j < ${#RENAMED_NEW[@]}; j++)); do
            [ -z "${CUR_RAW[i]}" ] && [ "${RENAMED_NEW[$j]}" = "${CAT_PREF[$i]}" ] &&
                CUR_RAW[i]=$(pref_get "$PREFS_JS" "${RENAMED_OLD[$j]}")
        done
    done
}

cfg_default_raw() {
    case "${CAT_KIND[$1]}" in
        choice) pref_string "${CAT_DEFAULT[$1]}" ;;
        *) printf '%s' "${CAT_DEFAULT[$1]}" ;;
    esac
}

# Raw value that applies after the answers given so far.
cfg_effective_raw() {
    local i=$1
    case "${NEW_RAW[$i]}" in
        -) cfg_default_raw "$i" ;;
        "") if [ -n "${CUR_RAW[$i]}" ]; then printf '%s' "${CUR_RAW[$i]}"; else cfg_default_raw "$i"; fi ;;
        *) printf '%s' "${NEW_RAW[$i]}" ;;
    esac
}

cfg_index_of() {
    local i
    for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
        [ "${CAT_PREF[$i]}" = "$1" ] && { printf '%s' "$i"; return 0; }
    done
    return 1
}

# Label of a choice value ("value=Label;value=Label"), or the value itself.
cfg_choice_label() {
    printf '%s' "$2" | awk -v RS=';' -v want="$1" '
        { sub(/\n$/, ""); eq = index($0, "="); if (substr($0, 1, eq - 1) == want) { print substr($0, eq + 1); found = 1; exit } }
        END { if (!found) print want }
    '
}

# How a raw value reads for question i.
cfg_display() {
    local i=$1 shown
    shown=$(pref_display "$2")
    if [ -n "${CAT_CHOICES[$i]}" ]; then
        cfg_choice_label "$shown" "${CAT_CHOICES[$i]}"
    else
        printf '%s' "$shown"
    fi
}

# Status 0 when the question's dependency allows asking it.
cfg_dependency_met() {
    local dep=${CAT_DEP[$1]} want=true j
    [ -n "$dep" ] || return 0
    case "$dep" in !*) dep=${dep#!} want=false ;; esac
    j=$(cfg_index_of "$dep") || return 0
    [ "$(cfg_effective_raw "$j")" = "$want" ]
}

# Records an answer, normalising "same as Zen's default" to "-".
cfg_answer() {
    local i=$1 raw=$2
    [ "$raw" = "$(cfg_default_raw "$i")" ] && raw="-"
    NEW_RAW[i]=$raw
}

# Asks question i. Returns 1 when the user typed q (stop asking).
cfg_ask_one() {
    local i=$1
    local kind=${CAT_KIND[$1]} cur shown_default="" n value entry
    local values=() labels=()
    cur=$(cfg_effective_raw "$i")
    [ "$cur" = "$(cfg_default_raw "$i")" ] && shown_default=" (Zen default)"

    say ""
    say "$C_BOLD${CAT_QUESTION[$i]}$C_RESET"
    [ -n "${CAT_HELP[$i]}" ] && say "  $C_DIM${CAT_HELP[$i]}$C_RESET"
    if [ -n "${CAT_CHOICES[$i]}" ]; then
        n=0
        while IFS= read -r entry; do
            [ -n "$entry" ] || continue
            values+=("${entry%%=*}")
            labels+=("${entry#*=}")
            n=$((n + 1))
            say "  $n) ${entry#*=}"
        done <<EOF
$(printf '%s\n' "${CAT_CHOICES[$i]}" | tr ';' '\n')
EOF
    fi
    say "  Currently: $(cfg_display "$i" "$cur")$shown_default   $C_DIM(${CAT_PREF[$i]})$C_RESET"

    while :; do
        case "$kind" in
            bool) ask "  [y]es, [n]o, [d]efault, Enter = keep, [q] = finish: " ;;
            *)
                if [ ${#values[@]} -gt 0 ]; then
                    ask "  1-${#values[@]}, [d]efault, Enter = keep, [q] = finish: "
                else
                    ask "  A number, [d]efault, Enter = keep, [q] = finish: "
                fi
                ;;
        esac
        case "$REPLY" in
            "") return 0 ;;
            q | Q) return 1 ;;
            d | D | default)
                NEW_RAW[i]="-"
                return 0
                ;;
        esac
        case "$kind" in
            bool)
                case "$REPLY" in
                    y | Y | yes | on | true) cfg_answer "$i" true; return 0 ;;
                    n | N | no | off | false) cfg_answer "$i" false; return 0 ;;
                esac
                ;;
            *)
                if [ ${#values[@]} -gt 0 ]; then
                    case "$REPLY" in
                        '' | *[!0-9]*) ;;
                        *)
                            if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le ${#values[@]} ]; then
                                value=${values[$((REPLY - 1))]}
                                if [ "$kind" = choice ]; then
                                    cfg_answer "$i" "$(pref_string "$value")"
                                else
                                    cfg_answer "$i" "$value"
                                fi
                                return 0
                            fi
                            ;;
                    esac
                else
                    case "$REPLY" in
                        '' | *[!0-9]*) ;;
                        *)
                            # Drop leading zeros so prefs.js gets a plain integer.
                            value=$(printf '%s' "$REPLY" | sed 's/^0*//')
                            cfg_answer "$i" "${value:-0}"
                            return 0
                            ;;
                    esac
                fi
                ;;
        esac
        say "  Sorry, that is not a valid answer."
    done
}

# Prints the pending changes; status 1 when there are none.
cfg_summary() {
    local i old new any=1
    for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
        [ -n "${NEW_RAW[$i]}" ] || continue
        # Skip answers that leave things exactly as they are.
        if [ "${NEW_RAW[$i]}" = "-" ]; then
            [ -n "${CUR_RAW[$i]}" ] || continue
        else
            [ "${NEW_RAW[$i]}" = "${CUR_RAW[$i]}" ] && continue
        fi
        old=$(cfg_display "$i" "$(if [ -n "${CUR_RAW[$i]}" ]; then printf '%s' "${CUR_RAW[$i]}"; else cfg_default_raw "$i"; fi)")
        new=$(cfg_display "$i" "$(cfg_effective_raw "$i")")
        [ "${NEW_RAW[$i]}" = "-" ] && new="$new (Zen default)"
        say "  ${CAT_PREF[$i]}: $old -> $new"
        any=0
    done
    return $any
}

# Saves the answers, moves renamed preferences and records the questions as seen.
cfg_write() {
    local i changed=()
    migrate_renamed_prefs
    mark_questions_seen
    for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
        case "${NEW_RAW[$i]}" in
            "") continue ;;
            -) [ -n "${CUR_RAW[$i]}" ] || continue; pref_unset "${CAT_PREF[$i]}" ;;
            *) [ "${NEW_RAW[$i]}" = "${CUR_RAW[$i]}" ] && continue; pref_set "${CAT_PREF[$i]}" "${NEW_RAW[$i]}" ;;
        esac
        changed+=("${CAT_PREF[$i]}")
    done
    prefs_apply
    warn_user_js_overrides "${changed[@]}"
}

# Status 0 when section s was picked in the space-separated list $2 ("a" = all).
cfg_section_picked() {
    case " $2 " in *" a "* | *" $(($1 + 1)) "*) return 0 ;; esac
    return 1
}

configure_interactive() {
    local i s picks=""
    open_tty || die "configure needs a terminal to ask its questions."
    cfg_load_state

    say "${C_BOLD}URL bar behaviour$C_RESET"
    say "These are Zen's own about:config preferences. For each one press Enter to keep"
    say "it, d to go back to Zen's default, or q to stop and review your answers."
    say "On/off options can also be changed later in Settings > Zen Mods > $MOD_NAME;"
    say "numbers can only be changed here or in about:config."
    say ""
    for ((s = 0; s < ${#SECTION_TITLE[@]}; s++)); do
        say "  $((s + 1))) ${SECTION_TITLE[$s]} $C_DIM- ${SECTION_DESC[$s]}$C_RESET"
    done
    say "  a) All of them"
    while :; do
        ask "Which parts? (numbers separated by spaces) [a]: "
        picks=${REPLY:-a}
        local bad=""
        for s in $picks; do
            case "$s" in
                a) ;;
                *[!0-9]* | "") bad=1 ;;
                *) { [ "$s" -ge 1 ] && [ "$s" -le ${#SECTION_TITLE[@]} ]; } || bad=1 ;;
            esac
        done
        [ -z "$bad" ] && break
        say "Please enter numbers from the list, or a."
    done

    local list=""
    for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
        cfg_section_picked "${CAT_SECTION[$i]}" "$picks" && list="$list $i"
    done
    cfg_run_questions "$list"
}

# Asks the questions with the given indices (space-separated), shows the
# summary and saves on confirmation. Needs cfg_load_state and Zen closed.
cfg_run_questions() {
    local i s last_section=-1
    for i in $1; do
        s=${CAT_SECTION[$i]}
        if [ "$s" != "$last_section" ]; then
            say ""
            say "$C_BLUE$C_BOLD== ${SECTION_TITLE[$s]} ==$C_RESET"
            last_section=$s
        fi
        if ! cfg_dependency_met "$i"; then
            say ""
            say "$C_DIM(Skipped \"${CAT_QUESTION[$i]}\": it only matters when ${CAT_DEP[$i]#!} is $(case "${CAT_DEP[$i]}" in !*) printf off ;; *) printf on ;; esac).)$C_RESET"
            continue
        fi
        cfg_ask_one "$i" || break
    done

    say ""
    if ! cfg_summary >"$WORK_DIR/summary"; then
        # Still worth saving: which questions were seen, and any renamed preference.
        require_zen_closed
        cfg_write
        ok "Nothing to change."
        return 0
    fi
    say "${C_BOLD}Changes to save:$C_RESET"
    cat "$WORK_DIR/summary"
    if ! ask_yes_no "Save these changes?" y; then
        say "Nothing was saved."
        return 0
    fi
    require_zen_closed
    cfg_write
    ok "Saved. They take effect the next time you start Zen."
}

configure_list() {
    local i s=-1 raw mark
    cfg_load_state
    for ((i = 0; i < ${#CAT_PREF[@]}; i++)); do
        if [ "${CAT_SECTION[$i]}" != "$s" ]; then
            s=${CAT_SECTION[$i]}
            say ""
            say "$C_BOLD${SECTION_TITLE[$s]}$C_RESET"
        fi
        raw=$(cfg_effective_raw "$i")
        mark=""
        [ -z "${CUR_RAW[$i]}" ] && mark=" $C_DIM(Zen default)$C_RESET"
        printf '  %-52s %s%s\n' "${CAT_PREF[$i]}" "$(cfg_display "$i" "$raw")" "$mark"
    done
}
