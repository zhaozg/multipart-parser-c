#!/bin/bash
# Upstream Tracking Helper Script
# This script helps check for new issues and PRs from upstream

set -e

UPSTREAM_OWNER="iafonov"
UPSTREAM_REPO="multipart-parser-c"
UPSTREAM_URL="https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}"

echo "=================================="
echo "Upstream Tracking Helper"
echo "Upstream: ${UPSTREAM_URL}"
echo "=================================="
echo ""

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "⚠️  GitHub CLI (gh) is not installed."
    echo "   Install it from: https://cli.github.com/"
    echo ""
    echo "   Without gh CLI, you can manually check:"
    echo "   - Issues: ${UPSTREAM_URL}/issues"
    echo "   - PRs: ${UPSTREAM_URL}/pulls"
    exit 1
fi

echo "📊 Fetching upstream statistics..."
echo ""

# Get open issues count
echo "🔍 Open Issues:"
gh issue list --repo "${UPSTREAM_OWNER}/${UPSTREAM_REPO}" --state open --limit 100 --json number,title,createdAt,author | \
    jq -r '.[] | "  #\(.number) - \(.title) (by @\(.author.login), \(.createdAt[:10]))"'
echo ""

# Get open PRs count
echo "🔀 Open Pull Requests:"
gh pr list --repo "${UPSTREAM_OWNER}/${UPSTREAM_REPO}" --state open --limit 100 --json number,title,createdAt,author | \
    jq -r '.[] | "  #\(.number) - \(.title) (by @\(.author.login), \(.createdAt[:10]))"'
echo ""

# Get recent closed PRs (last 10)
echo "✅ Recently Closed PRs (last 10):"
gh pr list --repo "${UPSTREAM_OWNER}/${UPSTREAM_REPO}" --state closed --limit 10 --json number,title,closedAt,mergedAt | \
    jq -r '.[] | if .mergedAt then "  #\(.number) - \(.title) [MERGED \(.mergedAt[:10])]" else "  #\(.number) - \(.title) [CLOSED \(.closedAt[:10])]" end'
echo ""

echo "=================================="
echo "📝 Next Steps:"
echo "=================================="
echo "1. Review the issues and PRs above"
echo "2. Update docs/ISSUES_TRACKING.md with any new issues"
echo "3. Update docs/PR_ANALYSIS.md with any new PRs"
echo "4. Update UPSTREAM_TRACKING.md with latest status"
echo "5. Update CHANGELOG.md if you merge anything"
echo ""
echo "For detailed view of a specific issue/PR:"
echo "  gh issue view <number> --repo ${UPSTREAM_OWNER}/${UPSTREAM_REPO}"
echo "  gh pr view <number> --repo ${UPSTREAM_OWNER}/${UPSTREAM_REPO}"
echo ""
