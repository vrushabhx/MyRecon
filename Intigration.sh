#!/bin/bash

# Check if a target was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target-domain>"
    exit 1
fi

# Define the target domain from the first argument
TARGET=$1

# Define output directories
OUTPUT_DIR="output"
mkdir -p $OUTPUT_DIR

# Step 1: Run Subfinder to find subdomains
echo "[+] Running Subfinder on $TARGET..."
subfinder -d $TARGET -o $OUTPUT_DIR/subdomains.txt
echo "[+] Subfinder completed. Output saved to $OUTPUT_DIR/subdomains.txt"

# Step 2: Use httpx to probe for live web servers
echo "[+] Running httpx on subdomains..."
httpx -l $OUTPUT_DIR/subdomains.txt -o $OUTPUT_DIR/live_hosts.txt
echo "[+] httpx completed. Output saved to $OUTPUT_DIR/live_hosts.txt"

# Check for 403 Forbidden responses
echo "[+] Checking for 403 Forbidden responses..."
grep "403" $OUTPUT_DIR/live_hosts.txt > $OUTPUT_DIR/403_hosts.txt

if [ -s $OUTPUT_DIR/403_hosts.txt ]; then
    echo "[+] Found 403 responses. Attempting bypass..."
    
    # Attempt to bypass 403 using bypass-403 tool
    while read -r url; do
        echo "[+] Attempting 403 bypass on $url..."
        bypass-403 -u $url -o $OUTPUT_DIR/bypass_403_results.txt
    done < $OUTPUT_DIR/403_hosts.txt

    echo "[+] 403 bypass attempts completed. Results saved to $OUTPUT_DIR/bypass_403_results.txt"
else
    echo "[+] No 403 responses found. Skipping 403 bypass."
fi

# Step 3: Use Katana for crawling the live hosts
echo "[+] Running Katana on live hosts..."
katana -u -f urls -i $OUTPUT_DIR/live_hosts.txt -o $OUTPUT_DIR/katana_output.txt
echo "[+] Katana completed. Output saved to $OUTPUT_DIR/katana_output.txt"

# Step 4: Run Nuclei for vulnerability scanning on the live hosts
echo "[+] Running Nuclei on live hosts..."
nuclei -l $OUTPUT_DIR/live_hosts.txt -o $OUTPUT_DIR/nuclei_output.txt
echo "[+] Nuclei completed. Output saved to $OUTPUT_DIR/nuclei_output.txt"

# Step 5: Combine all outputs into a single file
echo "[+] Combining outputs..."
cat $OUTPUT_DIR/subdomains.txt $OUTPUT_DIR/live_hosts.txt $OUTPUT_DIR/katana_output.txt $OUTPUT_DIR/nuclei_output.txt $OUTPUT_DIR/bypass_403_results.txt > $OUTPUT_DIR/final_output.txt
echo "[+] All outputs combined into $OUTPUT_DIR/final_output.txt"

# Optional: Clean up intermediate files
rm $OUTPUT_DIR/subdomains.txt $OUTPUT_DIR/live_hosts.txt $OUTPUT_DIR/katana_output.txt $OUTPUT_DIR/nuclei_output.txt $OUTPUT_DIR/403_hosts.txt

echo "[+] Script execution completed. Final output available in $OUTPUT_DIR/final_output.txt"
