#!/bin/bash
set -e

# Visualize issue dependencies as a Mermaid diagram
# This script:
# 1. Fetches all issues from the repository
# 2. Queries blocking relationships via GraphQL
# 3. Calculates topological depth for each issue
# 4. Generates a Mermaid diagram with color-coding by depth

# Get configuration from command line or environment
OWNER="${OWNER:-}"
REPO="${REPO:-}"

# Usage message
usage() {
    echo "Usage: $0 OWNER REPO" >&2
    echo "" >&2
    echo "Generate a Mermaid diagram of issue dependencies with color-coding by topological depth." >&2
    echo "" >&2
    echo "Arguments:" >&2
    echo "  OWNER    GitHub organization or user" >&2
    echo "  REPO     Repository name" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  $0 myorg myrepo > dependencies.mmd" >&2
    exit 1
}

# Parse arguments or use environment variables as fallback
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ $# -eq 2 ]; then
    OWNER="$1"
    REPO="$2"
else
    # Fall back to environment variables
    OWNER="${OWNER:-}"
    REPO="${REPO:-}"
fi

if [ -z "$OWNER" ]; then
    echo "Error: OWNER must be provided as argument or environment variable" >&2
    usage
fi

if [ -z "$REPO" ]; then
    echo "Error: REPO must be provided as argument or environment variable" >&2
    usage
fi

echo "Fetching issues from repository $OWNER/$REPO..." >&2

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

# Get all issues (open and closed)
ALL_ISSUES=$(gh api graphql -f query="
{
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    issues(first: 100, states: [OPEN, CLOSED]) {
      nodes {
        number
        title
        state
        blockedBy(first: 100) {
          nodes {
            number
          }
        }
      }
    }
  }
}" 2>&1)

# Check if query was successful
if ! echo "$ALL_ISSUES" | jq -e '.data.repository.issues' > /dev/null 2>&1; then
    echo "Error: Failed to fetch issues from $OWNER/$REPO" >&2
    exit 1
fi

echo "Building dependency graph..." >&2

# Extract issue data into temporary file
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "$ALL_ISSUES" | jq -r '.data.repository.issues.nodes[] |
    "\(.number)|\(.state)|\(.title)|\([.blockedBy.nodes[].number] | join(","))"' > "$TEMP_DIR/issues.txt"

# Helper functions to read/write data using files (bash 3.2 compatible)
get_depth() {
    local issue=$1
    if [ -f "$TEMP_DIR/depth_$issue" ]; then
        cat "$TEMP_DIR/depth_$issue"
    fi
}

set_depth() {
    local issue=$1
    local depth=$2
    echo "$depth" > "$TEMP_DIR/depth_$issue"
}

get_state() {
    local issue=$1
    grep "^$issue|" "$TEMP_DIR/issues.txt" | cut -d'|' -f2
}

get_title() {
    local issue=$1
    grep "^$issue|" "$TEMP_DIR/issues.txt" | cut -d'|' -f3
}

get_blockers() {
    local issue=$1
    grep "^$issue|" "$TEMP_DIR/issues.txt" | cut -d'|' -f4
}

get_all_issues() {
    cut -d'|' -f1 "$TEMP_DIR/issues.txt"
}

# Calculate depth using recursive topological sort
calculate_depth() {
    local issue=$1

    # If already calculated, return it
    local existing_depth
    existing_depth=$(get_depth "$issue")
    if [ -n "$existing_depth" ]; then
        echo "$existing_depth"
        return
    fi

    # Get blockers for this issue
    local blockers
    blockers=$(get_blockers "$issue")

    # If no blockers, depth is 0
    if [ -z "$blockers" ]; then
        set_depth "$issue" 0
        echo 0
        return
    fi

    # Find max depth of all blockers
    local max_depth=0
    local old_ifs="$IFS"
    local blocker_depth
    IFS=','
    for blocker in $blockers; do
        if [ -n "$blocker" ]; then
            blocker_depth=$(calculate_depth "$blocker")
            if [ "$blocker_depth" -ge "$max_depth" ]; then
                max_depth=$((blocker_depth + 1))
            fi
        fi
    done
    IFS="$old_ifs"

    set_depth "$issue" "$max_depth"
    echo "$max_depth"
}

echo "Calculating topological depths..." >&2

# Calculate depth for all issues
for issue in $(get_all_issues); do
    calculate_depth "$issue" > /dev/null
done

# Find max depth for color palette
MAX_DEPTH=0
while read -r issue; do
    depth=$(get_depth "$issue")
    if [ "$depth" -gt "$MAX_DEPTH" ]; then
        MAX_DEPTH=$depth
    fi
done < <(get_all_issues)

echo "Generating Mermaid diagram..." >&2

# Helper function to get color by index
# Colors are spaced around the color wheel for maximum contrast between adjacent depths
get_color() {
    local idx=$1
    case $idx in
        0) echo "#ffcdd2" ;;  # Red (0°)
        1) echo "#c5e1a5" ;;  # Green (120°)
        2) echo "#bbdefb" ;;  # Blue (240°)
        3) echo "#ffe082" ;;  # Yellow (60°)
        4) echo "#ce93d8" ;;  # Purple (300°)
        5) echo "#80deea" ;;  # Cyan (180°)
        6) echo "#ffab91" ;;  # Orange (30°)
        7) echo "#a5d6a7" ;;  # Light green (150°)
        8) echo "#9fa8da" ;;  # Indigo (270°)
        9) echo "#fff59d" ;;  # Light yellow (90°)
        *) echo "#e0e0e0" ;;  # Gray (fallback)
    esac
}

# Generate Mermaid output
echo "graph TD"
echo ""

# Add all issues with styling
ISSUE_COUNT=0
while read -r issue; do
    depth=$(get_depth "$issue")
    state=$(get_state "$issue")
    title=$(get_title "$issue")

    # Escape special characters in title
    title="${title//\"/\\\"}"

    # Choose color based on depth
    color_idx=$((depth % 10))
    color=$(get_color "$color_idx")

    # Add stroke for closed issues
    if [ "$state" = "CLOSED" ]; then
        echo "    issue${issue}[\"#${issue}: ${title}\"]"
        echo "    style issue${issue} fill:${color},stroke:#4caf50,stroke-width:3px"
    else
        echo "    issue${issue}[\"#${issue}: ${title}\"]"
        echo "    style issue${issue} fill:${color},stroke:#333,stroke-width:1px"
    fi

    ISSUE_COUNT=$((ISSUE_COUNT + 1))
done < <(get_all_issues)

echo ""

# Add edges (blocking relationships)
while read -r issue; do
    blockers=$(get_blockers "$issue")
    if [ -n "$blockers" ]; then
        old_ifs="$IFS"
        IFS=','
        for blocker in $blockers; do
            if [ -n "$blocker" ]; then
                echo "    issue${blocker} --> issue${issue}"
            fi
        done
        IFS="$old_ifs"
    fi
done < <(get_all_issues)

echo ""
echo "%% Legend:"
echo "%% - Different colors = different topological depths (spaced around color wheel for contrast)"
echo "%% - Green border = closed issue"
echo "%% - Gray border = open issue"
echo "%% - Arrow direction = blocks relationship (A --> B means A blocks B)"

echo "Done! Found $ISSUE_COUNT issues with max depth $MAX_DEPTH" >&2
