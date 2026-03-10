#!/usr/bin/env bash
# claudes-codex-buddy — shared helpers
# Sourced by hooks and scripts. Never executed directly.

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
CODEX_BUDDY_HOME="${HOME}/.claudes-codex-buddy"
CODEX_BUDDY_CONFIG="${CODEX_BUDDY_HOME}/config.json"
CODEX_BUDDY_DEBUG_LOG="${CODEX_BUDDY_HOME}/debug.log"
CODEX_BUDDY_MAX_LOG_SIZE=1048576  # 1MB

# ── Debug logging ────────────────────────────────────────────────────────────
codex_buddy_debug() {
  local debug_enabled="${_CODEX_BUDDY_DEBUG_CACHED:-}"
  if [[ -z "$debug_enabled" ]]; then
    debug_enabled="$(codex_buddy_config "debug" "false")"
    export _CODEX_BUDDY_DEBUG_CACHED="$debug_enabled"
  fi
  [[ "$debug_enabled" != "true" ]] && return 0

  mkdir -p "$CODEX_BUDDY_HOME"

  # Rotate if too large
  if [[ -f "$CODEX_BUDDY_DEBUG_LOG" ]]; then
    local size
    size=$(wc -c < "$CODEX_BUDDY_DEBUG_LOG" 2>/dev/null || echo 0)
    if (( size > CODEX_BUDDY_MAX_LOG_SIZE )); then
      mv "$CODEX_BUDDY_DEBUG_LOG" "${CODEX_BUDDY_DEBUG_LOG}.old"
    fi
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$CODEX_BUDDY_DEBUG_LOG"
}

# ── Config reader ────────────────────────────────────────────────────────────
# Usage: codex_buddy_config "key" "default_value"
codex_buddy_config() {
  local key="$1"
  local default="${2:-}"

  if [[ -f "$CODEX_BUDDY_CONFIG" ]] && command -v jq &>/dev/null; then
    local val
    val=$(jq -r --arg k "$key" '.[$k] // empty' "$CODEX_BUDDY_CONFIG" 2>/dev/null)
    if [[ -n "$val" ]]; then
      echo "$val"
      return 0
    fi
  fi

  echo "$default"
}

# ── Config writer ────────────────────────────────────────────────────────────
# Usage: codex_buddy_config_set "key" "value"
codex_buddy_config_set() {
  local key="$1"
  local value="$2"

  mkdir -p "$CODEX_BUDDY_HOME"

  if ! command -v jq &>/dev/null; then
    codex_buddy_debug "jq not found, cannot write config"
    return 1
  fi

  local existing="{}"
  [[ -f "$CODEX_BUDDY_CONFIG" ]] && existing=$(cat "$CODEX_BUDDY_CONFIG")

  local tmp="${CODEX_BUDDY_CONFIG}.tmp.$$"
  echo "$existing" | jq --arg k "$key" --arg v "$value" '.[$k] = $v' > "$tmp"
  mv "$tmp" "$CODEX_BUDDY_CONFIG"
}

# ── Find codex binary ───────────────────────────────────────────────────────
codex_buddy_find_codex() {
  # Check explicit config override first
  local configured
  configured="$(codex_buddy_config "codex_path" "")"
  if [[ -n "$configured" && -x "$configured" ]]; then
    echo "$configured"
    return 0
  fi

  # Standard PATH lookup
  if command -v codex &>/dev/null; then
    command -v codex
    return 0
  fi

  # Common install locations
  local candidates=(
    "${HOME}/.nvm/versions/node/*/bin/codex"
    "${HOME}/.local/bin/codex"
    "/usr/local/bin/codex"
  )
  for pattern in "${candidates[@]}"; do
    # shellcheck disable=SC2086
    for bin in $pattern; do
      if [[ -x "$bin" ]]; then
        echo "$bin"
        return 0
      fi
    done
  done

  return 1
}

# ── Get codex version ───────────────────────────────────────────────────────
codex_buddy_version() {
  local codex_bin
  codex_bin="$(codex_buddy_find_codex 2>/dev/null)" || return 1
  "$codex_bin" --version 2>/dev/null | head -1
}

# ── Session directory ────────────────────────────────────────────────────────
codex_buddy_session_dir() {
  local session_id="${CLAUDE_SESSION_ID:-default}"
  local dir="/tmp/codex-buddy-${session_id}"
  mkdir -p "$dir"
  echo "$dir"
}

# ── Get model from config cascade ───────────────────────────────────────────
# Priority: plugin config → codex config.toml → fallback
codex_buddy_model() {
  # 1. Plugin config
  local model
  model="$(codex_buddy_config "model" "")"
  if [[ -n "$model" ]]; then
    echo "$model"
    return 0
  fi

  # 2. Codex config.toml
  local codex_config="${HOME}/.codex/config.toml"
  if [[ -f "$codex_config" ]]; then
    local toml_model
    toml_model=$(grep '^model' "$codex_config" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
    if [[ -n "$toml_model" ]]; then
      echo "$toml_model"
      return 0
    fi
  fi

  # 3. Fallback
  echo "gpt-5.4-codex"
}

# ── Get sandbox mode ────────────────────────────────────────────────────────
codex_buddy_sandbox() {
  codex_buddy_config "sandbox" "full-auto"
}

# ── Get default timeout (seconds) ───────────────────────────────────────────
codex_buddy_timeout() {
  codex_buddy_config "timeout" "120"
}

# ── JSON escape ──────────────────────────────────────────────────────────────
codex_buddy_escape_json() {
  local input="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$input" | jq -Rs .
  else
    # Minimal fallback
    printf '"%s"' "$(printf '%s' "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')"
  fi
}
