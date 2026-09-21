# Prompt: Review Line 24 protocol copy for correctness and goal fit

## Context

Line 24 is an offline bystander guidance product. Documentation is the product design; `protocol/graphs/zero-echelon-core/graph.json` is what the app executes. Do not invent clinical interventions. Do not rewrite medicine — only check wording and alignment.

Product principles (must hold for every phrase):

- One action per phrase; imperative present tense; observable signs, not diagnoses.
- Scene safety vetoes medicine; call **112** is always available (101 on veto screens).
- No reassurance, no “dead”, no improvised tourniquet, no sealed chest wrap, no stomach washout.
- No Good Samaritan legal promise for Ukraine.
- UA and EN must be semantic twins, not literal calques.

## Source of truth (read in this order)

1. `docs/03-пріоритети-та-конфлікти.md` — what is allowed / forbidden on a step.
2. `docs/04-блок-схеми.md` — flow and branches only (not literal wording).
3. `docs/07-голосові-скрипти-UA-EN.md` — canonical spoken/on-screen wording.
4. `docs/01-обсяг-роли-глосарій.md` — roles and glossary.
5. `docs/12-екрани-та-специфікація.md` — screen/button map.
6. `docs/05`, `docs/08`, `docs/09`, `docs/10` — roles, report, second wave, legal tone.
7. `docs/research/*` — evidence; unsupported claims are invalid.
8. `protocol/graphs/zero-echelon-core/graph.json` — executed strings; must match `docs/07`.
9. App chrome outside the graph: `ZeroEchelon/ZeroEchelon/Views/NodeFrameView.swift`, `SettingsView.swift`, `web/src/main.ts`, `web/src/engine.ts`.

**Do not use block diagrams as the wording source.** Use `docs/04` for sequence; use `docs/07` for words; use `docs/03` for whether those words are the right decision.

## Instructions

### Step 1

**Action:** Build a checklist of all node `id`s from `docs/07` and map each to the matching node in `graph.json` (`voice.ua` / `voice.en`, button labels).  
**Objective:** Know the full set of user-facing protocol strings.  
**Rationale:** Missed nodes create silent defects in production.  
**Example:** Map `Disclaimer` → graph node `Disclaimer` voice + helper note if present.

### Step 2

**Action:** For each `id`, score the UA and EN text against `docs/07` principles and against the matching rule in `docs/03` / branch in `docs/04`.  
**Objective:** Detect wrong action, wrong tone, or illegal vocabulary.  
**Rationale:** A fluent phrase that violates safety veto or invents medicine is a product failure.  
**Example:** If a bleed screen says “apply a belt tourniquet”, flag as fail citing Stop-the-Bleed / registry and invariant in `docs/07`.

### Step 3

**Action:** Diff `docs/07` wording vs `graph.json` strings for the same `id`. List every mismatch.  
**Objective:** Find drift between documentation canon and runtime.  
**Rationale:** The app must not paraphrase `docs/07`.  
**Example:** `Call` in 07 says “Викличте 112…” but graph still says “103” → critical mismatch.

### Step 4

**Action:** Review chrome strings outside the graph (emergency bar, Back, Settings, last-event, QR labels, partner caption) against the same principles and `docs/10` / `docs/12`.  
**Objective:** Catch non-graph copy that breaks product rules.  
**Rationale:** Users see chrome on every screen.  
**Example:** Emergency bar must dial `112`, not `103`, unless a veto path intentionally prioritizes `101`.

### Step 5

**Action:** Produce a markdown report with tables:

1. `id | locale | current | verdict (ok/fix/rephrase) | basis (doc + section) | proposed text (if any)`
2. `07 ↔ graph mismatches`
3. `chrome issues`
4. `priority fixes (P0/P1/P2)`

**Objective:** Give an actionable review artifact, not a vague essay.  
**Rationale:** Downstream edits need precise IDs and citations.  
**Example:** P0 = safety/legal wrong number or forbidden action; P1 = unclear multi-action phrase; P2 = style polish.

### Step 6

**Action:** Save the report under `.cursor/output/protocol_copy_review_YYYY-MM-DD.md` and do **not** edit `graph.json` or `docs/07` in this pass unless explicitly asked after the report.  
**Objective:** Separate review from implementation.  
**Rationale:** Copy changes need product/medical sign-off.  
**Example:** Report proposes new Disclaimer EN; leave files untouched until approved.

## Final Notes

- Prefer citing `docs/03` conflict IDs (K*) and registry entries from `docs/02` over general medical intuition.
- Emergency number in product copy is **112** (101 remains on danger/veto screens).
- Stakeholder docs under `docs/stakeholder/` are **not** canon unless a gap marks them accepted.
