from review import *
# Part 24 · in the app (founder c-ck7ekg, c-hn3fgr, c-71kiak: "what is this", "not sure what this is for", "won't be the size and
# shape of what it looks like in the app"): the entry page at true 390×844, built from the part 24 pieces, and the delete dialog over it.
import importlib.util, json
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
e, t = load('p24_entry'), load('p06_topbar')
CHEV = json.load(open('../icons/outlined-20.json'))['chevron-right']
back = (f'<div layer-name="hit area 44" style="width:44px;height:44px;flex-shrink:0;display:flex;align-items:center;justify-content:center">'
        f'<div layer-name="c:icon-button/wash/rest" style="width:36px;height:36px;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">'
        f'<svg layer-name="c:icon/chevron-left" width="20" height="20" viewBox="0 0 24 24"><g transform="translate(24 0) scale(-1 1)"><path fill="{C("icon-default")}" fill-rule="evenodd" d="{CHEV}"/></g></svg></div></div>')
edit = (f'<div layer-name="c:button/text/rest" style="height:44px;display:flex;align-items:center;padding:0 {V("spacing-2")};font-family:{V("font-label")};font-size:{V("text-md")};'
        f'font-weight:{V("font-weight-medium")};letter-spacing:{V("tracking-label")};color:{C("text-primary")}">edit</div>')
BAR = t.bar(back + '<div style="flex:1"></div>' + edit, 'entry')
BODY = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}">' + e.words("i think it's the 9am standup. i dread it.")
        + e.meta(['today', '9:12', 'written', 'read'], 'read') + e.link() + '</div>'
        + e.took_list([e.took('the monday standup is hard for you'), e.took('you feel dread before 9am meetings', 'noted')]))
def page(name, over=''):
    return (f'<div layer-name="{name}" style="width:390px;height:844px;flex-shrink:0;position:relative;overflow:clip;display:flex;flex-direction:column;'
            f'background:{C("background-canvas")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">'
            + t.STATUS + BAR
            + f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-8")};padding:{V("spacing-4")} {V("spacing-screen-margin")} 0">' + BODY + '</div>'
            + f'<div style="padding:0 {V("spacing-screen-margin")} {V("spacing-8")}">' + e.delete_row() + '</div>' + over + '</div>')
SCRIM = (f'<div layer-name="scrim" style="position:absolute;left:0;top:0;width:390px;height:844px;background:{C("background-scrim")};'
         f'display:flex;align-items:center;justify-content:center">' + e.dialog(w=342, bare=True) + '</div>')
cap = lambda a, b: (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-1")};width:390px">'
                    f'<div style="font-family:{V("font-label")};font-size:{V("text-sm")};font-weight:{V("font-weight-medium")};color:{C("text-primary")}">{a}</div>'
                    f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-snug")};color:{C("text-secondary")}">{b}</div></div>')
col = lambda *x: f'<div style="display:flex;flex-direction:column;gap:{V("spacing-4")}">' + ''.join(x) + '</div>'
HTML = (f'<div layer-name="part 24 · in the app" style="display:flex;gap:{V("spacing-10")};align-items:flex-start">'
        + col(page('phone · entry page'), cap('the entry page, 1× · where you land when you tap an entry in the journal drawer',
              'your words at the top, as you said them. under them: when, how (written or voice), and whether retro has read it. "show it in the conversation" takes you back to where you said it. '
              '"what i took from this" lists what retro learned from it, one line each; "not right" corrects one on the spot. delete is last, at the bottom.'))
        + col(page('phone · delete dialog', SCRIM), cap('delete, 1× · asks once, at full width (342, the screen margins)',
              'the page dims; the card says what goes (the entry and what retro took from it). "delete it" is the only lit thing on screen; "keep it" is the quiet way out.'))
        + col(cap('the meta line, as retro works', 'after you edit an entry, retro reads it again: the line says "retro is reading it again". if your phone was offline when you said it, the line turns red: "didn\'t send · tap to retry". those are the two other states in the tiles above.'))
        + '</div>')
open('p24_ctx.html', 'w').write(HTML)
