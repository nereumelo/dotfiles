# ~/.config/bash/functions.sh — anything with args/conditionals
# shellcheck shell=bash

mkcd() {
  mkdir -p -- "$1" && cd -- "$1" || return
}

# Windows binaries are not on PATH (wsl.conf appendWindowsPath=false).
_windows_exe() {
  local p
  for p in "$@"; do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

# Map file(1) --mime-encoding labels to iconv -f names.
_copy_iconv_from() {
  case "$1" in
    utf-8|us-ascii|ascii) printf '%s\n' UTF-8 ;;
    utf-16le) printf '%s\n' UTF-16LE ;;
    utf-16be) printf '%s\n' UTF-16BE ;;
    utf-16) printf '%s\n' UTF-16 ;;
    iso-8859-1) printf '%s\n' ISO-8859-1 ;;
    iso-8859-15) printf '%s\n' ISO-8859-15 ;;
    windows-1252|cp1252) printf '%s\n' WINDOWS-1252 ;;
    unknown-8bit|binary|'') printf '%s\n' UTF-8 ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Drop a leading UTF-8 BOM (U+FEFF) so it is not pasted as the first char.
_copy_strip_utf8_bom() {
  local f="$1" tmp sig
  [[ -s "$f" ]] || return 0
  sig="$(command head -c 3 "$f")" || return
  if [[ "$sig" != $'\xef\xbb\xbf' ]]; then
    return 0
  fi
  tmp="$(mktemp)" || return
  command tail -c +4 "$f" >"$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# Convert source bytes to UTF-8 text with no BOM (X11/Wayland clipboard).
_copy_to_utf8() {
  local from="$1" src="$2" out="$3"
  if [[ "$from" == UTF-8 ]]; then
    command cat -- "$src" >"$out" || return
  else
    iconv -f "$from" -t UTF-8 -- "$src" >"$out" || return
  fi
  _copy_strip_utf8_bom "$out"
}

# WSLg shares the X11/Wayland clipboard with Windows. No clip.exe / BOM.
_copy_to_clipboard() {
  local payload="$1"
  if [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
    if xclip -selection clipboard -in <"$payload"; then
      return 0
    fi
  fi
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    if wl-copy --type text/plain <"$payload"; then
      return 0
    fi
  fi
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'copy: no DISPLAY/WAYLAND_DISPLAY (WSLg?)\n' >&2
    return 1
  fi
  printf 'copy: need xclip (X11) or wl-copy (Wayland)\n' >&2
  return 1
}

# Clipboard via WSLg (xclip / wl-copy). Detects source encoding, emits UTF-8.
#   copy [file]
#   <cmd> | copy
copy() {
  local tmp out enc from
  if [[ $# -gt 1 ]]; then
    printf 'usage: copy [file]\n       <cmd> | copy\n' >&2
    return 2
  fi
  if [[ $# -eq 1 ]]; then
    if [[ ! -f "$1" ]]; then
      printf 'copy: not a regular file: %s\n' "$1" >&2
      return 1
    fi
  elif [[ -t 0 ]]; then
    printf 'usage: copy [file]\n       <cmd> | copy\n' >&2
    return 2
  fi

  tmp="$(mktemp)" || return
  out="$(mktemp)" || { rm -f "$tmp"; return 1; }

  if [[ $# -eq 1 ]]; then
    if ! command cat -- "$1" >"$tmp"; then
      rm -f "$tmp" "$out"
      return 1
    fi
  elif ! command cat >"$tmp"; then
    rm -f "$tmp" "$out"
    return 1
  fi

  enc="$(file -b --mime-encoding "$tmp" 2>/dev/null || printf '%s\n' utf-8)"
  enc="${enc,,}"
  from="$(_copy_iconv_from "$enc")"

  if _copy_to_utf8 "$from" "$tmp" "$out" && _copy_to_clipboard "$out"; then
    rm -f "$tmp" "$out"
    return 0
  fi
  if [[ "$from" != UTF-8 ]] && _copy_to_utf8 UTF-8 "$tmp" "$out" && _copy_to_clipboard "$out"; then
    rm -f "$tmp" "$out"
    return 0
  fi
  if [[ "$from" != ISO-8859-1 ]] && _copy_to_utf8 ISO-8859-1 "$tmp" "$out" && _copy_to_clipboard "$out"; then
    rm -f "$tmp" "$out"
    return 0
  fi

  printf 'copy: could not put text on the clipboard (detected %s)\n' "$enc" >&2
  rm -f "$tmp" "$out"
  return 1
}

# Open a path in Windows Explorer. No arg → current directory.
#   open
#   open .
#   open ~/me/dotfiles
open() {
  local explorer target win
  if [[ $# -gt 1 ]]; then
    printf 'usage: open [path]\n' >&2
    return 2
  fi

  target="${1:-.}"
  if [[ ! -e "$target" ]]; then
    printf 'open: no such path: %s\n' "$target" >&2
    return 1
  fi

  explorer="$(_windows_exe \
    /mnt/c/Windows/explorer.exe \
    /mnt/c/Windows/System32/explorer.exe \
    /mnt/c/Windows/Sysnative/explorer.exe)" || {
    printf 'open: explorer.exe not found under /mnt/c/Windows (WSL interop?)\n' >&2
    return 1
  }
  if ! command -v wslpath >/dev/null 2>&1; then
    printf 'open: wslpath missing\n' >&2
    return 1
  fi

  target="$(realpath -e -- "$target")" || return
  win="$(wslpath -w "$target")" || return

  # explorer.exe often exits non-zero even when the window opens.
  if [[ -d "$target" ]]; then
    "$explorer" "$win" >/dev/null 2>&1 || true
  else
    "$explorer" /select,"$win" >/dev/null 2>&1 || true
  fi
}

# HostName/User/IdentityAgent/IdentitiesOnly live in ~/.ssh/config.local (not git).
# IdentityFile lives in ~/.ssh/config.identity and is inlined into ~/.ssh/config
# by chezmoi (ssh-pub). One Host alias per block.

# Tilde is for OpenSSH config (IdentityAgent ~/.bitwarden-ssh-agent-notify.sock), not bash expansion.
# shellcheck disable=SC2088
_SSH_IDENTITY_AGENT='~/.bitwarden-ssh-agent-notify.sock'

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

_ssh_config_identity() {
  printf '%s\n' "${HOME}/.ssh/config.identity"
}

_ssh_ensure_config_identity() {
  mkdir -p "${HOME}/.ssh" || return
  chmod 700 "${HOME}/.ssh"
  local f
  f="$(_ssh_config_identity)"
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

_ssh_expand_identity_path() {
  local p="$1"
  p="${p#\"}"
  p="${p%\"}"
  p="${p#\'}"
  p="${p%\'}"
  if [[ "$p" == "~/"* ]]; then
    printf '%s\n' "${HOME}/${p#~/}"
  else
    printf '%s\n' "$p"
  fi
}

_ssh_identity_points_to() {
  local host="$1" want="$2"
  local have
  have="$(_ssh_local_field "$host" IdentityFile "$(_ssh_config_identity)" || true)"
  if [[ -z "$have" ]]; then
    have="$(_ssh_local_field "$host" IdentityFile || true)"
  fi
  [[ -n "$have" ]] || return 1
  [[ "$(_ssh_expand_identity_path "$have")" == "$(_ssh_expand_identity_path "$want")" ]]
}

# MODE=setup  host hostname user — set HostName/User + agent defaults (no IdentityFile)
# MODE=agent  host               — keep HostName/User/extras; fill agent; drop IdentityFile
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
    function parse_host_line(line,    n, i, t) {
      n = split(line, t, /[[:space:]]+/)
      n_other = 0
      delete others
      matched = 0
      for (i = 2; i <= n; i++) {
        if (t[i] == "" || t[i] ~ /^#/) break
        if (t[i] == host) matched = 1
        else others[++n_other] = t[i]
      }
      leftover_names = ""
      for (i = 1; i <= n_other; i++) leftover_names = leftover_names (i == 1 ? "" : " ") others[i]
      return matched
    }
    function emit_kv(hn, usr, ag, io,    i) {
      if (hn != "") print "  HostName " hn
      if (usr != "") print "  User " usr
      print "  IdentityAgent " ag
      print "  IdentitiesOnly " io
      for (i = 1; i <= n_extra; i++) print extras[i]
    }
    function emit_target(    hn, usr, ag, io) {
      print "Host " host
      if (mode == "setup") {
        hn = hostname
        usr = user
        ag = agent
        io = "yes"
      } else {
        hn = vals["HostName"]
        usr = vals["User"]
        ag = (vals["IdentityAgent"] != "") ? vals["IdentityAgent"] : agent
        io = (vals["IdentitiesOnly"] != "") ? vals["IdentitiesOnly"] : "yes"
      }
      emit_kv(hn, usr, ag, io)
    }
    function emit_leftover(    ag, io) {
      if (leftover_names == "") return
      print "Host " leftover_names
      ag = (vals["IdentityAgent"] != "") ? vals["IdentityAgent"] : agent
      io = (vals["IdentitiesOnly"] != "") ? vals["IdentitiesOnly"] : "yes"
      emit_kv(vals["HostName"], vals["User"], ag, io)
    }
    function flush() {
      if (!in_block) return
      if (skip_discard) {
        # drop duplicate Host <host>
      } else if (current_is_target) {
        emit_target()
        emit_leftover()
        emitted_target = 1
      } else {
        printf "%s", buf
      }
      buf = ""
      in_block = 0
      current_is_target = 0
      skip_discard = 0
      leftover_names = ""
      delete vals
      delete extras
      n_extra = 0
    }
    {
      sub(/\r$/, "")
    }
    $1 == "Host" || $1 == "Match" {
      flush()
      in_block = 1
      current_is_target = 0
      skip_discard = 0
      leftover_names = ""
      if ($1 == "Host" && parse_host_line($0)) {
        if (emitted_target) {
          if (n_other == 0) {
            skip_discard = 1
          } else {
            buf = "Host " leftover_names ORS
            leftover_names = ""
          }
        } else {
          current_is_target = 1
        }
      } else {
        buf = $0 ORS
      }
      next
    }
    in_block && skip_discard { next }
    in_block && current_is_target {
      raw = trim($0)
      if (raw == "" || raw ~ /^#/) next
      key = $1
      rest = trim(substr($0, index($0, $1) + length($1)))
      if (key == "HostName" || key == "User" || key == "IdentityAgent" || key == "IdentitiesOnly") {
        vals[key] = rest
      } else if (key == "IdentityFile") {
        # IdentityFile belongs in ~/.ssh/config.identity (ssh-pub), not config.local
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
        leftover_names = ""
        emit_target()
      }
      if (mode == "agent" && !emitted_target) {
        exit 1
      }
      exit 0
    }
  ' "$f" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if cmp -s "$tmp" "$f"; then
    rm -f "$tmp"
    return 0
  fi
  mv "$tmp" "$f"
  chmod 600 "$f"
}

ssh-host-local() {
  if [[ $# -ne 3 ]]; then
    printf 'usage: ssh-host-local <host> <hostname> <user>\n' >&2
    printf 'IdentityAgent (%s) and IdentitiesOnly (yes) are always set.\n' "$_SSH_IDENTITY_AGENT" >&2
    printf 'Re-run is a no-op when HostName/User/agent already match (Port and extra keys kept).\n' >&2
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

_ssh_rewrite_identity_host() {
  local host="$1" identity_file="$2"
  local f tmp
  _ssh_ensure_config_identity || return
  f="$(_ssh_config_identity)"
  tmp="$(mktemp "${f}.XXXXXX")" || return
  if ! awk -v host="$host" -v identity_file="$identity_file" '
    function emit_target() {
      print "Host " host
      print "  IdentityFile " identity_file
    }
    function flush() {
      if (!in_block) return
      if (skip_discard) {
      } else if (current_is_target) {
        emit_target()
        emitted_target = 1
      } else {
        printf "%s", buf
      }
      buf = ""
      in_block = 0
      current_is_target = 0
      skip_discard = 0
    }
    {
      sub(/\r$/, "")
    }
    $1 == "Host" || $1 == "Match" {
      flush()
      in_block = 1
      current_is_target = 0
      skip_discard = 0
      if ($1 == "Host") {
        matched = 0
        for (i = 2; i <= NF; i++) {
          if ($i == "" || $i ~ /^#/) break
          if ($i == host) matched = 1
        }
        if (matched) {
          if (emitted_target) skip_discard = 1
          else current_is_target = 1
          next
        }
      }
      buf = $0 ORS
      next
    }
    in_block && skip_discard { next }
    in_block && current_is_target { next }
    in_block {
      buf = buf $0 ORS
      next
    }
    { print }
    END {
      flush()
      if (!emitted_target) emit_target()
    }
  ' "$f" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if cmp -s "$tmp" "$f"; then
    rm -f "$tmp"
    return 0
  fi
  mv "$tmp" "$f"
  chmod 600 "$f"
}

_ssh_ensure_host_agent() {
  local host="$1"
  _ssh_rewrite_local_host agent "$host"
}

# IdentityFile goes in ~/.ssh/config.identity (inlined into ~/.ssh/config).
# Also drop a leftover IdentityFile from config.local so Include does not win.
_ssh_set_identity_file() {
  local host="$1" identity_file="$2"
  _ssh_rewrite_identity_host "$host" "$identity_file" || return
  if _ssh_host_in_local "$host"; then
    _ssh_rewrite_local_host agent "$host" || true
  fi
}

_ssh_set_identity_file_if_missing() {
  local host="$1" identity_file="$2"
  _ssh_host_in_local "$host" || return 0
  local from_idf from_local
  from_idf="$(_ssh_local_field "$host" IdentityFile "$(_ssh_config_identity)" || true)"
  from_local="$(_ssh_local_field "$host" IdentityFile || true)"
  if [[ -n "$from_idf" ]]; then
    if [[ -n "$from_local" ]]; then
      _ssh_rewrite_local_host agent "$host" || true
    fi
    return 0
  fi
  if [[ -n "$from_local" ]]; then
    _ssh_set_identity_file "$host" "$from_local"
    return 0
  fi
  _ssh_set_identity_file "$host" "$identity_file"
}

# Create Host only if missing. Existing HostName/User (ssh.github.com, GHE, …) are kept.
_ssh_seed_host() {
  local host="$1" hostname="$2" user="$3"
  _ssh_ensure_config_local || return
  if _ssh_host_in_local "$host"; then
    _ssh_ensure_host_agent "$host"
  else
    ssh-host-local "$host" "$hostname" "$user" >/dev/null
  fi
}

ssh-pub() {
  if [[ $# -ne 2 ]]; then
    printf 'usage: ssh-pub <host> <key>\n' >&2
    printf 'Writes ~/.ssh/<key>.pub from the agent and IdentityFile on Host <host>\n' >&2
    printf 'into ~/.ssh/config (via config.identity + chezmoi). Host must exist in config.local.\n' >&2
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

  local lines matches exact chosen count dest want
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
  # shellcheck disable=SC2088
  want="~/.ssh/${key}.pub"

  if [[ -f "$dest" ]] && cmp -s <(printf '%s\n' "$chosen") "$dest" && _ssh_identity_points_to "$host" "$want"; then
    printf 'ssh-pub: %s already on Host %s\n' "$dest" "$host"
    return 0
  fi

  printf '%s\n' "$chosen" >"$dest"
  chmod 644 "$dest"
  # OpenSSH expands ~ in IdentityFile; do not use $HOME here.
  # shellcheck disable=SC2088
  _ssh_set_identity_file "$host" "$want" || return

  if command -v chezmoi >/dev/null 2>&1; then
    chezmoi apply || printf 'ssh-pub: wrote the key; chezmoi apply failed (config IdentityFile / git signing)\n' >&2
  fi

  printf 'Wrote %s and IdentityFile on Host %s\n' "$dest" "$host"
  if command -v ssh-keygen >/dev/null 2>&1; then
    command ssh-keygen -lf "$dest"
  fi
}

_ssh_tty() {
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    printf '%s\n' /dev/tty
  else
    return 1
  fi
}

_ssh_read_text() {
  local field="$1" desc="$2" value=""
  local tty
  tty="$(_ssh_tty)" || {
    printf 'ssh-manage: need a tty\n' >&2
    return 1
  }
  printf '%s (text) %s: ' "$field" "$desc" >"$tty"
  IFS= read -r -e value <"$tty" || return 1
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ -z "$value" ]]; then
    printf 'ssh-manage: %s is required\n' "$field" >&2
    return 1
  fi
  printf '%s\n' "$value"
}

_ssh_pick_line() {
  local field="$1" desc="$2"
  local -a items=()
  local line tty n choice
  while IFS= read -r line; do
    [[ -n "$line" ]] && items+=("$line")
  done
  if ((${#items[@]} == 0)); then
    printf 'ssh-manage: no %s to choose\n' "$field" >&2
    return 1
  fi
  tty="$(_ssh_tty)" || {
    printf 'ssh-manage: need a tty\n' >&2
    return 1
  }
  if command -v fzf >/dev/null 2>&1; then
    line="$(printf '%s\n' "${items[@]}" | fzf --prompt="${field} (list) " --header="$desc" \
      --height=40% --reverse --no-multi)" || return 1
    [[ -n "$line" ]] || return 1
    printf '%s\n' "$line"
    return 0
  fi
  printf '%s (list) %s\n' "$field" "$desc" >"$tty"
  n=1
  for line in "${items[@]}"; do
    printf '  %d) %s\n' "$n" "$line" >"$tty"
    n=$((n + 1))
  done
  printf 'Select [1-%d]: ' "${#items[@]}" >"$tty"
  IFS= read -r -e choice <"$tty" || return 1
  if [[ ! "$choice" =~ ^[1-9][0-9]*$ ]] || ((choice < 1 || choice > ${#items[@]})); then
    printf 'ssh-manage: invalid selection\n' >&2
    return 1
  fi
  printf '%s\n' "${items[$((choice - 1))]}"
}

_ssh_list_local_hosts() {
  local f
  f="$(_ssh_config_local)"
  [[ -f "$f" ]] || return 1
  awk '
    $1 == "Host" {
      for (i = 2; i <= NF; i++) {
        if ($i == "" || $i ~ /^#/) break
        if ($i ~ /[*?]/) continue
        print $i
      }
    }
  ' "$f" | awk 'NF && !seen[$0]++'
}

_ssh_list_agent_key_comments() {
  local sock lines
  sock="${SSH_AUTH_SOCK:-}"
  if [[ ! -S "$sock" ]]; then
    if [[ -S "${HOME}/.bitwarden-ssh-agent-notify.sock" ]]; then
      sock="${HOME}/.bitwarden-ssh-agent-notify.sock"
    else
      sock="${HOME}/.bitwarden-ssh-agent.sock"
    fi
  fi
  if [[ ! -S "$sock" ]]; then
    printf 'ssh-manage: Bitwarden SSH agent socket missing — unlock Arch Bitwarden\n' >&2
    return 1
  fi
  local old_sock="${SSH_AUTH_SOCK:-}"
  export SSH_AUTH_SOCK="$sock"
  if ! lines="$(ssh-add -L 2>/dev/null)"; then
    [[ -n "$old_sock" ]] && export SSH_AUTH_SOCK="$old_sock"
    printf 'ssh-manage: ssh-add -L failed (unlock Bitwarden and Allow the agent prompt)\n' >&2
    return 1
  fi
  [[ -n "$old_sock" ]] && export SSH_AUTH_SOCK="$old_sock"
  printf '%s\n' "$lines" | awk '
    NF >= 3 {
      comment = $3
      for (i = 4; i <= NF; i++) comment = comment " " $i
      if (comment ~ /^[A-Za-z0-9._-]+$/) print comment
    }
  ' | awk 'NF && !seen[$0]++'
}

# Interactive wrapper for ssh-host-local / ssh-pub (no args).
ssh-manage() {
  if [[ $# -ne 0 ]]; then
    printf 'usage: ssh-manage\n' >&2
    printf '  1) Set Host        — ssh-host-local (host / hostname / user)\n' >&2
    printf '  2) Set Public Key  — ssh-pub (host from config.local, key from Bitwarden)\n' >&2
    return 2
  fi
  local tty mode host hostname user key
  tty="$(_ssh_tty)" || {
    printf 'ssh-manage: need a tty\n' >&2
    return 1
  }
  printf 'ssh-manage\n' >"$tty"
  printf '  1) Set Host\n' >"$tty"
  printf '  2) Set Public Key\n' >"$tty"
  printf 'Mode [1/2]: ' >"$tty"
  IFS= read -r -e mode <"$tty" || return 1
  case "$mode" in
    1)
      host="$(_ssh_read_text host 'SSH alias you type (vps, github.com)')" || return
      hostname="$(_ssh_read_text hostname 'real name (DNS, IP, or ssh.github.com)')" || return
      user="$(_ssh_read_text user 'remote user (git, alice)')" || return
      ssh-host-local "$host" "$hostname" "$user"
      ;;
    2)
      host="$(_ssh_list_local_hosts | _ssh_pick_line host 'Host aliases in ~/.ssh/config.local (Set Host first)')" || return
      host="${host%% *}"
      key="$(_ssh_list_agent_key_comments | _ssh_pick_line key 'Bitwarden SSH key comment from the agent')" || return
      key="${key%% *}"
      ssh-pub "$host" "$key"
      ;;
    *)
      printf 'ssh-manage: choose 1 or 2\n' >&2
      return 2
      ;;
  esac
}
