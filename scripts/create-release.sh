#!/bin/bash
# ABOUTME: Helper script for creating releases with validation and safety checks
# ABOUTME: Automates the release process while ensuring all checks pass

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

VERSION="${1:-}"
RELEASE_TYPE="${2:-stable}"

show_usage() {
    cat << EOF
Usage: $0 <version> [release-type]

Create a new release tag with validation

Arguments:
  version       Version number (e.g., 1.2.3)
  release-type  Type of release (stable, alpha, beta, rc) [default: stable]

Examples:
  $0 1.2.3                    # Stable release v1.2.3
  $0 1.2.3 alpha              # Alpha release v1.2.3-alpha.1
  $0 1.2.3 beta               # Beta release v1.2.3-beta.1
  $0 1.2.3 rc                 # Release candidate v1.2.3-rc.1

Pre-release Versioning:
  Script automatically increments pre-release numbers if tags exist:
    - v1.2.3-alpha.1 exists → creates v1.2.3-alpha.2
    - v1.2.3-beta.1 exists → creates v1.2.3-beta.2

Steps Performed:
  1. Validate version format
  2. Check git repository state
  3. Run test suite
  4. Test release workflow
  5. Create annotated git tag
  6. Show push instructions

EOF
}

if [[ -z "$VERSION" ]]; then
    show_usage
    exit 1
fi

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format: $VERSION${NC}"
    echo "Expected: X.Y.Z (e.g., 1.2.3)"
    exit 1
fi

# Construct full version tag
FULL_VERSION="$VERSION"
if [[ "$RELEASE_TYPE" != "stable" ]]; then
    # Find next pre-release number
    EXISTING_TAGS=$(git tag -l "v${VERSION}-${RELEASE_TYPE}.*" | sort -V)
    if [[ -n "$EXISTING_TAGS" ]]; then
        LAST_TAG=$(echo "$EXISTING_TAGS" | tail -1)
        LAST_NUM=$(echo "$LAST_TAG" | grep -oP "${RELEASE_TYPE}\.\K[0-9]+")
        NEXT_NUM=$((LAST_NUM + 1))
    else
        NEXT_NUM=1
    fi
    FULL_VERSION="${VERSION}-${RELEASE_TYPE}.${NEXT_NUM}"
fi

TAG_NAME="v${FULL_VERSION}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ProtonVPN Manager Release Creator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Version: $FULL_VERSION"
echo "Tag: $TAG_NAME"
echo "Type: $RELEASE_TYPE"
echo ""

# Pre-flight checks
echo -e "${YELLOW}Running pre-flight checks...${NC}"
echo ""

# Check if tag already exists
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo -e "${RED}Error: Tag $TAG_NAME already exists${NC}"
    echo "Use a different version number or delete the existing tag."
    exit 1
fi

# Check git repository state
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${RED}Error: Working directory has uncommitted changes${NC}"
    echo "Commit or stash changes before creating a release."
    git status --short
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "master" ]] && [[ "$RELEASE_TYPE" == "stable" ]]; then
    echo -e "${YELLOW}Warning: Creating stable release from branch: $CURRENT_BRANCH${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check remote sync
if ! git fetch --dry-run origin master &>/dev/null; then
    echo -e "${YELLOW}Warning: Unable to fetch from remote${NC}"
else
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse '@{u}' 2>/dev/null || echo "")
    BASE=$(git merge-base @ '@{u}' 2>/dev/null || echo "")

    if [[ -n "$REMOTE" ]] && [[ "$LOCAL" != "$REMOTE" ]]; then
        if [[ "$LOCAL" = "$BASE" ]]; then
            echo -e "${RED}Error: Local branch is behind remote${NC}"
            echo "Pull latest changes before creating a release."
            exit 1
        elif [[ "$REMOTE" = "$BASE" ]]; then
            echo -e "${YELLOW}Warning: Local branch is ahead of remote${NC}"
            echo "Remember to push commits before pushing the tag."
        else
            echo -e "${RED}Error: Local and remote have diverged${NC}"
            echo "Resolve divergence before creating a release."
            exit 1
        fi
    fi
fi

echo -e "${GREEN}✓ Pre-flight checks passed${NC}"
echo ""

# Run tests
echo -e "${YELLOW}Running test suite...${NC}"
if ./tests/run_tests.sh &>/dev/null; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${RED}✗ Tests failed${NC}"
    echo "Fix test failures before creating a release."
    exit 1
fi
echo ""

# Test release workflow
echo -e "${YELLOW}Testing release workflow...${NC}"
if ./scripts/test-release-workflow.sh "$FULL_VERSION" &>/dev/null; then
    echo -e "${GREEN}✓ Release workflow test passed${NC}"
else
    echo -e "${RED}✗ Release workflow test failed${NC}"
    echo "Run './scripts/test-release-workflow.sh $FULL_VERSION' for details."
    exit 1
fi
echo ""

# Generate changelog preview
echo -e "${YELLOW}Generating changelog preview...${NC}"
if command -v git-chglog &>/dev/null; then
    PREVIOUS_TAG=$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    if [[ -n "$PREVIOUS_TAG" ]]; then
        echo "Changes since $PREVIOUS_TAG:"
        echo ""
        git log --pretty=format:"%s" "${PREVIOUS_TAG}..HEAD" | head -10
        echo ""
        echo "... (see full changelog in release notes)"
    else
        echo "First release - full changelog will be generated"
    fi
else
    echo -e "${YELLOW}git-chglog not installed - changelog will be generated during release${NC}"
fi
echo ""

# Create tag
echo -e "${YELLOW}Creating release tag...${NC}"

# Generate tag message
TAG_MESSAGE="Release ${FULL_VERSION}

$(if [[ "$RELEASE_TYPE" != "stable" ]]; then echo "Pre-release version"; echo ""; fi)
This release includes:
$(git log --pretty=format:"- %s" "$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"..HEAD | head -5)

Created: $(date '+%Y-%m-%d %H:%M:%S')
Branch: ${CURRENT_BRANCH}
Commit: $(git rev-parse --short HEAD)
"

# Create annotated tag
if git tag -a "$TAG_NAME" -m "$TAG_MESSAGE"; then
    echo -e "${GREEN}✓ Tag created successfully${NC}"
else
    echo -e "${RED}✗ Failed to create tag${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Release Tag Created Successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Tag: $TAG_NAME"
echo "Commit: $(git rev-parse --short HEAD)"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo ""
echo "1. Review the tag:"
echo "   git show $TAG_NAME"
echo ""
echo "2. Push the tag to trigger release workflow:"
echo "   git push origin $TAG_NAME"
echo ""
echo "3. Monitor the GitHub Actions workflow:"
echo "   https://github.com/maxrantil/protonvpn-manager/actions"
echo ""
echo "4. Review and publish the release:"
echo "   https://github.com/maxrantil/protonvpn-manager/releases"
echo ""

if [[ "$RELEASE_TYPE" != "stable" ]]; then
    echo -e "${YELLOW}Note: This is a pre-release ($RELEASE_TYPE)${NC}"
    echo "It will be marked as pre-release on GitHub automatically."
    echo ""
fi

echo -e "${YELLOW}To delete the tag if something goes wrong:${NC}"
echo "   git tag -d $TAG_NAME"
echo ""
