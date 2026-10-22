import json
def tree(spec):
    out=[]
    def walk(items,parent,depth):
        for it in items:
            id_,title,plain,*rest=it
            kids=rest[0] if rest else []
            out.append({"id":id_,"parent":parent,"title":title,"plain":plain})
            walk(kids,id_,depth+1)
    walk(spec,None,0); return out

app=[
 ("A0","Foundations","The base everything else in the app sits on",[
  ("A0.tests","Tests and testing tools","So every change proves itself",[
   ("PL0.1","Tests that actually run","CI runs the app's tests on every PR"),
   ("PL0.4","Pinned packages","Same library versions on every build"),
   ("T02a","Launch options","Open the app on sample or live data, any account"),
   ("T02","Screen launcher","Open any screen in any state for screenshots"),
  ]),
  ("A0.platform","The Platform layer","One home for networking, sign-in and storage",[
   ("PL0.2","Platform folder and logging","Where the new plumbing lives; logs with no personal text"),
   ("PL0.3","Wiring it together","One place the app's services are built and handed out"),
   ("PL5.2","The router","Every way into the app, one list"),
   ("PL7.1","Privacy manifest","What Apple checks on upload"),
  ]),
  ("A0.client","Talking to the server","Typed, retried, never logs you out by mistake",[
   ("PL1.1a","Client: types and envelope","The shapes of every request and reply"),
   ("PL1.1b","Client: the sender","Sends requests with the right headers"),
   ("PL1.2","Retries and timeouts","Survives bad signal"),
   ("PL1.3","Session store","Keeps you signed in, even while the phone is locked"),
   ("PL1.4","Sign in with Apple","The new sign-in, old screens stay signed in"),
   ("PL1.5","Silent refresh and sign-out","No surprise logouts"),
  ]),
  ("A0.store","Never lose an entry","Saved on the phone first, sent exactly once",[
   ("PL2.0","GRDB spike","Prove the local database works"),
   ("PL2.1","Local database","Entries, the outbox and cached reads"),
   ("PL2.2a","Outbox: the queue","Write and queue in one step"),
   ("PL2.2b","Outbox: the sender","Sends on launch, on return, in the background"),
   ("PL2.3","Old screens use the outbox","Entries from today's screens can't be lost either"),
  ]),
  ("A0.shared","Shared components","Built once, used across the journal",[
   ("UI0.1","Edge blur","The soft blur under the tab bar"),
   ("C39","Loading, empty, error, offline","The four states every screen shares",[
    ("C39.1","Skeleton shimmer",""),("C39.2","Empty line",""),("C39.3","Error and try again",""),("C39.4","Offline line",""),
   ]),
   ("C19","Sheet and dialog","The slide-up sheet and the confirm dialog",[
    ("C19.1","Sheet host","Drag, snap, the page behind"),("C19.2","Dialog","Confirm and destructive choices"),
   ]),
   ("C20","Menu","Long-press menus"),
   ("C32","Evidence row","Where something came from"),
  ]),
 ]),
 ("A1","Journal","The core: send things in, hear your brief, answer guesses",[
  ("A1.data","Journal data","Sample data first, then the real thing",[
   ("UI1.0","Sample journal data","Lets screens be built before the server is ready"),
   ("PL3.1a","Live: send and today","Real sending and today's messages"),
   ("PL3.1b","Live: brief and audio","Real brief with audio"),
   ("PL3.1c","Live: guesses","Real guesses and answers"),
   ("PL3.1d","Live: entries","Real history"),
   ("PLP.1a","Live audio player","Plays real audio: interruptions, headphones, lock screen"),
   ("PLP.1b","One player at a time","The new brief player and old podcasts never play together"),
  ]),
  ("P09","Page: the journal (JR-1)","Where you send things in",[
   ("C17","Top bar","Title that shrinks as you scroll"),
   ("C18","Tab bar","Journal, podcasts, goals, you"),
   ("C26","Brief card","Today's brief at the top",[
    ("C26.1","Card and its states","rest, playing, played, waiting, error, offline"),("C26.2","Getting ready row","While the brief is being made"),("C26.3","Slim bar","When you scroll past it"),
   ]),
   ("C30","Messages","Your messages and Retro's replies",[
    ("C30.1","Your message","sending, waiting, not sent"),("C30.2","Retro's acknowledgement","the short canned reply"),("C30.3","Voice note","waveform bubble"),
   ]),
   ("C28","Guess card","Retro asks, you answer"),
   ("P09.page","Journal page assembled","All the parts on one screen, on sample data"),
  ]),
  ("P10","Page: today's brief (JR-2)","The brief player",[
   ("UI3.0","Sample playback","Audio player on sample data"),
   ("C25","Scrubber","Parts and position"),
   ("C24","Play controls","Play, pause, skip"),
   ("C23b","Player sheet","The full player"),
   ("C22","Mini-player","Keeps playing while you move around"),
   ("P10.page","Brief page assembled",""),
  ]),
  ("P11","Page: all entries (JR-3)","Everything you've sent",[
   ("C31","Entry row",""),("UI1.1","Drawer","Slides in with your history"),("P11.page","Entries page assembled",""),
  ]),
  ("P12","Page: one entry (JR-4)","One entry in full",[
   ("P12.page","Entry page assembled","'What Retro took' waits until after Beta 1"),
  ]),
  ("T04","Journal flow test","Send, go offline, come back: everything arrives once"),
 ]),
 ("A3","Send a report","Testers send us how the app behaved, no personal content",[
  ("DG.3","Session recorder","On-phone log of what the app did, ids and numbers only"),
  ("DG.4","Instrumentation","Network, outbox, errors, crashes, performance"),
  ("DG.5","Report builder","Bundles the report, sends it safely"),
  ("DG.6","Send a report sheet","Settings row, shake to report, sent with a reference"),
 ]),
 ("A2","Getting in","Invite link, sign in, you're in",[
  ("PL1.7a","Access check and redeem","The app knows if you're let in"),
  ("PL1.7b","Invite link auto-applies","Tap the link, sign in, done"),
  ("PI1","Invite gate screen","Type a code or join the waitlist"),
  ("PI2","You're in (M14)","The celebration moment"),
 ]),
]
backend=[
 ("B0","Foundations","The safe, testable base for every new route",[
  ("BE0.S","Local staging","The backend and brain on the Mac, on a test database"),
  ("BE0.0","Runtime hygiene","Fixes the server's known rough edges"),
  ("BE0.1","Door kit","Every route checks who you are and what you own",[
   ("BE0.1a","Kit",""),("BE0.1b","Limits",""),("BE0.1c","Logs with no personal text",""),
  ]),
  ("BE0.2","Test harness","Every route tested over HTTP"),
  ("BE0.3","Error-leak cleanup","Errors never expose internals"),
 ]),
 ("B1","Staying signed in","Short logins that refresh silently",[
  ("BE0.4a","Session tables and issuing",""),("BE0.4b","Refresh and rotation",""),("BE0.4c","New sign-in route",""),
 ]),
 ("B2","Invites","Waitlist, your approvals, three links each",[
  ("BE0.12a","Tables and the gate",""),("BE0.12b","Redeem and links",""),("BE0.12c","Your approval tool",""),
 ]),
 ("B3","Brain safety","Fixes in the brain before people use it",[
  ("BEA.1","Corrections work in production",""),
  ("BEA.2","No one can reach another's data",""),
  ("BEA.4","Every AI call counted against the cap",""),
  ("BEA.7","Private audio links",""),
  ("BEA.8","Quiet weeks aren't errors",""),
 ]),
 ("B5","Diagnostics","Receives and stores 'send a report'",[
  ("DG.1","Report door","Strict, private, kept 30 days"),
  ("DG.2","Report viewer","Admin view for debugging"),
 ]),
 ("B4","Journal routes","What the journal screens talk to",[
  ("BE1.1","Send into your bank","Entries saved exactly once"),
  ("BE1.5","Entry history",""),
  ("BE1.3","Today's brief",""),
  ("BE1.3b","Brief audio","Briefs become audio",[("BE1.3b-1","Brain: make and store audio",""),("BE1.3b-2","Route: audio in the reply","")]),
  ("BE1.4","Guesses","List and answer guesses"),
 ]),
]
for name,spec in (("app",app),("backend",backend)):
    nodes=tree(spec)
    ids=[n["id"] for n in nodes]; assert len(ids)==len(set(ids)),name
    json.dump({"nodes":nodes},open(f"plan-{name}.json","w"),indent=1)
    leaves=[n for n in nodes if not any(m["parent"]==n["id"] for m in nodes)]
    print(name,len(nodes),"nodes",len(leaves),"PRs")
