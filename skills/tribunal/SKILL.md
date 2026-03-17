---
name: tribunal
description: Adversarial debate or Socratic inquiry — two AIs argue, question, or explore with evidence, Claude judges or synthesizes
---

# /tribunal — Adversarial Debate & Socratic Inquiry

Two AI buddies engage on a codebase question. Every claim requires FILE:LINE evidence. Claude evaluates based on evidence quality, not consensus.

## Modes

| Mode | What AIs do | Claude's role | Best for |
|------|------------|---------------|----------|
| `adversarial` (default) | Argue FOR vs AGAINST | Judge — picks winner | Binary decisions, tradeoff calls, competing proposals |
| `socratic` | Probe assumptions with questions, then answer them with evidence | Synthesizer — surfaces verified insights | Early exploration, bug investigation, unclear problem framing |

Choose `adversarial` when the question is already a concrete claim or decision.
Choose `socratic` when you first need to test the framing, assumptions, or missing evidence behind the question.

Socratic mode is a fixed 2-round protocol:
- **Round 1:** Each AI asks 3-5 code-grounded questions
- **Round 2:** Each AI answers the other AI's questions with code evidence

## How to invoke

```
/tribunal "Should we refactor the auth middleware to use async/await?"
/tribunal --socratic "Is our error handling strategy resilient enough?"
/tribunal --socratic "What should we consider before migrating to a monorepo?"
/tribunal --mode socratic "Why does this test flake on CI but pass locally?"
```

## Trigger modes

1. **Manual:** User types `/tribunal "question"` or `/tribunal --socratic "question"`
2. **Forge close call:** Auto-triggered when forge scores are within 3 points — was the winner really better?
3. **Review disagreement:** Auto-triggered when `/codex-review` and `/gemini-review` give conflicting assessments

## Step-by-step workflow

### Phase 0: Setup

1. **Parse the question.** Extract the debatable claim from the user's message.
2. **Detect the mode.** Check for `--socratic` or `--mode socratic` flag. Default: adversarial.
3. **Detect available buddies:**

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib.sh"
AVAILABLE=$(ai_buddies_available_buddies)
```

4. Require at least 2 buddies. If only 1 is available, explain and offer alternatives.
5. **Tell the user** which buddies will participate, the mode, and how many rounds.

### Phase 1: Dispatch

Run the tribunal orchestrator:

```bash
# Adversarial (default)
MANIFEST_PATH=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tribunal-run.sh" \
  --question "THE_QUESTION" \
  --cwd "$(pwd)" \
  --rounds 2 \
  --timeout 600)

# Socratic
MANIFEST_PATH=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/tribunal-run.sh" \
  --question "THE_QUESTION" \
  --cwd "$(pwd)" \
  --mode socratic \
  --rounds 2 \
  --timeout 600)
```

### Phase 2: Read results

Read `$MANIFEST_PATH` (tribunal-manifest.json). It contains:

```json
{
  "question": "...",
  "mode": "adversarial|socratic",
  "rounds": 2,
  "debaters": ["codex", "gemini"],
  "arguments": {
    "codex": { "round_1": "...", "round_2": "..." },
    "gemini": { "round_1": "...", "round_2": "..." }
  }
}
```

### Phase 3: Evaluate (mode-dependent)

---

#### Adversarial mode: Evidence-weighted judging

**Your most important job as judge:**

1. **Parse evidence objects** from each debater's arguments. Expected format:
   ```json
   {"claim":"...", "file":"path", "lines":"N-M", "evidence":"quoted code", "severity":1-5}
   ```

2. **Verify each citation.** Read the referenced file and line range. Score evidence quality 0-10:
   - 10: Exact quote matches, line numbers correct, directly supports claim
   - 7-9: Correct file, approximate lines, relevant evidence
   - 4-6: Right area but stretched interpretation
   - 1-3: Tangential or misquoted
   - 0: Fabricated or wrong file

3. **Score = evidence_quality (0-10) x severity (1-5).** Max 50 per claim.

4. **No-evidence claims score ZERO.** This is the key differentiator from brainstorm.

5. **Present the verdict** using the adversarial output format below.

---

#### Socratic mode: Assumption synthesis

**Your most important job as synthesizer:**

1. **Parse question objects** from Round 1. Each AI generated probing questions with evidence for why the question matters:
   ```json
   {"question":"...", "type":"ASSUMPTION|CLARIFYING|EVIDENCE|VIEWPOINT|CONSEQUENCE|META", "file":"path", "lines":"N-M", "evidence":"...", "why_it_matters":"..."}
   ```

2. **Parse answer objects** from Round 2. Each AI answered the other's questions:
   ```json
   {"original_question":"...", "answer":"...", "file":"path", "lines":"N-M", "evidence":"...", "deeper_question":"...", "confidence":"HIGH|MEDIUM|LOW"}
   ```

3. **Verify evidence** for both questions and answers — same rigor as adversarial mode.

4. **Score question quality** for each AI (0-10):
   - Specificity (pointed vs generic)
   - Evidence quality (why the question matters)
   - Actionability (does answering this change the decision?)
   - Novelty (unique insight vs obvious question)

5. **Synthesize** — don't pick a winner. Present what was learned using the Socratic output format below.

## Output formats

### Adversarial output

```markdown
## Tribunal: [question summary]

### Arguments

**FOR ([buddy name]):**
| Claim | File:Lines | Evidence Quality | Severity | Score |
|-------|-----------|-----------------|----------|-------|
| ... | path:N-M | X/10 | Y/5 | Z/50 |

**AGAINST ([buddy name]):**
| Claim | File:Lines | Evidence Quality | Severity | Score |
|-------|-----------|-----------------|----------|-------|
| ... | path:N-M | X/10 | Y/5 | Z/50 |

### Verdict

**Winner: [FOR/AGAINST]** — Total score X vs Y.

[2-3 sentence summary of why, highlighting the strongest evidence from each side]

### Key findings
- [Bullet point of most impactful evidence found]
- [Bullet point of claims that had weak/no evidence]
```

### Socratic output

```markdown
## Socratic Inquiry: [topic summary]

### Assumptions Exposed
| # | Assumption | Exposed By | Evidence | Status |
|---|-----------|-----------|----------|--------|
| 1 | [hidden assumption] | [buddy] | file:lines | CONFIRMED RISK / UNRESOLVED / SAFE |

### Key Questions Answered
| Question | Answer | Confidence | Evidence |
|----------|--------|-----------|----------|
| [probing question] | [code-backed answer] | HIGH/MED/LOW | file:lines |

### Remaining Open Questions
- [Questions neither AI could answer with evidence]
- [Deeper questions surfaced in Round 2]

### Question Quality
| Buddy | Specificity | Evidence | Actionability | Novelty | Score |
|-------|-----------|----------|--------------|---------|-------|
| [buddy] | X/10 | X/10 | X/10 | X/10 | X/40 |

### Recommended Next Steps
1. Investigate [open question] before deciding
2. The premise assumes [X] — verify with [method]
3. Consider [alternative framing] of the original question
```

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `tribunal_rounds` | `2` | Cross-examination rounds |
| `tribunal_max_buddies` | `2` | Max debaters (2 is ideal for adversarial) |

## Rules

- **Evidence over eloquence.** A well-cited claim beats a persuasive paragraph.
- **Verify citations.** Always read the referenced files to confirm evidence.
- **No-evidence = zero.** Enforce strictly in both modes.
- **Adversarial: Claude is the judge.** You evaluate, you don't argue.
- **Socratic: Claude is the synthesizer.** You surface insights, you don't pick a winner.
- **Always clean up** worktrees after the session.
- **Keep it focused.** Tribunal is for specific codebase questions, not general opinions.
