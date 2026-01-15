#!/bin/bash
set -e

# Find newly unblocked issues that were blocked by the closed issue
# This script:
# 1. Takes the closed issue number as input
# 2. Queries which issues it was blocking via GraphQL
# 3. For each blocked issue, checks if all its blockers are now closed
# 4. Outputs newly unblocked issue numbers

# Usage message
usage() {
    echo "Usage: $0 CLOSED_ISSUE OWNER REPO" >&2
    echo "" >&2
    echo "Find issues that are newly unblocked after closing a specific issue." >&2
    echo "" >&2
    echo "Arguments:" >&2
    echo "  CLOSED_ISSUE  Issue number that was just closed" >&2
    echo "  OWNER         GitHub organization or user" >&2
    echo "  REPO          Repository name" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  $0 10 myorg myrepo" >&2
    exit 1
}

# Parse arguments or use environment variables as fallback
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ $# -eq 3 ]; then
    CLOSED_ISSUE="$1"
    OWNER="$2"
    REPO="$3"
else
    # Fall back to environment variables
    CLOSED_ISSUE="${CLOSED_ISSUE:-}"
    OWNER="${OWNER:-}"
    REPO="${REPO:-}"
fi

if [ -z "$CLOSED_ISSUE" ]; then
    echo "Error: CLOSED_ISSUE must be provided as argument or environment variable" >&2
    usage
fi

if [ -z "$OWNER" ]; then
    echo "Error: OWNER must be provided as argument or environment variable" >&2
    usage
fi

if [ -z "$REPO" ]; then
    echo "Error: REPO must be provided as argument or environment variable" >&2
    usage
fi

echo "Checking issues blocked by #$CLOSED_ISSUE in repository $OWNER/$REPO..." >&2

# Validate repository exists
REPO_CHECK=$(gh api "repos/$OWNER/$REPO" 2>&1 || true)
if echo "$REPO_CHECK" | grep -q "Not Found"; then
    echo "Error: Repository '$OWNER/$REPO' not found" >&2
    echo "Please verify the owner and repository name are correct" >&2
    exit 1
fi

if echo "$REPO_CHECK" | grep -q "API rate limit exceeded"; then
    echo "Error: GitHub API rate limit exceeded" >&2
    exit 1
fi

# Query the closed issue to find what it was blocking
BLOCKS_QUERY=$(gh api graphql -f query="
{
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    issue(number: $CLOSED_ISSUE) {
      number
      state
      blocking(first: 100) {
        nodes {
          number
          state
        }
      }
    }
  }
}" 2>&1)

# Check if query was successful
if ! echo "$BLOCKS_QUERY" | jq -e '.data.repository.issue' > /dev/null 2>&1; then
    echo "Error: Failed to query issue #$CLOSED_ISSUE in $OWNER/$REPO" >&2

    # Check if issue doesn't exist
    if echo "$BLOCKS_QUERY" | jq -r '.data.repository.issue' | grep -q "null"; then
        echo "Issue #$CLOSED_ISSUE does not exist in this repository" >&2
    fi

    exit 1
fi

# Get issues that were blocked by the closed issue
BLOCKED_ISSUES=$(echo "$BLOCKS_QUERY" | jq -r '.data.repository.issue.blocking.nodes[] | select(.state == "OPEN") | .number')

if [ -z "$BLOCKED_ISSUES" ]; then
    echo "No open issues were blocked by #$CLOSED_ISSUE" >&2
    exit 0
fi

echo "Found blocked issues, checking if they are now unblocked..." >&2
UNBLOCKED=()

# For each issue that was blocked, check if all its blockers are now closed
for issue_num in $BLOCKED_ISSUES; do
    BLOCKED_BY=$(gh api graphql -f query="
    {
      repository(owner: \"$OWNER\", name: \"$REPO\") {
        issue(number: $issue_num) {
          number
          state
          blockedBy(first: 100) {
            nodes {
              number
              state
            }
          }
        }
      }
    }" 2>&1)

    # Check if query was successful
    if echo "$BLOCKED_BY" | jq -e '.data.repository.issue' > /dev/null 2>&1; then
        # Get all blocker states
        BLOCKER_STATES=$(echo "$BLOCKED_BY" | jq -r '.data.repository.issue.blockedBy.nodes[].state')

        # Check if any blocker is still open
        HAS_OPEN_BLOCKER=false
        for state in $BLOCKER_STATES; do
            if [ "$state" = "OPEN" ]; then
                HAS_OPEN_BLOCKER=true
                break
            fi
        done

        # If all blockers are closed, issue is now unblocked
        if [ "$HAS_OPEN_BLOCKER" = false ]; then
            UNBLOCKED+=("$issue_num")
        fi
    fi
done

# Output unblocked issue numbers (one per line)
for issue in "${UNBLOCKED[@]}"; do
    echo "$issue"
done

echo "Found ${#UNBLOCKED[@]} newly unblocked issues" >&2
