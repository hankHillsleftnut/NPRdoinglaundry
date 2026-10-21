from review import *
# Settings in the app (founder c-tfhjt3 on part 22, c-fits17 on part 21: "what is this"): the settings page at 390×844, built from the
# part 21 section label, the part 22 row and the part 26 controls, so each part is seen where it lives.
import importlib.util, json
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
s, t, l = load('p26_settings_rows'), load('p06_topbar'), load('p21_labels')
CHEV = json.load(open('../icons/outlined-20.json'))['chevron-right']
back = (f'<div style="width:44px;height:44px;flex-shrink:0;display:flex;align-items:center;justify-content:center">'
        f'<div layer-name="c:icon-button/wash/rest" style="width:36px;height:36px;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">'
        f'<svg layer-name="c:icon/chevron-left" width="20" height="20" viewBox="0 0 24 24"><g transform="translate(24 0) scale(-1 1)"><path fill="{C("icon-default")}" fill-rule="evenodd" d="{CHEV}"/></g></svg></div></div>')
title = (f'<div style="flex:1;display:flex;justify-content:center;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};'
         f'letter-spacing:{V("tracking-label")};color:{C("text-secondary")}">settings</div>')
BAR = t.bar(back + title + t.SPACER, 'settings')
def group(label, *rows):
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")}"><div style="padding:0 {V("spacing-screen-margin")}">{l.lab("section", label)}</div>'
            + s.stack(*rows) + '</div>')
chev = s.glyph('chevron-right', 16, C('icon-muted'))
val = lambda v: f'<div style="display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">' + s.txt(v, 'text-md', 'text-secondary') + chev + '</div>'
BODY = (group('retro', s.row('value', s.words('voice', 'how retro sounds when it reads to you') + val('warm')), s.hairline(),
              s.row('switch', s.words('autoplay the next episode', 'when the current one ends') + s.switch(True)))
        + group('what retro can see', s.row('source', s.well('calendar') + s.words('calendar', 'so your brief knows your day') + s.status('connected', 'source-connected')), s.hairline(True),
                s.row('source', s.well('mic') + s.words('voice notes', 'in your own words') + s.raised_pill('connect', 'add')))
        + group('your data', s.row('value', s.words('export your journal', 'everything you wrote, as text') + chev), s.hairline(),
                s.row('leaves-app', s.words('privacy policy', 'opens in safari') + s.glyph('external', 16, C('icon-muted'))))
        + s.stack(s.row('danger', s.dwell() + s.words('delete my account', 'removes everything, after a confirmation', 'status-danger-text'))))
PHONE = (f'<div layer-name="phone · settings" style="width:390px;height:844px;flex-shrink:0;overflow:clip;display:flex;flex-direction:column;'
         f'background:{C("background-canvas")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">'
         + t.STATUS + BAR + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-8")};padding-top:{V("spacing-4")}">' + BODY + '</div></div>')
CAP = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")};width:390px">'
       f'<div style="font-family:{V("font-label")};font-size:{V("text-sm")};font-weight:{V("font-weight-medium")};color:{C("text-primary")}">in the app, 1× · the settings page</div>'
       f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-snug")};color:{C("text-secondary")}">'
       'the grey words ("retro", "what retro can see", "your data") are the part 21 labels: they name a group. each line under them is a part 22 row: '
       'one thing you can open or change, with its control on the right (part 26). the thin lines between rows are the hairlines.</div></div>')
HTML = f'<div layer-name="part 22 · in the app" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">{PHONE}{CAP}</div>'
open('p22_ctx.html', 'w').write(HTML)
