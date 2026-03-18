#!/usr/bin/env bash
# =============================================================================
# helm-rollback.sh - Rollback webapp to a previous Helm revision
# =============================================================================
# Usage:
#   ./scripts/helm-rollback.sh <environment> [revision]
#
# If no revision is given, rolls back to the immediately previous revision.
#
# Examples:
#   ./scripts/helm-rollback.sh dev
#   ./scripts/helm-rollback.sh prod 3
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <environment> [revision]"
    exit 1
fi

ENVIRONMENT="$1"
REVISION="${2:-}"
RELEASE_NAME="webapp-${ENVIRONMENT}"
NAMESPACE="webapp-${ENVIRONMENT}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment: ${ENVIRONMENT}"
    exit 1
fi

log_info "============================================"
log_info "  Helm Rollback - ${ENVIRONMENT^^}"
log_info "============================================"

log_info "Current release history:"
echo ""
helm history "${RELEASE_NAME}" -n "${NAMESPACE}" --max 10
echo ""

if [[ "$ENVIRONMENT" == "prod" ]]; then
    log_warn "You are about to rollback PRODUCTION."
    read -rp "Type 'yes' to proceed: " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        log_error "Rollback aborted."
        exit 1
    fi
fi

ROLLBACK_ARGS=(
    "${RELEASE_NAME}"
    --namespace "${NAMESPACE}"
    --wait
    --timeout 5m
)

if [[ -n "$REVISION" ]]; then
    log_info "Rolling back to revision ${REVISION}..."
    ROLLBACK_ARGS+=("${REVISION}")
else
    log_info "Rolling back to previous revision..."
fi

helm rollback "${ROLLBACK_ARGS[@]}"
log_ok "Rollback completed!"

echo ""
log_info "Updated release history:"
helm history "${RELEASE_NAME}" -n "${NAMESPACE}" --max 10

echo ""
log_info "Current status:"
helm status "${RELEASE_NAME}" -n "${NAMESPACE}"
