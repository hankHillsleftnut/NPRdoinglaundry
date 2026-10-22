import json
def flat(spec,parent=None,out=None):
    out=[] if out is None else out
    for it in spec:
        id_,title,plain,*rest=it
        out.append({"id":id_,"parent":parent,"title":title,"plain":plain,"later":True})
        if rest: flat(rest[0],id_,out)
    return out
app_later=[
 ("L.first","Later · First run","New onboarding for new people (the current one works for Beta 1)",[
  ("P01","Splash and sign-in (ON-1/2)","Includes Google sign-in"),
  ("P02","The questions (ON-3–9)",""),("P03","Privacy (ON-5)",""),("P04","Connect your sources (ON-6)",""),
  ("P05","Getting ready (ON-10)",""),("P06","The first-episode tease (ON-11)",""),("P07","Paywall (ON-12)","With RevenueCat"),
  ("P08","First home (ON-13)",""),("P32","Returning sign-in (AC-1)",""),("PX","Force-update screen",""),
  ("PL6","Payments in the app","RevenueCat, one source of entitlement"),("PL5.1","Push notifications",""),
 ]),
 ("L.pod","Later · Podcasts","Weekly episodes in the new design",[
  ("P13","Podcasts tab (PC-1)",""),("P14","Episode player (PC-2)",""),("P15","Where Retro says it (PC-3)",""),("PL3.4","Podcasts on live data",""),
 ]),
 ("L.goals","Later · Goals","",[("P16","Goals tab (GL-1)",""),("P17","One goal (GL-2)",""),("PL3.5","Goals on live data","")]),
 ("L.you","Later · You","Your map and search",[
  ("P18","You tab (YO-1)",""),("P19","Search answer (YO-2)",""),("P20","Entry from search (YO-3)",""),("P21","A person or theme (YO-4)",""),("P22","Answers (YO-5)",""),("PL3.6","You on live data",""),
 ]),
 ("L.settings","Later · Settings and account","",[
  ("P23","Settings pages (ST-1…9)","Nine pages"),("P33","Signing out (AC-2)",""),("PI3","Your invites","Your three links"),("PL3.7","Settings on live data",""),
 ]),
 ("L.outside","Later · Outside the app","",[
  ("P34","Share extension",""),("P35","Lock screen and Now Playing",""),("P36","Notifications",""),("P37","Widgets",""),
 ]),
 ("L.moments","Later · Signature moments","M01–M13, each with its page",[]),
 ("L.retire","Later · Retire the old app","Old screens and data removed flow by flow",[]),
]
be_later=[
 ("LB.store","Later · Before the App Store","Required before a public release",[
  ("BE0.5","Apple sign-in revoke",""),("BE0.6","Delete everything (brain)",""),("BE0.7","Account deletion route",""),
  ("BE0.8","Delete my data, keep my account",""),("BE0.13","Apple sign-in notifications",""),("BE2.4","Google sign-in",""),
  ("BE2.8","Payments: RevenueCat mirror",""),("BE0.9","Shared limiter",""),("BE0.10","Minimum app version",""),("BE0.11","Cost per user, measured",""),
 ]),
 ("LB.journal2","Later · Journal, round two","",[
  ("BE1.5b","Edit and delete an entry",""),("BE1.6","What Retro took",""),("BE1.7","\"Not right\"",""),("BEA.3","Preferences merge",""),("BEA.5","One first pass at a time",""),("BEA.6","Bad JSON is a 400",""),
 ]),
 ("LB.first","Later · First run","",[("BE2.5","The first-episode job",""),("BE2.7","Push notifications",""),("BE2.9","Notion connector","")]),
 ("LB.flows","Later · Podcasts, goals, you, settings","The routes each new flow needs",[
  ("BE3.0","Episode chapters",""),("BE3.x","Podcasts routes",""),("BE4.x","Goals routes",""),("BE5.x","You and search routes",""),("BE6.x","Settings routes, export",""),
 ]),
]
for eng,spec in (("app",app_later),("backend",be_later)):
    plan=json.load(open(f"plan-{eng}.json"))
    plan["nodes"]=[n for n in plan["nodes"] if not n.get("later")]+flat(spec)
    json.dump(plan,open(f"plan-{eng}.json","w"),indent=1)
    nodes=plan["nodes"]
    leaves=[n["id"] for n in nodes if n.get("later") and not any(m["parent"]==n["id"] for m in nodes)]
    k=lambda s:"".join(c if c.isalnum() else "_" for c in s)
    json.dump({"items":{k(i):{"s":"later"} for i in leaves}},open(f"later-{eng}.json","w"))
    print(eng,len(nodes),"nodes,",len(leaves),"later")
