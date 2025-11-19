#!/bin/bash

# Will send a curl request to the specified URL with the specified data and file.
set -euo pipefail

# Uncomment this when debugging the script.
#set -x

#########################################
# SETUP DEFAULTS #
#########################################
API_URL="${SITE_URL}/edd-api/download-deploy"
SLUG="${SLUG:-${GITHUB_REPOSITORY#*/}}"
VERSION="${VERSION:-${GITHUB_REF#refs/tags/}}"; VERSION="${VERSION#v}"
BUILD_DIR="${HOME}/build-${SLUG}"
CHANGELOG=""

# If the version is not set, check if package.json exists and get the version from there otherwise exit.
if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if [ -f ./package.json ]; then
        VERSION=$(node -p "require('./package.json').version")
    else
        VERSION=""
    fi
fi

#if changelog.txt exists, read it and store it in the CHANGELOG variable.
if [[ -f "${GITHUB_WORKSPACE}/changelog.txt" ]]; then
	CHANGELOG=$(<"${GITHUB_WORKSPACE}/changelog.txt")
fi

#########################################
# CHECK IF EVERYTHING IS SET CORRECTLY #
#########################################
for var in SITE_URL API_KEY API_TOKEN ITEM_ID VERSION; do
    if [ -z "${!var}" ]; then
        echo "$var is not set, exiting..."
        exit 1
    fi
done

# Output the download slug
echo "ℹ︎ SLUG is $SLUG"

# Output the download version
echo "ℹ︎ VERSION is $VERSION"
echo "version=$VERSION" >> "${GITHUB_OUTPUT}"

# Output the download changelog only first 100 characters.
echo "ℹ︎ CHANGELOG is ${CHANGELOG:0:100}"

# Output the download build directory
echo "ℹ︎ BUILD_DIR is $BUILD_DIR"

# Copy the file to the build directory
echo "➤ Copying files..."
if [[ -e "$GITHUB_WORKSPACE/.distignore" ]]; then
	echo "ℹ︎ Using .distignore"
	rsync -rc --exclude-from="$GITHUB_WORKSPACE/.distignore" "$GITHUB_WORKSPACE/" "$BUILD_DIR" --delete --delete-excluded
else
	rsync -rc "$GITHUB_WORKSPACE/" "$BUILD_DIR" --delete --delete-excluded
fi
# Remove empty directories
find "$BUILD_DIR" -type d -empty -delete
echo "✓ Files copied!"

# Zipping files
echo "➤ Zipping files..."
# use a symbolic link so the directory in the zip matches the file name
ln -s "$BUILD_DIR" "${GITHUB_WORKSPACE}/${SLUG}"
zip -r "${GITHUB_WORKSPACE}/${SLUG}.zip" "$SLUG"
unlink "${GITHUB_WORKSPACE}/${SLUG}"
echo "zip_path=${GITHUB_WORKSPACE}/${SLUG}.zip" >> "${GITHUB_OUTPUT}"
echo "✓ Zip file generated!"

# If dry run, then exit.
if $DRY_RUN; then
  echo "ℹ︎ Dry run: exiting..."
  exit 0
fi

# Release the download
echo "➤ Releasing download..."
curl -X POST "$API_URL" \
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
	-F "file=@${GITHUB_WORKSPACE}/${SLUG}.zip"

# add an empty line.
echo ""

# Check if the release was successful.
if [ $? -eq 0 ]; then
	echo "✓ Download released!"
else
	echo "✗ Failed to release download!"
	exit 1
fi

echo "✓ Done!"
