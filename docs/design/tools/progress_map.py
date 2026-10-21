# Generates docs/design/m14-progress-map.md from one list, so counts never drift.
import re
T = []  # (id, layer, byte, needs, status, pr, repo)
REPO = {"B0.0":"NPRdoinglaundry (docs)","X02":"app + backend","X07":"backend","X08":"agent","B0.2":"founder","B0.4":"backend (supabase/)","B0.5":"app + backend","B0.6":"app","B0.7":"agent","B1.04":"backend","B1.05":"app","B1.09":"agent + backend","B1.11":"backend + agent","B1.12":"backend + agent","B2.01":"backend + app","B2.04":"backend","B2.06":"agent + backend","B2.07":"app","B2.08":"backend + agent","B2.09":"backend + app","B2.10":"backend","B2.11":"app (StoreKit config)","B2.12":"app","B2.13":"backend","B3.02":"backend","B3.03":"app","B7.02":"agent","B8.01":"app","B8.02":"app","B8.03":"app","B8.04":"app"}
def repo_for(i):
    if i.startswith(("F","S","C","P","M","L")): return "app"
    if i.startswith("E"): return "paper"
    if i.startswith("X"): return "app"
    if i.startswith("W"): return "app + backend"
    if i.startswith("G"): return "all"
    if i.startswith("B0.1"): return "NPRdoinglaundry"
    if i.startswith("B"): return "backend"
    return "?"
def add(layer, items):
    for it in items:
        i, b, n = it[0], it[1], (it[2] if len(it) > 2 else "")
        st = it[3] if len(it) > 3 else "todo"
        T.append((i, layer, b, n, st, it[4] if len(it) > 4 else "", REPO.get(i, repo_for(i))))

add("0 · Platform baseline (B0)", [
 ("B0.1","Merge this branch into main: speech proxy, fail-closed payments, main's dedup, goals and Calendar fixes","", "done", "[#20](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/20)"),
 ("B0.0","Commit the plan, progress map, motion system, goal prompt and design-system docs to NPRdoinglaundry, so they live in git","", "doing"),
 ("B0.2","Rotate the ElevenLabs key (you, in ElevenLabs); confirm no client holds it","B0.1"),
 ("B0.3","Lock down /claude/generate: per-user limits now, purpose routes later","B0.1"),
 ("B0.4","Migrations for podcast_episodes and the users columns that only live in the combined SQL","B0.1"),
 ("B0.5","One idempotency key per entry; stop the double voice upload and the resync re-upload","B0.1"),
 ("B0.6","Remove dead OpenAIService and the /insights call that 404s","B0.1"),
 ("B0.7","Auth on the agent's /runs cost dashboard","B0.1"),
])
add("0b · Paper: the final everything set (E), the master the code is checked against", [
 ("E01","Re-take all 37 screens on 06 · everything · latest from their masters (after the reorg, new prices and off-axis tiles); replace copies, never add, to keep the file under its size limit",""),
 ("E02","Every key state of each screen on its master, on 05b (loading, empty, error, offline where the screen has them)","E01"),
 ("E03","SE (small screen) layout decided for every screen","E01"),
 ("E04","Dark set follows: the dark session rebuilds the changed boards, and the audit is clean","E01"),
 ("E05","Final read-through with you: everything page approved as the build master (red dots off)","E02,E03,E04"),
 ("E06","Keep it current: every design change found in code goes to the master first, then the copy on 06 (standing rule)",""),
])
add("1 · UI foundation (F)", [
 ("F01","Add the new motion and haptic tokens to tokens.json (snappy, settle, pop, gentle, curve.move, typeOn)",""),
 ("F02","Generator: springs, curves and haptics into RMotion / RHaptic; colours and sizes regenerate","F01"),
 ("F03","RType: every text role, Exposure axes, Dynamic Type","F02"),
 ("F04","RDepth: wash, sunken, raised, secondary, lit","F02"),
 ("F05","Foundation gallery preview (light and dark) checked against the Paper token sheet","F03,F04"),
 ("F06","Motion modifiers 1: .rPress, .rAppear (stagger), with Reduce Motion built in","F02"),
 ("F07","Motion modifiers 2: .rPop, .rShake, .rBlurReplace","F02"),
 ("F08","Motion modifiers 3: .rFloat (life rules), .rScrollLag","F02"),
 ("F09","Motion lab preview: every spring and curve side by side; tune the ramps","F06,F07,F08"),
 ("F10","Screen switches: design.v2.<screen> flags (debug and TestFlight on, App Store off)",""),
 ("F11","Fonts: check Exposure, Hedvig and Geist registration and PostScript names",""),
 ("F12","Token-literal check: a script that fails a PR with raw colours, sizes or springs in views","F02"),
])
add("2 · Platform foundation (B1)", [
 ("B1.01","Typed API client core: Codable requests, one execute, mapped errors","B0.1"),
 ("B1.02","Codable models per domain (entries, episodes, goals, sources, facts)","B1.01"),
 ("B1.03","Retries with backoff, timeouts, offline detection","B1.01"),
 ("B1.04","Backend: real token refresh (refresh tokens, rotation)","B0.1"),
 ("B1.05","App: silent token refresh; a 401 retries once before signing out","B1.04,B1.01"),
 ("B1.06","Local store (SwiftData): entries, episodes, goals cache","B1.02"),
 ("B1.07","Outbox: entries save locally first and send once when online","B1.06,B0.5"),
 ("B1.08","Analytics facade plus the first events (screen, action, error)",""),
 ("B1.09","Per-user cost view: join the agent traces per user and week","B0.7"),
 ("B1.10","Backend safe-door middleware for agent routes: auth, user from token, per-user rate and spend limits","B0.1"),
 ("B1.11","Account deletion: backend cascade through the backend, agent tables and storage","B1.10"),
 ("B1.12","Delete all my data (keep the account)","B1.11"),
 ("B1.13","Privacy manifest (PrivacyInfo.xcprivacy) and required-reason APIs",""),
])
SUB = ["icon well","hairline · full","hairline · inset after icon","red dot","glow stack (the lit object)","grain","progress hairline","knows-you track","spinner","the mark","status dot (connected, problem, syncing)","waveform bars","section label","artwork mesh","SF Symbol wrapper (size, weight, tint from tokens)","press style"]
add("3 · Sub-components (S)", [(f"S{n:02d}", s, "F05") for n, s in enumerate(SUB, 1)])
COMP = [
 ("button · lit","S05,S16"),("button · secondary","S16"),("button · text","S16"),("icon button (wash)","S01,S16"),("pill / chip","S16"),("tag",""),
 ("switch",""),("segmented",""),("settings row · value / nav","S02,S03"),("source row (connect → connected, reconnect, syncing)","S01,S11,S09"),
 ("text field",""),("search field",""),("composer","S12"),("voice composer","S12"),("talk button","S05"),("listening field (voice-level glow)","S05"),
 ("top bar (entry, settings, tab title)","S01"),("tab bar","S15"),("sheet and dialog",""),("menu / title menu",""),("toast (floats)",""),
 ("mini-player","S14,S07"),("player","S14"),("transport",""),("scrubber",""),
 ("brief card","S14"),("episode tile (scroll lag)","S14"),("guess card",""),("goal card",""),("message (yours, Retro's, streaming)",""),("entry row",""),("evidence row",""),("benefit row with tile",""),
 ("onboarding question (types out, haptic per word)",""),("onboarding progress","S07"),("knows-you meter","S08"),("paywall plan pair","S05"),
 ("you map: nodes, lines, life",""),("loading, empty, error, offline states (shared)","S09"),("lock screen and widget views","S14"),
]
add("4 · Components (C)", [(f"C{n:02d}", c + " — every state, light and dark, motion pass", d) for n,(c,d) in enumerate(COMP,1)])
PAGES = [("ON-1/2","splash and sign-in"),("ON-3–9","the questions"),("ON-5","privacy"),("ON-6","connect"),("ON-10","getting ready"),("ON-11","the tease"),("ON-12","paywall"),("ON-13","first home"),
 ("JR-1","journal"),("JR-2","today's brief"),("JR-3","all entries"),("JR-4","one entry"),("PC-1","podcasts"),("PC-2","player"),("PC-3","why this is here"),
 ("GL-1","goals"),("GL-2","one goal"),("YO-1","you"),("YO-2","search"),("YO-3","a source"),("YO-4","a node"),("YO-5","what I know"),
 ("ST-1","settings"),("ST-2","daily brief"),("ST-3","sources"),("ST-4","a source"),("ST-5","privacy"),("ST-6","how straight"),("ST-7","voice"),("ST-8","what I've learned"),("ST-9","account"),
 ("AC-1","sign in, returning"),("AC-2","signing out"),("EX-1","share"),("EX-2","lock screen / Live Activity"),("EX-3","notifications"),("EX-4","widgets")]
add("5 · Pages (P), built from components with sample data where needed", [(f"P{n:02d}", f"{c} · {t} — interaction sheet from Paper (arrive, leave, every touch, haptics, life, Reduce Motion); matches Paper (17 Pro, SE, light, dark); data contract written", "components") for n,(c,t) in enumerate(PAGES,1)])
add("6 · Backend capabilities per flow (B2–B8)", [
 ("B2.01","Google sign-in for the app (backend verify + app)","B1.04"),("B2.02","Door: onboarding interpret","B1.10"),("B2.03","Door: onboarding readiness and advance","B1.10"),
 ("B2.04","Structured onboarding answers (migration + write)","B2.02"),("B2.05","Knows-you endpoint (connected-source count for now)","B1.10"),
 ("B2.06","Notion connector (agent) + OAuth provider (backend)","B1.10"),("B2.07","Hide GitHub until its connector exists (flag)","F10"),
 ("B2.08","First episode as a background job (no 8-minute request)","B0.4"),("B2.09","APNs: device-token table and register endpoint","B1.10"),
 ("B2.10","APNs sender + 'episode ready' push","B2.09,B2.08"),("B2.11","StoreKit 2 products: $24.99/mo, $239.99/yr","" ),
 ("B2.12","App: purchase and restore (still fail-closed until validated)","B2.11"),("B2.13","Backend: transaction validation + entitlement table","B2.12"),
 ("B3.01","Door: conversation (send, today)","B1.10"),("B3.02","Streaming replies (server-sent events) backend","B3.01"),("B3.03","Streaming client","B3.02,B1.01"),
 ("B3.04","Doors: today's brief and brief history","B1.10"),("B3.05","Door: hypotheses / guess cards","B1.10"),("B3.06","Entry history endpoint","B1.10"),
 ("B3.07","Door: what Retro took from an entry (lineage)","B1.10"),("B3.08","Door: corrections ('not right')","B1.10"),
 ("B4.01","Weekly episode push","B2.10"),("B4.02","Door: why this is here (evidence)","B1.10"),("B4.03","Door: episode feedback","B1.10"),
 ("B5.01","Door: goal evidence","B1.10"),("B5.02","Goal check-in push","B2.10"),
 ("B6.01","Door: people","B1.10"),("B6.02","Door: portrait","B1.10"),("B6.03","Door: facts by area with sureness","B1.10"),("B6.04","Door: search answer","B1.10"),("B6.05","Door: search sources","B6.04"),
 ("B7.01","Doors: settings and preferences (ambient, how straight, voice speed and mode)","B1.10"),("B7.02","Brief time per user (replace the fixed 08:00 UTC cron)","B3.04"),
 ("B7.03","Server data export","B1.10"),("B7.04","Manage subscription link + renewal date","B2.13"),
 ("B8.01","Widget extension: episode and brief widgets (replace the template)","B1.06"),("B8.02","Lock screen widget","B8.01"),("B8.03","Share extension","B1.07"),("B8.04","Notification categories and deep-link router","B2.10"),
])
FLOWS = [("first run","ON-*","B2.*","#2 #3 #4 #7 #13"),("daily loop","JR-*","B3.*","#8"),("podcasts","PC-*","B4.*","#6 #9 #10"),("goals","GL-*","B5.*","#11"),("you","YO-*","B6.*","#12"),("settings and account","ST-*, AC-*","B7.*",""),("outside the app","EX-*","B8.*","")]
rows=[]
for n,(f,p,b,m) in enumerate(FLOWS,1):
    rows += [(f"W{n}", f"Wire {f}: swap sample data for live; ledger for {f} at zero", f"{p}, {b}"),
             (f"L{n}", f"Flow pass {f}: navigation, transitions, signature moments {m}".strip(), f"W{n}"),
             (f"G{n}", f"Ship gate {f}: TestFlight real account, cost logged, errors and offline, App Store rules, your sign-off → switch on, old screens deleted", f"L{n}")]
add("7 · Wiring, flows and ship gates (W, L, G)", rows)
add("9 · Retire the old (X): nothing old left half-alive", [
 ("X01","Inventory every old screen, service, route and table with its replacement and retirement trigger (plan §6b), kept current",""),
 ("X02","Version floor: minimum supported app version + force-update screen (app) and version header (backend)","B1.01"),
 ("X03","Remove experiments with no new design: video journal, Polaroid, iMessage onboarding, the extra Home variants","G1"),
 ("X04","Remove the old design system (button styles, stray font helpers, ad-hoc colours) after the last old screen","G6"),
 ("X05","Remove ClaudeService, AIServiceManager and TTS fallbacks once every caller uses backend doors","G2"),
 ("X06","One-time migration of each person's local entries and goals into SwiftData (checksum, keep the old files until confirmed), then delete the old storage","B1.06"),
 ("X07","Remove old backend routes (/claude/generate, /pipeline/*, /goals/extract*, sync podcast generate) after 14 days of no calls from supported versions","X02,G7"),
 ("X08","Agent: retire legacy observations / insights tables after a backup","X07"),
 ("X09","Final sweep: unused files, assets and dependencies removed; the app is only the new code","X03,X04,X05,X06,X07"),
])
add("8 · Signature moments (M), each with its motion visual pass", [(f"M{n:02d}", d, "") for n,d in enumerate([
 "orb breathes, satellites drift (splash)","listening glow follows your voice","answer word ink-sharpens","+ connect → connected, meter fills (and the 'knows you well' pop)","getting ready honest steps","player shrinks into mini-player, paywall rises","plan glow slides, save 20% rolls","your bubble lifts, reply sharpens line by line","play morph, rolling time, chapter ticks","tiles lag the scroll","goal card folds, bar eases","new fact blooms into the map","questions type out with a soft tick per word"],1)])

done = sum(1 for t in T if t[4]=="done"); doing=sum(1 for t in T if t[4]=="doing")
out=["# M14 progress map · every byte, smallest to largest","",
"**Bottom line:** M14 is a finite pool of **%d bytes**. Each byte is one small PR (or one founder action). Status: **%d done · %d doing · %d to do**. It's built bottom-up: platform baseline → foundation → sub-components → components → pages → backend per flow → wiring → flow pass → ship gate. The log of every merged PR is in `swift-implementation-plan.md` §10." % (len(T),done,doing,len(T)-done-doing),
"","Repo key: **app** = `Retrospect/` and **backend** = `backend/` in `hankHillsleftnut/NPRdoinglaundry` (local `retrospect-main`); **agent** = `hankHillsleftnut/Retrospect-agent` (local `retrospect-agent`); **paper** = the Paper master file. Never commit to `RETROSPECT_BACKUP_2026-05-28`.","","Regenerate this file with `python3 docs/design/tools/progress_map.py` after changing a status there. Status: todo · doing · review · done · blocked (with the reason).",""]
layer=None
for i,l,b,n,s,pr,rp in T:
    if l!=layer:
        ls=[t for t in T if t[1]==l]; d=sum(1 for t in ls if t[4]=="done")
        out+=["",f"## {l} · {d}/{len(ls)} done","","| ID | Byte | Repo | Needs | Status | PR |","|---|---|---|---|---|---|"]; layer=l
    out.append(f"| {i} | {b} | {rp} | {n} | {s} | {pr} |")
open("docs/design/m14-progress-map.md","w").write("\n".join(out)+"\n")
print(len(T), done, doing)
