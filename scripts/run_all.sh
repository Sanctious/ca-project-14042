#!/bin/bash

MAX_JOBS=8

TRACES=(
        "traces/403.gcc-17B.champsimtrace.xz"
        "traces/429.mcf-51B.champsimtrace.xz"
        "traces/470.lbm-1274B.champsimtrace.xz"
        "traces/471.omnetpp-188B.champsimtrace.xz"
)

mkdir -p logs

for binary in ./bin/*; do
        [[ -x "$binary" && -f "$binary" ]] || continue

        binary_name=$(basename "$binary")

        for trace in "${TRACES[@]}"; do
                trace_name=$(basename "$trace" .champsimtrace.xz)

                echo "Starting ${binary_name} on ${trace_name}"

                "$binary" \
                        --warmup-instructions=12500000 \
                        --simulation-instructions=50000000 \
                        "$trace" \
                        >"logs/${binary_name}_${trace_name}.log" 2>&1 &

                while (($(jobs -rp | wc -l) >= MAX_JOBS)); do
                        sleep 1
                done
        done
done

wait

echo "All simulations finished."
