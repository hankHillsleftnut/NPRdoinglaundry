### UI1.2 · "What i took" and "not right"                            size: M
Place in the tree: journal › JR-4 › what i took (took row, correction flow)
Repo · branch: NPRdoinglaundry · ui/UI1.2-what-i-took
Needs: C32, #45 (`RPill`), C19.2 (the confirm choice uses the dialog style), UI1.0        Unblocks: P12

Why: under every entry you can see exactly what Retro took from it. When something is wrong, you say so in one tap, and you see it struck out and "noted".

Inputs:
- Reference: §C17 entry, JR-4 (P12 row in §E), decision 01 (`BQB-0`, what i took A)
- Paper:
  - entry master `E20-0`: page `E25-0`, editing `G8L-0`
  - part 24 `A5L-0` (`AUC-0` in the app)
  - decided card `CFB-0`
  - JR-4 instances `c:took-row/claim/rest` `1FR9-0`, `c:took-row/claim/noted` `1FR3-0`, `c:pill/neutral/rest` `1FRB-0`, `c:link/conversation/rest` `1FRI-0`
- Contract: 02 §6 (`GET /v2/entries/:id/took`; `POST /v2/corrections` → applied | confirm | askOwnWords | notACorrection; `POST /v2/corrections/confirm`). Blocked live until BEA.1; samples cover every outcome.

Spec:
- **Section:** a section label "what i took" (S13), then took rows.
- **Took row** (from `1FR9-0`):
  - the claim in your words' register (`type.text.md` `text.primary`)
  - a sureness word (Geist 12 `text.label`: "just a hunch / fairly sure / very sure", founder question 7)
  - a trailing neutral pill "not right" with the `correct` glyph (`1FRB-0`)
- **Noted** (`1FR3-0`): the claim struck through over 240ms (a `strikethrough` drawn as an animated trim on a 1pt line, not the text attribute, so it can animate) + "noted" (Geist 12 `text.label`); the pill is gone. (Founder question 6: lean keep it struck.)
- **Nothing taken yet** (`reading: waiting`): "retro hasn't read this yet. it will in a minute." (serif `text.secondary`); it fills in on its own when reading completes (the flow updates; rows `.rAppear` stagger).
- **Correction outcomes:**

| Outcome | What the person sees |
|---|---|
| `applied` | the row strikes through + "noted"; the echo line under the section ("got it. i'll stop saying …, and 2 things built on it.") blur-in, `confirm` |
| `confirm` (candidates) | a C19.1 medium sheet: "which one is wrong?" with candidate rows (C32 shape, no chevron); choosing → "wrong, or has it changed?" two pills → confirm → applied |
| `askOwnWords` | the sheet shows your own quote ("you wrote on 2 sep: …") and asks "has this changed?" with "it's changed" / "it was never right" |
| `notACorrection` | a quiet line "nothing to change there." blur-in, then gone after 4s |
| error | "couldn't save that · try again" `status.dangerText` under the row, `error` |
| offline | the pill is disabled with "needs a connection" (corrections aren't queued: they need the brain's answer) |

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | rows | — | — |
| pill pressed | 0.94 | `.rPress` | none |
| pending | ring on the pill | `spin` | — |
| applied | strike over 240ms + "noted" + echo | `curve.standard` 240 | `confirm` |
| waiting | the one serif line | — | — |
| filled in | rows arrive | `.rAppear` stagger 60ms | — |
| error / offline | as above | blur-in | `error` (error only) |
| dark | dark tokens | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| not right | 0.94 | none | pending ring | `correct(about: item)` → outcome | same |
| a candidate (confirm sheet) | wash | `select` | `snappy` | marks the choice | same |
| wrong / changed | 0.94 | `confirm` on apply | sheet closes on `sheetDismiss` | applied | fade |
| "show it in the conversation" link | dims 0.7 | none | — | back to the thread at this entry | same |

Accessibility:
- each row reads "<claim>, fairly sure", with the action "not right"
- noted reads "<claim>, noted, no longer used"
- the echo is announced once
- AX3: the pill moves under the claim

Acceptance:
- Matches `1FR9-0`, `1FR3-0` and part 24.
- Every outcome reachable from sample scenarios.
- No correction is ever queued offline.

Tests:
- (snapshot) rest, pending, noted, waiting, error and offline, light, dark and ax3
- (snapshot) the confirm sheet and the ask-own-words sheet
- (unit) each correction outcome maps to its screen state
- (UI) choosing not right on a fact shows it struck through and noted
- (UI) the not-a-correction line disappears after 4 seconds (injected clock)

Proof in the PR: standard proof, plus the strike recording.

Watch out:
- The echo and quote are the person's words: never log them, even in DEBUG.
