#!/bin/bash

# Ensure a target domain is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target-domain> [--proxy]"
    exit 1
fi

TARGET=$1
BASE_DIR="/Users/apple/Desktop/Targets"

# Replace '.' with '_' in the target domain for the directory name
TARGET_DIR_NAME=${TARGET//./_}
TARGET_DIR="$BASE_DIR/$TARGET_DIR_NAME"

PROXY="http://127.0.0.1:8080"
PROXY_OPTION=""

# Check if --proxy argument is provided
if [[ "$@" == *"--proxy"* ]]; then
    PROXY_OPTION="--proxy $PROXY"
fi

# Create target directory
mkdir -p $TARGET_DIR

# 1. Subdomain Enumeration
echo "[+] Running Subfinder..."
subfinder -d $TARGET -o $TARGET_DIR/subdomains.txt $PROXY_OPTION

echo "[+] Running httpx..."
httpx -l $TARGET_DIR/subdomains.txt -o $TARGET_DIR/live_hosts.txt $PROXY_OPTION

# 2. Historical URL Discovery
echo "[+] Running waybackurls..."
waybackurls $TARGET > $TARGET_DIR/waybackurls.txt 

# 3. 403 Forbidden Bypass (if applicable)
if grep -q "403" $TARGET_DIR/live_hosts.txt; then
    echo "[+] Found 403 responses. Attempting bypass..."
    while read -r url; do
        bypass-403 -u $url -o $TARGET_DIR/bypass_403_results.txt $PROXY_OPTION
    done < <(grep "403" $TARGET_DIR/live_hosts.txt)
else
    echo "[+] No 403 responses found."
fi

# 4. Crawling & Vulnerability Scanning
echo "[+] Running Katana..."
katana -list $TARGET_DIR/live_hosts.txt -o $TARGET_DIR/katana_output.txt $PROXY_OPTION

echo "[+] Running Nuclei..."
nuclei -l $TARGET_DIR/live_hosts.txt -o $TARGET_DIR/nuclei_output.txt $PROXY_OPTION

echo "[+] Reconnaissance completed. Results are in $TARGET_DIR"
