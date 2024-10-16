#!/bin/bash

###############################################################################
# GCP enumeration script by the GitLab Red Team (improved version).

# This script is meant to run from a Linux Google Compute Instance. All
# commands are passive, and will generate miscellaneous text files in the
# `out-gcp-enum` folder in the current working directory.

# Provide a "-d" argument to debug stderr. Logs are saved in "enum.log".
# Use "-p" to enable parallel execution of some tasks.
###############################################################################

OUTDIR="out-gcp-enum-$(date -u +'%Y-%m-%d-%H-%M-%S')"
META="http://metadata.google.internal"
DEBUG=false
PARALLEL=false
LOGFILE="enum.log"

# Parse command-line arguments
while getopts ":dp" opt; do
  case $opt in
    d)
      DEBUG=true
      ;;
    p)
      PARALLEL=true
      ;;
    *)
      echo "Usage: $0 [-d] [-p]"
      exit 1
      ;;
  esac
done

# Create output directory
if [[ ! -d "$OUTDIR" ]]; then
    mkdir "$OUTDIR"
    echo "[*] Created folder '$OUTDIR' for output"
else
    echo "[!] Output folder exists, something went wrong! Exiting."
    exit 1
fi

# Standard function for running commands
echo "[*] Starting GCP Enumeration" > "$LOGFILE"
function run_cmd() {
    command="$1"
    outfile="$OUTDIR/$2"
    description="$3"

    echo "[*] $description" | tee -a "$LOGFILE"

    # Execute the command, managing stderr based on the DEBUG flag
    if $DEBUG; then
        /bin/bash -c "$command" >> "$outfile" 2>> "$LOGFILE"
    else
        /bin/bash -c "$command" >> "$outfile" 2>/dev/null
    fi

    # Provide feedback on command success/failure
    if [ $? -eq 0 ]; then
        echo "  [+] SUCCESS" | tee -a "$LOGFILE"
    else
        echo "  [!] FAIL" | tee -a "$LOGFILE"
    fi
}

# General enumeration commands
declare -A ENUM_COMMANDS
ENUM_COMMANDS=(
    ["gcloud-info.txt"]="gcloud info --quiet"
    ["gcloud-config.txt"]="gcloud config list --quiet"
    ["metadata.txt"]="curl '$META/computeMetadata/v1/?recursive=true&alt=text' -H 'Metadata-Flavor: Google'"
    ["compute-instances.json"]="gcloud compute instances list --quiet --format=json"
    ["firewall.json"]="gcloud compute firewall-rules list --quiet --format=json"
    ["subnets.json"]="gcloud compute networks subnets list --quiet --format=json"
    ["service-accounts.json"]="gcloud iam service-accounts list --quiet --format=json"
    ["projects.json"]="gcloud projects list --quiet --format=json"
    ["compute-templates.json"]="gcloud compute instance-templates list --quiet --format=json"
    ["compute-images.json"]="gcloud compute images list --no-standard-images --quiet --format=json"
    ["cloud-functions.json"]="gcloud functions list --quiet --format=json"
    ["pubsub.json"]="gcloud pubsub subscriptions list --quiet --format=json"
    ["backend-services.json"]="gcloud compute backend-services list --quiet --format=json"
    ["ai-platform.json"]="gcloud ai-platform models list --quiet --format=json && gcloud ai-platform jobs list --quiet --format=json"
    ["cloud-run-managed.json"]="gcloud run services list --platform=managed --quiet --format=json"
    ["cloud-run-gke.json"]="gcloud run services list --platform=gke --quiet --format=json"
    ["cloud-sql-instances.json"]="gcloud sql instances list --quiet --format=json"
    ["cloud-spanner-instances.json"]="gcloud spanner instances list --quiet --format=json"
    ["cloud-bigtable.json"]="gcloud bigtable instances list --quiet --format=json"
    ["cloud-filestore.json"]="gcloud filestore instances list --quiet --format=json"
    ["logging-folders.json"]="gcloud logging logs list --quiet --format=json"
    ["k8s-clusters.json"]="gcloud container clusters list --quiet --format=json"
    ["k8s-images.json"]="gcloud container images list --quiet --format=json"
    ["buckets.txt"]="gsutil ls -L"
    ["kms.txt"]="gcloud kms keyrings list --location global --quiet"
)

# Execute enumeration commands
echo "[*] Executing enumeration commands"
for outfile in "${!ENUM_COMMANDS[@]}"; do
    command="${ENUM_COMMANDS[$outfile]}"
    description="Exporting $(basename "$outfile" .json) info"
    if $PARALLEL; then
        run_cmd "$command" "$outfile" "$description" &
    else
        run_cmd "$command" "$outfile" "$description"
    fi
done

# Wait for background tasks to complete if in parallel mode
if $PARALLEL; then
    wait
fi

echo "[+] All done, good luck!" | tee -a "$LOGFILE"
