# Git minimum for includeIf hasconfig:remote.*.url (org name/email/signing).
# Sourced by install.sh and verify.sh. GIT_MIN_VERSION is the floor.
GIT_MIN_VERSION=2.36

git_installed_version() {
  command git version 2>/dev/null | awk '{print $3}'
}

# git_at_least [min] — true when installed git is >= min (default GIT_MIN_VERSION).
git_at_least() {
  local min="${1:-$GIT_MIN_VERSION}" have
  have="$(git_installed_version)"
  [[ -n "$have" ]] && [[ "$(printf '%s\n' "$min" "$have" | sort -V | head -1)" == "$min" ]]
}
