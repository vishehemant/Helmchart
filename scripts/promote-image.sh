#!/usr/bin/env bash
# =============================================================================
# promote-image.sh - Promote an image tag from one environment to the next
# =============================================================================
# This simulates a GitOps promotion workflow by updating the values file.
#
# Usage:
#   ./scripts/promote-image.sh <source-env> <target-env>
#
# Examples:
#   ./scripts/promote-image.sh dev staging
#   ./scripts/promote-image.sh staging prod
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENVIRONMENTS_DIR="${ROOT_DIR}/environments"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source-env> <target-env>"
    exit 1
fi

SOURCE_ENV="$1"
TARGET_ENV="$2"

SOURCE_VALUES="${ENVIRONMENTS_DIR}/${SOURCE_ENV}/values.yaml"
TARGET_VALUES="${ENVIRONMENTS_DIR}/${TARGET_ENV}/values.yaml"

for f in "$SOURCE_VALUES" "$TARGET_VALUES"; do
    if [[ ! -f "$f" ]]; then
        log_error "Values file not found: ${f}"
        exit 1
    fi
done

SOURCE_TAG=$(grep 'tag:' "$SOURCE_VALUES" | head -1 | awk '{print $2}' | tr -d '"')
TARGET_TAG=$(grep 'tag:' "$TARGET_VALUES" | head -1 | awk '{print $2}' | tr -d '"')

log_info "============================================"
log_info "  Image Promotion"
log_info "============================================"
log_info "Source : ${SOURCE_ENV} (tag: ${SOURCE_TAG})"
log_info "Target : ${TARGET_ENV} (tag: ${TARGET_TAG})"
echo ""

if [[ "$TARGET_ENV" == "prod" ]]; then
    log_warn "You are promoting to PRODUCTION."
    read -rp "Type 'yes' to proceed: " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        log_error "Promotion aborted."
        exit 1
    fi
fi

sed -i "s|tag: \"${TARGET_TAG}\"|tag: \"${SOURCE_TAG}\"|" "$TARGET_VALUES"
log_ok "Updated ${TARGET_ENV} image tag from '${TARGET_TAG}' to '${SOURCE_TAG}'."

echo ""
log_info "Next steps:"
log_info "  1. Review the change:  git diff environments/${TARGET_ENV}/values.yaml"
log_info "  2. Commit and push:    git add . && git commit -m 'Promote ${SOURCE_TAG} to ${TARGET_ENV}' && git push"
log_info "  3. Argo CD will detect the change and sync automatically (if auto-sync is enabled)."
