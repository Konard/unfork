#!/usr/bin/env bash
# unfork.sh
#
# Universal script: detaches a forked GitHub repo into a new standalone repo.
# Workflow:
#   1. Clone or update a bare mirror of the original into <repo>.git
#   2. Copy that mirror to <repo>-unforked.git
#   3. Push the copied mirror to the new standalone GitHub repo
# Usage:
#   ./unfork.sh <repository-url> [new-owner]
# Example:
#   ./unfork.sh https://github.com/deep-assistant/api-gateway
#   ./unfork.sh deep-assistant/api-gateway my-username
# Requirements: git, GitHub CLI (gh) authenticated (e.g. via `gh auth login`).

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <repository-url> [new-owner]"
  exit 1
fi

# Input URL or owner/repo
ORIGIN_INPUT="$1"
# Strip .git suffix and trailing slash
ORIGIN_INPUT="${ORIGIN_INPUT%.git}"
ORIGIN_INPUT="${ORIGIN_INPUT%/}"

# Derive owner/repo path
case "$ORIGIN_INPUT" in
  git@github.com:*)
    REPO_PATH="${ORIGIN_INPUT#git@github.com:}"
    ;;
  https://github.com/*)
    REPO_PATH="${ORIGIN_INPUT#https://github.com/}"
    ;;
  http://github.com/*)
    REPO_PATH="${ORIGIN_INPUT#http://github.com/}"
    ;;
  *)
    REPO_PATH="$ORIGIN_INPUT"
    ;;
esac
# Clean path
REPO_PATH="${REPO_PATH%.git}"
REPO_PATH="${REPO_PATH%/}"

# Split into owner and repo
ORIGIN_OWNER="${REPO_PATH%%/*}"
ORIGIN_REPO="${REPO_PATH#*/}"

# Determine new owner (optional override)
if [[ $# -eq 2 ]]; then
  NEW_OWNER="$2"
else
  NEW_OWNER="$ORIGIN_OWNER"
fi

# New repository name
NEW_REPO="${ORIGIN_REPO}-unforked"

# Directories for mirrors
ORIGIN_MIRROR_DIR="${PWD}/${ORIGIN_REPO}.git"
NEW_MIRROR_DIR="${PWD}/${NEW_REPO}.git"

# Step 1: clone or update original mirror
if [[ -d "$ORIGIN_MIRROR_DIR" ]]; then
  echo "Updating existing mirror in $ORIGIN_MIRROR_DIR..."
  git --git-dir="$ORIGIN_MIRROR_DIR" fetch --all --prune
else
  echo "Creating bare mirror of $ORIGIN_INPUT into $ORIGIN_MIRROR_DIR..."
  git clone --bare "$ORIGIN_INPUT" "$ORIGIN_MIRROR_DIR"
fi

# Step 2: prepare new mirror by copying
if [[ -d "$NEW_MIRROR_DIR" ]]; then
  echo "Removing existing new mirror at $NEW_MIRROR_DIR..."
  rm -rf "$NEW_MIRROR_DIR"
fi

echo "Copying $ORIGIN_MIRROR_DIR to $NEW_MIRROR_DIR..."
cp -a "$ORIGIN_MIRROR_DIR" "$NEW_MIRROR_DIR"

# Step 3: verify GitHub CLI is available
# This must be on its own line to detect correctly
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is required." >&2
  exit 1
fi

# Create target GitHub repo if missing
echo "Ensuring target repo ${NEW_OWNER}/${NEW_REPO} exists..."
if ! gh repo view "${NEW_OWNER}/${NEW_REPO}" >/dev/null 2>&1; then
  echo "Creating new repo ${NEW_OWNER}/${NEW_REPO}..."
  gh repo create "${NEW_OWNER}/${NEW_REPO}" --public -y
else
  echo "Target repo already exists, skipping creation."
fi

# Push the new mirror to GitHub
echo "Pushing mirror from $NEW_MIRROR_DIR to GitHub..."
(
  cd "$NEW_MIRROR_DIR"
  git push --mirror "https://github.com/${NEW_OWNER}/${NEW_REPO}.git"
)

# Final summary
cat <<EOF
Done! Your standalone repository is available at:
https://github.com/${NEW_OWNER}/${NEW_REPO}

Local mirror directories:
  Original mirror: $ORIGIN_MIRROR_DIR
  Unforked mirror: $NEW_MIRROR_DIR
EOF
