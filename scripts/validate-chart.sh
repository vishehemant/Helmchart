#!/usr/bin/env bash
# =============================================================================
# validate-chart.sh - Lint and validate the Helm chart against all environments
# =============================================================================
# Usage:
#   ./scripts/validate-chart.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CHART_PATH="${ROOT_DIR}/helm-charts/webapp"
ENVIRONMENTS_DIR="${ROOT_DIR}/environments"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

ERRORS=0

log_info "============================================"
log_info "  Helm Chart Validation"
log_info "============================================"
echo ""

# --- Step 1: Lint the base chart ---
log_info "Step 1: Linting base chart..."
if helm lint "${CHART_PATH}"; then
    log_ok "Base chart lint passed."
else
    log_error "Base chart lint failed!"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# --- Step 2: Lint with each environment values ---
for ENV_DIR in "${ENVIRONMENTS_DIR}"/*/; do
    ENV_NAME=$(basename "${ENV_DIR}")
    VALUES_FILE="${ENV_DIR}/values.yaml"

    if [[ ! -f "$VALUES_FILE" ]]; then
        log_error "No values.yaml found in ${ENV_DIR}"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    log_info "Step 2: Linting chart with ${ENV_NAME} values..."
    if helm lint "${CHART_PATH}" -f "${VALUES_FILE}"; then
        log_ok "${ENV_NAME} lint passed."
    else
        log_error "${ENV_NAME} lint failed!"
        ERRORS=$((ERRORS + 1))
    fi
    echo ""
done

# --- Step 3: Template rendering ---
for ENV_DIR in "${ENVIRONMENTS_DIR}"/*/; do
    ENV_NAME=$(basename "${ENV_DIR}")
    VALUES_FILE="${ENV_DIR}/values.yaml"
    RELEASE_NAME="webapp-${ENV_NAME}"

    log_info "Step 3: Rendering templates for ${ENV_NAME}..."
    if helm template "${RELEASE_NAME}" "${CHART_PATH}" \
        -f "${VALUES_FILE}" \
        --namespace "webapp-${ENV_NAME}" > /dev/null 2>&1; then
        log_ok "${ENV_NAME} template render passed."
    else
        log_error "${ENV_NAME} template render failed!"
        helm template "${RELEASE_NAME}" "${CHART_PATH}" \
            -f "${VALUES_FILE}" \
            --namespace "webapp-${ENV_NAME}" 2>&1 || true
        ERRORS=$((ERRORS + 1))
    fi
    echo ""
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
    log_error "Validation completed with ${ERRORS} error(s)."
    exit 1
else
    log_ok "All validations passed!"
fi
