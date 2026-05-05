#!/bin/bash

RESULT_DIR="."
OUTPUT_CSV="InterZone_Results.csv"

# CSV Header
echo "bs,numjobs,bw_kb_s,iops,clat_ns_mean" > $OUTPUT_CSV

for f in Result_*.json; do
     [ -e "$f" ] || continue

     # Extract block size from filename
     filename=$(basename "$f" .json)

    # Expecting: Result_<bs>_<numjobs>
    Z=$(echo "$filename" | cut -d'_' -f2)
    T=$(echo "$filename" | cut -d'_' -f3)
   
    # Extract metrics using jq

    BW=$(jq '[.jobs[].write.bw] | add' "$f")
    IOPS=$(jq '[.jobs[].write.iops] | add' "$f")
    CLAT=$(jq '[.jobs[].write.clat_ns.mean] | add / length' "$f")

    # Append to CSV
    echo "$Z,$T,$BW,$IOPS,$CLAT" >> $OUTPUT_CSV
done

echo "CSV saved to $OUTPUT_CSV"
echo ""
