# Splash D ("the dots connect") in motion, from components exported out of Paper (page 06, board KUC; the map,
# words and sign-in reuse splash-a/ exports of part 43 A).
# Founder 20 Oct: "refine this", "more natural motion", then "it's unclear how the tags become the constellation".
# So each tag now travels to its own place on the map and turns into that node (the pill fades as the orb lands,
# then the orb takes its name): walk by the river → the river, 9am standup → work, ran 5k → running,
# coffee with maya → maya; the two feelings ("slept badly", "felt sharp") become small stars between them.
# Run from this folder: python3 build_splash_d.py → splash-d.html (images inlined so it renders in the side panel).
import base64

def b64(p):
    return 'data:image/png;base64,' + base64.b64encode(open(p, 'rb').read()).decode()

D, A = 'splash-d', 'splash-a'
MAP_TOP = 20
# chip file, left, top, width, arrival delay, what it becomes: (kind, index into the map lists)
CHIPS = [
    ('c-voice', 206, 430, 167, 0.10, ('person', 2)), ('c-standup', 22, 500, 148, 0.30, ('person', 3)),
    ('c-slept', 30, 104, 109, 0.20, ('dot', 1)), ('c-ran', 268, 118, 99, 0.45, ('person', 1)),
    ('c-sharp', 18, 330, 149, 0.38, ('dot', 3)), ('c-mum', 236, 600, 134, 0.55, ('person', 0)),
]
PEOPLE = [(93, 112, 'l-maya', 100, 86, 36), (243, 99, 'l-running', 293, 113, 47),
          (253, 204, 'l-river', 303, 218, 50), (103, 217, 'l-work', 110, 266, 34)]  # map coords
DOTS = [(158, 14), (341, 143), (239, 318), (131, 318), (37, 116)]
YOU_AT = 1.15     # you form at the centre of the (not yet drawn) map
TRAVEL = 2.15     # tags start for their places
STEP = 0.07
FLY = 1.0
PART = 0   # the tags drift down to make room as you form

chips, landed, labels, dots = [], {}, [], []
for i, (f, x, y, w, d, (kind, k)) in enumerate(CHIPS):
    if kind == 'person':
        px, py = PEOPLE[k][0] + 22, PEOPLE[k][1] + 22 + MAP_TOP
    else:
        px, py = DOTS[k][0] + 10, DOTS[k][1] + 10 + MAP_TOP
    start = TRAVEL + i * STEP
    chips.append(f'<div class="chip" style="left:{x}px;top:{y}px;width:{w}px;--d:{d}s;--t:{start:.2f}s;'
                 f'--dx:{px - (x + w / 2):.0f}px;--dy:{py - (y + 16) - PART:.0f}px;--fl:{2.4 + i * 0.41:.2f}s">'
                 f'<div class="part{" far" if i in (1, 3, 5) else ""}"><img src="{b64(f"{D}/{f}.png")}" style="width:{w}px"></div></div>')
    landed[(kind, k)] = start + FLY * 0.62

people = []
for k, (x, y, lab, lx, ly, lw) in enumerate(PEOPLE):
    t = landed[('person', k)]
    people.append(f'<img class="person" src="{b64(f"{A}/person{k + 1}.png")}" style="left:{x}px;top:{y}px;animation-delay:{t:.2f}s">')
    labels.append(f'<img class="lab" src="{b64(f"{A}/{lab}.png")}" style="left:{lx}px;top:{ly}px;width:{lw}px;animation-delay:{t + .25:.2f}s">')
for k, (x, y) in enumerate(DOTS):
    t = landed.get(('dot', k), TRAVEL + 0.75 + k * 0.05)
    dots.append(f'<img class="dot" src="{b64(f"{A}/dot{k + 1}.png")}" style="left:{x}px;top:{y}px;animation-delay:{t:.2f}s">')

END = max(landed.values())
html = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Splash D in motion</title>
<style>
:root{{--canvas:#F4F2EE;--label:#696765;--ink:#121212;--std:cubic-bezier(.16,1,.3,1);--spring:cubic-bezier(.34,1.32,.5,1)}}
*{{box-sizing:border-box}}body{{margin:0;background:#EDEAE4;font-family:"Geist",-apple-system,system-ui,sans-serif;color:var(--ink);-webkit-font-smoothing:antialiased;display:flex;flex-direction:column;align-items:center;gap:20px;padding:36px 16px 60px}}
.cap{{max-width:440px;font-size:13px;line-height:1.5;color:var(--label);text-align:center}}
button{{font:500 13px "Geist",system-ui;border:0;border-radius:999px;padding:8px 16px;background:rgba(40,36,30,.07);cursor:pointer}}
.device{{width:402px;height:874px;border-radius:56px;position:relative;box-shadow:0 0 0 10px #1c1b19,0 0 0 11px #3a3834,0 40px 80px -30px rgba(40,30,20,.45);overflow:hidden;transform:scale(.82);transform-origin:top center;margin-bottom:-157px}}
.screen{{position:absolute;inset:0;background-color:var(--canvas);background-image:radial-gradient(65% 34% at 90% 0%,rgba(255,200,92,.34) 0%,transparent 100%),radial-gradient(70% 38% at 0% 18%,rgba(179,225,255,.36) 0%,transparent 100%),radial-gradient(60% 26% at 50% 34%,rgba(217,240,255,.40) 0%,transparent 100%)}}
.wall{{position:absolute;inset:-6%;background:inherit;animation:wallIn 1.2s var(--std) both,drift 16s ease-in-out 1.2s infinite alternate}}
@keyframes wallIn{{from{{opacity:0}}}}@keyframes drift{{to{{transform:translate(-2%,1.5%) scale(1.03)}}}}
/* 1 · pieces of a week arrive on springs and float while they wait */
.chip{{position:absolute;z-index:3;animation:chipIn .9s var(--spring) var(--d) both,travel {FLY}s var(--std) var(--t) forwards}}
.part{{animation:part .9s var(--std) {YOU_AT - .35:.2f}s forwards}}
.far{{opacity:.4;filter:blur(2px);animation:focus .6s var(--std) {YOU_AT + .7:.2f}s forwards}}
@keyframes focus{{to{{opacity:1;filter:none}}}}
@keyframes part{{to{{transform:translateY({PART}px)}}}}
.chip img{{display:block;animation:float var(--fl) ease-in-out calc(var(--d) + .9s) infinite alternate}}
@keyframes chipIn{{from{{opacity:0;transform:translateY(12px) scale(.94);filter:blur(6px)}}}}
@keyframes float{{0%{{transform:translate(0,0)}}50%{{transform:translate(3px,-4px)}}100%{{transform:translate(-3px,-2px)}}}}
/* 4 · each tag flies to its own place on the map and becomes that node: the pill shrinks and fades as the orb lands */
@keyframes travel{{55%{{opacity:1;filter:none}}100%{{transform:translate(var(--dx),var(--dy)) scale(.32);opacity:0;filter:blur(2px)}}}}
/* 2 · threads grow out from the first voice note while the last pieces land */
.threads{{position:absolute;left:0;top:0;width:402px;height:874px;animation:grow 1s var(--std) {YOU_AT + .3:.2f}s both,fade .6s ease-in {TRAVEL + .35:.2f}s forwards}}
@keyframes grow{{from{{clip-path:circle(0px at 195px 200px);opacity:.4}}to{{clip-path:circle(470px at 195px 200px);opacity:1}}}}
@keyframes fade{{to{{opacity:0}}}}
/* 3 · you form where the centre of your map will be; one sentence says what it sees */
.absorb{{position:absolute;left:195px;top:{180 + MAP_TOP}px;width:0;height:0;border-radius:50%;border:1px solid rgba(127,205,255,.7);animation:ripple 1.3s var(--std) {YOU_AT + .15:.2f}s both}}
@keyframes ripple{{0%{{opacity:0}}15%{{opacity:1}}100%{{width:240px;height:240px;margin:-120px 0 0 -120px;opacity:0}}}}
.sentence{{position:absolute;left:24px;top:610px;width:354px;animation:textIn .7s var(--std) {YOU_AT + .3:.2f}s both,textOut .5s ease-in {END + .35:.2f}s forwards}}
.source{{position:absolute;left:24px;top:656px;width:354px;animation:textIn .7s var(--std) {YOU_AT + .45:.2f}s both,textOut .45s ease-in {END + .3:.2f}s forwards}}
@keyframes textIn{{from{{opacity:0;transform:translateY(8px);filter:blur(6px)}}}}
@keyframes textOut{{to{{opacity:0;transform:translateY(-10px);filter:blur(4px)}}}}
.map{{position:absolute;left:0;top:{MAP_TOP}px;width:402px;height:380px;animation:breathe 8s ease-in-out {END + 2:.2f}s infinite alternate}}
@keyframes breathe{{to{{transform:translateY(-3px) scale(1.008)}}}}
.map img{{position:absolute}}
.you{{left:163px;top:148px;width:64px;height:64px;border-radius:50%;z-index:2;animation:youIn .9s var(--spring) {YOU_AT}s both}}
@keyframes youIn{{from{{opacity:0;transform:scale(.25);filter:blur(6px)}}}}
.rings{{left:0;top:0;width:390px;height:360px;transform-origin:195px 180px;animation:rings 1.1s var(--std) {TRAVEL + .1:.2f}s both}}
@keyframes rings{{from{{opacity:0;transform:scale(.55)}}}}
.lines{{left:0;top:0;width:390px;height:360px;animation:lines 1.1s var(--std) {TRAVEL + .25:.2f}s both}}
@keyframes lines{{from{{clip-path:circle(0px at 195px 180px)}}to{{clip-path:circle(240px at 195px 180px)}}}}
.dot{{width:20px;height:20px;animation:land .6s var(--spring) both}}
.person{{width:44px;height:44px;border-radius:50%;animation:land .7s var(--spring) both}}
@keyframes land{{from{{opacity:0;transform:scale(.45)}}}}
.lab{{animation:lab .5s var(--std) both}}@keyframes lab{{from{{opacity:0;transform:translateY(4px)}}}}
.words{{position:absolute;left:0;top:400px;width:402px;animation:rise .8s var(--std) {END + .55:.2f}s both}}
.signin{{position:absolute;left:0;top:674px;width:402px;animation:rise .8s var(--std) {END + .72:.2f}s both}}
@keyframes rise{{from{{opacity:0;transform:translateY(16px)}}}}
.status{{position:absolute;left:0;top:0;width:402px;z-index:5}}
@media (prefers-reduced-motion:reduce){{*{{animation-duration:.14s!important;animation-delay:0s!important;animation-iteration-count:1!important}}}}
</style></head><body>
<div class="device" id="dev"><div class="screen"><div class="wall"></div>
<img class="threads" src="{b64(f"{D}/threads.png")}">
<div class="map"><img class="rings" src="{b64(f"{A}/rings.png")}"><img class="lines" src="{b64(f"{A}/lines.png")}">
{"".join(dots)}{"".join(people)}<img class="you" src="{b64(f"{A}/you.png")}">{"".join(labels)}</div>
<span class="absorb"></span>

{"".join(chips)}
<img class="words" src="{b64(f"{A}/words.png")}"><img class="signin" src="{b64(f"{A}/signin.png")}"><img class="status" src="{b64(f"{A}/status.png")}"></div></div>
<button id="r">replay</button>
<p class="cap">splash D, built from the real Paper components. life without a through line: moments of your week drift in, unconnected. then retrospect arrives at the centre, threads reach out from it to everything, and each moment is pulled along its thread into its place on your map: the river, work, running, maya, and how you felt as the small stars. then the promise.</p>
<script>document.getElementById('r').onclick=()=>{{const d=document.getElementById('dev');d.replaceWith(d.cloneNode(true))}};</script>
</body></html>'''
open('splash-d.html', 'w').write(html)
print('splash-d.html', len(html) // 1024, 'KB; ends ~', round(END + 1.35, 1), 's')
