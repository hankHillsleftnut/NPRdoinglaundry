# M9 · the settings pages (ST-1 to ST-9) in hi-fi, composed only from approved parts: the settings bar (part 22/27),
# rows of every kind (part 26: value ›, picker ↕, switch, choice tick, leaves-the-app ↗, source, danger), switch and
# segmented (part 25), the raised pill (part 20). Icons on ST-1 rows (decision 02 A); ↕ for values chosen in place,
# › for pages (decision 04 B). Danger rows are alone and last, in the thumb zone. One lit object: none on any page.
import importlib.util, json
from review import V, C
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
s, sw, l, c22 = load('p26_settings_rows'), load('p25_switch_segmented'), load('p21_labels'), load('p22_context')
I = json.load(open('../icons/outlined-20.json'))
W = lambda html: html.replace('width:390px;', '')   # rows stretch to the phone (402 / 375 / 440)
def bar(name): return W(c22.BAR.replace('>settings</div>', f'>{name}</div>'))
CHEV, UPDN = s.glyph('chevron-right', 16, C('icon-muted')), s.glyph('chevron-up-down', 16, C('icon-muted'))
def trail(v=None, kind='page'):
    g = {'page': CHEV, 'pick': UPDN, 'out': s.glyph('external', 16, C('icon-muted')), 'none': ''}[kind]
    return f'<div style="display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">' + (s.txt(v, 'text-md', 'text-secondary') if v else '') + g + '</div>'
def r(title, sub=None, v=None, kind='page', icon=None):
    return W(s.row('value', (s.well(icon) if icon else '') + s.words(title, sub) + trail(v, kind)))
def rsw(title, sub, on): return W(s.row('switch', s.words(title, sub) + s.switch(on)))
def rtick(title, sub, on): return W(s.row('choice', s.words(title, sub) + s.tick(on)))
def rpill(title, sub, label, icon): return W(s.row('action', s.words(title, sub) + s.raised_pill(label, icon)))
def rdanger(title, sub): return W(s.row('danger', s.dwell() + s.words(title, sub, 'status-danger-text')))
def group(label, *rows, icon=False):
    rows = [x for pair in zip(rows, [W(s.hairline(icon))] * len(rows)) for x in pair][:-1]
    head = f'<div style="padding:0 {V("spacing-screen-margin")}">{l.lab("section", label)}</div>' if label else ''
    return f'<div layer-name="group · {label or "untitled"}" style="display:flex;flex-direction:column;gap:{V("spacing-1")}">' + head + s.stack(*rows) + '</div>'
def para(label, text, inky=False):
    body = (f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-card")};color:{C("text-primary")};text-wrap:balance">{text}</div>'
            if inky else f'<div style="font-family:{V("font-text")};font-size:{V("text-body")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-card")};color:{C("text-primary")};text-wrap:balance">{text}</div>')
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:0 {V("spacing-screen-margin")}">' + (l.lab('section', label) if label else '') + body + '</div>')
def note(text): return f'<div style="padding:0 {V("spacing-screen-margin")};font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-snug")};color:{C("text-secondary")};text-wrap:balance">{text}</div>'
def segblock(label, opts, sel, caption):
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:0 {V("spacing-screen-margin")}">' + l.lab('section', label)
            + sw.seg(opts, sel).replace('width:326px;', '') + l.lab('section', caption).replace('font-weight:var(--font-weight-medium)', 'font-weight:var(--font-weight-regular)') + '</div>')
def phone(name, title, body, foot=''):
    return (f'<div layer-name="{name}" style="width:402px;height:874px;flex-shrink:0;position:relative;overflow:clip;display:flex;flex-direction:column;'
            f'background:{C("background-canvas")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">'
            f'<div layer-name="status slot" style="height:62px;flex-shrink:0"></div>' + bar(title)
            + f'<div layer-name="body" style="flex:1 1 0%;min-height:0;display:flex;flex-direction:column;gap:{V("spacing-8")};padding-top:{V("spacing-4")}">' + body + '</div>'
            + (f'<div layer-name="danger · last" style="padding-bottom:{V("spacing-10")}">{foot}</div>' if foot else '')
            + f'<div layer-name="home indicator" style="position:absolute;bottom:8px;left:134px;width:134px;height:5px;border-radius:{V("radius-control")};background:{C("text-primary")}"></div></div>')

PAGES = {
 'ST-1': phone('ST-1 · settings', 'settings',
   group('your brief', r('daily brief', v='8:30 · on', icon='brief'), icon=True)
   + group('listening', r('voice', v='warm', kind='pick', icon='mic'), r('talk or read', v='talk', kind='pick', icon='keyboard'), icon=True)
   + group('you', r('how straight i am with you', v='honest', kind='pick', icon='sliders'), r("what i've learned", icon='journal'), icon=True)
   + group('sources', r('connected sources', '4 connected · 1 needs you', icon='podcasts'), icon=True)
   + group('', r('privacy', icon='lock'), r('account', icon='you'), icon=True)),
 'ST-2': phone('ST-2 · daily brief', 'daily brief',
   group('', rsw('each morning', 'a short brief, made from yesterday', True), r('time', 'your time, london', '8:30 am', 'pick'))
   + segblock('length', ['short', 'standard', 'long'], 'standard', 'standard is about 4 minutes.')
   + group('', rpill("play today's", 'tuesday · 4 min', 'play', 'play'))),
 'ST-3': phone('ST-3 · sources', 'sources',
   group('connected', W(s.row('source', s.well('calendar') + s.words('calendar', 'so your brief knows your day') + s.status('connected', 'source-connected'))),
         W(s.row('source', s.well('brief') + s.words('health', 'how you slept, how you moved') + s.status('syncing', 'source-syncing'))),
         W(s.row('source', s.well('podcasts') + s.words('podcasts', 'stopped reading on monday') + s.raised_pill('reconnect', 'retry'))), icon=True)
   + group('add', r('add a source', 'mail, notes, health, music', icon='add'), r('import a file', 'notes, a journal, an export', icon='download'), icon=True)),
 'ST-4': phone('ST-4 · a source', 'calendar',
   para('reads', 'your events: when, how long, and who was there.')
   + para('helps me see', 'what your weeks are really like, and what fills them.')
   + group('', rpill('last read 2 min ago', None, 'sync now', 'retry')),
   rdanger('disconnect…', 'stops reading; keeps what it read') + W(s.hairline(True)) + rdanger('delete what it read…', 'removes it from what retro knows')),
 'ST-5': phone('ST-5 · privacy', 'privacy',
   group('', rsw('read in the background', 'off means retro only learns from what you send it', True), r("where it's processed", 'europe · named providers'),
         rpill('download my data', None, 'export', 'download')),
   rdanger('delete my data…', 'everything retro knows about you')),
 'ST-6': phone('ST-6 · how straight', 'how straight i am with you',
   group('', rtick('just what happened', 'no reading between the lines', False), rtick('gentle questions', "i ask, i don't tell", False),
         rtick('honest observations', 'i say what i see, kindly', True), rtick("don't hold back", 'i say it plainly', False))
   + note('i picked honest observations because you answer the hard questions, and say "not quite" when i\'m wrong.')
   + group('', r('let it decide'))),
 'ST-7': phone('ST-7 · voice and listening', 'voice and listening',
   group('', rpill('voice', 'warm · one voice behind every show', 'sample', 'play'), r('speed', 'for briefs and episodes', '1×', 'pick'))
   + segblock('talk or read', ['talk', 'read'], 'talk', 'talk: retro speaks its replies. read: words only.')),
 'ST-8': phone("ST-8 · what i've learned", "what i've learned",
   para(None, 'you answer questions about work most, 8 of 10.', True)
   + note("you skip ones about family (1 of 5), so i ask those less, and only when you bring it up first.")
   + f'<div style="padding:0 {V("spacing-screen-margin")}">' + l.lab('section', 'last changed on sunday') + '</div>'),
 'ST-9': phone('ST-9 · account', 'account',
   group('your plan', r('yearly', 'renews on 3 march · $199.99', kind='none'), r('manage subscription', 'in apple settings', kind='out'), r('restore purchases', kind='none'))
   + f'<div layer-name="group · sign out" style="display:flex;flex-direction:column;padding:{V("spacing-6")} {V("spacing-screen-margin")} 0">'
   + f'<div layer-name="c:button/secondary/rest · sign out" style="min-height:{V("spacing-size-row-default")};display:flex;align-items:center;justify-content:center;padding:0 {V("spacing-4")};border-radius:{V("radius-control")};background:{C("surface-secondary-action")};'
     f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 4px 6px -2px {C("depth-shadow-cast")}">'
   + s.txt('sign out', 'text-body', 'text-primary', w='font-weight-medium', fam='font-label') + '</div></div>',
   rdanger('delete account…', 'your entries, episodes and everything retro knows')),
}
if __name__ == '__main__':
    import sys
    for k, v in PAGES.items(): open(f'p52_{k}.html', 'w').write(v)
# Pages let sublines wrap (balanced); the approved rows keep titles and values on one line. Applied when writing *.min.html.
