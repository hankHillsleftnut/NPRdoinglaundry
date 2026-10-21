# (Paper boards on 04b were assembled by cloning the masters; this file is the reference spec, the boards are the source of truth.)
# M4 · Journal pages in hi-fi (JR-3 drawer, JR-4 entry), assembled only from the approved masters (parts 06, 23, 24 and the M3 states).
# Page level only: three device sizes, the key states (founder 20 Oct: key states only; largest text and contrast come from SwiftUI),
# and the page pass. Two gaps from the mid-fi are closed here: the drawer's foot (settings · version, under a fade) and the entry's
# voice note and "nothing taken yet" states.
import importlib.util, json
from review import V, C
from review2 import _t, _kicker
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
d, e, t, m3 = load('p23_drawer'), load('p24_entry'), load('p06_topbar'), load('m3_states')
I = json.load(open('../icons/outlined-20.json'))
glyph = d.glyph
SIZES = [('SE', 375, 667, True), ('17 Pro', 402, 874, False), ('Pro Max', 440, 956, False)]
PRO = SIZES[1]
def status(se): return t.STATUS.replace('padding: 21px 24px 19px', 'padding: 0px 16px') if se else t.STATUS
def margin(se): return V('spacing-5') if se else V('spacing-screen-margin')  # 20 on SE, 24 elsewhere (process: rhythm)
def shell(name, w, h, inner, bg='background-canvas'):
    return (f'<div layer-name="{name}" style="width:{w}px;height:{h}px;flex-shrink:0;position:relative;overflow:clip;display:flex;flex-direction:column;'
            f'background:{C(bg)};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">{inner}</div>')

# ---------- JR-3 · the drawer page ----------
def foot(w, se):  # mid-fi: settings and the version stay at the foot; the list fades out under them
    row = (f'<div layer-name="c:row/drawer-foot/rest" style="min-height:44px;display:flex;align-items:center;gap:{V("spacing-3")};padding:0 {V("spacing-3")}">'
           + glyph('sliders', 20, C('icon-default')) + _t('settings', 'text-md', 'text-primary', 'font-label', 'font-weight-medium', 'flex:1')
           + _t('v1.0', 'text-sm', 'text-label', 'font-label') + '</div>')
    return (f'<div layer-name="foot · fade + settings" style="position:absolute;left:0;bottom:0;width:{w}px;padding:{V("spacing-12")} {V("spacing-4")} {V("spacing-4") if se else V("spacing-8")};'
            f'background:linear-gradient(180deg, transparent 0%, {C("surface-control")} 55%)">{row}</div>')
def days_full():
    return (d.group(d.day('today'), d.entry("i think it's the 9am standup. i dread it.", '3 messages · retro replied · 9:12', 'here'))
            + d.group(d.day('yesterday'), d.entry('slept badly, long day of meetings', '2 messages · 22:40'),
                      d.entry('on the walk home i kept thinking about the offer, and whether i even want it', 'voice note · 1:42'),
                      d.entry('the fundraise article you shared', 'not sent · tap to retry', 'unsent'))
            + d.group(d.day('sun 19 oct'), d.entry('long walk, first good sleep in a week', '4 messages · 21:05'),
                      d.entry('mum called. we talked about dad for the first time in months', 'voice note · 6:18'))
            + d.group(d.day('sat 18 oct'), d.entry('ran 5k without stopping', '1 message · 8:02')))
def drawer_phone(name, size, content, page=True):
    _, w, h, se = size
    dw = w - 74  # the journal keeps 74 of its edge visible as the way back (master: 316 on 390)
    drawer = (f'<div layer-name="drawer" style="position:absolute;left:0;top:0;width:{dw}px;height:{h}px;padding:{V("spacing-8") if se else V("spacing-16")} {V("spacing-4")} 0;'
              f'display:flex;flex-direction:column;gap:{V("spacing-4")}">{content}</div>' + foot(dw, se))
    pg = (f'<div layer-name="journal (pushed right)" style="position:absolute;left:{dw}px;top:0;width:{w}px;height:{h}px;background:{C("background-canvas")};'
          f'border-radius:{V("radius-sheet")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 4px 12px {C("shadow-overlay-2")}, 0 24px 48px -12px {C("shadow-overlay-1")};overflow:clip">'
          + f'<div style="height:{22 if se else 62}px"></div>' + t.bar(t.drawer_button(False) + t.small_label + t.SPACER, 'label')
          + f'<div style="padding:{V("spacing-4")} {margin(se)}">{t.MSG}</div></div>') if page else ''
    return shell(name, w, h, drawer + pg + f'<div layer-name="status bar (over both layers)" style="position:absolute;left:0;top:0;width:{w}px">{status(se)}</div>', 'surface-control')
def offline_line():
    return (f'<div layer-name="offline line" style="display:flex;align-items:center;gap:{V("spacing-1")};padding:0 {V("spacing-3")}">'
            + glyph('offline', 14, C('icon-muted')) + _t("offline · new notes send when you're back", 'text-sm', 'text-label', 'font-label') + '</div>')
JR3_SIZES = [drawer_phone(f'JR-3 · {s[0]} · {s[1]}×{s[2]}', s, d.search('rest') + days_full()) for s in SIZES]
JR3_STATES = [
    ('empty · your first day', 'one quiet line says what will appear; no illustration, no button. the foot is still there.',
     drawer_phone('JR-3 · empty', PRO, d.search('rest') + m3.quiet('nothing yet. say anything.', 'what you say shows up here, by day'))),
    ('searching', 'results replace the days as you type; the word you typed is blue and medium.',
     drawer_phone('JR-3 · searching', PRO, d.search('typing') + d.group(d.day('2 matches'), d.entry('the 9am standup again', 'today · 9:12', match='standup'),
                                                                         d.entry('standup ran long, i said nothing', 'tue 14 oct · 10:05', match='standup')))),
    ('no results', 'the field keeps your word so you can change it.',
     drawer_phone('JR-3 · no results', PRO, m3.typed('kayak') + m3.quiet('nothing with that word yet', 'try another word you might have said'))),
    ('offline', 'everything is on the phone, so the list still opens. one grey line under search says so; new notes wait, marked, and send on their own. not red: nothing went wrong.',
     drawer_phone('JR-3 · offline', PRO, d.search('rest') + offline_line()
                  + d.group(d.day('today'), d.entry('the train is stuck again, writing this underground', 'waiting to send · 9:40'),
                            d.entry("i think it's the 9am standup. i dread it.", '3 messages · retro replied · 9:12', 'here'))
                  + d.group(d.day('yesterday'), d.entry('slept badly, long day of meetings', '2 messages · 22:40')))),
]

# ---------- JR-4 · the entry page ----------
def back(): return load('p24_context').back
EDIT = load('p24_context').edit
def entry_phone(name, size, head, took, over='', bar=None, below=True):
    _, w, h, se = size
    b = bar if bar is not None else t.bar(back() + '<div style="flex:1"></div>' + EDIT, 'entry')
    body = (f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-8")};padding:{V("spacing-4")} {margin(se)} 0">' + head + took + '</div>'
            + (f'<div style="padding:0 {margin(se)} {V("spacing-4") if se else V("spacing-8")}">' + e.delete_row() + '</div>' if below else ''))
    return shell(name, w, h, status(se) + b + body + over)
def head(words, meta, extra=''): return f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}">' + e.words(words) + meta + extra + '</div>'
STANDUP = head("i think it's the 9am standup. i dread it.", e.meta(['today', '9:12', 'written', 'read'], 'read'), e.link())
TOOK = e.took_list([e.took('the monday standup is hard for you'), e.took('you feel dread before 9am meetings', 'noted')])
def voice_row():  # the play row for a voice entry (mid-fi needs: "a play row under the date; the words are the transcript")
    return (f'<div layer-name="c:voice-row/entry/rest" style="min-height:44px;display:flex;align-items:center;gap:{V("spacing-3")}">'
            + f'<div layer-name="c:icon-button/wash/rest" style="width:36px;height:36px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">{glyph("play", 16, C("icon-default"))}</div>'
            + f'<div layer-name="track" style="flex:1;height:{V("spacing-size-border-ring")};border-radius:{V("radius-small")};background:{C("surface-wash-pressed")}"></div>'
            + _t('1:42', 'text-sm', 'text-label', 'font-label') + '</div>')
def quiet_took(line): return e.took_list([_t(line, 'text-md', 'text-tertiary', extra=f'padding:{V("spacing-1")} 0')])
def dialog_over(w, h):
    return (f'<div layer-name="scrim" style="position:absolute;left:0;top:0;width:{w}px;height:{h}px;background:{C("background-scrim")};'
            f'display:flex;align-items:center;justify-content:center">' + e.dialog(w=w - 48, bare=True) + '</div>')
def keyboard(w):
    return (f'<div layer-name="keyboard (system, not ours)" style="width:{w}px;height:291px;flex-shrink:0;background:{C("surface-control")};display:flex;align-items:center;justify-content:center">'
            + _t('system keyboard', 'text-sm', 'text-label', 'font-label') + '</div>')
JR4_SIZES = [entry_phone(f'JR-4 · {s[0]} · {s[1]}×{s[2]}', s, STANDUP, TOOK) for s in SIZES]
EBAR = m3.bar
EFIELD = m3.field
JR4_STATES = [
    ('voice note', 'a play row under the date; your words are the transcript, so a long one wraps and the page scrolls.',
     entry_phone('JR-4 · voice note', PRO, head("on the walk home i kept thinking about the offer, and whether i even want it. the money's better, but i'd be commuting again, and i only just got my mornings back.",
                                                e.meta(['yesterday', '18:05', 'voice', 'read'], 'read'), voice_row() + e.link()),
                 e.took_list([e.took("you're weighing the new offer against your mornings")]))),
    ('nothing taken yet', 'just sent: retro hasn\'t read it. the list says so instead of hiding, and fills in on its own.',
     entry_phone('JR-4 · nothing taken yet', PRO, head('ran 5k without stopping', e.meta(['today', '8:02', 'written', 'sent']), e.link()),
                 quiet_took("retro hasn't read this yet. it will in a minute."))),
    ('editing', 'tap edit: the words become a sunken field, the keyboard comes up, delete hides. save is plain ink.',
     shell('JR-4 · editing', PRO[1], PRO[2], status(False) + EBAR
           + f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-4")} {V("spacing-screen-margin")}">' + EFIELD
           + _t('retro reads it again when you save', 'text-sm', 'text-label', 'font-label') + '</div>' + keyboard(PRO[1]))),
    ('offline · didn\'t send', 'said with no signal: the line turns red with one tap to retry; it also retries on its own. nothing is taken until it sends.',
     entry_phone('JR-4 · offline', PRO, head('the train is stuck again, writing this underground', e.meta([], 'failed')),
                 quiet_took("nothing yet. retro reads it once it sends."))),
    ('delete, asking once', 'the page dims; the dialog spans the margins; "delete it" is the only lit thing.',
     entry_phone('JR-4 · delete dialog', PRO, STANDUP, TOOK, dialog_over(PRO[1], PRO[2]))),
]

# ---------- the board ----------
def tile(phone, title, note, w):
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-3")};width:{w}px;flex-shrink:0">{phone}'
            + _t(title, 'text-md', 'text-primary', 'font-label', 'font-weight-medium') + _t(note, 'text-md', 'text-secondary') + '</div>')
RED = f'<div layer-name="needs you · red dot" style="width:{V("spacing-3")};height:{V("spacing-3")};flex-shrink:0;border-radius:{V("radius-control")};background:{C("status-danger")}"></div>'
def header(code, title, purpose, lit):
    return (f'<div layer-name="header" style="display:flex;flex-direction:column;gap:{V("spacing-2")};max-width:900px">'
            + f'<div style="display:flex;align-items:center;gap:{V("spacing-3")}">'
            + _t('approve?', 'text-sm', 'text-inverse', 'font-label', 'font-weight-medium', f'padding:{V("spacing-1")} {V("spacing-3")};border-radius:{V("radius-control")};background:{C("ink-default")};white-space:nowrap')
            + _kicker(f'M4 · gate C1 · {code} · hi-fi page') + RED + '</div>'
            + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};line-height:{V("leading-tight")};color:{C("text-primary")}">{title}</div>'
            + _t(f'{purpose} · lit action: {lit}', 'text-md', 'text-secondary') + '</div>')
def section(name, tiles):
    return (f'<div layer-name="{name}" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">' + _kicker(name)
            + f'<div style="display:flex;gap:{V("spacing-10")};align-items:flex-start">' + ''.join(tiles) + '</div></div>')
def passed(rows):
    return (f'<div layer-name="page pass" style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-4")} {V("spacing-5")};border-radius:{V("radius-panel")};background:{C("surface-wash")};max-width:1200px">'
            + _kicker('page pass') + ''.join(_t(f'{k} · {v}', 'text-md', 'text-primary') for k, v in rows)
            + _t('to answer: comment "yes" on this board, or the change on the phone itself', 'text-sm', 'text-label', 'font-label') + '</div>')
SIZE_NOTE = {'SE': '20 margins, short status bar, the foot sits 16 off the bottom', '17 Pro': 'the size every state below is drawn at', 'Pro Max': 'more rows show; nothing stretches past the reading width'}
def write(code):
    if code == 'JR-3':
        sizes = section('sizes', [tile(p, f'{s[0]} · {s[1]}×{s[2]}', SIZE_NOTE[s[0]], s[1]) for p, s in zip(JR3_SIZES, SIZES)])
        states = section('key states · 17 Pro', [tile(p, a, b, PRO[1]) for a, b, p in JR3_STATES])
        rows = [('content first', 'opens on your own words, newest day first; the conversation you came from is lifted'),
                ('one lit object', 'none: the drawer is an index, nothing on it is the main action'),
                ('hierarchy', 'words (17, ink) → day labels (12, grey) → meta; the search field is the only shape at the top'),
                ('rhythm', 'days 16 apart, rows 4 apart, 16 drawer padding; the journal keeps 74 of its edge as the way back'),
                ('edges', 'the list fades under the foot (progressive blur in the build); nothing is cut in half at the top'),
                ('real data', 'a two-line voice note, an unsent note, a six-minute call, a one-word day'),
                ('states', 'empty, searching, no results, offline. no loading or error state: the list is on the phone, it opens instantly'),
                ('sizes', 'SE, 17 Pro, Pro Max'), ('dark', 'comes with M12, as planned'),
                ('added from the mid-fi', 'settings · version at the foot (the master had dropped it); sliders is the settings glyph')]
        return header('JR-3', 'the journal drawer', 'every conversation by day; find one by a word you said, tap to jump there', 'none') + sizes + states + passed(rows)
    sizes = section('sizes', [tile(p, f'{s[0]} · {s[1]}×{s[2]}', SIZE_NOTE[s[0]].replace(', the foot sits 16 off the bottom', '; delete sits 16 off the bottom'), s[1]) for p, s in zip(JR4_SIZES, SIZES)])
    states = section('key states · 17 Pro', [tile(p, a, b, PRO[1]) for a, b, p in JR4_STATES])
    rows = [('content first', 'your words at the top, large and inky, before anything about them'),
            ('one lit object', 'none at rest; the delete dialog\'s button is the only one, and only while it asks'),
            ('hierarchy', 'words → when · how · read → what retro took → delete, last and quiet in the thumb zone'),
            ('rhythm', 'sections 32 apart, 8 inside; 24 margins (20 on SE)'),
            ('edges', 'a long voice transcript scrolls under the top bar with the same blur as the journal'),
            ('real data', 'a one-line note, a three-line transcript, a claim that wraps, a corrected claim'),
            ('states', 'voice note, nothing taken yet, editing, offline (didn\'t send), delete. read and re-reading are in the master'),
            ('sizes', 'SE, 17 Pro, Pro Max'), ('dark', 'comes with M12, as planned'),
            ('added from the mid-fi', 'the voice note\'s play row and "nothing taken yet": both built from existing parts (wash icon button, the meta line)')]
    return header('JR-4', 'an entry', 'read back one thing you said; correct what retro took, or remove it', 'none at rest') + sizes + states + passed(rows)
def board(code): return f'<div style="display:flex;flex-direction:column;gap:{V("spacing-10")};padding:{V("spacing-10")};width:100%">' + write(code) + '</div>'
for code in ('JR-3', 'JR-4'):
    open(f'm4_{code.lower().replace("-", "")}.html', 'w').write(board(code))
