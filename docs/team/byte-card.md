# The byte card

Every byte in every plan is written as a card in this shape. Cards for the current and next phase are written in full; later phases carry the header, why, place in the tree and dependencies, and are filled in full before their phase starts (README §5: detail near, outline far, because the founder's decisions keep moving the far work). A card is the agent's whole brief: an agent with only this card, `context.md` and the references must be able to build the byte without asking where anything is.

```
### <ID> · <title>                                              size: S | M | L
Place in the tree: <flow › page/capability › component/door › part>
Repo · branch: <repo> · <prefix>/<id>-<slug>
Needs: <byte ids that must be merged first>      Unblocks: <byte ids>

Why: one or two sentences in the user's terms (what someone can do or feel that they couldn't).

Inputs (read these, nothing else is needed):
- Contract: <file §>            - Paper: <node ids, board names>
- Reference: <file §>           - Code anchors: <path:line, what's there>

Spec:
<UI: anatomy with every value as a token; the state table (state → look → motion → haptic);
 the interaction table (touch → press → haptic → motion (spring/curve, duration) → outcome →
 Reduce Motion); accessibility (VoiceOver label/traits/actions, Dynamic Type, contrast, hit areas).
 Backend: request, validation, ownership, limits bucket, agent call (path, timeout, retry), mapping,
 errors (code per case), logging, migrations (file name, columns).
 Plumbing: types and their namespace, public API, concurrency (actor / MainActor), persistence,
 failure behaviour, bridges to old code.>

Steps: the order of work, each a few words.

Acceptance (observable, each a yes/no):
- …

Tests (named as sentences; layer from testing.md):
- …

Proof in the PR: <screenshots next to Paper node X in light/dark/AX3; recordings; test output; staging run>

Watch out: the specific traps for this byte (from the references and the findings log).
```

Sizes: **S** under half a day, **M** about a day, **L** two days and a candidate for splitting further down the tree.
