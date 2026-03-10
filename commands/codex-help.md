---
name: codex-help
description: Reference for Claude's Codex Buddy plugin
---

# Codex Buddy — Help & Reference

## Available Skills

| Skill | Description |
|-------|-------------|
| `/codex "prompt"` | Ask Codex anything — brainstorm, delegate, second opinion |
| `/codex-review` | Code review via Codex (uncommitted, branch, commit) |
| `/codex-help` | This help reference |

## Configuration

Config file: `~/.claudes-codex-buddy/config.json`

| Key | Default | Description |
|-----|---------|-------------|
| `model` | *(from ~/.codex/config.toml)* | Override Codex model |
| `timeout` | `120` | Max seconds per Codex call |
| `sandbox` | `full-auto` | Sandbox mode (`full-auto` or `suggest`) |
| `codex_path` | *(auto-detected)* | Explicit path to codex binary |
| `debug` | `false` | Enable debug logging |

### Example config

```json
{
  "model": "gpt-5.4-codex",
  "timeout": "180",
  "sandbox": "full-auto",
  "debug": "false"
}
```

## Review Targets

```
/codex-review                        # uncommitted changes
/codex-review branch:main            # diff from main to HEAD
/codex-review commit:abc1234         # specific commit
/codex-review "focus on security"    # with extra instructions
```

## Requirements

- **Codex CLI** v0.100.0+ (`npm install -g @openai/codex`)
- **OpenAI API key** configured for Codex (`OPENAI_API_KEY` env var)
- **jq** (optional, for config management)
- **git** (required for `/codex-review`)

## Debug Logging

Enable debug mode:
```bash
mkdir -p ~/.claudes-codex-buddy
echo '{"debug": "true"}' > ~/.claudes-codex-buddy/config.json
```

Logs are written to `~/.claudes-codex-buddy/debug.log` (auto-rotated at 1MB).

## How It Works

```
User → Claude → /codex skill → Bash(codex-run.sh) → codex exec → output file → Claude reads → presents
```

Codex runs in `--ephemeral --full-auto` mode — stateless, no interactive prompts, no persistent state.
Output is captured to a temp file via `-o`, which Claude reads and synthesizes.
