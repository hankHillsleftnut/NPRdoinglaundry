# M10 · outside the app: EX-1 share to retrospect (share extension), EX-2 lock screen (now playing), EX-3 notifications,
# EX-4 widgets. System chrome (wallpaper, clock, the now-playing material, notification material) is drawn plainly in
# night tokens so our parts read on it; only what Retrospect controls is designed: the share sheet, the words, the widget.
import importlib.util
from review import V, C
from review2 import _t
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
b, e, g, pl = load('p03_briefcard'), load('p40_episode_tiles'), load('p48_goal'), load('p20_pill')
W = 'width:402px;height:874px;flex-shrink:0;position:relative;overflow:clip;display:flex;flex-direction:column;border-radius:var(--radius-sheet)'
WALL = f'background-color:{C("night-700")};background-image:radial-gradient(circle farthest-corner at 85% 10% in oklab, {C("amber-300")} 0%, transparent 45%), radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("night-950")} 0%, transparent 85%)'
STATUS_LIGHT = (f'<div layer-name="status (light)" style="height:54px;flex-shrink:0;display:flex;align-items:center;justify-content:space-between;padding:0 {V("spacing-8")}">'
                + _t('9:41', 'text-body', 'text-inverse', 'font-text', 'font-weight-semibold') + _t('●●● ◔ ▭', 'text-sm', 'text-inverse', 'font-label') + '</div>')
def clock(date, time):
    return (f'<div layer-name="lock clock (system)" style="display:flex;flex-direction:column;align-items:center;gap:{V("spacing-1")};padding-top:{V("spacing-4")}">'
            + _t(date, 'text-md', 'text-inverse', 'font-text', 'font-weight-medium')
            + f'<div style="font-family:{V("font-text")};font-weight:{V("font-weight-semibold")};font-size:{V("text-hero")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-title")};color:{C("text-inverse")}">{time}</div></div>')
def material(inner, extra=''):  # the system's frosted card, drawn as a dimmed night layer under the content
    return (f'<div layer-name="system material" style="position:relative;border-radius:{V("radius-card")};overflow:clip;{extra}">'
            f'<div style="position:absolute;inset:0;background:{C("night-900")};opacity:{V("opacity-dimmed")}"></div>'
            f'<div style="position:relative;display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-4")}">{inner}</div></div>')
def home_ind(light=True): return (f'<div layer-name="home indicator" style="position:absolute;bottom:8px;left:134px;width:134px;height:5px;border-radius:{V("radius-control")};'
                                  f'background:{C("text-inverse" if light else "text-primary")}"></div>')
def mesh(kind, size, r='radius-default'):
    base, img = e.MESH[kind]
    return f'<div layer-name="artwork · mesh · {kind}" style="width:{size}px;height:{size}px;flex-shrink:0;border-radius:{V(r)};background-color:{base};background-image:{img}"></div>'

# EX-2 · lock screen, now playing (system card; our words: title, the part being spoken, its source)
def transport():
    ic = lambda n, s: b.icon(n, s, C('text-inverse'))
    return (f'<div style="display:flex;align-items:center;justify-content:center;gap:{V("spacing-12")}">' + ic('skip-back-15', 28) + ic('pause', 36) + ic('skip-forward-30', 28) + '</div>')
scrub = (f'<div layer-name="scrubber (system)" style="display:flex;flex-direction:column;gap:{V("spacing-1")}">'
         f'<div style="height:4px;border-radius:{V("radius-control")};background:{C("night-500")};overflow:clip"><div style="width:30%;height:100%;background:{C("text-inverse")}"></div></div>'
         f'<div style="display:flex;justify-content:space-between">' + _t('1:12', 'text-xs', 'text-inverse', 'font-mono') + _t('−2:48', 'text-xs', 'text-inverse', 'font-mono') + '</div></div>')
NOWPLAYING = material(
    f'<div style="display:flex;gap:{V("spacing-3")};align-items:center">' + mesh('brief', 48)
    + f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">'
    + _t("the fundraise article you sent", 'text-body', 'text-inverse', 'font-text', 'font-weight-semibold', 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis')
    + _t("retrospect · tuesday's brief · part 2 of 3", 'text-sm', 'text-inverse', 'font-label', extra='opacity:var(--opacity-dimmed)') + '</div></div>'
    + scrub + transport(), 'margin:0 var(--spacing-3)')
EX2 = (f'<div layer-name="EX-2 · lock screen · now playing" style="{W};{WALL}">' + STATUS_LIGHT + clock('tuesday 21 october', '8:42')
       + f'<div style="flex:1"></div><div style="padding-bottom:{V("spacing-12")}">' + NOWPLAYING + '</div>' + home_ind() + '</div>')

# EX-3 · notifications: private by default (that something is ready, not what's in it); one a day at most
def notif(time, line, dim=False):
    head = (f'<div style="display:flex;align-items:center;gap:{V("spacing-2")}"><div layer-name="app icon" style="width:20px;height:20px;border-radius:{V("radius-small")};background:{C("surface-secondary-action")}"></div>'
            + _t('retrospect', 'text-sm', 'text-inverse', 'font-text', 'font-weight-semibold', 'flex:1') + _t(time, 'text-sm', 'text-inverse', 'font-label') + '</div>')
    return material(head + _t(line, 'text-body', 'text-inverse', extra='text-wrap:balance'), 'margin:0 var(--spacing-3);' + ('opacity:var(--opacity-disabled);' if dim else ''))
EX3 = (f'<div layer-name="EX-3 · notifications" style="{W};{WALL}">' + STATUS_LIGHT + clock('sunday 26 october', '9:00')
       + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-3")};padding-top:{V("spacing-8")}">'
       + notif('now', "this week's episode is here.")
       + f'<div style="padding:{V("spacing-2")} {V("spacing-6")} 0">' + _t('at most one a day. the other two kinds:', 'text-sm', 'text-inverse', 'font-label', extra='opacity:var(--opacity-dimmed)') + '</div>'
       + notif('8:30', 'your brief is ready · 4 min', True) + notif('6:10 pm', 'one question for you, when you have a minute.', True)
       + '</div>' + home_ind() + '</div>')

# EX-4 · widgets on the home screen: small = the mark + tell me…; medium = today's brief, serif headline, play · talk
def widget(inner, w, h):
    return (f'<div layer-name="c:widget/{w}x{h}" style="width:{w}px;height:{h}px;box-sizing:border-box;flex-shrink:0;display:flex;flex-direction:column;'
            f'padding:{V("spacing-4")};border-radius:{V("radius-widget")};background:{C("background-raised")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 8px 24px -8px {C("depth-shadow-cast")}">{inner}</div>')
MARK16 = (f'<div layer-name="c:the-mark/16" style="width:16px;height:16px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-secondary-action")};'
          f'box-shadow:0 0 0 1px {C("border-secondary-ring")}, 0 1px 1px {C("depth-shadow-contact")}"></div>')
def wash_pill(label, icon=None):
    return (f'<div layer-name="c:pill/neutral" style="height:32px;display:flex;align-items:center;gap:{V("spacing-1")};padding:0 {V("spacing-3")};border-radius:{V("radius-control")};background:{C("surface-wash")}">'
            + (b.icon(icon, 14, C('icon-default')) if icon else '') + _t(label, 'text-md', 'text-primary', 'font-label', 'font-weight-medium') + '</div>')
SMALL = widget(MARK16 + f'<div style="flex:1"></div>' + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-lg")};line-height:{V("leading-tight")};color:{C("text-primary")}">tell me…</div>'
               + _t('talk to retro', 'text-sm', 'text-label', 'font-label'), 164, 164)
MEDIUM = widget(f'<div style="display:flex;align-items:center;gap:{V("spacing-2")}">' + MARK16 + _t("today's brief · 4 min", 'text-xs', 'text-label', 'font-mono') + '</div>'
                + f'<div style="padding-top:{V("spacing-2")};font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-lg")};line-height:{V("leading-tight")};color:{C("text-primary")};text-wrap:balance">a heavier week than usual, and it shows.</div>'
                + f'<div style="flex:1"></div><div style="display:flex;gap:{V("spacing-2")}">' + wash_pill('play', 'play') + wash_pill('talk', 'mic') + '</div>', 344, 164)
def app(): return f'<div layer-name="app (system)" style="width:62px;height:62px;border-radius:{V("radius-card")};background:{C("night-500")};opacity:{V("opacity-dimmed")}"></div>'
APPS = f'<div style="display:grid;grid-template-columns:repeat(2, 62px);gap:{V("spacing-6")} {V("spacing-6")}">' + app() * 4 + '</div>'
EX4 = (f'<div layer-name="EX-4 · widgets" style="{W};{WALL}">' + STATUS_LIGHT
       + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-4")} {V("spacing-6")} 0">'
       + f'<div style="display:flex;justify-content:space-between;align-items:flex-start">' + SMALL + APPS + '</div>' + MEDIUM
       + f'<div style="display:flex;justify-content:space-between">' + app() * 4 + '</div></div>' + home_ind() + '</div>')

# EX-1 · share to retrospect: the system share sheet hosts our extension over safari
SHEET_TOP = (f'<div layer-name="behind · safari (dimmed)" style="height:90px;flex-shrink:0;background:{C("night-800")}"></div>')
thing = (f'<div layer-name="the thing" style="display:flex;gap:{V("spacing-3")};align-items:center;padding:{V("spacing-3")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
         + mesh('calls', 48) + f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:{V("spacing-size-border-ring")}">'
         + _t('how to raise a seed round in 2026', 'text-md', 'text-primary', 'font-text', 'font-weight-medium', 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis')
         + _t('youtube.com · 40 min video', 'text-sm', 'text-label', 'font-label') + '</div></div>')
read = (f'<div layer-name="retro\'s read" style="display:flex;flex-direction:column;gap:{V("spacing-2")}">' + _t("retro's read", 'text-sm', 'text-label', 'font-label', 'font-weight-medium')
        + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};letter-spacing:{V("tracking-card")};color:{C("text-primary")};text-wrap:balance">a 40-minute talk on raising a seed round, mostly about angels.</div>'
        + f'<div style="display:flex;align-items:center;gap:{V("spacing-2")};padding-top:{V("spacing-1")}">' + _t('goes with', 'text-sm', 'text-label', 'font-label')
        + wash_pill('raise the seed', 'goals') + _t('change', 'text-md', 'text-link', 'font-text', 'font-weight-medium') + '</div></div>')
why = (f'<div layer-name="add why (optional)" style="display:flex;flex-direction:column;gap:{V("spacing-2")}">' + _t('add why (optional)', 'text-sm', 'text-label', 'font-label', 'font-weight-medium')
       + f'<div layer-name="c:composer/compact" style="height:48px;display:flex;align-items:center;gap:{V("spacing-2")};padding:0 {V("spacing-1")};border-radius:{V("radius-control")};background:{C("surface-control")};'
         f'box-shadow:inset 0 1px 2px {C("depth-shadow-sunken")}, inset 0 0 0 0.5px {C("depth-stroke-outer")}">'
       + f'<div style="width:36px;height:36px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">{b.icon("mic", 18, C("icon-default"))}</div>'
       + _t('for the raise, the bit on angels…', 'text-body', 'text-tertiary', extra='flex:1') + '</div></div>')
LIT = (f'background:linear-gradient(180deg, {C("glow-primary-gradient-top")}, {C("glow-primary-gradient-bottom")});'
       f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, inset 0 -1px 1.5px {C("glow-primary-edge")}, inset 0 0 6px {C("glow-primary-bloom")}, 0 0 0 1.5px {C("glow-primary-ring")}, 0 6px 14px -4px {C("glow-primary-halo")}, 0 2px 2px {C("glow-primary-cast")}')
save = (f'<div layer-name="c:button/lit/save" style="height:{V("spacing-size-control-hero")};display:flex;align-items:center;justify-content:center;border-radius:{V("radius-control")};{LIT}">'
        + _t('save', 'text-body', 'glow-primary-foreground', 'font-text', 'font-weight-semibold') + '</div>')
head = (f'<div layer-name="sheet header" style="display:flex;align-items:center;height:44px">' + _t('cancel', 'text-body', 'text-link', 'font-text', extra='width:72px')
        + _t('save to retrospect', 'text-md', 'text-secondary', 'font-label', 'font-weight-medium', 'flex:1;text-align:center') + '<div style="width:72px"></div></div>')
EX1 = (f'<div layer-name="EX-1 · share to retrospect" style="{W};background:{C("night-800")}">' + SHEET_TOP
       + f'<div layer-name="extension sheet" style="flex:1 1 0%;min-height:0;display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-2")} {V("spacing-screen-margin")} {V("spacing-10")};'
         f'border-radius:{V("radius-sheet")} {V("radius-sheet")} 0 0;background:{C("background-canvas")}">'
       + f'<div style="align-self:center;width:36px;height:5px;border-radius:{V("radius-control")};background:{C("border-strong")}"></div>'
       + head + thing + read + why + '<div style="flex:1"></div>' + save + '</div>' + home_ind(False) + '</div>')
PAGES = {'EX-1': EX1, 'EX-2': EX2, 'EX-3': EX3, 'EX-4': EX4}
if __name__ == '__main__':
    for k, v in PAGES.items(): open(f'p53_{k}.html', 'w').write(v.replace('font-weight:var(--font-weight-regular);', ''))
