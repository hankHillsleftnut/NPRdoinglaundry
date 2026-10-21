# AC-1 · sign in (returning): shown only when silent renewal fails, so most people never see it.
# Built from the splash's sign-in zone (part 43) so it is familiar, but quieter: no constellation, no pitch.
# The mark (38, the size the spec gives for the onboarding welcome) carries "this is retrospect"; one inky line says why you're here.
import importlib.util
from review import V, C
from review2 import _t
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
t, b = load('p06_topbar'), load('p03_briefcard')
STATUS = t.STATUS.replace(' clip-rule="evenodd" style="opacity: .35" ', ' fill-opacity="0.35" ').replace(' style="opacity: .35" ', ' fill-opacity="0.35" ').replace(' clip-rule="evenodd" ', ' ')
DIM = f'opacity:{V("opacity-disabled")};'
SIZES = {'se': (375, 667), 'pro': (402, 874), 'max': (440, 956)}
MARK = (f'<div layer-name="c:the-mark/38" style="width:38px;height:38px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-secondary-action")};'
        f'box-shadow:inset 0 0 0 1px {C("depth-stroke-inner-top")}, 0 0 0 1px {C("border-secondary-ring")}, 0 6px 7px {C("depth-shadow-cast")}, 0 1px 2px {C("depth-shadow-contact")}"></div>')
APPLE_D = 'M16.37 1.43c0 1.14-.49 2.27-1.18 3.08-.74.9-1.99 1.57-2.99 1.57-.12 0-.23-.02-.3-.03-.01-.06-.04-.22-.04-.39 0-1.15.57-2.27 1.21-2.98.8-.94 2.14-1.64 3.25-1.68.03.13.05.28.05.43zm4.56 15.71c-.03.07-.46 1.58-1.52 3.12-.94 1.34-1.94 2.71-3.430 2.71-1.52 0-1.9-.88-3.63-.88-1.7 0-2.3.91-3.67.91-1.38 0-2.33-1.26-3.43-2.8-1.29-1.82-2.32-4.63-2.32-7.28 0-4.28 2.8-6.55 5.55-6.55 1.45 0 2.68.95 3.6.95.87 0 2.22-1.01 3.9-1.01.61 0 2.89.06 4.37 2.19-.13.09-2.38 1.37-2.38 4.19 0 3.26 2.85 4.42 2.96 4.45z'
G = [('#EA4335', 'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z'),
     ('#4285F4', 'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z'),
     ('#FBBC05', 'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z'),
     ('#34A853', 'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.150 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z')]  # Google's brand colours: its mark may not be recoloured
# the buttons are slots: on the board they're replaced with clones of the splash's own buttons (part 43), so the brand marks
# (Google's colours can't be tokens) come from one place
def apple(dim=False): return f'<div layer-name="slot · apple{" · dim" if dim else ""}" style="height:{V("spacing-size-control-hero")}"></div>'
def google(dim=False): return f'<div layer-name="slot · google{" · dim" if dim else ""}" style="height:{V("spacing-size-control-hero")}"></div>'
def _apple_drawn(dim=False):
    return (f'<div layer-name="c:sign-in/apple" style="height:{V("spacing-size-control-hero")};display:flex;align-items:center;justify-content:center;gap:{V("spacing-2")};'
            f'border-radius:{V("radius-control")};background:{C("sign-in-apple-fill")};box-shadow:0 1px 2px {C("depth-shadow-contact")}, 0 8px 16px -8px {C("depth-shadow-cast")};{DIM if dim else ""}">'
            f'<svg width="18" height="20" viewBox="0 0 24 24"><path d="{APPLE_D}" fill="{C("sign-in-apple-label")}"/></svg>'
            + _t('Sign in with Apple', 'text-body', 'sign-in-apple-label', 'font-text', 'font-weight-medium') + '</div>')
def _google_drawn(dim=False):
    return (f'<div layer-name="c:sign-in/google" style="height:{V("spacing-size-control-hero")};display:flex;align-items:center;justify-content:center;gap:{V("spacing-3")};'
            f'border-radius:{V("radius-control")};background:{C("sign-in-google-fill")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
            f'0 1px 1.5px {C("depth-shadow-contact")}, 0 6px 14px -6px {C("depth-shadow-cast")};{DIM if dim else ""}">'
            f'<svg width="18" height="18" viewBox="0 0 48 48">' + ''.join(f'<path d="{d}" fill="{c}"/>' for c, d in G) + '</svg>'
            + _t('Continue with Google', 'text-body', 'sign-in-google-label', 'font-text', 'font-weight-medium') + '</div>')
def newhere(dim=False):
    return (f'<div layer-name="new here" style="height:44px;display:flex;align-items:center;justify-content:center;{DIM if dim else ""}">'
            + _t('new here? get started', 'text-md', 'text-link', 'font-text', 'font-weight-medium') + '</div>')
def phone(size, state='rest'):
    w, h = SIZES[size]; se = size == 'se'
    line = {'rest': 'sign in to pick up where you left off.',
            'restoring': 'bringing back your entries and episodes…',
            'failed': 'sign in to pick up where you left off.'}[state]
    sub = (f'<div style="display:flex;align-items:center;justify-content:center;gap:{V("spacing-2")}">'
           + (f'<div layer-name="c:syncing-ring" style="width:14px;height:14px;flex-shrink:0;border-radius:{V("radius-control")};box-shadow:inset 0 0 0 2px {C("border-subtle")};'
              f'background:conic-gradient({C("icon-muted")} 0deg 110deg, transparent 110deg)"></div>' if state == 'restoring' else '')
           + _t(line, 'text-body', 'text-secondary', extra=f'letter-spacing:{V("tracking-card")};text-align:center;text-wrap:balance') + '</div>')
    # SE: the words sit a step higher (the middle is shorter) and the buttons keep their full 56 height; only the gaps tighten
    middle = (f'<div layer-name="middle" style="flex:1 1 0%;min-height:0;display:flex;flex-direction:column;align-items:center;justify-content:center;'
              f'gap:{V("spacing-5" if se else "spacing-6")};padding:0 {V("spacing-screen-margin")}">' + MARK
              + f'<div style="display:flex;flex-direction:column;align-items:center;gap:{V("spacing-2")}">'
              + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-title")};font-size:{V("text-3xl")};line-height:{V("leading-tight")};'
                f'letter-spacing:{V("tracking-title")};color:{C("text-primary")};text-align:center">welcome back.</div>' + sub + '</div></div>')
    err = (f'<div layer-name="error · one line" style="display:flex;align-items:flex-start;justify-content:center;gap:{V("spacing-2")};padding:0 {V("spacing-2")}">'
           + b.icon('alert', 16, C('status-danger'))
           + _t("that didn't work. your entries are safe; try again.", 'text-md', 'text-secondary', extra='text-wrap:balance') + '</div>') if state == 'failed' else ''
    dim = state == 'restoring'
    bottom = (f'<div layer-name="sign-in · bottom zone" style="display:flex;flex-direction:column;gap:{V("spacing-3")};'
              f'padding:0 {V("spacing-screen-margin")} {V("spacing-4" if se else "spacing-10")}">' + err + apple(dim) + google(dim) + newhere(dim) + '</div>')
    status = STATUS.replace('padding: 21px 24px 19px;', 'padding: 1px 16px;') if se else STATUS
    home = '' if se else (f'<div layer-name="home indicator" style="position:absolute;bottom:8px;left:{(w - 134) // 2}px;width:134px;height:5px;'
                          f'border-radius:{V("radius-control")};background:{C("text-primary")}"></div>')
    radius = '0' if se else V('radius-sheet')
    return (f'<div layer-name="AC-1 · {size} · {state}" style="width:{w}px;height:{h}px;flex-shrink:0;position:relative;overflow:clip;display:flex;flex-direction:column;'
            f'border-radius:{radius};background:{C("background-canvas")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">' + status + middle + bottom + home + '</div>')
def tile(p, title, why, w):
    return (f'<div layer-name="tile · {title}" style="display:flex;flex-direction:column;gap:{V("spacing-3")};width:{w}px">' + p
            + _t(title, 'text-md', 'text-primary', 'font-label', 'font-weight-medium') + _t(why, 'text-md', 'text-secondary') + '</div>')
def label(s): return _t(s, 'text-sm', 'text-label', 'font-label', 'font-weight-medium', f'letter-spacing:{V("tracking-label")}')
header = (f'<div layer-name="header" style="display:flex;flex-direction:column;gap:{V("spacing-2")};max-width:900px">'
          f'<div style="display:flex;align-items:center;gap:{V("spacing-3")}">'
          + _t('approve?', 'text-sm', 'text-inverse', 'font-label', 'font-weight-medium', f'padding:{V("spacing-1")} {V("spacing-3")};border-radius:{V("radius-control")};background:{C("ink-default")}')
          + _t('M6 · AC-1 · sign in, returning', 'text-lg', 'text-primary', 'font-label', 'font-weight-medium')
          + f'<div layer-name="needs you · red dot" style="width:{V("spacing-3")};height:{V("spacing-3")};flex-shrink:0;border-radius:{V("radius-control")};background:{C("status-danger")}"></div></div>'
          + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};line-height:{V("leading-tight")};color:{C("text-primary")}">welcome back: get in, land where you were</div>'
          + _t("only when silent renewal fails · the splash's sign-in zone, without the pitch · lit action: none (Apple's black button leads)", 'text-md', 'text-secondary') + '</div>')
sizes = (f'<div layer-name="sizes" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">' + label('sizes · rest')
         + f'<div style="display:flex;gap:{V("spacing-10")};align-items:flex-start">' + phone('se') + phone('pro') + phone('max') + '</div></div>')
states = (f'<div layer-name="key states · 17 Pro" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">' + label('key states · 17 Pro')
          + f'<div style="display:flex;gap:{V("spacing-10")};align-items:flex-start">'
          + tile(phone('pro', 'restoring'), 'restoring', 'after Apple says yes: the line under the title becomes the wait, with the syncing ring; the buttons rest disabled so nothing can be tapped twice. it lands where you were.', 402)
          + tile(phone('pro', 'failed'), 'failed', 'one plain line above the buttons, saying what is safe; the buttons stay live so trying again is one tap.', 402) + '</div></div>')
pas = (f'<div layer-name="page pass" style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-4")} {V("spacing-5")};border-radius:{V("radius-panel")};background:{C("surface-wash")};width:1200px">'
       + label('page pass')
       + _t('content first · the mark and one inky line in the middle; the two buttons and "new here" in the thumb zone, in the same order as the splash', 'text-md', 'text-primary')
       + _t('small screens · on SE the middle shortens and the words stay centred in what is left; the buttons keep their full height (they are the only thing to do here); gaps tighten one step and the bottom padding drops to 16 (no home indicator)', 'text-md', 'text-primary')
       + _t('one lit object · none: Apple\'s black button is the lead by Apple\'s own rules, so nothing glows here', 'text-md', 'text-primary')
       + _t('to answer: comment "yes" on this board, or the change on the phone itself', 'text-sm', 'text-label', 'font-label') + '</div>')
open('p47_signin_returning.html', 'w').write(header + sizes + states + pas)
