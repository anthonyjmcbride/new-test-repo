#! /bin/sh
set -eu

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

check_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' not found."
}

check_command git
check_command curl
check_command jq

GITHUB_USER=${GITHUB_USER:-anthonyjmcbride}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
repoName=${1:-}
while [ -z "$repoName" ]; do
  echo "Please enter the name of the new repository:"
  read -r -p $'Repository name: ' repoName
 done

printf '# %s\n' "$repoName" > README.md
git init || fail 'git init failed'
git add README.md || fail 'git add failed'
git commit -m "first commit" || fail 'git commit failed'

if [ -n "$GITHUB_TOKEN" ]; then
  create_response=$(curl -sS -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/user/repos \
    -d "{\"name\": \"$repoName\", \"private\": false}" -w "\n%{http_code}")
else
  create_response=$(curl -sS -u "$GITHUB_USER" -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/user/repos \
    -d "{\"name\": \"$repoName\", \"private\": false}" -w "\n%{http_code}")
fi
http_code=$(printf '%s' "$create_response" | tail -n1)
response_body=$(printf '%s' "$create_response" | sed '$d')
[ "$http_code" = "201" ] || fail "GitHub repo creation failed (HTTP $http_code): $(printf '%s' "$response_body" | jq -r '.message // "unknown error"')"

GIT_URL=$(printf '%s' "$response_body" | jq -r '.clone_url // empty')
[ -n "$GIT_URL" ] || fail 'Could not determine Git clone URL from GitHub response.'

git branch -M main || fail 'git branch -M main failed'
git remote add origin "$GIT_URL" || fail 'git remote add origin failed'
git push -u origin main || fail 'git push failed'

