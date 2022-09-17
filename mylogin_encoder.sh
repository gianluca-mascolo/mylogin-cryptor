#!/bin/bash

set -euo pipefail

_gethelp() {
    echo "Usage: $0 [-f MYLOGIN_FILE] [-p PLAINTEXT_FILE] [-y]"
    cat << EOF
Encrypt a plain text file for mysql credentials.

mylogin.cnf location may be specified with -f or with MYSQL_TEST_LOGIN_FILE environment variable. Default location: ~/.mylogin.cnf
Use -p to select a plaintext file. Default: standard input
Use -y to force overwrite MYLOGIN_FILE. Default: ask

EOF
}

while getopts "hyf:p:" Option
do
    case $Option in
        f)
            MYLOGIN_FILE="$OPTARG"
        ;;
        p)
            PLAINTEXT_FILE="$OPTARG"
        ;;
        y)
            OVERWRITE_MYLOGIN="overwrite"
        ;;
        h)
            _gethelp
            exit 0
        ;;
        *)
            _gethelp
            exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

[ "${MYLOGIN_FILE:+is_set}" = "is_set" ] || MYLOGIN_FILE="${MYSQL_TEST_LOGIN_FILE:-$HOME/.mylogin.cnf}"
KeyPress="x"
if [ -f "$MYLOGIN_FILE" ] && [ "${OVERWRITE_MYLOGIN:-n}" != "overwrite" ]; then {
    read -r -p "$MYLOGIN_FILE already exist. Do you want to overwrite it? (y/n)" -s -n1 -t10 KeyPress
    [ "$KeyPress" != "y" ] && exit 0
    echo ""
}
fi

ENCRYPTED_KEY=""
declare -a HEX_KEY
for ((i=0;i<20;i++)); do {
    BYTE="$((RANDOM%256))"
    ENCRYPTED_KEY="${ENCRYPTED_KEY}$(printf '\\x%02x' "$BYTE")"
    HEX_KEY[$((i%16))]=$((${HEX_KEY[$((i%16))]:-0}^BYTE))
}
done
# shellcheck disable=SC2059
printf "\x00\x00\x00\x00${ENCRYPTED_KEY}" > "$MYLOGIN_FILE"
OPENSSL_KEY="$(printf %02x "${HEX_KEY[@]}")"
while read -r line; do {
    ENCRYPTED_LINE="$(echo "$line" | openssl enc -e -aes-128-ecb -K "$OPENSSL_KEY" | od -An -tu1 -w1 -v | tr -s '[:space:]' ' ')"
    # shellcheck disable=SC2086
    ENCRYPTED_LINE="$(printf '\\x%02x' $ENCRYPTED_LINE)"
    ENCRYPTED_LENGTH="$(echo -nE "$ENCRYPTED_LINE" | wc -c)"
    ENCRYPTED_LENGTH="$((ENCRYPTED_LENGTH / 4))"
    # shellcheck disable=SC2059
    printf "\x$(printf %02x $ENCRYPTED_LENGTH)\x00\x00\x00${ENCRYPTED_LINE}" >> "$MYLOGIN_FILE"
}
done < "${PLAINTEXT_FILE:-/dev/stdin}"
