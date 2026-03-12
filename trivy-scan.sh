#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# trivy-scan.sh – Run Trivy vulnerability scanner on the
# Cloud System Monitor Docker image
# ─────────────────────────────────────────────────────────────
set -euo pipefail

IMAGE_NAME="${1:-cloud-system-monitor:latest}"
REPORT_FILE="trivy-report.json"

echo "============================================"
echo "  Trivy Security Scan"
echo "  Image: ${IMAGE_NAME}"
echo "============================================"
echo ""

# ── Check if Trivy is installed ─────────────────────────────
if ! command -v trivy &> /dev/null; then
    echo "❌ Trivy is not installed."
    echo "   Install: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
    exit 1
fi

# ── Run table report (human-readable) ───────────────────────
echo "🔍 Scanning for HIGH and CRITICAL vulnerabilities..."
echo ""
trivy image \
    --severity HIGH,CRITICAL \
    --format table \
    "${IMAGE_NAME}"

# ── Run JSON report (machine-readable) ──────────────────────
echo ""
echo "📄 Generating JSON report → ${REPORT_FILE}"
trivy image \
    --severity HIGH,CRITICAL \
    --format json \
    --output "${REPORT_FILE}" \
    "${IMAGE_NAME}"

echo ""
echo "✅ Scan complete. Report saved to ${REPORT_FILE}"
