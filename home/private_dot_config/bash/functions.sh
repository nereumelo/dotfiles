# ~/.config/bash/functions.sh — anything with args/conditionals
# shellcheck shell=bash

mkcd() {
  mkdir -p -- "$1" && cd -- "$1" || return
}

# Host blocks live in ~/.ssh/config.local (not git):
#   HostName, User, IdentityAgent, IdentitiesOnly, IdentityFile
# ssh-host-local <host> <hostname> <user>
# ssh-pub <host> <key>

# Tilde is for OpenSSH config (IdentityAgent ~/.bitwarden-ssh-agent.sock), not bash expansion.
# shellcheck disable=SC2088
_SSH_IDENTITY_AGENT='~/.bitwarden-ssh-agent.sock'

_ssh_config_local() {
  printf '%s\n' "${HOME}/.ssh/config.local"
}

_ssh_ensure_config_local() {
  mkdir -p "${HOME}/.ssh" || return
  chmod 700 "${HOME}/.ssh"
  local f
  f="$(_ssh_config_local)"
  [[ -e "$f" ]] || touch "$f"
  chmod 600 "$f"
}

_ssh_require_token() {
  local label="$1" value="$2"
  if [[ -z "$value" || "$value" == -* || "$value" =~ [[:space:]] ]]; then
    printf '%s: invalid %s\n' "${FUNCNAME[1]}" "$label" >&2
    return 2
  fi
}

_ssh_host_in_local() {
  local host="$1"
  local f
  f="$(_ssh_config_local)"
  [[ -f "$f" ]] || return 1
  awk -v host="$host" '
    {
      sub(/\r$/, "")
    }
    $1 == "Host" {
      for (i = 2; i <= NF; i++) {
        if ($i == host) { found = 1; exit }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$f"
}

_ssh_local_field() {
  local host="$1" field="$2"
  local f="${3:-$(_ssh_config_local)}"
  [[ -f "$f" ]] || return 1
  awk -v host="$host" -v field="$field" '
    {
      sub(/\r$/, "")
    }
    $1 == "Host" {
      inhost = 0
      for (i = 2; i <= NF; i++) if ($i == host) inhost = 1
      next
    }
    $1 == "Match" { inhost = 0; next }
    inhost && $1 == field {
      $1 = ""
      sub(/^[[:space:]]+/, "")
      print
      found = 1
      exit
    }
    END { exit found ? 0 : 1 }
  ' "$f"
}

# MODE=setup  host hostname user
# MODE=identity host identity_file
_ssh_rewrite_local_host() {
  local mode="$1" host="$2"
  local hostname="${3:-}" user="${4:-}" identity_file="${5:-}"
  local f tmp
  f="$(_ssh_config_local)"
  tmp="$(mktemp "${f}.XXXXXX")" || return
  if ! awk -v mode="$mode" -v host="$host" -v hostname="$hostname" \
      -v user="$user" -v identity_file="$identity_file" \
      -v agent="$_SSH_IDENTITY_AGENT" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function flush() {
      if (!in_block) return
      if (current_is_target) {
        emit_target()
        emitted_target = 1
      } else {
        printf "%s", buf
      }
      buf = ""
      in_block = 0
      current_is_target = 0
      host_line = ""
      delete vals
      delete extras
      n_extra = 0
    }
    function emit_target(    hn, usr, idf, ag, io, i) {
      print host_line
      hn = (mode == "setup") ? hostname : vals["HostName"]
      usr = (mode == "setup") ? user : vals["User"]
      if (mode == "identity" && identity_file != "") idf = identity_file
      else idf = vals["IdentityFile"]
      if (hn != "") print "  HostName " hn
      if (usr != "") print "  User " usr
      if (mode == "setup") {
        ag = agent
        io = "yes"
      } else {
        ag = (vals["IdentityAgent"] != "") ? vals["IdentityAgent"] : agent
        io = (vals["IdentitiesOnly"] != "") ? vals["IdentitiesOnly"] : "yes"
      }
      print "  IdentityAgent " ag
      print "  IdentitiesOnly " io
      if (idf != "") print "  IdentityFile " idf
      for (i = 1; i <= n_extra; i++) print extras[i]
    }
    {
      sub(/\r$/, "")
    }
    $1 == "Host" || $1 == "Match" {
      flush()
      in_block = 1
      host_line = $0
      current_is_target = 0
      if ($1 == "Host") {
        for (i = 2; i <= NF; i++) {
          if ($i == host) current_is_target = 1
        }
      }
      if (!current_is_target) buf = $0 ORS
      next
    }
    in_block && current_is_target {
      line = $0
      raw = trim(line)
      if (raw == "" || raw ~ /^#/) next
      key = $1
      rest = trim(substr($0, index($0, $1) + length($1)))
      if (key == "HostName" || key == "User" || key == "IdentityAgent" || key == "IdentitiesOnly" || key == "IdentityFile") {
        vals[key] = rest
      } else {
        extras[++n_extra] = $0
      }
      next
    }
    in_block {
      buf = buf $0 ORS
      next
    }
    { print }
    END {
      flush()
      if (mode == "setup" && !emitted_target) {
        host_line = "Host " host
        emit_target()
      }
      if (mode == "identity" && !emitted_target) {
        exit 1
      }
      exit 0
    }
  ' "$f" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$f"
  chmod 600 "$f"
}

ssh-host-local() {
  if [[ $# -ne 3 ]]; then
    printf 'usage: ssh-host-local <host> <hostname> <user>\n' >&2
    printf 'IdentityAgent (%s) and IdentitiesOnly (yes) are always set.\n' "$_SSH_IDENTITY_AGENT" >&2
    return 2
  fi
  local host="$1" hostname="$2" user="$3"
  _ssh_require_token host "$host" || return
  _ssh_require_token hostname "$hostname" || return
  _ssh_require_token user "$user" || return
  _ssh_ensure_config_local || return
  _ssh_rewrite_local_host setup "$host" "$hostname" "$user" || return
  printf 'Host %s → HostName %s User %s (IdentityAgent %s, IdentitiesOnly yes)\n' \
    "$host" "$hostname" "$user" "$_SSH_IDENTITY_AGENT"
}

_ssh_set_identity_file() {
  local host="$1" identity_file="$2"
  _ssh_rewrite_local_host identity "$host" "" "" "$identity_file"
}

ssh-pub() {
  if [[ $# -ne 2 ]]; then
    printf 'usage: ssh-pub <host> <key>\n' >&2
    printf 'Writes ~/.ssh/<key>.pub from the agent and sets IdentityFile on Host <host>.\n' >&2
    printf 'Host must already exist in ~/.ssh/config.local (ssh-host-local).\n' >&2
    return 2
  fi
  local host="$1" key="$2"
  _ssh_require_token host "$host" || return
  if [[ ! "$key" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'ssh-pub: key must be a simple name (A-Z a-z 0-9 . _ -)\n' >&2
    return 2
  fi
  _ssh_ensure_config_local || return
  if ! _ssh_host_in_local "$host"; then
    printf 'ssh-pub: host %s is not in ~/.ssh/config.local\n' "$host" >&2
    printf 'Set it up first: ssh-host-local %s <hostname> <user>\n' "$host" >&2
    return 1
  fi

  local sock="${SSH_AUTH_SOCK:-${HOME}/.bitwarden-ssh-agent.sock}"
  if [[ ! -S "$sock" ]]; then
    printf 'ssh-pub: Bitwarden SSH agent socket missing — unlock Arch Bitwarden\n' >&2
    return 1
  fi
  local old_sock="${SSH_AUTH_SOCK:-}"
  export SSH_AUTH_SOCK="$sock"

  local lines matches exact chosen count dest
  if ! lines="$(ssh-add -L 2>/dev/null)"; then
    [[ -n "$old_sock" ]] && export SSH_AUTH_SOCK="$old_sock"
    printf 'ssh-pub: ssh-add -L failed (unlock Bitwarden and Allow the agent prompt)\n' >&2
    return 1
  fi
  [[ -n "$old_sock" ]] && export SSH_AUTH_SOCK="$old_sock"

  matches="$(printf '%s\n' "$lines" | grep -F -i -- "$key" || true)"
  if [[ -z "$matches" ]]; then
    printf 'ssh-pub: no agent key comment matches %s\n' "$key" >&2
    printf 'List comments with: ssh-add -L\n' >&2
    return 1
  fi

  exact="$(printf '%s\n' "$matches" | awk -v k="$key" '
    { if (tolower($NF) == tolower(k)) print }
  ')"
  if [[ -n "$exact" ]]; then
    matches="$exact"
  fi
  count="$(printf '%s\n' "$matches" | grep -c .)"
  if [[ "$count" -gt 1 ]]; then
    printf 'ssh-pub: multiple agent keys match %s; use a more specific Bitwarden comment:\n' "$key" >&2
    printf '%s\n' "$matches" | awk '{ print "  " $NF }' >&2
    return 1
  fi
  chosen="$matches"

  dest="${HOME}/.ssh/${key}.pub"
  printf '%s\n' "$chosen" >"$dest"
  chmod 644 "$dest"
  # OpenSSH expands ~ in IdentityFile; do not use $HOME here.
  # shellcheck disable=SC2088
  _ssh_set_identity_file "$host" "~/.ssh/${key}.pub" || return

  if [[ "$key" == "home-personal" || "$key" == "work" ]] && command -v chezmoi >/dev/null 2>&1; then
    chezmoi apply || printf 'ssh-pub: wrote the key; chezmoi apply failed (git signing templates)\n' >&2
  fi

  printf 'Wrote %s and IdentityFile on Host %s\n' "$dest" "$host"
  if command -v ssh-keygen >/dev/null 2>&1; then
    command ssh-keygen -lf "$dest"
  fi
}
