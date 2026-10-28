#!/usr/bin/env bash
# ==============================================================================
# Script Name: ops-audit.sh
# Purpose:     Pre-deployment Linux node health audit & HTTP 5xx log analyzer
# Author:      Hein Htet Zaw
# ==============================================================================

set -euo pipefail

DISK_THRESHOLD=85
INODE_THRESHOLD=85
LOG_FILE="${1:-/var/log/nginx/access.log}" TMP_REPORT="/tmp/ops_audit_$$.txt"

cleanup() {
    rm -f "$TMP_REPORT"
}
trap cleanup EXIT INT TERM

log_info()  { echo -e "[INFO]  $(date +'\%Y-\%m-\%dT\%H:\%M:\%S\%z') -$*"; }
log_error() { echo -e "[ERROR] $(date +'\%Y-\%m-\%dT\%H:\%M:\%S\%z') -$*" >&2; }

log_info "Starting Linux Node Pre-Flight Health Audit..."

# 1. Check Disk Block Usage
ROOT_DISK_USE=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
if (( ROOT_DISK_USE >= DISK_THRESHOLD )); then
    log_error "Root disk usage critical: ${ROOT_DISK_USE}\% (Threshold:${DISK_THRESHOLD}%)"
    exit 1
else
    log_info "Root disk block usage healthy: ${ROOT_DISK_USE}%"
fi

# 2. Check Filesystem Inode Usage (Prevents 'No space left on device' when GBs are free)
ROOT_INODE_USE=$(df -Pi / | awk 'NR==2 {gsub("%","",$5); print $5}')
if (( ROOT_INODE_USE >= INODE_THRESHOLD )); then
    log_error "Root inode usage critical: ${ROOT_INODE_USE}\% (Threshold:${INODE_THRESHOLD}%)"
    exit 1
else
    log_info "Root inode usage healthy: ${ROOT_INODE_USE}%"
fi

# 3. Check for Deleted Files Held Open by Active Processes (Disk leak check)
if command -v lsof >/dev/null 2>&1; then
    DELETED_OPEN=$(lsof +L1 2>/dev/null | wc -l || true)
    log_info "Open unlinked (deleted) file descriptors count: ${DELETED_OPEN}"
fi

# 4. Parse Access Logs for HTTP 5xx Server Errors if log file exists
if [[ -f "$LOG_FILE" ]]; then
    log_info "Analyzing ${LOG_FILE} for top offending IPs triggering HTTP 5xx errors..."
    awk '$9 ~ /^5[0-9][0-9]$/ {print $1}' "$LOG_FILE" \
        | sort | uniq -c | sort -nr | head -n 5 > "$TMP_REPORT"

    if [[ -s "$TMP_REPORT" ]]; then
        echo "--- Top 5 IPs Receiving 5xx Errors ---"
        cat "$TMP_REPORT"
    else
        log_info "Zero HTTP 5xx errors found in ${LOG_FILE}."
    fi
else
    log_info "Log file ${LOG_FILE} not present; skipping log parse."
fi

log_info "Node health audit completed successfully."
