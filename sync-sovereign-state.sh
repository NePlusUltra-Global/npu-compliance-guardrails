#!/bin/bash

# 29TH REGIME: BATCH STATE SYNCHRONIZATION
# Enforces deterministic guardrails across all sovereign nodes
# Usage: ./sync-sovereign-state.sh (from repository root)

set -euo pipefail

REGIME="29TH REGIME"
TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)

echo "=========================================="
echo "$REGIME: BATCH STATE SYNCHRONIZATION"
echo "Initiated: $TIMESTAMP"
echo "=========================================="
echo ""

SYNCED_COUNT=0
NOOP_COUNT=0
ERROR_COUNT=0

for dir in */ ; do
    if [ -d "$dir/.git" ]; then
        echo "────────────────────────────────────────"
        echo "NODE: $dir"
        cd "$dir"
        
        # Check if there are changes
        if [[ $(git status --porcelain) ]]; then
            echo "STATUS: Uncommitted state detected."
            git add .
            git commit -m "ENFORCEMENT: Sovereign state synchronization [$(date +%Y-%m-%d\ %H:%M:%S)]"
            if git push origin main 2>/dev/null || git push origin master 2>/dev/null; then
                echo "✓ State liquidated and pushed to origin."
                ((SYNCED_COUNT++))
            else
                echo "✗ Push failed. Manual intervention required."
                ((ERROR_COUNT++))
            fi
        else
            echo "STATUS: Node is already at Sovereign Baseline. Zero friction."
            ((NOOP_COUNT++))
        fi
        
        cd ..
    fi
done

echo ""
echo "=========================================="
echo "$REGIME: SYNCHRONIZATION REPORT"
echo "────────────────────────────────────────"
echo "Nodes synchronized: $SYNCED_COUNT"
echo "Nodes baseline:     $NOOP_COUNT"
echo "Nodes with errors:  $ERROR_COUNT"
echo "Timestamp:          $TIMESTAMP"
echo "=========================================="
