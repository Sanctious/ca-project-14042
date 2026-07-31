#!/bin/bash

OUTFILE="llc_results.csv"

echo "Binary,LLC_Access,LLC_Hit,IPC" >"$OUTFILE"

for logfile in logs/*.log; do
        [[ -f "$logfile" ]] || continue

        name=$(basename "$logfile" .log)

        # LLC statistics
        llc_line=$(grep "cpu0->LLC TOTAL" "$logfile")

        access=$(echo "$llc_line" | awk '{for(i=1;i<=NF;i++) if($i=="ACCESS:") print $(i+1)}')
        hit=$(echo "$llc_line" | awk '{for(i=1;i<=NF;i++) if($i=="HIT:") print $(i+1)}')

        # IPC (take the last reported IPC in the log)
        ipc=$(grep "cumulative IPC:" "$logfile" | tail -n1 |
                awk '{for(i=1;i<=NF;i++) if($i=="IPC:") print $(i+1)}')

        echo "$name,$access,$hit,$ipc" >>"$OUTFILE"
done

echo "Results written to $OUTFILE"
