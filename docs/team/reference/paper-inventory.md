# Paper inventory · node-level map (read-only research, 21 Oct)

Light file `01M5D5J321P5X86ZT58002B7NT` ("Retrospect"); dark file `01M5EK9MGGWHX9H05V9MENVB6P` ("Retrospect · dark"). Node ids are Paper ids, pass them with the light file id unless marked dark. Nothing was edited.

Sections
0. Page map (light file)
1. Page 06 · everything · latest: every screen, its phone, its component instances
2. Component cross-reference: c:* → screens → master node; masters per family on 02 · components; missing masters
3. Approvals page: boards and parts still waiting
4. Comment threads
5. State boards (loading / empty / error / offline)
6. Dark mode twins
7. Findings (inconsistencies, unapproved parts in use, missing masters)

## 0. Page map (light file)

| page | id | what is on it |
|---|---|---|
| 00 · start here | p-1-0 | not inventoried |
| 00 · approvals · waiting on you | p-G-0 | 89Q-0 journal sub-components round 1 · 2FI5-0 toast and tags round 1 · NV7-0 read me · 2H3N-0 the invite (another session; skipped) |
| 01 · foundations | p-2-0 | 2D-0 f1 palette · 9V-0 f2 colour roles · ME-0 f3 type/space/size/radius · 1TX-0 f3b tracking · 1AI-0 f4 depth · 1DX-0 f5 icons (old sheet, no c: names) · 1-0 f6 motion and haptics · 1OO-0 f7 edges and transitions |
| 02 · components | p-3-0 | 35 boards, see §2 |
| 02b · decisions made | p-C-0 | decisions 01–06 (BQB, BQC, BQD, BZV, FT3, IFL), approved part cards 1–8 (CF7…CFE), E4L-0 M3 key states, 90C-0 archive of unchosen versions |
| 04b · pages · hi-fi | p-D-0 | per-screen hi-fi boards: F5K JR-1, FII JR-2, E6M JR-3, E6N JR-4, HGX PC-1, H1F PC-2, I0Q PC-3, J0U GL-1, JPZ GL-2, K2D YO-1, KGL YO-2, L9D YO-3, KWP YO-4, LBO YO-5, LJJ ST-1…9, ILW AC-1, M6H EX, GH8 part 43 splash, V6L ON-6, O1R M6 end (ON-10/11/13, AC-2), OE0 M11 journey map; group headers ITJ, 233G, ITK, ITL, JPS, K2E, LJK, M6I |
| 05 · the app in order · hi-fi | p-F-0 | MAR-0 (stale: most columns still say "waiting on approval"; holds state variants for JR-1, JR-3, JR-4, PC-3) |
| 05b · states · onboarding | p-8-0 | 5Q1-0 every onboarding page's states (old 390×844 phones) |
| 06 · everything · latest | p-J-0 | 16EK-0, see §1 |

## 1. Page 06 · everything · latest (artboard 16EK-0)

Structure: area → `col · CODE` → [title text, status group, `slot · CODE`] → phone. The status group's 8×8 red-dot rectangle exists in some columns but is `display: none` on all of them (all 10 checked: 16EV, 16FF, 16FN, 16FV, 16G3, 16GB, 16I6, 16IH, 16KZ, 16L7). Every column's chip reads "approved". Component lists exclude anything under a layer named "hidden …". Nested instances are listed too (e.g. the icon inside an icon button).

Areas: onboarding 16EO-0 · journal 16GG-0 · podcasts 16H7-0 · goals 16HT-0 · you 16IA-0 · settings and account 16JA-0 · outside the app 16LB-0.

#### area · onboarding

| screen | status chip (node) | visible phone | hidden copies in slot | component instances (name → one node id) |
|---|---|---|---|---|
| ON-1/2 · splash + sign-in (col 16ER-0) | approved · from approvals · part 43 (16ET-0; red dot present, hidden) | 1F4Q-0 "ON-1/2 · splash + sign-in" | — | `c:you-map/orbits/rest` 1F5K-0 |
| ON-3–9 · the questions (col 16EZ-0) | approved · from 05 (16F1-0; red dot none) | 1F6C-0 "ON-4a · listening" | — | `c:onboarding-progress` 1F74-0<br>`c:top-bar/onboarding` 1F6W-0<br>`c:icon-button/wash/rest` 1F70-0<br>`c:icon/chevron-left` 1F71-0<br>`c:onboarding/question` 1F6V-0<br>`c:onboarding/your-words` 1F6R-0<br>`c:voice-composer/listening` 1F6E-0<br>`c:icon-button/wash/mic-off` 1F6F-0<br>`c:icon/mic-off` 1F6G-0 |
| ON-5 · privacy (col 16F5-0) | approved · from 05 (16F7-0; red dot none) | 1F7I-0 "ON-5 · privacy" | — | `c:onboarding-progress` 1F8D-0<br>`c:icon-button/wash/rest` 1F89-0<br>`c:icon/chevron-left` 1F8A-0<br>`c:privacy-mark` 1F82-0<br>`c:icon/lock` 1F85-0<br>`c:voice-composer/speaking` 1F7K-0<br>`c:icon-button/wash/mic-off` 1F7L-0<br>`c:icon/mic-off` 1F7N-0 |
| ON-6 · connect (col 16FB-0) | approved · from approvals · ON-6 (16FD-0; red dot present, hidden) | 2190-0 "ON-6 · connect" | — | `c:onboarding-progress` 21CD-0<br>`c:icon-button/wash/rest` 21C9-0<br>`c:icon/chevron-left` 21CA-0<br>`c:knows-you-meter/1-of-6` 21C1-0<br>`c:label/section/rest` 21BY-0<br>`c:settings-row/source/connected` 21BN-0<br>`c:hairline/inset-icon/rest` 21BJ-0<br>`c:settings-row/source/rest` 21B8-0<br>`c:pill/raised/rest` 21B9-0<br>`c:settings-row/nav · more apps` 2199-0<br>`c:button/lit/continue` 2194-0<br>`c:button/text/later` 2192-0 |
| ON-10 · getting ready (col 16FJ-0) | approved · from approvals · M6 end (16FL-0; red dot present, hidden) | 26LG-0 "ON-10 · getting ready" | 1FBL-0, 1LGN-0 | `c:onboarding-progress` 26NA-0<br>`c:top-bar/onboarding` 26N2-0<br>`c:icon-button/wash/rest` 26N6-0<br>`c:icon/chevron-left` 26N7-0<br>`c:onboarding/question` 26N1-0<br>`c:onboarding/your-words` 26MX-0<br>`c:getting-ready` 26LV-0<br>`c:brief-card/artwork/making` 26ML-0<br>`c:icon/play` 26MS-0<br>`c:spinner/20` 26M3-0<br>`c:stage/next` 26LZ-0<br>`c:voice-composer/listening` 26LI-0<br>`c:icon-button/wash/mic-off` 26LJ-0<br>`c:icon/mic-off` 26LK-0 |
| ON-11 · the tease (col 16FR-0) | approved · from approvals · M6 end (16FT-0; red dot present, hidden) | 26NO-0 "ON-11 · the tease" | 1FDQ-0, 1L8M-0 | `c:player-sheet/brief/playing` 26NZ-0<br>`c:the-mark/22` 26PQ-0<br>`c:the-mark/glyph` 26PR-0<br>`c:icon/share` 26PL-0<br>`c:icon/chevron-down` 26PI-0<br>`c:pill/neutral/rest` 26OV-0<br>`c:icon/correct` 26OX-0<br>`c:scrubber/chapters` 26OM-0<br>`c:transport/recess/playing` 26O3-0<br>`c:icon/skip-back-15` 26O9-0<br>`c:button/raised/pause` 26O6-0<br>`c:icon/pause` 26O7-0<br>`c:icon/skip-forward-30` 26O4-0 |
| ON-12 · paywall · A (col 16FZ-0) | approved · from approvals · decision 06 (16G1-0; red dot present, hidden) | 22M4-0 "ON-12 · A · the plans are the buttons" | 2117-0 | `c:mini-player/paused` 22TR-0<br>`c:icon-button/wash/play` 22TT-0<br>`c:benefit-row` 22S1-0<br>`c:button/secondary/plan-monthly` 22MM-0<br>`c:button/lit/plan-yearly` 22MH-0<br>`c:badge/save` 22MI-0 |
| ON-13 · first home (col 16G7-0) | approved · from approvals · M6 end (16G9-0; red dot present, hidden) | 1FI8-0 "ON-13 · first home" | — | `c:top-bar/title/rest` 1FJV-0<br>`c:icon-button/wash/rest` 1FJY-0<br>`c:icon/drawer` 1FJZ-0<br>`c:brief-card/artwork/making` 1FJL-0<br>`c:icon/play` 1FJQ-0<br>`c:entry/setup-recap` 1FJ6-0<br>`c:message/theirs/rest` 1FJ3-0<br>`c:hint/1-of-3` 1FJ0-0<br>`c:voice-composer/muted-empty` 1FIS-0<br>`c:icon-button/wash/mic` 1FIT-0<br>`c:icon/mic` 1FIV-0<br>`c:tab-bar/system/rest` 1FIA-0<br>`c:tab-bar/item/selected` 1FIN-0<br>`c:icon/journal/emphasis` 1FIP-0<br>`c:tab-bar/item/rest` 1FIJ-0<br>`c:icon/podcasts` 1FIL-0<br>`c:icon/goals` 1FIH-0<br>`c:icon/you` 1FID-0 |

#### area · journal

| screen | status chip (node) | visible phone | hidden copies in slot | component instances (name → one node id) |
|---|---|---|---|---|
| JR-1 · journal (col 16GJ-0) | approved · from 05 (16GL-0; red dot none) | 1FKB-0 "JR-1 · 17 Pro" | — | `c:top-bar/title/rest` 1FM0-0<br>`c:icon-button/wash/rest` 1FM3-0<br>`c:icon/drawer` 1FM4-0<br>`c:brief-card/artwork/rest` 1FLM-0<br>`c:button/lit/play` 1FLS-0<br>`c:message/mine/rest` 1FLH-0<br>`c:message/theirs/rest` 1FL9-0<br>`c:icon/chevron-right` 1FLC-0<br>`c:voice-composer/muted-empty` 1FKV-0<br>`c:icon-button/wash/mic` 1FKW-0<br>`c:icon/mic` 1FKY-0<br>`c:tab-bar/system/rest` 1FKD-0<br>`c:tab-bar/item/selected` 1FKQ-0<br>`c:icon/journal/emphasis` 1FKS-0<br>`c:tab-bar/item/rest` 1FKM-0<br>`c:icon/podcasts` 1FKO-0<br>`c:icon/goals` 1FKK-0<br>`c:icon/you` 1FKG-0 |
| JR-2 · today's brief (col 16GP-0) | approved · from approvals · JR-2 (16GR-0; red dot none) | 1FMG-0 "phone · sheet over journal" | — | `c:player-sheet/brief/playing` 1FMR-0<br>`c:the-mark/22` 1FOL-0<br>`c:the-mark/glyph` 1FOM-0<br>`c:icon/share` 1FOG-0<br>`c:icon/chevron-down` 1FOD-0<br>`c:brief-item/now/playing` 1FO0-0<br>`c:icon/chevron-right` 1FO2-0<br>`c:brief-item/next/rest` 1FNV-0<br>`c:pill/neutral/rest` 1FNL-0<br>`c:icon/correct` 1FNN-0<br>`c:scrubber/chapters` 1FNE-0<br>`c:transport/recess/playing` 1FMV-0<br>`c:icon/skip-back-15` 1FN1-0<br>`c:button/raised/pause` 1FMY-0<br>`c:icon/pause` 1FMZ-0<br>`c:icon/skip-forward-30` 1FMW-0 |
| JR-3 · all entries (col 16GV-0) | approved · from 05 (16GX-0; red dot none) | 1FOQ-0 "JR-3 · 17 Pro" | — | `c:search-field/journal/rest` 1FQT-0<br>`c:label/day/rest` 1FQQ-0<br>`c:entry-row/drawer/here` 1FQN-0<br>`c:entry-row/drawer/rest` 1FQH-0<br>`c:entry-row/drawer/unsent` 1FQ8-0<br>`c:top-bar/label/rest` 1FPD-0<br>`c:icon-button/wash/rest` 1FPH-0<br>`c:icon/drawer` 1FPI-0<br>`c:row/drawer-foot/rest` 1FOS-0<br>`c:icon/sliders` 1FOV-0 |
| JR-4 · one entry (col 16H1-0) | approved · from 05 (16H3-0; red dot none) | 1FQX-0 "JR-4 · 17 Pro" | — | `c:top-bar/entry/rest` 1FRR-0<br>`c:icon-button/wash/rest` 1FRW-0<br>`c:icon/chevron-left` 1FRX-0<br>`c:button/text/rest` 1FRS-0<br>`c:entry/words/rest` 1FRQ-0<br>`c:link/conversation/rest` 1FRI-0<br>`c:took-row/claim/rest` 1FR9-0<br>`c:pill/neutral/rest` 1FRB-0<br>`c:took-row/claim/noted` 1FR3-0<br>`c:row/destructive/rest` 1FQZ-0 |

#### area · podcasts

| screen | status chip (node) | visible phone | hidden copies in slot | component instances (name → one node id) |
|---|---|---|---|---|
| PC-1 · podcasts (col 16HA-0) | approved · from approvals · PC-1 (16HC-0; red dot none) | 1FSA-0 "PC-1 · 17 Pro" | — | `c:top-bar/title/rest` 1FUX-0<br>`c:episode-tile/hero/rest` 1FUK-0<br>`c:button/lit/play` 1FUR-0<br>`c:episode-tile/square/rest` 1FUE-0<br>`c:tab-bar/system/rest` 1FSE-0<br>`c:tab-bar/item/rest` 1FSR-0<br>`c:icon/journal/emphasis` 1FST-0<br>`c:tab-bar/item/selected` 1FSN-0<br>`c:icon/podcasts` 1FSP-0<br>`c:icon/goals` 1FSL-0<br>`c:icon/you` 1FSH-0 |
| PC-2 · the player (col 16HG-0) | approved · from approvals · PC-2 (16HI-0; red dot none) | 1FV9-0 "phone · sheet over journal" | — | `c:player-sheet/brief/playing` 1FVK-0<br>`c:the-mark/22` 1FXB-0<br>`c:the-mark/glyph` 1FXC-0<br>`c:icon/share` 1FX6-0<br>`c:icon/chevron-down` 1FX3-0<br>`c:pill/neutral/rest` 1FWG-0<br>`c:icon/correct` 1FWI-0<br>`c:scrubber/chapters` 1FW7-0<br>`c:transport/recess/playing` 1FVO-0<br>`c:icon/skip-back-15` 1FVU-0<br>`c:button/raised/pause` 1FVR-0<br>`c:icon/pause` 1FVS-0<br>`c:icon/skip-forward-30` 1FVP-0 |
| PC-3 · why this is here (col 16HM-0) | approved · from 05 (16HO-0; red dot none) | 1FXG-0 "phone · sheet over journal" | — | `c:player-sheet/brief/playing` 1FXR-0<br>`c:icon-button/wash/rest` 1FZI-0<br>`c:icon/chevron-left` 1FZJ-0<br>`c:icon/chevron-down` 1FZD-0<br>`c:claim/asked` 1FZ6-0<br>`c:evidence-row/rest` 1FYW-0<br>`c:icon/journal` 1FZ3-0<br>`c:icon/chevron-right` 1FYX-0<br>`c:icon/calendar` 1FYL-0<br>`c:episode-moment/rest` 1FY2-0<br>`c:pill/neutral/rest` 1FY4-0<br>`c:icon/correct` 1FXW-0 |

#### area · goals

| screen | status chip (node) | visible phone | hidden copies in slot | component instances (name → one node id) |
|---|---|---|---|---|
| GL-1 · goals (col 16HW-0) | approved · from approvals · GL-1 (16HY-0; red dot none) | 1FZO-0 "GL-1 · 17 Pro" | — | `c:top-bar/title/rest` 1G3J-0<br>`c:icon-button/wash/add` 1G3K-0<br>`c:icon/add` 1G3M-0<br>`c:goal-card/guess` 1G35-0<br>`c:icon-well/guess` 1G3F-0<br>`c:icon/guess` 1G3G-0<br>`c:pill/raised` 1G39-0<br>`c:goal-card/rest` 1G2R-0<br>`c:goal-card/too early` 1G21-0<br>`c:goal-row/faded` 1G1X-0<br>`c:icon/chevron-right` 1G1Y-0<br>`c:tab-bar/system/rest` 1FZS-0<br>`c:tab-bar/item/rest` 1G05-0<br>`c:icon/journal/emphasis` 1G07-0<br>`c:icon/podcasts` 1G03-0<br>`c:tab-bar/item/selected` 1FZX-0<br>`c:icon/goals` 1FZZ-0<br>`c:icon/you` 1FZV-0 |
| GL-2 · one goal (col 16I2-0) | approved · from approvals · GL-2 (16I4-0; red dot present, hidden) | 1G3Z-0 "GL-2 · 17 Pro" | — | `c:top-bar/entry/rest` 1G5F-0<br>`c:icon-button/wash/rest` 1G5K-0<br>`c:icon/chevron-left` 1G5L-0<br>`c:button/text/rest` 1G5G-0<br>`c:evidence-row/rest` 1G52-0<br>`c:icon/calendar` 1G59-0<br>`c:icon/chevron-right` 1G53-0<br>`c:icon/journal` 1G4R-0<br>`c:claim/asked · a pattern` 1G45-0<br>`c:icon-well/guess` 1G4F-0<br>`c:icon/guess` 1G4G-0<br>`c:pill/raised` 1G49-0<br>`c:pill/neutral` 1G42-0 |

#### area · you

| screen | status chip (node) | visible phone | hidden copies in slot | component instances (name → one node id) |
|---|---|---|---|---|
| YO-1 · you (col 16ID-0) | approved · from approvals · YO-1 (16IF-0; red dot present, hidden) | 1G5Y-0 "YO-1 · 17 Pro" | — | `c:top-bar/title/rest` 1G7X-0<br>`c:search-field/rest` 1G7R-0<br>`c:icon/mic` 1G7U-0<br>`c:you-map/orbits/rest` 1G6Z-0<br>`c:settings-row/nav · what i know` 1G6S-0<br>`c:settings-row/nav · a question waiting` 1G6M-0<br>`c:tab-bar/system/rest` 1G62-0<br>`c:tab-bar/item/rest` 1G6F-0<br>`c:icon/journal/emphasis` 1G6H-0<br>`c:icon/podcasts` 1G6D-0<br>`c:icon/goals` 1G69-0<br>`c:tab-bar/item/selected` 1G63-0<br>`c:icon/you` 1G65-0 |
| YO-2 · search (col 16IL-0) | approved · from approvals · YO-2 (16IN-0; red dot none) | 1G8E-0 "YO-2 · 17 Pro · found" | — | `c:top-bar/title/rest` 1GAB-0<br>`c:search-field/typed` 1GA2-0<br>`c:icon/mic` 1GA8-0<br>`c:icon/close` 1GA4-0<br>`c:answer/found` 1G9Y-0<br>`c:source-result/rest` 1G9P-0<br>`c:icon/chevron-right` 1G9Q-0<br>`c:settings-row/switch · only certain` 1G91-0<br>`c:switch/default/off` 1G92-0<br>`c:tab-bar/system/rest` 1G8I-0<br>`c:tab-bar/item/rest` 1G8V-0<br>`c:icon/journal/emphasis` 1G8X-0<br>`c:icon/podcasts` 1G8T-0<br>`c:icon/goals` 1G8P-0<br>`c:tab-bar/item/selected` 1G8J-0<br>`c:icon/you` 1G8L-0 |
| YO-3 · a source (col 16IR-0) | approved · from approvals · YO-3 (16IT-0; red dot none) | 1GAS-0 "YO-3 · 17 Pro · a journal entry" | — | `c:top-bar/entry/rest` 1GBJ-0<br>`c:icon-button/wash/rest` 1GBO-0<br>`c:icon/chevron-left` 1GBP-0<br>`c:button/text/rest` 1GBK-0<br>`c:entry/words/rest` 1GBI-0<br>`c:link/conversation/rest` 1GBA-0<br>`c:settings-row/nav` 1GB2-0 |
| YO-4 · a node (col 16IX-0) | approved · from approvals · YO-4 (16IZ-0; red dot none) | 1GC2-0 "YO-4 · 17 Pro · a person" | — | `c:player-sheet/brief/playing` 1GCD-0<br>`c:icon/chevron-down` 1GDY-0<br>`c:claim/stated` 1GDS-0<br>`c:evidence-row/rest` 1GDI-0<br>`c:icon/journal` 1GDP-0<br>`c:icon/chevron-right` 1GDJ-0<br>`c:icon/calendar` 1GD7-0<br>`c:chip/link` 1GCV-0<br>`c:pill/neutral/still true` 1GCK-0<br>`c:icon/check` 1GCM-0<br>`c:pill/neutral/rest` 1GCG-0<br>`c:icon/correct` 1GCI-0 |
| YO-5 · what i know (col 16J3-0) | approved · from approvals · YO-5 (16J5-0; red dot none) | 1SZX-0 "YO-5 · 17 Pro" | — | `c:top-bar/settings/rest` 1T1K-0<br>`c:icon-button/wash/rest` 1T1O-0<br>`c:icon/chevron-left` 1T1P-0<br>`c:icon/chevron-right` 1T1F-0<br>`c:answer-row/rest` 1T0Z-0 |

#### area · settings and account

| screen | status chip (node) | visible phone | hidden copies in slot | component instances (name → one node id) |
|---|---|---|---|---|
| ST-1 · settings (col 16JD-0) | approved · from 05 (16JF-0; red dot none) | 1GGA-0 "ST-1 · settings" | — | `c:top-bar/settings/rest` 1GJ1-0<br>`c:icon-button/wash/rest` 1GJ6-0<br>`c:icon/chevron-left` 1GJ7-0<br>`c:label/section/rest` 1GJ0-0<br>`c:settings-row/value/rest` 1GIQ-0<br>`c:hairline/inset/rest` 1GIC-0 |
| ST-2 · daily brief (col 16JJ-0) | approved · from 05 (16JL-0; red dot none) | 1GJK-0 "ST-2 · daily brief" | — | `c:top-bar/settings/rest` 1GKP-0<br>`c:icon-button/wash/rest` 1GKT-0<br>`c:icon/chevron-left` 1GKU-0<br>`c:settings-row/switch/rest` 1GKJ-0<br>`c:switch/default/on` 1GKK-0<br>`c:hairline/inset/rest` 1GKH-0<br>`c:settings-row/value/rest` 1GK9-0<br>`c:label/section/rest` 1GK6-0<br>`c:segmented/3/rest` 1GJZ-0<br>`c:settings-row/action/rest` 1GJP-0<br>`c:pill/raised/rest` 1GJQ-0 |
| ST-3 · sources (col 16JP-0) | approved · from 05 (16JR-0; red dot none) | 1GL7-0 "ST-3 · sources" | — | `c:top-bar/settings/rest` 1GND-0<br>`c:icon-button/wash/rest` 1GNH-0<br>`c:icon/chevron-left` 1GNI-0<br>`c:settings-row/source/rest` 1GN1-0<br>`c:hairline/inset-icon/rest` 1GMX-0<br>`c:pill/raised/rest` 1GMN-0<br>`c:settings-row/source/problem` 1GM8-0<br>`c:settings-row/source/syncing` 1GLS-0<br>`c:status/syncing · spinner 6 (arc rotates 1s linear)` 1GLV-0<br>`c:settings-row/value/rest` 1GLK-0 |
| ST-4 · a source (col 16JV-0) | approved · from 05 (16JX-0; red dot none) | 1GNV-0 "ST-4 · a source" | — | `c:top-bar/settings/rest` 1GOO-0<br>`c:icon-button/wash/rest` 1GOS-0<br>`c:icon/chevron-left` 1GOT-0<br>`c:settings-row/action/rest` 1GOE-0<br>`c:pill/raised/rest` 1GOF-0<br>`c:settings-row/danger/rest` 1GO5-0 |
| ST-5 · privacy (col 16K1-0) | approved · from 05 (16K3-0; red dot none) | 1GP6-0 "ST-5 · privacy" | — | `c:top-bar/settings/rest` 1GQ4-0<br>`c:icon-button/wash/rest` 1GQ8-0<br>`c:icon/chevron-left` 1GQ9-0<br>`c:settings-row/switch/rest` 1GPY-0<br>`c:switch/default/on` 1GPZ-0<br>`c:hairline/inset/rest` 1GPW-0<br>`c:settings-row/value/rest` 1GPQ-0<br>`c:settings-row/action/rest` 1GPI-0<br>`c:pill/raised/rest` 1GPJ-0<br>`c:settings-row/danger/rest` 1GP9-0 |
| ST-6 · how straight (col 16K7-0) | approved · from 05 (16K9-0; red dot none) | 1GQM-0 "ST-6 · how straight i am with you" | — | `c:top-bar/settings/rest` 1GRL-0<br>`c:icon-button/wash/rest` 1GRP-0<br>`c:icon/chevron-left` 1GRQ-0<br>`c:settings-row/choice/rest` 1GRG-0<br>`c:settings-row/choice/chosen` 1GR1-0<br>`c:icon/check` 1GR2-0 |
| ST-7 · voice (col 16KD-0) | approved · from 05 (16KF-0; red dot none) | 1GS3-0 "ST-7 · voice and listening" | — | `c:top-bar/settings/rest` 1GSY-0<br>`c:icon-button/wash/rest` 1GT2-0<br>`c:icon/chevron-left` 1GT3-0<br>`c:settings-row/action/rest` 1GSQ-0<br>`c:pill/raised/rest` 1GSR-0<br>`c:hairline/inset/rest` 1GSO-0<br>`c:settings-row/value/rest` 1GSG-0<br>`c:label/section/rest` 1GSD-0<br>`c:segmented/3/rest` 1GS8-0 |
| ST-8 · what i've learned (col 16KJ-0) | approved · from 05 (16KL-0; red dot none) | 1GTG-0 "ST-8 · what i've learned" | — | `c:top-bar/settings/rest` 1GTN-0<br>`c:icon-button/wash/rest` 1GTR-0<br>`c:icon/chevron-left` 1GTS-0 |
| ST-9 · account (col 16KP-0) | approved · from 05 (16KR-0; red dot none) | 1GU5-0 "ST-9 · account" | — | `c:top-bar/settings/rest` 1GV7-0<br>`c:icon-button/wash/rest` 1GVB-0<br>`c:icon/chevron-left` 1GVC-0<br>`c:settings-row/value/rest` 1GV2-0<br>`c:hairline/inset/rest` 1GV0-0<br>`c:settings-row/leaves-app/rest` 1GUU-0<br>`c:icon/external` 1GUV-0<br>`c:settings-row/action/rest` 1GUQ-0<br>`c:icon/sign-out` 1GUM-0<br>`c:settings-row/danger/rest` 1GU8-0 |
| AC-2 · signing out (col 16KV-0) | approved · from approvals · M6 end (16KX-0; red dot present, hidden) | 1GVP-0 "AC-2 · signing out" | — | `c:top-bar/settings/rest` 1GX9-0<br>`c:icon-button/wash/rest` 1GXD-0<br>`c:icon/chevron-left` 1GXE-0<br>`c:settings-row/value/rest` 1GX4-0<br>`c:hairline/inset/rest` 1GX2-0<br>`c:settings-row/leaves-app/rest` 1GWW-0<br>`c:icon/external` 1GWX-0<br>`c:settings-row/action/rest` 1GWS-0<br>`c:icon/sign-out` 1GWO-0<br>`c:settings-row/danger/rest` 1GWA-0<br>`c:sheet/sign-out` 1GVR-0<br>`c:spinner/20` 1GW1-0<br>`c:button/lit/send-then-sign-out` 1GVV-0<br>`c:button/text/cancel` 1GVT-0 |
| AC-1 · sign in, returning (col 16L3-0) | approved · from approvals · AC-1 (16L5-0; red dot present, hidden) | 1GXR-0 "AC-1 · 17 Pro · rest" | — | `c:you-map/orbits/rest` 1GYO-0<br>`c:you-orb/56 (was an empty mark)` 1GYN-0 |

#### area · outside the app

| screen | status chip (node) | visible phone | hidden copies in slot | component instances (name → one node id) |
|---|---|---|---|---|
| EX-1 · share (col 16LE-0) | approved · from approvals · EX (16LG-0; red dot none) | 1H1M-0 "EX-1 · share to retrospect" | — | `c:share/item-card` 1H1Z-0<br>`c:pill/neutral` 1H23-0<br>`c:composer/compact` 1H1S-0<br>`c:icon/mic` 1H1V-0<br>`c:button/lit/save` 1H1P-0 |
| EX-2 · lock screen (col 16LK-0) | approved · from approvals · EX (16LM-0; red dot none) | 1H2J-0 "EX-2 · lock screen · now playing" | — | `c:icon/skip-back-15` 1H2T-0<br>`c:icon/pause` 1H2R-0<br>`c:icon/skip-forward-30` 1H2P-0 |
| EX-3 · notifications (col 16LQ-0) | approved · from approvals · EX (16LS-0; red dot none) | 1H3E-0 "EX-3 · notifications" | — | — none (system UI only) |
| EX-4 · widgets (col 16LW-0) | approved · from approvals · EX (16LY-0; red dot none) | 1H4D-0 "EX-4 · widgets" | — | `c:widget/164x164` 1H55-0<br>`c:the-mark/16` 1H59-0<br>`c:the-mark/glyph` 1H5A-0<br>`c:widget/344x164` 1H4L-0<br>`c:pill/neutral · play` 1H4P-0<br>`c:pill/neutral · talk` 1H4N-0 |

## 2. Component cross-reference (c:* used on 06)

One row per name and variant. "rep" is one 06 instance. "master" is the best node to read values from: 02 · components first (", in phone" means it sits inside an in-context phone on that board). Masters from legacy boards are flagged.

| family | name | screens | rep (06) | master |
|---|---|---|---|---|
| answer | `c:answer/found` | YO-2 | 1G9Y-0 | K0U-0 (part 50) |
| answer-row | `c:answer-row/rest` | YO-5 | 1T0Z-0 | — none on 02 · components |
| badge | `c:badge/save` | ON-12 | 22MI-0 | — none on 02 · components |
| benefit-row | `c:benefit-row` | ON-12 | 22S1-0 | — none on 02 · components |
| brief-card | `c:brief-card/artwork/making` | ON-10, ON-13 | 26ML-0 | — none on 02 · components |
| brief-card | `c:brief-card/artwork/rest` | JR-1 | 1FLM-0 | B3G-0 (c · brief card) |
| brief-item | `c:brief-item/next/rest` | JR-2 | 1FNV-0 | BHX-0 (c · brief items + recap card) |
| brief-item | `c:brief-item/now/playing` | JR-2 | 1FO0-0 | BI2-0 (c · brief items + recap card) |
| button | `c:button/lit/continue` | ON-6 | 2194-0 | — none on 02 · components |
| button | `c:button/lit/plan-yearly` | ON-12 | 22MH-0 | — none on 02 · components |
| button | `c:button/lit/play` | JR-1, PC-1 | 1FLS-0 | FXV-0 (part 40) |
| button | `c:button/lit/save` | EX-1 | 1H1P-0 | — none on 02 · components |
| button | `c:button/lit/send-then-sign-out` | AC-2 | 1GVV-0 | — none on 02 · components |
| button | `c:button/raised/pause` | ON-11, JR-2, PC-2 | 26O6-0 | B9J-0 (c · player sheet, in phone) |
| button | `c:button/secondary/plan-monthly` | ON-12 | 22MM-0 | — none on 02 · components |
| button | `c:button/text/cancel` | AC-2 | 1GVT-0 | — none on 02 · components |
| button | `c:button/text/later` | ON-6 | 2192-0 | — none on 02 · components |
| button | `c:button/text/rest` | JR-4, GL-2, YO-3 | 1FRS-0 | E2Q-0 (c · entry page · what i took · delete, in phone) |
| chip | `c:chip/link` | YO-4 | 1GCV-0 | — none on 02 · components |
| claim | `c:claim/asked` | PC-3 | 1FZ6-0 | G3C-0 (part 41) |
| claim | `c:claim/asked · a pattern` | GL-2 | 1G45-0 | G3C-0 (part 41) (base c:claim/asked) |
| claim | `c:claim/stated` | YO-4 | 1GDS-0 | G2A-0 (part 41) |
| composer | `c:composer/compact` | EX-1 | 1H1S-0 | — none on 02 · components |
| entry | `c:entry/setup-recap` | ON-13 | 1FJ6-0 | — none on 02 · components |
| entry | `c:entry/words/rest` | JR-4, YO-3 | 1FRQ-0 | E2U-0 (c · entry page · what i took · delete, in phone) |
| entry-row | `c:entry-row/drawer/here` | JR-3 | 1FQN-0 | DHU-0 (c · label · day and section, in phone) |
| entry-row | `c:entry-row/drawer/rest` | JR-3 | 1FQH-0 | DRR-0 (c · journal drawer · search · entry row) |
| entry-row | `c:entry-row/drawer/unsent` | JR-3 | 1FQ8-0 | DI6-0 (c · label · day and section, in phone) |
| episode-moment | `c:episode-moment/rest` | PC-3 | 1FY2-0 | — none on 02 · components |
| episode-tile | `c:episode-tile/hero/rest` | PC-1 | 1FUK-0 | FXR-0 (part 40) |
| episode-tile | `c:episode-tile/square/rest` | PC-1 | 1FUE-0 | FYG-0 (part 40) |
| evidence-row | `c:evidence-row/rest` | PC-3, GL-2, YO-4 | 1FYW-0 | G2G-0 (part 41) |
| getting-ready | `c:getting-ready` | ON-10 | 26LV-0 | — none on 02 · components |
| goal-card | `c:goal-card/guess` | GL-1 | 1G35-0 | IYO-0 (part 48) |
| goal-card | `c:goal-card/rest` | GL-1 | 1G2R-0 | IXB-0 (part 48) |
| goal-card | `c:goal-card/too early` | GL-1 | 1G21-0 | IY9-0 (part 48) |
| goal-row | `c:goal-row/faded` | GL-1 | 1G1X-0 | IYZ-0 (part 48) |
| hairline | `c:hairline/inset-icon/rest` | ON-6, ST-3 | 21BJ-0 | DWM-0 (c · settings rows · every kind) |
| hairline | `c:hairline/inset/rest` | ST-1, ST-2, ST-5, ST-7, ST-9, AC-2 | 1GIC-0 | DUM-0 (c · settings rows · every kind) |
| hint | `c:hint/1-of-3` | ON-13 | 1FJ0-0 | — none on 02 · components |
| icon | `c:icon/add` | GL-1 | 1G3M-0 | — none on 02 · components |
| icon | `c:icon/calendar` | PC-3, GL-2, YO-4 | 1FYL-0 | G38-0 (part 41) |
| icon | `c:icon/check` | YO-4, ST-6 | 1GCM-0 | 8R1-0 (legacy · c4 · title menu, paywall, settings) |
| icon | `c:icon/chevron-down` | ON-11, JR-2, PC-2, PC-3, YO-4 | 26PI-0 | BAV-0 (c · player sheet, in phone) |
| icon | `c:icon/chevron-left` | ON-3–9, ON-5, ON-6, ON-10, JR-4, PC-3, GL-2, YO-3, YO-5, ST-1, ST-2, ST-3, ST-4, ST-5, ST-6, ST-7, ST-8, ST-9, AC-2 | 1F71-0 | DJD-0 (c · label · day and section, in phone) |
| icon | `c:icon/chevron-right` | JR-1, JR-2, PC-3, GL-1, GL-2, YO-2, YO-4, YO-5 | 1FLC-0 | BI4-0 (c · brief items + recap card) |
| icon | `c:icon/close` | YO-2 | 1GA4-0 | K0P-0 (part 50) |
| icon | `c:icon/correct` | ON-11, JR-2, PC-2, PC-3, YO-4 | 26OX-0 | BAA-0 (c · player sheet, in phone) |
| icon | `c:icon/drawer` | ON-13, JR-1, JR-3 | 1FJZ-0 | B4V-0 (c · top bar, in phone) |
| icon | `c:icon/external` | ST-9, AC-2 | 1GUV-0 | — none on 02 · components |
| icon | `c:icon/goals` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FIH-0 | GY1-0 (part 45, in phone) |
| icon | `c:icon/guess` | GL-1, GL-2 | 1G3G-0 | — none on 02 · components |
| icon | `c:icon/journal` | PC-3, GL-2, YO-4 | 1FZ3-0 | G7Z-0 (c · journal drawer · search · entry row) |
| icon | `c:icon/journal/emphasis` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FIP-0 | GY9-0 (part 45, in phone) |
| icon | `c:icon/lock` | ON-5 | 1F85-0 | HG0-0 (part 44, in phone) |
| icon | `c:icon/mic` | ON-13, JR-1, YO-1, YO-2, EX-1 | 1FIV-0 | K0D-0 (part 50) |
| icon | `c:icon/mic-off` | ON-3–9, ON-5, ON-10 | 1F6G-0 | B00-0 (c · voice composer) |
| icon | `c:icon/pause` | ON-11, JR-2, PC-2, EX-2 | 26O7-0 | GX6-0 (part 45) |
| icon | `c:icon/play` | ON-10, ON-13 | 26MS-0 | FXX-0 (part 40) |
| icon | `c:icon/podcasts` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FIL-0 | GY5-0 (part 45, in phone) |
| icon | `c:icon/share` | ON-11, JR-2, PC-2 | 26PL-0 | BAY-0 (c · player sheet, in phone) |
| icon | `c:icon/sign-out` | ST-9, AC-2 | 1GUM-0 | — none on 02 · components |
| icon | `c:icon/skip-back-15` | ON-11, JR-2, PC-2, EX-2 | 26O9-0 | 8OY-0 (legacy · c5 · states, dark and access) |
| icon | `c:icon/skip-forward-30` | ON-11, JR-2, PC-2, EX-2 | 26O4-0 | 8P1-0 (legacy · c5 · states, dark and access) |
| icon | `c:icon/sliders` | JR-3 | 1FOV-0 | F2P-0 (c · journal drawer · search · entry row, in phone) |
| icon | `c:icon/you` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FID-0 | GXX-0 (part 45, in phone) |
| icon-button | `c:icon-button/wash/add` | GL-1 | 1G3K-0 | — none on 02 · components |
| icon-button | `c:icon-button/wash/mic` | ON-13, JR-1 | 1FIT-0 | B0S-0 (c · voice composer) |
| icon-button | `c:icon-button/wash/mic-off` | ON-3–9, ON-5, ON-10 | 1F6F-0 | AZY-0 (c · voice composer) |
| icon-button | `c:icon-button/wash/play` | ON-12 | 22TT-0 | — none on 02 · components |
| icon-button | `c:icon-button/wash/rest` | ON-3–9, ON-5, ON-6, ON-10, ON-13, JR-1, JR-3, JR-4, PC-3, GL-2, YO-3, YO-5, ST-1, ST-2, ST-3, ST-4, ST-5, ST-6, ST-7, ST-8, ST-9, AC-2 | 1F70-0 | B4U-0 (c · top bar, in phone) |
| icon-well | `c:icon-well/guess` | GL-1, GL-2 | 1G3F-0 | — none on 02 · components |
| knows-you-meter | `c:knows-you-meter/1-of-6` | ON-6 | 21C1-0 | — none on 02 · components |
| label | `c:label/day/rest` | JR-3 | 1FQQ-0 | DRP-0 (c · journal drawer · search · entry row) |
| label | `c:label/section/rest` | ON-6, ST-1, ST-2, ST-7 | 21BY-0 | DJL-0 (c · label · day and section, in phone) |
| link | `c:link/conversation/rest` | JR-4, YO-3 | 1FRI-0 | E2Z-0 (c · entry page · what i took · delete, in phone) |
| message | `c:message/mine/rest` | JR-1 | 1FLH-0 | B8J-0 (c · conversation, in phone) |
| message | `c:message/theirs/rest` | ON-13, JR-1 | 1FJ3-0 | B8B-0 (c · conversation, in phone) |
| mini-player | `c:mini-player/paused` | ON-12 | 22TR-0 | — none on 02 · components |
| onboarding | `c:onboarding/question` | ON-3–9, ON-10 | 1F6V-0 | GEA-0 (part 42, in phone) |
| onboarding | `c:onboarding/your-words` | ON-3–9, ON-10 | 1F6R-0 | GEB-0 (part 42, in phone) |
| onboarding-progress | `c:onboarding-progress` | ON-3–9, ON-5, ON-6, ON-10 | 1F74-0 | GDY-0 (part 42, in phone) |
| pill | `c:pill/neutral` | GL-2, EX-1 | 1G42-0 | — none on 02 · components |
| pill | `c:pill/neutral · play` | EX-4 | 1H4P-0 | — none on 02 · components |
| pill | `c:pill/neutral · talk` | EX-4 | 1H4N-0 | — none on 02 · components |
| pill | `c:pill/neutral/rest` | ON-11, JR-2, JR-4, PC-2, PC-3, YO-4 | 26OV-0 | D9G-0 (c · pill) |
| pill | `c:pill/neutral/still true` | YO-4 | 1GCK-0 | — none on 02 · components |
| pill | `c:pill/raised` | GL-1, GL-2 | 1G39-0 | IYS-0 (part 48) |
| pill | `c:pill/raised/rest` | ON-6, ST-2, ST-3, ST-4, ST-5, ST-7 | 21B9-0 | D9Z-0 (c · pill) |
| player-sheet | `c:player-sheet/brief/playing` | ON-11, JR-2, PC-2, PC-3, YO-4 | 26NZ-0 | B9C-0 (c · player sheet, in phone) |
| privacy-mark | `c:privacy-mark` | ON-5 | 1F82-0 | HFX-0 (part 44, in phone) |
| row | `c:row/destructive/rest` | JR-4 | 1FQZ-0 | E3J-0 (c · entry page · what i took · delete, in phone) |
| row | `c:row/drawer-foot/rest` | JR-3 | 1FOS-0 | F2M-0 (c · journal drawer · search · entry row, in phone) |
| scrubber | `c:scrubber/chapters` | ON-11, JR-2, PC-2 | 26OM-0 | 8QQ-0 (legacy · c5 · states, dark and access) |
| search-field | `c:search-field/journal/rest` | JR-3 | 1FQT-0 | G7T-0 (c · journal drawer · search · entry row) |
| search-field | `c:search-field/rest` | YO-1 | 1G7R-0 | K0B-0 (part 50) |
| search-field | `c:search-field/typed` | YO-2 | 1GA2-0 | K0J-0 (part 50) |
| segmented | `c:segmented/3/rest` | ST-2, ST-7 | 1GJZ-0 | DTG-0 (c · switch · segmented) |
| settings-row | `c:settings-row/action/rest` | ST-2, ST-4, ST-5, ST-7, ST-9, AC-2 | 1GJP-0 | — none on 02 · components |
| settings-row | `c:settings-row/choice/chosen` | ST-6 | 1GR1-0 | DUX-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/choice/rest` | ST-6 | 1GRG-0 | DV6-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/danger/rest` | ST-4, ST-5, ST-9, AC-2 | 1GO5-0 | DW2-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/leaves-app/rest` | ST-9, AC-2 | 1GUU-0 | DVL-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/nav` | YO-3 | 1GB2-0 | — none on 02 · components |
| settings-row | `c:settings-row/nav · a question waiting` | YO-1 | 1G6M-0 | — none on 02 · components |
| settings-row | `c:settings-row/nav · more apps` | ON-6 | 2199-0 | — none on 02 · components |
| settings-row | `c:settings-row/nav · what i know` | YO-1 | 1G6S-0 | — none on 02 · components |
| settings-row | `c:settings-row/source/connected` | ON-6 | 21BN-0 | — none on 02 · components |
| settings-row | `c:settings-row/source/problem` | ST-3 | 1GM8-0 | DX5-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/source/rest` | ON-6, ST-3 | 21B8-0 | DWC-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/source/syncing` | ST-3 | 1GLS-0 | DXJ-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/switch · only certain` | YO-2 | 1G91-0 | K1V-0 (part 50) |
| settings-row | `c:settings-row/switch/rest` | ST-2, ST-5 | 1GKJ-0 | DUG-0 (c · settings rows · every kind) |
| settings-row | `c:settings-row/value/rest` | ST-1, ST-2, ST-3, ST-5, ST-7, ST-9, AC-2 | 1GIQ-0 | DVT-0 (c · settings rows · every kind) |
| share | `c:share/item-card` | EX-1 | 1H1Z-0 | — none on 02 · components |
| sheet | `c:sheet/sign-out` | AC-2 | 1GVR-0 | — none on 02 · components |
| source-result | `c:source-result/rest` | YO-2 | 1G9P-0 | K14-0 (part 50) |
| spinner | `c:spinner/20` | ON-10, AC-2 | 26M3-0 | — none on 02 · components |
| stage | `c:stage/next` | ON-10 | 26LZ-0 | — none on 02 · components |
| status | `c:status/syncing · spinner 6 (arc rotates 1s linear)` | ST-3 | 1GLV-0 | DXR-0 (c · settings rows · every kind) |
| switch | `c:switch/default/off` | YO-2 | 1G92-0 | DSR-0 (c · switch · segmented) |
| switch | `c:switch/default/on` | ST-2, ST-5 | 1GKK-0 | DSW-0 (c · switch · segmented) |
| tab-bar | `c:tab-bar/item/rest` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FIJ-0 | GY3-0 (part 45, in phone) |
| tab-bar | `c:tab-bar/item/selected` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FIN-0 | GY7-0 (part 45, in phone) |
| tab-bar | `c:tab-bar/system/rest` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FIA-0 | B3X-0 (c · tab bar, in phone) |
| the-mark | `c:the-mark/16` | EX-4 | 1H59-0 | V4W-0 (c · the mark) |
| the-mark | `c:the-mark/22` | ON-11, JR-2, PC-2 | 26PQ-0 | V4T-0 (c · the mark) |
| the-mark | `c:the-mark/glyph` | ON-11, JR-2, PC-2, EX-4 | 26PR-0 | V4P-0 (c · the mark) |
| took-row | `c:took-row/claim/noted` | JR-4 | 1FR3-0 | E3C-0 (c · entry page · what i took · delete, in phone) |
| took-row | `c:took-row/claim/rest` | JR-4 | 1FR9-0 | E35-0 (c · entry page · what i took · delete, in phone) |
| top-bar | `c:top-bar/entry/rest` | JR-4, GL-2, YO-3 | 1FRR-0 | E2J-0 (c · entry page · what i took · delete, in phone) |
| top-bar | `c:top-bar/label/rest` | JR-3 | 1FPD-0 | B5B-0 (c · top bar, in phone) |
| top-bar | `c:top-bar/onboarding` | ON-3–9, ON-10 | 1F6W-0 | GE1-0 (part 42, in phone) |
| top-bar | `c:top-bar/settings/rest` | YO-5, ST-1, ST-2, ST-3, ST-4, ST-5, ST-6, ST-7, ST-8, ST-9, AC-2 | 1T1K-0 | DJ7-0 (c · label · day and section, in phone) |
| top-bar | `c:top-bar/title/rest` | ON-13, JR-1, PC-1, GL-1, YO-1, YO-2 | 1FJV-0 | B4R-0 (c · top bar, in phone) |
| transport | `c:transport/recess/playing` | ON-11, JR-2, PC-2 | 26O3-0 | B9G-0 (c · player sheet, in phone) |
| voice-composer | `c:voice-composer/listening` | ON-3–9, ON-10 | 1F6E-0 | AZX-0 (c · voice composer) |
| voice-composer | `c:voice-composer/muted-empty` | ON-13, JR-1 | 1FIS-0 | B0R-0 (c · voice composer) |
| voice-composer | `c:voice-composer/speaking` | ON-5 | 1F7K-0 | B0C-0 (c · voice composer) |
| widget | `c:widget/164x164` | EX-4 | 1H55-0 | — none on 02 · components |
| widget | `c:widget/344x164` | EX-4 | 1H4L-0 | — none on 02 · components |
| you-map | `c:you-map/orbits/rest` | ON-1/2, YO-1, AC-1 | 1F5K-0 | B6Q-0 (c · you map) |
| you-orb | `c:you-orb/56 (was an empty mark)` | AC-1 | 1GYN-0 | — none on 02 · components |

## 2b. Masters per family on 02 · components (p-3-0)

Boards: 89H how this page works · 233J/233M/233P row headers · SUL the mark · AZN voice composer · B17 brief card · B18 tab bar · B19 top bar · B1A you map · B1B conversation · B1C player sheet · B1D brief items + recap · D90 pill · DF6 label · DF7 settings row + hairline · DF8 drawer/search/entry row · DS5 switch/segmented · DS6 settings rows · DS7 settings page · E20 entry page · GD2 part 42 onboarding question · GJJ part 44 privacy · GT1 part 45 mini-player · ITY part 48 goal card · JZQ part 50 search · FWU part 40 episode tiles · G1E part 41 why this is here · 98O ON-1 C2 depth field · legacy QW c1, UA c2, X2 c3, 102 c4, 1XE c5, 25P c6 (reference only, mostly unnamed layers).

| family | board | master node(s) |
|---|---|---|
| the-mark | SUL-0 | master:the-mark/38 V4O-0 · /22 V4T-0 · /16 V4W-0 · glyph V4P-0 |
| voice-composer | AZN-0 | listening AZX-0 · speaking B0C-0 · muted-empty B0R-0 · muted-typing B10-0 (icon-button/wash/mic-off AZY-0, wash/mic B0S-0, raised/send B11-0) |
| brief-card | B17-0 | artwork/rest B3G-0. `making` has no master here (only states on approvals CEM-0 and in screens 1FJL-0) |
| tab-bar | B18-0 | system/rest B3X-0 (items inside); cleaner item instances in part 45 GY7-0 (selected) GY3-0 (rest) |
| top-bar | B19-0 + others | title/rest B4R-0 · label/rest B5B-0 · label/scrolled B5W-0 · entry/rest E2J-0 (E20) · settings/rest DY4-0 (DS7) · onboarding GE1-0 (GD2) |
| you-map | B1A-0 | orbits/rest B6Q-0. Unpicked: stars/rest O1S-0, neighbourhoods/rest OB4-0 (JZQ "map versions · pick one", red dot visible) |
| message / guess-card | B1B-0 | mine/rest B8J-0 · mine/voice B8L-0 · mine/failed B7O-0 · theirs/rest B8B-0 · guess-card/open B7Q-0 |
| player-sheet | B1C-0 | brief/playing B9C-0 (master) · states ready BBA-0, holding scrubber BDA-0, menu open BFB-0 · transport/recess/playing B9G-0 · button/raised/pause B9J-0 · scrubber/chapters B9Z-0 · scrub-bubble/held BN4-0 · menu/more/open BFC-0 |
| brief-item / recap-card | B1D-0 | now/playing BI2-0 · next/rest BHX-0 · recap-card/rest BHK-0 |
| pill | D90-0 | neutral rest D9G-0 / pressed D9N-0 · raised rest D9Z-0 / pressed DA6-0 · lit rest DAI-0 / pressed DAP-0 · choice/on GSR-0, choice/off GGB-0 (GD2) |
| label | DF6-0 | day/rest DHS-0 · section/rest DJL-0 |
| hairline | DS6-0 | inset/rest DUM-0 · inset-icon/rest DWM-0 |
| drawer / search-field / entry-row | DF8-0 | search-field/journal rest DPR-0, typing DRF-0 · entry-row/drawer here DPY-0, rest DQ4-0, unsent DQA-0, pressed DRY-0 · row/drawer-foot/rest F2M-0 · empty-mark/journal G7Y-0 · empty-mark/search G8F-0 |
| switch / segmented | DS5-0 | switch/default off DSR-0, on DSW-0, pressed DT1-0, disabled DT6-0 · segmented/3/rest DTG-0, 2/rest DTQ-0, 3/disabled DTY-0 |
| settings-row | DS6-0 | switch/rest DUG-0 · choice/chosen DUX-0 · choice/rest DV6-0 · leaves-app/rest DVL-0 · value/rest DVT-0 · danger/rest DW2-0 · source/rest DWC-0, problem DX5-0, syncing DXJ-0 · status/syncing spinner DXR-0. No action/nav/source-connected master |
| settings page | DS7-0 / DF7-0 | page DY3-0 / DMF-0 |
| entry page | E20-0 | entry/words/rest E2U-0 · entry/words/editing G8U-0 · link/conversation E2Z-0 · took-row/claim rest E35-0, noted E3C-0 · button/text/rest E2Q-0 · row/destructive E3J-0 · dialog/destructive/rest E4B-0 · button/destructive-compact E4G-0 · button/link E4I-0 |
| onboarding question | GD2-0 (part 42) | onboarding-progress GDY-0 · onboarding/question GEA-0 · your-words GEB-0 · quick-answers GG6-0 · top-bar/onboarding GE1-0 |
| privacy-mark | GJJ-0 (part 44) | HFX-0 |
| mini-player | GT1-0 (part 45) | playing GX0-0 · failed GXB-0 (icon-button/wash/pause GX5-0, wash/retry GXG-0). No `paused` master |
| goal-card | ITY-0 (part 48) | rest IXB-0 · too early IY9-0 · guess IYO-0 · goal-row/faded IYZ-0 · unchosen styles words LOV-0, week LP2-0, dusk LQ4-0 |
| search | JZQ-0 (part 50) | search-field rest K0B-0, typed K0J-0 · answer/found K0U-0, abstained K24-0 · source-result/rest K14-0 · settings-row/switch · only certain K1V-0 |
| episode-tile | FWU-0 (part 40) | hero/rest FXR-0 · hero/making FZ1-0 · square/rest FYG-0 · button/lit/play FXV-0 |
| claim / evidence-row | G1E-0 (part 41) | claim/stated G2A-0 · claim/asked G3C-0 · evidence-row/rest G2G-0 |
| toast (pending) | approvals 2FI5-0 | toast/undo/rest 2FIL-0 · pressed 2FIR-0 · plain 2FIX-0 · ax3 2FJ3-0 · dark 2FJB-0 / 2FJF-0 |
| icons | approvals 89Q-0 part 00 | icon grid 8LM-0, one frame per glyph named `shipped · <name>` (e.g. drawer 92X-0, chevron-right 9UL-0, send 92H-0, retry 928-0). Foundations f5 1DX-0 is an older sheet (no drawer/send/retry/offline). No `c:icon/*` master exists anywhere |

### Used in 06 but with no master on 02 · components (43 names)

Read values from the 06 instance (rep id in §2) or the screen's 04b board.

| family | names | where to read instead |
|---|---|---|
| button | lit/continue, lit/plan-yearly, lit/save, lit/send-then-sign-out, secondary/plan-monthly, text/cancel, text/later; badge/save | 06 instances 2194, 22MH, 1H1P, 1GVV, 22MM, 1GVT, 2192, 22MI; legacy c1 QW-0 has unnamed primary/secondary rows; pill/lit DAI-0 is the nearest approved master |
| settings-row | action/rest (used on 6 screens), nav, nav · what i know, nav · a question waiting, nav · more apps, source/connected | 1GJP-0, 1GB2-0, 1G6S-0, 1G6M-0, 2199-0, 21BN-0 |
| pill | neutral (no state), neutral · play, neutral · talk, neutral/still true | 1G42-0, 1H4P-0, 1H4N-0, 1GCK-0 |
| icons | add, external, guess, sign-out | 1G3M-0, 1GUV-0, 1G3G-0, 1GUM-0 |
| icon-button / well | wash/add, wash/play, icon-well/guess | 1G3K-0, 22TT-0, 1G3F-0 |
| onboarding & M6 | getting-ready, stage/next, spinner/20, knows-you-meter/1-of-6, brief-card/artwork/making, entry/setup-recap, hint/1-of-3, sheet/sign-out, you-orb/56 | 26LV, 26LZ, 26M3, 21C1, 26ML, 1FJ6, 1FJ0, 1GVR, 1GYN; 04b boards O1R-0 (M6 end), V6L-0 (ON-6), ILW-0 (AC-1) |
| paywall | benefit-row, mini-player/paused | 22S1, 22TR; 02b IFL-0 decision 06 |
| other | answer-row/rest, chip/link, episode-moment/rest, composer/compact, share/item-card, widget/164x164, widget/344x164 | 1T0Z, 1GCV, 1FY2, 1H1S, 1H1Z, 1H55, 1H4L; 04b LBO-0, KWP-0, I0Q-0, M6H-0 |

## 3. Approvals page (p-G-0), what is still waiting

Boards: 89Q-0 review · journal sub-components · round 1 · 2FI5-0 review · toast and tags · round 1 · NV7-0 read me · 2H3N-0 the invite (skipped; it holds 4 more visible red dots 2H3Y, 2HBG, 2HHM, 2HSH).

Visible red dots (`needs you · red dot`, display not none):

| board | part | red dot | what is asked (verdict text node) |
|---|---|---|---|
| 89Q | part 03 brief card · M3 states (8R3-0, states CEM-0) | F33-0 | 8TU-0: D approved 20 Oct; approve D's other states being made / played / quiet day |
| 89Q | part 07 voice composer · thinking state (9UC-0, C9B-0) | F35-0 | 9UJ-0: four states approved 20 Oct; approve "thinking" |
| 89Q | part 08 conversation · message states (9W3-0, C3A-0) | F37-0 | 9WA-0: A picked; approve arriving / sending / not sent / pressed |
| 2FI5 | part 30 toast (2FIB-0) | 2FIG-0 | 2FP0-0: approve the toast as drawn |
| 2FI5 | part 30 round 4 · easier to see (2GJ6-0) | 2GJA-0 | 2H26-0: pick 1–4 after trying on phone (lean 2) |
| 2FI5 | part 31 tags (2FP2-0) | 2FP7-0 | 2FQV-0: approve quiet tag, pick A/B/C guess tag (lean B) |
| 2FI5 | part 31 round 2 · softer dash (2G2P-0) | 2G2T-0 | steps before / softer (lean) / softest |
| 2FI5 | part 32 placeholder contrast (2H28-0) | 2H2D-0 | A as drawn 4.2:1 vs B text secondary 5.3:1 (lean B) |

Hidden red dots (resolved rounds): 2FR1-0 toast round 2 (picked B frosted), 2G3R-0 toast round 3, 2FPW-0 guess-tag decision.

Waiting but with no red dot: part 09 player sheet (A38-0, A3G-0 "approve the four states, and name what goes in the … menu"), part 10 brief items + recap (A8W-0, A9X-0 "approve the now card, next rows and recap card"). Also on 02 · components: JZQ "map versions · pick one" NVD-0 (visible, uses `status-danger-text`).

Parts on 89Q whose verdict still reads "ready for your review" though 02b/02 record them approved (stale copy, not real asks): 01 icon drawer 8AX, 02 icon button 8DI, 04 tab bar 8UT, 05 you map 9BS, 06 top bar 9MU, 00 icon set 8JQ, 20 pill 9C1, 21 labels 9JY, 22 row 9P6, 23 drawer 9WC, 24 entry A5L, 25 switch ACB, 26 settings rows AM0.

## 4. Open comment threads

None. `list_comment_threads status=open` returns 0. 321 threads exist, all resolved; latest are on part 30 toast (2FIB), part 31 tags (2FP2) and one on area · onboarding (16EO) reading "no skip".

## 5. State boards

No state variants on 06; each column shows one phone. States live in five places.

### 5a. 05b · states · onboarding (5Q1-0, phones 390×844)

| screen | group | states (frame ids) |
|---|---|---|
| ON-1/2 splash + sign-in | 5ZQ-0 | idle 5ZT · signing in 607 · failed 60L · offline 610 · reduced motion 61F |
| ON-3 retro says hello | 7BN-0 | speaking 7BQ · muted 7CC · type chosen 7CY · replay 7DM |
| ON-4a your name | 647-0 | retro speaking 64A · listening 64S · thinking 65D · typed muted 65W · offline answer kept 66H |
| ON-4c a year from now | 672-0 | speaking 69D · listening 68S · thinking 689 · typed 67O · offline 674 |
| ON-4d lately | 69W-0 | speaking 6C7 · listening 6BM · thinking 6B3 · typed 6AI · offline 69Y |
| ON-8a what you care about | 6CQ-0 | speaking 6F1 · listening 6EG · thinking 6DX · typed 6DC · offline 6CS |
| ON-8b one thing to change | 6FK-0 | speaking 6HV · listening 6HA · thinking 6GR · typed 6G6 · offline 6FM |
| ON-4b retro replies | 6IE-0 | speaking 6IH · deeper, refers back 6IZ · one follow-up at most 6JH |
| ON-4e the news you follow | 6K0-0 | nothing picked 6K3 · picked 6L0 · none, fine 6LX |
| ON-5 privacy | 6MW-0 | reading aloud 6MZ · muted 6NL · policy open 6O7 |
| ON-6 connect | 6OT-0 | default 6OW · connecting 6Q1 · connected 6R4 · failed 6S8 · denied 6TB · waiting on approval 6UE |
| ON-9 how straight | 6VJ-0 | recommended 6VM · changed 6WE · said aloud 6X6 |
| ON-8c your morning brief | 6Y0-0 | on 6Y3 · time changed 6YQ · asking for notifications 6ZA · allowed 704 · not now 70S · turned off 71G |
| ON-10 getting ready | 725-0 | making 728 · quiet wait 72T · ready 73E · slow 73Z · failed 74K |

Not covered on 05b: ON-11, ON-12, ON-13.

### 5b. 05 · the app in order (MAR-0, 402×874)

| screen | state phones |
|---|---|
| ON-3–9 | MFT-0 listening, MGZ-0 quick answers |
| JR-1 | MJK-0 at rest, MLP-0, MNZ-0 (talking / thinking), MQ5-0 scrolled, MSH-0 (brief being made), MUI-0 first day |
| JR-3 | MW6-0 at rest · MYD-0 empty · MZJ-0 searching · N17-0 no results · N2N-0 offline |
| JR-4 | N51-0 at rest · N6E-0 voice note · N7R-0 nothing taken yet · N8R-0 editing · N9D-0 offline · NAB-0 delete dialog |
| PC-3 | NDK-0 stated, NBD-0 asked |
| ON-5, ST-1…9 | single phones (MIB, NFS, NJ2, NKP, NND, NOO, NQ4, NRL, NSY, NTN) |

Every other column on MAR-0 is a "waiting on approval" placeholder (ON-1/2, ON-12, JR-2, PC-1, PC-2, GL-1, GL-2, YO-1…5, AC-1, EX-1…4), although 06 marks them approved.

### 5c. Component-level states (02 · components)

| component | states |
|---|---|
| journal drawer / search | DF8: searching DRA-0 · nothing yet G7R-0 · no results G83-0 |
| entry | E20: delete dialog E3L-0 · editing G8N-0 |
| mini-player | GT1: failed GXB-0 |
| search answer | JZQ: abstained / nothing found K24-0 |
| episode hero | FWU: being made FZ1-0 |
| player sheet | B1C: ready BB7-0, holding scrubber BD7-0, menu open BF8-0 |
| settings source row | DS6: problem DX5-0, syncing DXJ-0 |
| switch / segmented | DS5: pressed DT1-0, disabled DT6-0 / DTY-0 |
| legacy c5 (1XE-0) | transport paused / playing / buffering / ended / failed / offline (1XJ-0); brief card played / quiet / making / couldn't load (206-0); mini-player pressed / buffering / couldn't play (20Z-0); button disabled / pending (22C-0); dark (22W-0); access (24B-0) |

### 5d. Approvals and 02b

| where | states |
|---|---|
| 89Q part 03 (CEO-0) | brief card being made CGP-0 · played CFY-0 · quiet day CGE-0 (pending) |
| 89Q part 07 (C9B-0) | composer thinking CB9-0 (pending) |
| 89Q part 08 (C3A-0) | arriving C50-0 · sending C5H-0 · not sent C5R-0 · long press C6F-0 (pending) |
| 89Q part 09 (A3D-0) | ready ALG · playing ALJ · holding scrubber ALM · menu open ALP (pending) |
| 02b E4L-0 (approved) | drawer nothing yet E4W-0 · search no results E58-0 · entry editing E5P-0 |
| 2FI5 part 30 | toast with undo / pressed / plain / ax3 / dark (2FIH-0, 2FJ8-0) (pending) |

No loading, empty, error or offline state is drawn anywhere for PC-1, PC-2, GL-1, GL-2, YO-1, YO-3, YO-4, YO-5, ST-2…9, AC-1 (restoring / failed is listed only as text on MAR-0), AC-2, EX-1…4, ON-11, ON-12, ON-13.

## 6. Dark mode (file 01M5EK9MGGWHX9H05V9MENVB6P)

Dark file pages: 00 start here p-1-0 (empty), 00 approvals p-G-0, 01 foundations p-2-0, 02 components p-3-0, 02b decisions p-C-0, 03 flows p-7-0, 04 screens mid-fi p-6-0, 04b pages hi-fi p-D-0, 05 app in order p-F-0, 05b states p-8-0, **05d dark mode · hi-fi (follows light) p-H-0**, 06 everything latest p-J-0 (**empty, 0 artboards**), 07 splash motion keyframes p-E-0, 90/91/92 archive stubs. Dark boards live on 05d p-H-0 (34 boards), one per 04b light board, each titled "dark · … · approve?" with a visible dark red dot (read me 1SZL-0: every dark board needs a yes).

| light screen (06) | dark twin board (p-H-0) |
|---|---|
| ON-1/2 | 2KXY-0 part 43 splash + sign-in |
| ON-3–9 | **none** (no dark of part 42) |
| ON-5 | **none** (no dark of part 44) |
| ON-6 | 2L1H-0, **empty: only its red dot** |
| ON-10, ON-11, ON-13 | 2L1K-0 M6 end |
| ON-12 | 2PGJ-0 decision 06 paywall |
| JR-1 / JR-2 / JR-3 / JR-4 | 2GCJ-0 / 2HLW-0 / 2FN7-0 / 2G1X-0 |
| PC-1 / PC-2 / PC-3 | 2HZY-0 / 2IFN-0 / 2GV0-0 (plus 2P6Q-0 part 40, 2PBS-0 part 41) |
| GL-1 / GL-2 | 2JCP-0 / 2JRP-0 |
| YO-1 … YO-5 | 2K03-0 / 2KAA-0 / 2KJQ-0 / 2KLW-0 / 2KQR-0 |
| ST-1 … ST-9 | 2H5G-0 (pages 2H5Q, 2H90, 2HAN, 2HDB, 2HEM, 2HG2, 2HHJ, 2HIW, 2HJL) |
| AC-1 / AC-2 | 2IRR-0 / 2L1K-0 |
| EX-1 … EX-4 | 2KTI-0 |
| app in order | 2NM4-0; journey map 2LAU-0; group headers 2H4A, 2H4H, 2H4O, 2H4V, 2H52, 2H59, 2HLI, 2HLP |

No dark twin exists for the component parts 42, 44, 45 (mini-player), 48 (goal card), 50 (search), the toast, or the 02 component boards. Approval status: all 34 dark boards are still waiting.

## 7. Findings

1. **43 component names used in 06 have no master on 02 · components** (§2b list). The worst gaps: `settings-row/action/rest` (6 settings screens), every `button/*` except `button/lit/play`, `raised/pause` and `text/rest`, the whole M6 set (getting-ready, stage, spinner/20, sheet/sign-out, hint, setup-recap), paywall parts, widgets, share card, and `brief-card/artwork/making` (ON-10, ON-13).
2. **No `c:icon/*` masters exist.** Icons are instanced inside other masters. The approved glyphs live on approvals 89Q part 00 (8LM-0, `shipped · *`). Foundations f5 1DX-0 is an older, incomplete sheet. `icon/add`, `external`, `guess` and `sign-out` appear on no master board.
3. **06 screens use parts that are still waiting on approval:** `brief-card/artwork/making` (ON-10 26ML, ON-13 1FJL; part 03 M3 states, F33 red dot); `player-sheet/brief/playing` plus transport and scrubber (ON-11, JR-2, PC-2, PC-3, YO-4; part 09 says "To decide"); `brief-item/*` (JR-2; part 10 "To decide"); `search-field/rest` and `composer/compact` placeholder contrast (YO-1, EX-1; part 32 red dot); `entry-row/drawer/unsent` (JR-3; part 08 not-sent state pending).
4. **AC-1 (1GXR) mixes in an unpicked map.** Its `c:you-map/orbits/rest` 1GYO-0 contains "star field (from map version B)" 1GZG-0, and the stars-vs-orbits choice is still open on JZQ (NVD-0 red dot). The orbits master is B6Q-0.
5. **Approval records disagree with each other.** 06 marks every screen approved. 05 MAR-0 still shows "waiting on approval" for 19 columns. Components B1C and B1D say "approved 20 Oct (02b part 09/10)", yet approvals parts 09 and 10 still ask "To decide" with no red dot. 13 approved parts still sit on the approvals page with "ready for your review" verdicts, against the approvals-page-only rule.
6. **"No skip" is not applied everywhere.** A resolved comment on 16EO reads "no skip". ON-10's top bar hides skip (26N3 "hidden · skip (removed 21 oct)"), but ON-3–9 (1F6X-0 "label · skip", display flex) and the part 42 master GD2 (GE7-0) still show it.
7. **ST-1 settings copy is wrong in the "privacy, account" group** (1GGD-0): its section label is "listening" (1GH0-0), privacy's value reads "warm" (1GGU-0) and account's reads "talk" (1GGJ-0). These are copy-paste leftovers. The same appears in the DF6 master (DLL/DLT/DM4).
8. **Instances drift from their masters.** `icon-button/wash/rest` is 32×32 in onboarding (1F70, GE3 in the part 42 master) and 36×36 elsewhere. `pill/raised` is 44 high in GL-1/GL-2 (1G39) but 32 in the part 48 master IYS. `top-bar/settings/rest` wraps the status bar in ST-1 (1GJ1) but not on ST-2…9. Several pills carry no state suffix (`c:pill/neutral`, `c:pill/raised`). Some names carry descriptions (`c:claim/asked · a pattern`, `c:settings-row/nav · what i know`, `c:you-orb/56 (was an empty mark)`, `c:status/syncing · spinner 6 (arc rotates 1s linear)`), so name-matching code will break.
9. **Dark mode is incomplete and wholly unapproved.** The dark file's 06 page is empty. Dark ON-6 (2L1H) is an empty board. ON-3–9 and ON-5 have no dark twin, and neither do the component parts 42/44/45/48/50 or the toast. All 34 dark boards carry "approve?".
10. **States are thin and in mixed formats.** 05b uses 390×844 phones while 06 uses 402×874. No error, offline or empty states exist for PC-1/2, GL-1/2, YO-1/3/4/5, ST-2…9, AC-1/2, EX or ON-11…13. Legacy c5 1XE-0 is the only place showing transport, brief-card and mini-player error states, and it is unnamed and pre-token. Hidden old copies sit in the slots of ON-10 (1FBL, 1LGN), ON-11 (1FDQ, 1L8M) and ON-12 (2117). The visible ON-12 phone 22M4 holds hidden children (22SC, 22MS, 22S9…) that engineers should ignore.
