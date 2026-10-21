# Token-only building blocks for Retrospect screens (light). Every value is a var(--…).
def V(n): return f"var(--{n})"
def C(n): return V("color-" + n)
ICON = {}
import re, os
_ic = os.path.join(os.path.dirname(__file__), '..', 'icons')
def icon(name, size=24, colour='icon-default', extra=''):
    svg = open(os.path.join(_ic, name + '.svg')).read()
    svg = re.sub(r'width="24" height="24"', f'width="{size}" height="{size}"', svg, count=1)
    return svg.replace('<svg ', f'<svg style="color:{C(colour)};flex-shrink:0;{extra}" ', 1)

def status():
    return (f'<div layer-name="status bar" style="height:54px;flex-shrink:0;padding:{V("spacing-4")} {V("spacing-8")} 0;display:flex;justify-content:space-between;'
            f'font-family:{V("font-text")};font-weight:{V("font-weight-semibold")};font-size:{V("text-body")};line-height:{V("leading-snug")};color:{C("text-primary")}">'
            f'<div>9:41</div><div style="display:flex;gap:{V("spacing-2")};align-items:center"><div style="width:17px;height:11px;border-radius:{V("radius-small")};background:{C("text-primary")}"></div>'
            f'<div style="width:25px;height:12px;border-radius:{V("radius-small")};background:{C("text-primary")}"></div></div></div>')

def home():
    return f'<div layer-name="home indicator" style="position:absolute;left:128px;bottom:8px;width:134px;height:5px;border-radius:{V("radius-control")};background:{C("text-primary")}"></div>'

def mono(text, colour='text-label', size='text-sm', extra=''):
    return f'<div style="font-family:{V("font-mono")};font-size:{V(size)};line-height:{V("leading-snug")};letter-spacing:{V("tracking-label")};color:{C(colour)};{extra}">{text}</div>'

def text(t, size='text-body', colour='text-primary', weight='font-weight-regular', lead='leading-normal', extra=''):
    return f'<div style="font-family:{V("font-text")};font-size:{V(size)};font-weight:{V(weight)};line-height:{V(lead)};color:{C(colour)};{extra}">{t}</div>'

def ink(t, size='text-3xl', track='tracking-title', weight='font-weight-ink-title', colour='text-primary', extra=''):
    return f'<div style="font-family:{V("font-display-inky")};font-weight:{V(weight)};font-size:{V(size)};line-height:{V("leading-tight")};letter-spacing:{V(track)};color:{C(colour)};{extra}">{t}</div>'

def topbar(label='', back=True, skip=False):
    b = (f'<div layer-name="back" style="width:{V("spacing-size-touch-target")};height:{V("spacing-size-touch-target")};display:flex;align-items:center;justify-content:flex-start">'
         + icon('arrow-right', 20, 'icon-muted', 'transform:rotate(180deg)') + '</div>') if back else f'<div style="width:{V("spacing-size-touch-target")}"></div>'
    s = (f'<div layer-name="skip" style="width:{V("spacing-size-touch-target")};height:{V("spacing-size-touch-target")};display:flex;align-items:center;justify-content:flex-end">' + mono('skip') + '</div>') if skip else f'<div style="width:{V("spacing-size-touch-target")}"></div>'
    return (f'<div layer-name="top bar" style="flex-shrink:0;height:{V("spacing-size-nav-bar")};padding:0 {V("spacing-screen-margin")};display:flex;align-items:center;justify-content:space-between">'
            + b + mono(label) + s + '</div>')

def mark(size=38):
    return (f'<div layer-name="the mark" style="width:{size}px;height:{size}px;flex-shrink:0;border-radius:{V("radius-control")};'
            f'background:radial-gradient(circle at 35% 25%, {C("background-raised")} 0%, {C("surface-secondary-action")} 100%);'
            f'box-shadow:inset 0 0 0 1px {C("depth-stroke-inner")}, inset 0 0 0 2px {C("border-secondary-ring")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 6px 12px -6px {C("depth-shadow-cast")}"></div>')

def bars(heights, colour='glow-primary-foreground'):
    return ''.join(f'<div style="width:{V("spacing-size-voice-bar-width")};height:{h}px;border-radius:{V("radius-control")};background:{C(colour)}"></div>' for h in heights)

def talk_button(state='rest'):
    s = V('spacing-size-voice-button')
    if state == 'speaking':
        body = f'background:{C("voice-speaking")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 2px 4px {C("shadow-ink-action-1")}, 0 10px 20px -10px {C("depth-shadow-cast")}'
        inner = f'<div style="display:flex;gap:{V("spacing-size-voice-bar-gap")};align-items:center">{bars([8,16,24,14,6],"text-inverse")}</div>'
    else:
        top, bot = ('glow-primary-gradient-top-lit', 'glow-primary-gradient-bottom-lit') if state == 'listening' else ('glow-primary-gradient-top', 'glow-primary-gradient-bottom')
        body = (f'background:linear-gradient(180deg, {C(top)} 0%, {C(bot)} 100%);'
                f'box-shadow:inset 0 1px 1px {C("glow-primary-rim")}, inset 0 -1.5px 1.5px {C("glow-primary-edge")}, inset 0 0 12px {C("glow-primary-bloom")}, '
                f'0 0 0 2px {C("glow-primary-ring")}, 0 0 16px {C("glow-primary-halo")}, 0 8px 16px -6px {C("depth-tint-primary")}')
        inner = (f'<div style="display:flex;gap:{V("spacing-size-voice-bar-gap")};align-items:center">{bars([10,22,32,18,8])}</div>' if state == 'listening'
                 else icon('mic', 28, 'glow-primary-foreground'))
    ring = (f'<div layer-name="breath ring" style="position:absolute;left:-8px;top:-8px;width:88px;height:88px;border-radius:{V("radius-control")};'
            f'border:{V("spacing-size-border-default")} solid {C("glow-primary-ring")};opacity:{V("opacity-dimmed")}"></div>') if state == 'listening' else ''
    return (f'<div layer-name="talk button ({state})" style="position:relative;width:{s};height:{s};flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;{body}">{ring}{inner}</div>')

def bubble(icon_name, label):
    return (f'<div layer-name="{label}" style="width:64px;display:flex;flex-direction:column;align-items:center;gap:{V("spacing-1")}">'
            f'<div style="width:{V("spacing-size-control-default")};height:{V("spacing-size-control-default")};border-radius:{V("radius-control")};background:{C("surface-wash")};display:flex;align-items:center;justify-content:center">'
            + icon(icon_name, 20, 'icon-default') + '</div>' + mono(label, size='text-xs') + '</div>')

def dock(state='rest', words='your turn', left=('keyboard', 'type'), right=None):
    l = bubble(*left) if left else '<div style="width:64px"></div>'
    r = bubble(*right) if right else '<div style="width:64px"></div>'
    return (f'<div layer-name="talk dock" style="flex-shrink:0;display:flex;flex-direction:column;align-items:center;gap:{V("spacing-3")};padding:{V("spacing-4")} {V("spacing-screen-margin")} {V("spacing-10")}">'
            f'<div style="width:100%;display:flex;align-items:center;justify-content:space-between">{l}{talk_button(state)}{r}</div>'
            + mono(words, 'text-label') + '</div>')

def segmented(options, selected=0, width=220):
    segs = ''
    for i, o in enumerate(options):
        if i == selected:
            segs += (f'<div style="flex:1;height:30px;border-radius:{V("radius-control")};background:{C("background-raised")};display:flex;align-items:center;justify-content:center;'
                     f'box-shadow:inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 3px 6px -2px {C("depth-shadow-cast")}">'
                     + mono(o, 'text-primary') + '</div>')
        else:
            segs += f'<div style="flex:1;height:30px;display:flex;align-items:center;justify-content:center">' + mono(o, 'text-label') + '</div>'
    return (f'<div layer-name="segmented" style="width:{width}px;height:36px;box-sizing:border-box;border:3px solid {C("surface-control")};border-radius:{V("radius-control")};background:{C("surface-control")};display:flex;'
            f'box-shadow:inset 0 1px 2px {C("depth-shadow-sunken")}">{segs}</div>')

def mine(t):
    return (f'<div layer-name="your answer" style="align-self:flex-end;max-width:280px;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-message")};border-bottom-right-radius:{V("radius-small")};background:{C("message-mine")}">'
            + text(t, lead='leading-normal') + '</div>')

def screen(*parts):
    return ''.join(parts) + home()

def progress(frac):
    return (f'<div layer-name="onboarding progress" style="flex-shrink:0;padding:0 {V("spacing-screen-margin")};height:{V("spacing-size-progress")}">'
            f'<div style="height:100%;border-radius:{V("radius-control")};background:{C("surface-track")};overflow:hidden">'
            f'<div style="width:{int(frac*100)}%;height:100%;border-radius:{V("radius-control")};background:{C("ink-default")}"></div></div></div>')

def level(colour, hs=(6, 12, 18, 10, 5)):
    return f'<div layer-name="level" style="display:flex;gap:{V("spacing-size-voice-bar-gap")};align-items:center;flex-shrink:0">' + bars(hs, colour) + '</div>'

def well(icon_name, raised=False):
    bg = (f'background:{C("background-raised")};box-shadow:inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}'
          if raised else f'background:{C("surface-wash")}')
    return (f'<div layer-name="{icon_name} well" style="width:{V("spacing-10")};height:{V("spacing-10")};flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;{bg}">'
            + icon(icon_name, 18, 'icon-default').replace('var(--cut,#F4F2EE)', C('background-field')) + '</div>')

def voice_composer(state='listening', words='', words_line=None):
    """After the current app's onboarding text-question bar (VoiceGoalsPage.inputBar): a pill at rest
    (32 button + 12 inset each side = 56), growing upward; the 32 button sits in the bottom-trailing corner,
    concentric with the 28 radius. Voice-first: that button is mute while listening, send once typed."""
    border = C('voice-listening') if state == 'listening' else C('border-subtle')
    if words:
        body = text(words, lead='leading-snug', extra='flex:1')
    else:
        ph = {'speaking': 'retro is speaking…', 'muted': 'type your answer', 'listening': 'listening…'}[state]
        body = text(ph, colour='text-tertiary', lead='leading-snug', extra='flex:1')
    lead = {'listening': level('voice-listening', (4, 9, 14, 8, 4)), 'speaking': level('voice-speaking', (3, 6, 9, 5, 3))}.get(state, '')
    if state == 'muted' and words:
        btn = (f'<div layer-name="send" style="width:{V("spacing-size-control-small")};height:{V("spacing-size-control-small")};flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;background:{C("accent-default")}">'
               + icon('send', 16, 'text-on-accent') + '</div>')
    else:
        btn = (f'<div layer-name="{"mic" if state == "muted" else "mute"}" style="width:{V("spacing-size-control-small")};height:{V("spacing-size-control-small")};flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;background:{C("surface-control")}">'
               + icon('mic' if state == 'muted' else 'mic-off', 16, 'icon-default').replace('var(--cut,#F4F2EE)', C('surface-control')) + '</div>')
    return (f'<div layer-name="voice composer ({state})" style="flex-shrink:0;padding:{V("spacing-4")} {V("spacing-screen-margin")} {V("spacing-10")}">'
            f'<div layer-name="bar" style="display:flex;align-items:flex-end;gap:{V("spacing-3")};padding:{V("spacing-3")} {V("spacing-3")} {V("spacing-3")} {V("spacing-5")};'
            f'border-radius:{V("radius-composer")};background:{C("background-raised")};border:{V("spacing-size-border-default")} solid {border};'
            f'box-shadow:0 4px 8px {C("depth-shadow-cast")}">'
            f'<div style="flex:1;min-height:{V("spacing-size-control-small")};display:flex;align-items:center;gap:{V("spacing-3")}">' + lead + body + '</div>'
            + btn + '</div></div>')
def lit_button(label, height='spacing-size-control-hero', extra=''):
    return (f'<div layer-name="lit · {label}" style="height:{V(height)};border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;'
            f'background:linear-gradient(180deg, {C("glow-primary-gradient-top")} 0%, {C("glow-primary-gradient-bottom")} 100%);'
            f'box-shadow:inset 0 1px 1px {C("glow-primary-rim")}, inset 0 -1.5px 1.5px {C("glow-primary-edge")}, inset 0 0 12px {C("glow-primary-bloom")}, 0 0 0 2px {C("glow-primary-ring")}, 0 0 16px {C("glow-primary-halo")}, 0 8px 16px -6px {C("depth-tint-primary")};{extra}">'
            + text(label, 'text-body', 'text-on-accent', 'font-weight-semibold', 'leading-snug') + '</div>')

def raised_button(label, height='spacing-size-control-hero', extra=''):
    return (f'<div layer-name="secondary · {label}" style="height:{V(height)};border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;background:{C("surface-secondary-action")};'
            f'box-shadow:inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 8px 16px -8px {C("depth-shadow-cast")};{extra}">'
            + text(label, 'text-body', 'text-primary', 'font-weight-medium', 'leading-snug') + '</div>')

def ink_button(label, height='spacing-size-control-hero', extra=''):
    return (f'<div layer-name="ink · {label}" style="height:{V(height)};border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;background:{C("ink-default")};'
            f'box-shadow:0 2px 4px {C("shadow-ink-action-1")};{extra}">' + text(label, 'text-body', 'text-inverse', 'font-weight-medium', 'leading-snug') + '</div>')

def compact_play(size='spacing-size-control-default', icon_size=18):
    return (f'<div layer-name="play (lit)" style="width:{V(size)};height:{V(size)};flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;'
            f'background:linear-gradient(180deg, {C("glow-primary-gradient-top")} 0%, {C("glow-primary-gradient-bottom")} 100%);'
            f'box-shadow:inset 0 1px 1px {C("glow-primary-rim")}, inset 0 -1.5px 1.5px {C("glow-primary-edge")}, inset 0 0 10px {C("glow-primary-bloom")}, 0 0 0 1.5px {C("glow-primary-ring")}, 0 6px 12px -6px {C("depth-tint-primary")}">'
            + icon('play', icon_size, 'glow-primary-foreground', 'margin-left:1.5px') + '</div>')

def card(inner, extra=''):
    return (f'<div style="border-radius:{V("radius-card")};background:{C("background-raised")};padding:{V("spacing-5")};'
            f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 6px 16px -8px {C("depth-shadow-cast")};{extra}">{inner}</div>')

def tabbar(selected='journal'):
    items = ''
    for t in ['journal', 'podcasts', 'goals', 'you']:
        on = t == selected
        items += (f'<div layer-name="tab · {t}" style="width:72px;display:flex;flex-direction:column;align-items:center;gap:{V("spacing-1")}">'
                  + icon(t, 22, 'icon-default' if on else 'icon-muted') + mono(t, 'text-primary' if on else 'text-label', 'text-xs') + '</div>')
    return (f'<div layer-name="tab bar" style="flex-shrink:0;height:83px;box-sizing:border-box;padding:{V("spacing-2")} {V("spacing-6")} 0;display:flex;justify-content:space-between;'
            f'background:{C("background-canvas")};border-top:{V("spacing-size-border-hairline")} solid {C("border-subtle")}">{items}</div>')

def scrubber(frac, left='0:31', right='4:58'):
    return (f'<div layer-name="scrubber" style="display:flex;flex-direction:column;gap:{V("spacing-2")}">'
            f'<div style="position:relative;height:{V("spacing-size-player-scrubber")};border-radius:{V("radius-control")};background:{C("surface-track")}">'
            f'<div style="width:{int(frac*100)}%;height:100%;border-radius:{V("radius-control")};background:{C("player-progress")}"></div>'
            f'<div style="position:absolute;left:calc({int(frac*100)}% - 6px);top:-4px;width:{V("spacing-size-player-thumb")};height:{V("spacing-size-player-thumb")};border-radius:{V("radius-control")};background:{C("surface-thumb")};box-shadow:0 0 0 0.5px {C("depth-stroke-outer")}, 0 2px 5px {C("shadow-thumb-1")}"></div></div>'
            f'<div style="display:flex;justify-content:space-between">{text(left, "text-sm", "text-label", lead="leading-snug")}{text(right, "text-sm", "text-label", lead="leading-snug")}</div></div>')

def transport(playing=True):
    mid = (f'<div layer-name="play/pause" style="width:{V("spacing-size-player-button")};height:{V("spacing-size-player-button")};border-radius:{V("radius-control")};background:{C("ink-default")};display:flex;align-items:center;justify-content:center;box-shadow:0 2px 4px {C("shadow-ink-action-1")}, 0 10px 20px -10px {C("depth-shadow-cast")}">'
           + icon('pause' if playing else 'play', 26, 'text-inverse') + '</div>')
    return (f'<div layer-name="transport" style="display:flex;align-items:center;justify-content:center;gap:{V("spacing-10")}">'
            + icon('skip-back-15', 28, 'icon-default') + mid + icon('skip-forward-30', 28, 'icon-default') + '</div>')

def artwork(size=48, radius='radius-default'):
    return (f'<div layer-name="artwork" style="width:{size}px;height:{size}px;flex-shrink:0;border-radius:{V(radius)};overflow:hidden;'
            f'background:radial-gradient(ellipse 90% 70% at 20% 0%, {C("sky-200")} 0%, transparent 100%), radial-gradient(ellipse 70% 60% at 100% 30%, {C("amber-200")} 0%, transparent 100%), radial-gradient(ellipse 100% 80% at 60% 100%, {C("sky-700")} 0%, transparent 100%), {C("sky-500")};'
            f'box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 6px 12px -6px {C("depth-tint-artwork")}"></div>')
