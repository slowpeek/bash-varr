# -*- mode: sh; sh-shell: bash; -*-
# shellcheck shell=bash

# MIT license (c) 2021 https://github.com/slowpeek
# Homepage: https://github.com/slowpeek/bash-varr

VARR_ERROR=${VARR_ERROR:-1}     # Exit code on error.
VARR_ENABLED=${VARR_ENABLED:-n} # Set to 'y' in the main script or env
                                # to enable.

if [[ $VARR_ENABLED == y ]]; then
    shopt -s expand_aliases     # An alias is used to inject local
                                # vars.
    set -T                      # Trace functions with the DEBUG trap.

    # upvar: varr_lvl varr_data
    varr_add () {
        # Set current nesting level.
        varr_lvl=${#FUNCNAME[@]}

        local var

        # Add args to the reserved vars list.
        for var; do
            varr_data[$var]=y
        done
    }

    # Inject essential vars ahead of call.
    alias varr='local -A varr_data; local varr_lvl; varr_add'

    # Check vars from 'local' statements vs 'varr_data' list.
    varr_check () {
        # Ignore scopes without any reserved vars.
        [[ -v varr_lvl && $varr_lvl == "${#FUNCNAME[@]}" ]] || return 0

        [[ $BASH_COMMAND == 'local '* ]] || return 0

        local lineno=$1 err with_chain=n

        if [[ $BASH_COMMAND == *=* ]]; then
            err="'local' statement should not assign values"
        else
            # shellcheck disable=SC2086
            set -- $BASH_COMMAND
            shift

            # Walk over options.
            while [[ $1 == -* ]]; do
                shift
            done

            local var

            for var; do
                if [[ $var != [a-zA-Z_]*([a-zA-Z_0-9]) ]]; then
                    err="'local' statement should only list static var names"
                    break
                fi

                if [[ -v varr_data[$var] ]]; then
                    err="'$var' could be shadowed"
                    with_chain=y
                    break
                fi
            done
        fi

        [[ -v err ]] || return 0

        # Append call chain to $err if asked.
        if [[ $with_chain == y ]]; then
            local f chain
            for f in "${FUNCNAME[@]:1}"; do
                chain="$f $chain"
            done

            chain=${chain::-1}
            chain=${chain#* }

            err+="; call chain: ${chain// / > }"
        fi

        echo "varr on $lineno: $err" >&2
        exit "$VARR_ERROR"
    }

    trap 'varr_check "$LINENO"' DEBUG
else
    # Not enabled, just a stub.
    varr () {
        :
    }
fi
