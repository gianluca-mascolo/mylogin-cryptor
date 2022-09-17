#!/bin/bash

# mylogin_decoder.sh
#
# Decode a mylogin.cnf encrypted file into plaintext
#
# Source repository: https://github.com/gianluca-mascolo/mylogin-cryptor
#
# Copyright (C) 2022 Gianluca Mascolo
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Requirements:
# od tr printf (package: coreutils)
# openssl (package: openssl)

# This script require the following utilities:
# od dd stat printf (package: coreutils)
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
    for BYTE in $(od -j4  -N20 -An -tu1 -w1 -v "$MYLOGIN_FILE"); do {
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
    READ_LEN="$(od -j${NEXT_BYTE} -N1 -An -tu1 -w1 -v "$MYLOGIN_FILE")"
    dd status=none ibs=1 skip=$((NEXT_BYTE+4)) obs=1 count=$((READ_LEN)) if="$MYLOGIN_FILE" | \
        openssl enc -d -aes-128-ecb -K "$OPENSSL_KEY"
    NEXT_BYTE=$((NEXT_BYTE+READ_LEN+4))
}
done
