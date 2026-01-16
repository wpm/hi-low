#!/bin/bash
set -e

# Trigger Claude on a list of issues
# This script:
# 1. Takes OWNER and REPO as first two arguments
# 2. Takes a list of issue numbers (remaining args or stdin)
# 3. Checks if Claude has already been triggered on each issue
# 4. Posts trigger comment if not already present
# 5. Outputs summary of triggered issues

# Usage message
usage() {
    echo "Usage: $0 OWNER REPO [PROJECT_NUMBER] [ISSUE_NUMBERS...]" >&2
    echo "" >&2
    echo "Trigger Claude on a list of issues by posting mention comments." >&2
    echo "" >&2
    echo "Arguments:" >&2
    echo "  OWNER          GitHub organization or user" >&2
    echo "  REPO           Repository name" >&2
    echo "  PROJECT_NUMBER GitHub Project number (optional, use '-' to skip)" >&2
    echo "                 If provided, issues will be moved to 'In Progress' status" >&2
    echo "  ISSUE_NUMBERS  Space-separated issue numbers, or read from stdin if not provided" >&2
    echo "" >&2
    echo "Environment Variables:" >&2
    echo "  TRIGGER_MESSAGE  Custom trigger message (optional)" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 myorg myrepo - 10 15 20" >&2
    echo "  $0 myorg myrepo 3 10 15 20" >&2
    echo "  echo -e '10\n15\n20' | $0 myorg myrepo 3" >&2
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

# Parse OWNER, REPO, and optional PROJECT_NUMBER from arguments
if [ $# -ge 2 ]; then
    OWNER="$1"
    REPO="$2"
    shift 2

    # Check if third argument is a project number or dash
    if [ $# -gt 0 ] && [ "$1" != "-" ]; then
        # Check if it looks like a number
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            PROJECT_NUMBER="$1"
            shift
        fi
    elif [ "$1" = "-" ]; then
        # Skip the dash placeholder
        shift
    fi
else
    echo "Error: OWNER and REPO are required arguments" >&2
    usage
fi

# Trigger message (can be overridden via environment)
TRIGGER_MESSAGE="${TRIGGER_MESSAGE:-@claude Implement this issue.}"

# Get issue numbers from remaining arguments or stdin
if [ $# -gt 0 ]; then
    ISSUE_NUMBERS="$*"
else
    # Read from stdin
    ISSUE_NUMBERS=$(cat)
fi

if [ -z "$ISSUE_NUMBERS" ]; then
    echo "No issue numbers provided" >&2
    exit 0
fi

# Validate repository exists
echo "Validating repository $OWNER/$REPO..." >&2
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

# Track triggered issues
TRIGGERED_COUNT=0
SKIPPED_COUNT=0
TRIGGERED_ISSUES=()

echo "Triggering Claude on issues in $OWNER/$REPO..." >&2
echo "" >&2

for issue_num in $ISSUE_NUMBERS; do
    echo "Checking issue #$issue_num..." >&2

    # Check if there's already a Claude trigger comment (to avoid duplicates)
    EXISTING_COMMENT=$(gh issue view "$issue_num" --repo "$OWNER/$REPO" --json comments \
        --jq '.comments[] | select(.body | contains("@claude") and contains("implement")) | .body' \
        2>/dev/null | head -1 || true)

    if [ -z "$EXISTING_COMMENT" ]; then
        # Post Claude trigger comment
        COMMENT_RESULT=$(gh issue comment "$issue_num" --repo "$OWNER/$REPO" --body "$TRIGGER_MESSAGE" 2>&1 || true)

        if echo "$COMMENT_RESULT" | grep -q "could not be found"; then
            echo "  ✗ Error: Issue #$issue_num does not exist" >&2
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        elif echo "$COMMENT_RESULT" | grep -q "API rate limit exceeded"; then
            echo "  ✗ Error: API rate limit exceeded" >&2
            exit 1
        else
            echo "  ✓ Posted trigger comment on issue #$issue_num" >&2
            TRIGGERED_COUNT=$((TRIGGERED_COUNT + 1))
            TRIGGERED_ISSUES+=("$issue_num")

            # Update project status to "In Progress" if PROJECT_NUMBER is provided
            if [ -n "${PROJECT_NUMBER:-}" ]; then
                echo "  → Updating status to 'In Progress'..." >&2

                # Get the project item ID for this issue
                PROJECT_ITEM=$(gh api graphql -f query="
                {
                  repository(owner: \"$OWNER\", name: \"$REPO\") {
                    issue(number: $issue_num) {
                      projectItems(first: 10) {
                        nodes {
                          id
                          project {
                            number
                          }
                        }
                      }
                    }
                  }
                }" 2>&1 | jq -r ".data.repository.issue.projectItems.nodes[] | select(.project.number == $PROJECT_NUMBER) | .id")

                if [ -n "$PROJECT_ITEM" ]; then
                    # Get the Status field ID and "In Progress" option ID
                    STATUS_FIELD=$(gh api graphql -f query="
                    {
                      user(login: \"$OWNER\") {
                        projectV2(number: $PROJECT_NUMBER) {
                          fields(first: 20) {
                            nodes {
                              ... on ProjectV2SingleSelectField {
                                id
                                name
                                options {
                                  id
                                  name
                                }
                              }
                            }
                          }
                        }
                      }
                    }" 2>&1 | jq -r '.data.user.projectV2.fields.nodes[] | select(.name == "Status")')

                    FIELD_ID=$(echo "$STATUS_FIELD" | jq -r '.id')
                    IN_PROGRESS_OPTION=$(echo "$STATUS_FIELD" | jq -r '.options[] | select(.name == "In Progress") | .id')

                    if [ -n "$FIELD_ID" ] && [ -n "$IN_PROGRESS_OPTION" ]; then
                        gh api graphql -f query="
                        mutation {
                          updateProjectV2ItemFieldValue(
                            input: {
                              projectId: \"$(gh api graphql -f query="{user(login: \"$OWNER\") {projectV2(number: $PROJECT_NUMBER) {id}}}" | jq -r '.data.user.projectV2.id')\"
                              itemId: \"$PROJECT_ITEM\"
                              fieldId: \"$FIELD_ID\"
                              value: {singleSelectOptionId: \"$IN_PROGRESS_OPTION\"}
                            }
                          ) {
                            projectV2Item {
                              id
                            }
                          }
                        }" > /dev/null 2>&1

                        echo "     ✓ Status updated to 'In Progress'" >&2
                    fi
                fi
            fi
        fi
    else
        echo "  - Issue #$issue_num already has a Claude trigger comment, skipping" >&2
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done

echo "" >&2
echo "Summary:" >&2
echo "  Triggered: $TRIGGERED_COUNT" >&2
echo "  Skipped:   $SKIPPED_COUNT" >&2

# Output triggered issue numbers (for downstream processing)
if [ ${#TRIGGERED_ISSUES[@]} -gt 0 ]; then
    for issue in "${TRIGGERED_ISSUES[@]}"; do
        echo "$issue"
    done
fi
