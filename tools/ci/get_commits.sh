#!/usr/bin/env bash
set -euo pipefail

EVENT_NAME="${1:?Usage: get_commits.sh <event_name> <before> <after> <pr_base> <pr_head> <sha>}"
EVENT_BEFORE="$2"
EVENT_AFTER="$3"
PR_BASE_SHA="$4"
PR_HEAD_SHA="$5"
GITHUB_SHA="$6"

if [ "$EVENT_NAME" = "push" ]; then
    if [ "$EVENT_BEFORE" = "0000000000000000000000000000000000000000" ]; then
        COMMITS=$(git rev-list --reverse "$EVENT_AFTER")
    elif git merge-base --is-ancestor "$EVENT_BEFORE" "$EVENT_AFTER" 2>/dev/null; then
        COMMITS=$(git rev-list --reverse "$EVENT_BEFORE".."$EVENT_AFTER")
    else
        COMMITS="$EVENT_AFTER"
    fi
elif [ "$EVENT_NAME" = "pull_request" ]; then
    if git merge-base --is-ancestor "$PR_BASE_SHA" "$PR_HEAD_SHA" 2>/dev/null; then
        COMMITS=$(git rev-list --reverse "$PR_BASE_SHA".."$PR_HEAD_SHA")
    else
        COMMITS="$GITHUB_SHA"
    fi
else
    COMMITS="$GITHUB_SHA"
fi

JSON_COMMITS="["
FIRST=true
INDEX=1

for COMMIT in $COMMITS; do
    MESSAGE=$(git log -1 --pretty=format:"%s" "$COMMIT")
    MESSAGE=$(echo "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    SHORT_SHA=$(git rev-parse --short "$COMMIT")

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        JSON_COMMITS="$JSON_COMMITS,"
    fi

    JSON_COMMITS="${JSON_COMMITS}{\"sha\":\"${COMMIT}\",\"short_sha\":\"${SHORT_SHA}\",\"message\":\"${MESSAGE}\",\"index\":${INDEX}}"
    INDEX=$((INDEX + 1))
done

JSON_COMMITS="$JSON_COMMITS]"

if [ "$JSON_COMMITS" = "[]" ]; then
    FALLBACK_SHA="${PR_HEAD_SHA:-$GITHUB_SHA}"
    FALLBACK_SHORT_SHA=$(git rev-parse --short "$FALLBACK_SHA")
    MESSAGE=$(git log -1 --pretty=format:"%s" "$FALLBACK_SHA")
    MESSAGE=$(echo "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    JSON_COMMITS="[{\"sha\":\"${FALLBACK_SHA}\",\"short_sha\":\"${FALLBACK_SHORT_SHA}\",\"message\":\"${MESSAGE}\",\"index\":1}]"
fi

echo "commits=$JSON_COMMITS" >> "$GITHUB_OUTPUT"