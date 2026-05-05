#!/bin/bash

RESULT_DIR="./results"
OUTPUT="$RESULT_DIR/final_results.csv"

echo "FT  ->  Latency(us/op), Workload (Sec),  Throughput(ops/sec) ,Bandwidth(MB/s)  ->   Duration(ns)" > "$OUTPUT"

for ft in $(seq 0 10 100); do

    log="$RESULT_DIR/output_ft_${ft}.log"

    if [[ ! -f "$log" ]]; then
        echo "Skipping ft=$ft (missing file)"
        continue
    fi

    # ---- TIME ----
    start=$(grep "start_time_ns" "$log" | cut -d= -f2)
    end=$(grep "end_time_ns" "$log" | cut -d= -f2)

    if [[ -z "$start" || -z "$end" ]]; then
        echo "Skipping ft=$ft (missing timestamps)"
        continue
    fi

    duration_ns=$((end - start))

    # ---- METRICS ----
    LAT=$(grep "fillrandom" "$log" | awk '{for(i=1;i<=NF;i++) if($i=="micros/op") print $(i-1)}')
    THR=$(grep "fillrandom" "$log" | awk '{for(i=1;i<=NF;i++) if($i=="ops/sec") print $(i-1)}')
    BW=$(grep "fillrandom" "$log" | awk -F';' '{print $2}' | awk '{print $1}')
    TIME_S=$(grep "fillrandom" "$log" | awk '{for(i=1;i<=NF;i++) if($i=="seconds") print $(i-1)}')
    echo "$ft  ->  $LAT , $TIME_S , $THR , $BW  ->  $duration_ns" >> "$OUTPUT"

    echo "ft=$ft -> $LAT,$THR,$BW"

done
echo "Extraction Done"
echo "Done -> $OUTPUT"
