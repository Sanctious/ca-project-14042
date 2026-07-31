#!/bin/bash

set -e

CONFIG="champsim_config.json"
OUTDIR="bin"

mkdir -p "$OUTDIR"

SETS_LIST=(1024 2048 4096)
WAYS=16

REPL_LIST=(
    lru
    mru
    random
    fifo
    ship
    srrip
    drrip
    bip
)

for sets in "${SETS_LIST[@]}"; do
    for repl in "${REPL_LIST[@]}"; do
        echo "========================================"
        echo "Building: sets=$sets ways=$WAYS replacement=$repl"

        tmp=$(mktemp)

        jq \
            --argjson sets "$sets" \
            --argjson ways "$WAYS" \
            --arg repl "$repl" \
            '
            .LLC.sets = $sets |
            .LLC.ways = $ways |
            .LLC.replacement = $repl
            ' \
            "$CONFIG" > "$tmp"

        mv "$tmp" "$CONFIG"

        # Remove generated configuration
        rm -rf .csconfig

        # Regenerate sources
        ./config.sh "$CONFIG"

        # Build
        make -j"$(sysctl -n hw.ncpu)"

        # Save binary
        cp bin/champsim \
            "$OUTDIR/champsim_llc_${sets}s_${WAYS}w_${repl}"

        echo "Saved as $OUTDIR/champsim_llc_${sets}s_${WAYS}w_${repl}"
        echo
    done
done

echo "========================================"
echo "Finished building all 24 binaries."