#!/usr/bin/env bash
# =============================================================================
# helm-diff.sh - Show what would change on the next deploy
# =============================================================================
# Requires the helm-diff plugin: helm plugin install https://github.com/databus23/helm-diff
#
# Usage:
#   ./scripts/helm-diff.sh <environment>
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CHART_PATH="${ROOT_DIR}/helm-charts/webapp"
ENVIRONMENTS_DIR="${ROOT_DIR}/environments"

BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <environment>"
    exit 1
fi

ENVIRONMENT="$1"
RELEASE_NAME="webapp-${ENVIRONMENT}"
NAMESPACE="webapp-${ENVIRONMENT}"
VALUES_FILE="${ENVIRONMENTS_DIR}/${ENVIRONMENT}/values.yaml"

if [[ ! -f "$VALUES_FILE" ]]; then
    log_error "Values file not found: ${VALUES_FILE}"
    exit 1
fi

if ! helm plugin list | grep -q diff; then
    log_info "Installing helm-diff plugin..."
    helm plugin install https://github.com/databus23/helm-diff
fi

log_info "Comparing deployed state with local chart for ${ENVIRONMENT}..."
echo ""

helm diff upgrade \
    "${RELEASE_NAME}" \
    "${CHART_PATH}" \
    --namespace "${NAMESPACE}" \
    -f "${VALUES_FILE}" \
    --allow-unreleased
