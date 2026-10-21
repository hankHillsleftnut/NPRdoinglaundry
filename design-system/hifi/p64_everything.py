# 06 · everything · latest: every screen's current version in one place, by area in order of use.
# Each column names its status and where it was copied from, so the snapshot stays traceable.
import json, sys
L = "font-family:var(--font-label);font-size:var(--text-sm);line-height:var(--leading-snug)"
ROWS = [
 ('onboarding', [('ON-1/2','splash + sign-in','approve?','approvals · part 43','GHS'),('ON-3–9','the questions','approved','05','MFT'),('ON-5','privacy','approved','05','MIB'),('ON-6','connect','approve?','approvals · ON-6','V72'),('ON-10','getting ready','approve?','approvals · M6 end','O4L'),('ON-11','the tease','approve?','approvals · M6 end','O5R'),('ON-12','paywall · A','approve?','approvals · decision 06','IGD'),('ON-13','first home','approve?','approvals · M6 end','O7W')]),
 ('journal', [('JR-1','journal','approved','05','MJK'),('JR-2',"today's brief",'approved','approvals · JR-2','FKY'),('JR-3','all entries','approved','05','MW6'),('JR-4','one entry','approved','05','N51')]),
 ('podcasts', [('PC-1','podcasts','approved','approvals · PC-1','HKC'),('PC-2','the player','approved','approvals · PC-2','H3P'),('PC-3','why this is here','approved','05','NDK')]),
 ('goals', [('GL-1','goals','approved','approvals · GL-1','J17'),('GL-2','one goal','approve?','approvals · GL-2','JQC')]),
 ('you', [('YO-1','you','approve?','approvals · YO-1','K2U'),('YO-2','search','approved','approvals · YO-2','KGY'),('YO-3','a source','approved','approvals · YO-3','L9O'),('YO-4','a node','approved','approvals · YO-4','KX2'),('YO-5','what i know','approved','approvals · YO-5','LBZ')]),
 ('settings and account', [('ST-1','settings','approved','05','NFS'),('ST-2','daily brief','approved','05','NJ2'),('ST-3','sources','approved','05','NKP'),('ST-4','a source','approved','05','NND'),('ST-5','privacy','approved','05','NOO'),('ST-6','how straight','approved','05','NQ4'),('ST-7','voice','approved','05','NRL'),('ST-8',"what i've learned",'approved','05','NSY'),('ST-9','account','approved','05','NTN'),('AC-2','signing out','approve?','approvals · M6 end','O9K'),('AC-1','sign in, returning','approve?','approvals · AC-1','IM9')]),
 ('outside the app', [('EX-1','share','approved','approvals · EX','M6W'),('EX-2','lock screen','approved','approvals · EX','M9V'),('EX-3','notifications','approved','approvals · EX','M7R'),('EX-4','widgets','approved','approvals · EX','M8Q')]),
]
def chip(s):
    if s == 'approved':
        return f'<div style="{L};font-weight:var(--font-weight-medium);color:var(--color-status-success)">approved</div>'
    return f'<div style="display:flex;align-items:center;gap:var(--spacing-1)"><div style="width:var(--spacing-2);height:var(--spacing-2);border-radius:var(--radius-control);background:var(--color-status-danger)"></div><div style="{L};font-weight:var(--font-weight-medium);color:var(--color-status-danger-text)">waiting on you</div></div>'
parts, slots = [], []
for area, cols in ROWS:
    c = ''.join(
        f'<div layer-name="col · {code}" style="display:flex;flex-direction:column;gap:var(--spacing-2);width:402px;flex-shrink:0">'
        f'<div style="{L};font-weight:var(--font-weight-medium);color:var(--color-text-primary)">{code} · {name}</div>'
        f'<div style="display:flex;justify-content:space-between;align-items:center">{chip(st)}<div style="{L};color:var(--color-text-label)">from {src}</div></div>'
        f'<div layer-name="slot · {code}" style="width:402px;height:874px;flex-shrink:0"></div></div>'
        for code, name, st, src, nid in cols)
    slots += [(code, nid) for code, _, _, _, nid in cols]
    parts.append(f'<div layer-name="area · {area}" style="display:flex;flex-direction:column;gap:var(--spacing-4)"><div style="font-family:var(--font-display);font-size:var(--text-2xl);letter-spacing:var(--tracking-title);line-height:var(--leading-tight);color:var(--color-text-primary)">{area}</div><div style="display:flex;gap:var(--spacing-8);align-items:flex-start">{c}</div></div>')
json.dump({'rows': parts, 'slots': slots}, open(sys.argv[1], 'w'))
