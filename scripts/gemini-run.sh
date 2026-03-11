#!/usr/bin/env bash
# claudes-ai-buddies — core wrapper for gemini CLI
# Usage: gemini-run.sh --prompt "..." [--cwd DIR] [--mode exec|review]
#        [--review-target uncommitted|branch:NAME|commit:SHA]
#        [--timeout SECS] [--model MODEL] [--sandbox MODE]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../hooks/lib.sh
source "${PLUGIN_ROOT}/hooks/lib.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
PROMPT=""
CWD="$(pwd)"
MODE="exec"
REVIEW_TARGET="uncommitted"
TIMEOUT="$(ai_buddies_timeout)"
MODEL="$(ai_buddies_gemini_model)"
SANDBOX="$(ai_buddies_sandbox)"

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)     PROMPT="$2";        shift 2 ;;
    --cwd)        CWD="$2";           shift 2 ;;
    --mode)       MODE="$2";          shift 2 ;;
    --review-target) REVIEW_TARGET="$2"; shift 2 ;;
    --timeout)    TIMEOUT="$2";       shift 2 ;;
    --model)      MODEL="$2";         shift 2 ;;
    --sandbox)    SANDBOX="$2";       shift 2 ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  echo "ERROR: --prompt is required" >&2
  exit 1
fi

# ── Find gemini ──────────────────────────────────────────────────────────────
GEMINI_BIN="$(ai_buddies_find_gemini 2>/dev/null)" || {
  echo "ERROR: gemini CLI not found. Install: npm install -g @google/gemini-cli" >&2
  exit 1
}

ai_buddies_debug "gemini-run: mode=$MODE, model=$MODEL, timeout=$TIMEOUT, cwd=$CWD"

# ── Prepare output ───────────────────────────────────────────────────────────
SESSION_DIR="$(ai_buddies_session_dir)"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
OUTPUT_FILE="${SESSION_DIR}/gemini-output-${TIMESTAMP}.md"
ERROR_FILE="${SESSION_DIR}/gemini-error-${TIMESTAMP}.log"

# ── Build the prompt ─────────────────────────────────────────────────────────
FINAL_PROMPT="$PROMPT"
if [[ "$MODE" == "review" ]]; then
  FINAL_PROMPT="$(ai_buddies_build_review_prompt "$PROMPT" "$CWD" "$REVIEW_TARGET")"
fi

# ── Map sandbox to gemini CLI flags ──────────────────────────────────────────
GEMINI_SANDBOX_ARGS=()
case "$SANDBOX" in
  full-auto) GEMINI_SANDBOX_ARGS=(--sandbox --approval-mode yolo) ;;
  suggest)   GEMINI_SANDBOX_ARGS=(--sandbox --approval-mode default) ;;
  *)         GEMINI_SANDBOX_ARGS=(--sandbox --approval-mode yolo) ;;
esac

# ── Run gemini ───────────────────────────────────────────────────────────────
ai_buddies_debug "gemini-run: executing gemini -p"

GEMINI_ARGS=(-p "$FINAL_PROMPT")
[[ -n "$MODEL" ]] && GEMINI_ARGS+=(--model "$MODEL")

EXIT_CODE=0
cd "$CWD"
ai_buddies_run_with_timeout "$TIMEOUT" "$GEMINI_BIN" \
  "${GEMINI_ARGS[@]}" \
  "${GEMINI_SANDBOX_ARGS[@]}" \
  > "$OUTPUT_FILE" 2>"$ERROR_FILE" || EXIT_CODE=$?

# ── Handle result ────────────────────────────────────────────────────────────
if [[ $EXIT_CODE -eq 124 ]]; then
  echo "TIMEOUT: Gemini did not respond within ${TIMEOUT}s" > "$OUTPUT_FILE"
  ai_buddies_debug "gemini-run: timed out after ${TIMEOUT}s"
elif [[ $EXIT_CODE -ne 0 ]]; then
  {
    echo "ERROR: Gemini exited with code ${EXIT_CODE}"
    echo ""
    echo "--- stderr ---"
    cat "$ERROR_FILE" 2>/dev/null || echo "(no stderr captured)"
  } > "$OUTPUT_FILE"
  ai_buddies_debug "gemini-run: failed with exit code ${EXIT_CODE}"
fi

# ── Output the file path for Claude to read ──────────────────────────────────
if [[ -f "$OUTPUT_FILE" ]]; then
  echo "$OUTPUT_FILE"
  ai_buddies_debug "gemini-run: output at ${OUTPUT_FILE}"
else
  echo "ERROR: No output file generated" >&2
  ai_buddies_debug "gemini-run: no output file"
  exit 1
fi
