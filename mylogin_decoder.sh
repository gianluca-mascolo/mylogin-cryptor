#!/bin/bash

# This script require the following utilities:
# od dd stat (package: coreutils)
# openssl (package: openssl)
set -euo pipefail

_gethelp() {
    echo "Usage: $0 [-f MYLOGIN_FILE]"
    cat << EOF
Decipher mysql credentials file in clear text.
mylogin.cnf location may be speficied with -f or with MYSQL_TEST_LOGIN_FILE environment variable. Default location: ~/.mylogin.cnf
EOF
}

decode_key() {
    local MYLOGIN_FILE
    local BYTE
    local -a HEX_KEY
    local i
    MYLOGIN_FILE="$1"
    i=0
    for BYTE in $(od  -j4  -N20 -An -td1 -w1 -v "$MYLOGIN_FILE" | grep -oE '[0-9]+'); do {
        HEX_KEY[$((i%16))]=$((${HEX_KEY[$((i%16))]:-0}^BYTE))
        i=$((i+1))
    }
    done
    printf %02x "${HEX_KEY[@]}"
}

while getopts "hf:" Option
do
    case $Option in
        f)
            MYLOGIN_FILE="$OPTARG"
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
if ! [ -f "$MYLOGIN_FILE" ]; then echo "ERROR: $MYLOGIN_FILE not found"; _gethelp; exit 1; fi
MYLOGIN_BYTE_LEN="$(stat --format=%s "$MYLOGIN_FILE")"
if [ "$MYLOGIN_BYTE_LEN" -le 24 ]; then echo "ERROR: $MYLOGIN_FILE bad format"; _gethelp; exit 1; fi

OPENSSL_KEY="$(decode_key "$MYLOGIN_FILE")"

NEXT_BYTE=24
while ((NEXT_BYTE<MYLOGIN_BYTE_LEN)); do {
    READ_LEN="$(od  -j${NEXT_BYTE} -N1 -An -td1 -w1 -v "$MYLOGIN_FILE" | grep -oE '[0-9]+')"
    dd status=none ibs=1 skip=$((NEXT_BYTE+4)) obs=1 count=$((READ_LEN)) if="$MYLOGIN_FILE" | \
        openssl enc -d -aes-128-ecb -K "$OPENSSL_KEY"
    NEXT_BYTE=$((NEXT_BYTE+READ_LEN+4))
}
done
