#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# =============================================================================
# EDD Download Deploy Action
# =============================================================================
# Deploys plugin/download to EDD-powered site via API
# =============================================================================

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "::error::$1"
}

log_warning() {
    echo "::warning::$1"
}

# -----------------------------------------------------------------------------
# Setup Defaults
# -----------------------------------------------------------------------------
readonly API_URL="${SITE_URL}/edd-api/download-deploy"
SLUG="${SLUG:-${GITHUB_REPOSITORY#*/}}"
VERSION="${VERSION:-${GITHUB_REF#refs/tags/}}"
VERSION="${VERSION#v}"
readonly BUILD_DIR="${HOME}/build-${SLUG}"
CHANGELOG=""

# If version is not set or invalid, try package.json
if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if [ -f ./package.json ]; then
        VERSION=$(node -p "require('./package.json').version")
        log_info "Version from package.json: $VERSION"
    else
        VERSION=""
    fi
fi

# Read changelog if exists
if [[ -f "${GITHUB_WORKSPACE}/changelog.txt" ]]; then
    CHANGELOG=$(<"${GITHUB_WORKSPACE}/changelog.txt")
    log_info "Changelog loaded (${#CHANGELOG} characters)"
fi

# -----------------------------------------------------------------------------
# Input Validation
# -----------------------------------------------------------------------------
for var in SITE_URL API_KEY API_TOKEN ITEM_ID VERSION; do
    if [ -z "${!var:-}" ]; then
        log_error "$var is not set"
        exit 1
    fi
done

readonly VERSION
readonly SLUG

# -----------------------------------------------------------------------------
# Display Configuration
# -----------------------------------------------------------------------------
log_info "=== Deployment Configuration ==="
log_info "Slug: $SLUG"
log_info "Version: $VERSION"
log_info "Item ID: $ITEM_ID"
log_info "Dry run: ${DRY_RUN:-false}"
if [ -n "$CHANGELOG" ]; then
    log_info "Changelog: ${CHANGELOG:0:100}..."
fi
echo ""

# Output version for GitHub Actions
echo "version=$VERSION" >> "${GITHUB_OUTPUT}"

# -----------------------------------------------------------------------------
# Copy Files to Build Directory
# -----------------------------------------------------------------------------
log_info "Copying files to build directory..."

if [[ -e "$GITHUB_WORKSPACE/.distignore" ]]; then
    log_info "Using .distignore for exclusions"
    rsync -rc --exclude-from="$GITHUB_WORKSPACE/.distignore" "$GITHUB_WORKSPACE/" "$BUILD_DIR" --delete --delete-excluded
else
    log_info "Using default exclusions"
    rsync -rc --exclude '.*' --exclude 'node_modules' "$GITHUB_WORKSPACE/" "$BUILD_DIR" --delete --delete-excluded
fi

# Remove empty directories
find "$BUILD_DIR" -type d -empty -delete 2>/dev/null || true

log_info "Files copied to build directory"

# -----------------------------------------------------------------------------
# Generate ZIP File
# -----------------------------------------------------------------------------
log_info "Generating ZIP file..."

# Create symbolic link for proper directory name in zip
ln -s "$BUILD_DIR" "${GITHUB_WORKSPACE}/${SLUG}"
zip -r "${GITHUB_WORKSPACE}/${SLUG}.zip" "$SLUG" >> /dev/null
unlink "${GITHUB_WORKSPACE}/${SLUG}"

readonly ZIP_PATH="${GITHUB_WORKSPACE}/${SLUG}.zip"
echo "zip_path=$ZIP_PATH" >> "${GITHUB_OUTPUT}"

log_info "ZIP file generated: ${SLUG}.zip"

# -----------------------------------------------------------------------------
# Dry Run Check
# -----------------------------------------------------------------------------
if [ "${DRY_RUN:-false}" = "true" ]; then
    log_warning "Dry run mode - upload skipped"
    exit 0
fi

# -----------------------------------------------------------------------------
# Upload to EDD
# -----------------------------------------------------------------------------
log_info "Uploading to EDD..."

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36" \
    -H "Accept: */*" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Connection: keep-alive" \
    -H "Referer: https://github.com" \
    -F "key=$API_KEY" \
    -F "token=$API_TOKEN" \
    -F "item_id=$ITEM_ID" \
    -F "version=$VERSION" \
    -F "changelog=$CHANGELOG" \
    -F "file=@${ZIP_PATH}")

# Extract HTTP status code (last line)
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1)
# Extract response body (all but last line)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

log_info "HTTP Status: $HTTP_STATUS"
log_info "Response: $RESPONSE_BODY"

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
    log_info "Upload successful"
else
    log_error "Upload failed with HTTP status $HTTP_STATUS"
    log_error "Response: $RESPONSE_BODY"
    exit 1
fi

# -----------------------------------------------------------------------------
# Success
# -----------------------------------------------------------------------------
log_info ""
log_info "=== Deployment Complete ==="
log_info "Download: $SLUG"
log_info "Version: $VERSION"
log_info "Site: $SITE_URL"
