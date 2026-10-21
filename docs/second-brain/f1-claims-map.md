# F1.1 — Map of every claim the brain stores today

19 October 2026. Context step for chunk F1 (claims, lineage, time). Read from a
database built from the migrations; production row counts only.

| Claim kind | Table | Evidence lives in | Points to | Status | Time | Prod rows |
|---|---|---|---|---|---|---|
| **Fact** | `assertions` | `assertion_evidence` (with exact span) | raw content / source item | `status`, `retired_by`, `retirement_reason`, `supersedes_id` | `valid_from`/`valid_to` (true-when) + `created_at` (learned-when) | ~750 |
| **Pattern** | `behavior_patterns` | `behavior_pattern_facts` | facts | `status`, `retired_at` | `first_seen_at`/`last_seen_at` | 106 |
| **Why** | `behavior_pattern_whys` | `evidence_assertion_ids` (array) | facts | `status`, `retired_at` | `created_at` | 27 |
| **Answer (36)** | `question_answers` | `answer_evidence` (stance supports/contradicts) | facts, patterns, raw content | `status`, `user_verdict`, `retired_at` | `last_moved_at`, decay by half-life | 31 (founder) |
| **Person / org** | `entities` + `entity_aliases` + `entity_resolution_candidates` | aliases → source items | — | `status`, `merged_into_id` | — | 940 / 1,266 / 0 |
| Legacy: identity inference, observation, insight, goal candidate | `identity_inferences`, `observations`, `insights`, `goal_candidates` | id arrays | raw content / observations | mixed | mixed | being retired (§6b) |
| Goal | `goals` | none | — | `is_active` | — | — |

## What this means for F1

- **Lineage already exists per kind** — four evidence tables. F1 does not need a
  new edge table or dual writes: a **view** (`claim_edges`) over the four gives
  one graph, additively. The array in `behavior_pattern_whys` is unnested in
  the view.
- **Time:** facts already have true-when and learned-when. Answers and patterns
  have their own time fields; F1 makes "invalidate, never delete" a checked
  rule across all of them rather than adding columns.
- **Gaps:** goals have no evidence (W4); legacy tables have only id arrays
  (left as they are, being retired); the resolution-candidates queue is empty —
  nothing has ever been held for a human (W2).
- **W2 changes:** people tables exist with 940 entities. W2 begins by measuring
  the existing resolution against its gate, then extends.
