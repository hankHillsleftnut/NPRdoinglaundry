# Part 27 · the settings page header and group titles (ST-1), with the whole page at 1× (founder 20 Oct: group titles are Geist labels).
import importlib.util
from review import *
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
s, c22, l = load('p26_settings_rows'), load('p22_context'), load('p21_labels')
STATUS = (f'<div layer-name="Status bar" style="height:62px;display:flex;align-items:center;padding:0 {V("spacing-6")}">'
          f'<div style="flex:1;font-family:system-ui;font-size:{V("text-body")};font-weight:{V("font-weight-semibold")};color:{C("text-primary")}">9:41</div></div>')
def bar(scrolled=False):
    edge = f'background:{C("background-canvas")};box-shadow:inset 0 -0.5px 0 {C("border-strong")};' if scrolled else ''
    return (f'<div layer-name="c:top-bar/settings/{"scrolled" if scrolled else "rest"}" style="width:390px;{edge}">' + STATUS
            + c22.BAR.replace('c:top-bar/settings/rest', 'bar') + '</div>')
chev = s.glyph('chevron-right', 16, C('icon-muted'))
def val(v): return f'<div style="display:flex;align-items:center;gap:{V("spacing-1")};flex-shrink:0">' + s.txt(v, 'text-md', 'text-secondary') + chev + '</div>'
def r(title, value=None, sub=None, kind='value'): return s.row(kind, s.words(title, sub) + (val(value) if value else chev))
def group(label, *rows):
    rows = [x for pair in zip(rows, [s.hairline()] * len(rows)) for x in pair][:-1]
    head = f'<div style="padding:0 {V("spacing-screen-margin")}">{l.lab("section", label)}</div>' if label else ''
    return f'<div layer-name="group · {label or "untitled"}" style="display:flex;flex-direction:column;gap:{V("spacing-1")}">' + head + s.stack(*rows) + '</div>'
BODY = (group('your brief', r('daily brief', '8:30 · on'))
        + group('listening', r('voice', 'warm'), r('talk or read', 'talk'))
        + group('you', r('how straight i am with you', 'honest'), r("what i've learned"))
        + group('sources', s.row('value', s.words('connected sources', '4 connected · 1 needs you') + chev))
        + group('', r('privacy'), r('account'), r('help')))
PHONE = (f'<div layer-name="phone · ST-1 settings" style="width:390px;height:844px;flex-shrink:0;overflow:clip;display:flex;flex-direction:column;'
         f'background:{C("background-canvas")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")}">'
         + bar() + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-8")};padding-top:{V("spacing-2")}">' + BODY + '</div></div>')
SCROLLED = (f'<div layer-name="scrolled" style="width:390px;height:150px;overflow:clip;position:relative;background:{C("background-canvas")};border-radius:{V("radius-sheet")} {V("radius-sheet")} 0 0;box-shadow:inset 0 0 0 1px {C("border-subtle")}">'
            + f'<div style="position:absolute;left:0;top:70px;width:390px">' + group('listening', r('voice', 'warm'), r('talk or read', 'talk')) + '</div>'
            + f'<div style="position:absolute;left:0;top:0">' + bar(True) + '</div></div>')
vis = (tile(PHONE, '1× · ST-1 in hi-fi: back · "settings" small and centred · groups by space, each named by a Geist label; the last group (privacy · account · help) needs no name')
       + tile(SCROLLED, '1× · scrolled: the bar takes the canvas and a 0.5 hairline, so rows pass under it cleanly; at rest it has neither'))
rows = {
 'purpose': ('✓', 'control in one calm list (ST-1): every row shows its current value, so you rarely need to open it'),
 'colour': ('✓', 'canvas page; labels text.label; titles text.primary; values text.secondary; chevrons icon.muted; no blue, no colour at all'),
 'type': ('✓', 'page label Geist 14 medium text.secondary (as the journal bar A); group labels Geist 12 medium (your call: Geist, not serif); titles SF Pro 17 tracking.card; values 14'),
 'space': ('✓', 'bar 44 under a 62 status; 8 to the first group; 32 between groups; label 4 above its rows; rows 56'),
 'shape': ('✓', 'no containers: groups by space (layout rule: space first); the back button is the 36 wash circle in a 44'),
 'depth': ('✓', 'all level 0; scrolled bar is still level 0, separated by a hairline, not a shadow (nothing floats on settings)'),
 'texture': ('—', 'none'),
 'icon': ('✓', 'chevron-left (the inked chevron, mirrored) for back; chevron-right 16 on every row that opens'),
 'tokens': ('✓', 'size.navBar, screen-margin, spacing 2/4/8, text.label/secondary/primary, icon.muted, border.strong, background.canvas, tracking.card/label; token-check 0'),
 'optical centring': ('✓', 'the page label centres on the screen, not between back and edge (a 44 spacer balances the back button)'),
 'contrast': ('✓', 'labels ≈ 5.1 : 1, values ≈ 6 : 1, titles ≈ 17 : 1'),
 'hit area': ('✓', 'back 44; every row full width 56'),
 'states': ('✓', 'bar rest / scrolled; rows rest / pressed (part 22); a source needing you says so in its subline ("1 needs you"), never a badge'),
 'motion': ('✓', 'the hairline and canvas fade in over 120ms as content passes under; Reduce Motion: instant'),
 'haptic': ('—', 'none'),
 'goals': ('✓', 'production settings, nothing for developers (O-28); account and help last'),
 'wireframe': ('✓', 'ST-1 exactly: back · settings, your brief · listening · you · sources · privacy/account/help, values shown'),
}
open('p27.html', 'w').write(part(27, 'settings page · header · groups', 'the settings page itself: its top bar and how groups are named', vis, rows,
     'ready for your review. one spec note: settings-row.md says a value row ends in chevron-up-down; the mid-fi and part 22 use the value + ›. drawn as ›; say if you want ↕ for values that open a picker.'))
