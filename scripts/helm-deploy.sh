#!/usr/bin/env bash
# =============================================================================
# helm-deploy.sh - Deploy webapp to a target environment using Helm
# =============================================================================
# Usage:
#   ./scripts/helm-deploy.sh <environment> [--dry-run] [--debug]
#
# Examples:
#   ./scripts/helm-deploy.sh dev
#   ./scripts/helm-deploy.sh staging --dry-run
#   ./scripts/helm-deploy.sh prod --debug
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CHART_PATH="${ROOT_DIR}/helm-charts/webapp"
ENVIRONMENTS_DIR="${ROOT_DIR}/environments"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <environment> [--dry-run] [--debug]"
    echo ""
    echo "Environments: dev, staging, prod"
    echo ""
    echo "Options:"
    echo "  --dry-run   Perform a dry run (template only, no install)"
    echo "  --debug     Enable Helm debug output"
    exit 1
}

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ $# -lt 1 ]]; then
    usage
fi

ENVIRONMENT="$1"
shift

DRY_RUN=false
DEBUG=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --debug)   DEBUG=true ;;
        *)         log_error "Unknown option: $1"; usage ;;
    esac
    shift
done

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Invalid environment: ${ENVIRONMENT}. Must be dev, staging, or prod."
    exit 1
fi

VALUES_FILE="${ENVIRONMENTS_DIR}/${ENVIRONMENT}/values.yaml"
RELEASE_NAME="webapp-${ENVIRONMENT}"
NAMESPACE="webapp-${ENVIRONMENT}"

if [[ ! -f "$VALUES_FILE" ]]; then
    log_error "Values file not found: ${VALUES_FILE}"
    exit 1
fi

log_info "============================================"
log_info "  Helm Deploy - ${ENVIRONMENT^^}"
log_info "============================================"
log_info "Release   : ${RELEASE_NAME}"
log_info "Namespace : ${NAMESPACE}"
log_info "Chart     : ${CHART_PATH}"
log_info "Values    : ${VALUES_FILE}"
log_info "Dry Run   : ${DRY_RUN}"
echo ""

HELM_ARGS=(
    "${RELEASE_NAME}"
    "${CHART_PATH}"
    --namespace "${NAMESPACE}"
    --create-namespace
    -f "${VALUES_FILE}"
    --wait
    --timeout 5m
)

if [[ "$DEBUG" == true ]]; then
    HELM_ARGS+=(--debug)
fi

if [[ "$DRY_RUN" == true ]]; then
    log_info "Running Helm template (dry run)..."
    helm template "${HELM_ARGS[@]}"
    log_ok "Dry run completed."
else
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        log_warn "You are about to deploy to PRODUCTION."
        read -rp "Type 'yes' to proceed: " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_error "Deployment aborted."
            exit 1
        fi
    fi

    log_info "Running Helm upgrade --install..."
    helm upgrade --install "${HELM_ARGS[@]}"
    log_ok "Deployment to ${ENVIRONMENT} succeeded!"

    echo ""
    log_info "Release status:"
    helm status "${RELEASE_NAME}" -n "${NAMESPACE}"
fi
