#!/bin/bash
RESULT_DIR="results_intrazone_512M_MU4"
OUTPUT_CSV="intrazone_results_512M_MU4.csv"

# header
echo "bs,bw_kb_s" > $OUTPUT_CSV

for f in $RESULT_DIR/*.json; do
    # extract block size from filename
    BS=$(basename $f | sed -E 's/intrazone_bs_(.*).json/\1/')
    
    # extract metrics using jq
    BW=$(jq '.jobs[0].write.bw' "$f")
    
    # append to CSV
    echo "$BS,$BW" >> $OUTPUT_CSV
done
