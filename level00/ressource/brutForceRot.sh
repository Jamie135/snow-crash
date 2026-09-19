#!/usr/bin/env bash
set -uo pipefail

HOST="$1"
PORT="4242"
SSH_USER="level00"
SSH_PASS="level00"
SU_USER="flag00"
BASE_PASS="cdiiddwpgswtgt"

caesar() {
    local input="$1"
    local n=$(( $2 % 26 ))
    local lower="abcdefghijklmnopqrstuvwxyz"
    local upper="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local rot_lower="${lower:$n}${lower:0:$n}"
    local rot_upper="${upper:$n}${upper:0:$n}"
    printf '%s' "$input" | tr "${lower}${upper}" "${rot_lower}${rot_upper}"
}

for i in $(seq 1 25); do
    candidate=$(caesar "$BASE_PASS" "$i")
    result=$(./try_su.exp "$HOST" "$PORT" "$SSH_USER" "$SSH_PASS" "$SU_USER" "$candidate" 2>/dev/null)

    echo "ROT$i -> $candidate" "$result"
    if [[ "$result" == "SUCCESS" ]]; then
        exit 0
    fi
done

echo "Aucune rotation trouvée."
exit 1