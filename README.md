# Claude's Codex Buddy

Use OpenAI's Codex CLI as a peer AI directly from Claude Code — brainstorm, delegate tasks, get code reviews.

## What it does

Spawns `codex exec` as a subprocess, captures the output, and presents it back through Claude. No MCP servers, no flaky connections — just a direct CLI call.

```
User → Claude → /codex skill → codex exec → output → Claude presents
```

## Skills

| Skill | Description |
|-------|-------------|
| `/codex "prompt"` | Ask Codex anything — brainstorm, delegate, second opinion |
| `/codex-review` | Code review via Codex (uncommitted, branch, commit) |
| `/codex-help` | Reference and configuration |

## Requirements

- [Codex CLI](https://github.com/openai/codex) v0.100.0+ (`npm install -g @openai/codex`)
- `OPENAI_API_KEY` environment variable
- Claude Code with plugin support

## Installation

```bash
# From the plugin directory
claude plugin install /path/to/claudes-codex-buddy

# Or via the monorepo
claude plugin install /path/to/claude-plugins/plugins/claudes-codex-buddy
```

## Configuration

Optional config at `~/.claudes-codex-buddy/config.json`:

```json
{
  "model": "gpt-5.4-codex",
  "timeout": "120",
  "sandbox": "full-auto",
  "debug": "false"
}
```

Falls back to `~/.codex/config.toml` for model selection.

## Examples

```
/codex "What's the best way to implement a rate limiter in Go?"
/codex "Debug this error: Cannot read property 'map' of undefined"
/codex-review
/codex-review branch:main
/codex-review commit:a1b2c3d "focus on security"
```

## Testing

```bash
bash tests/run-tests.sh
```

## License

MIT
