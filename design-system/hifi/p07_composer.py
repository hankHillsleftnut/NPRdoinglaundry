from review import *
import json
# Part 07 · voice composer · four states (M2, Journal composer). True 1×, dashed 44 hit guides, inspect by 3× screenshot.
# Spec: components/voice-composer.md. 56 pill (32 control + 12 inset), radius.composer 28 (concentric: 28 − 12 = 16 = the 32 button's radius),
# raised, 1pt hairline that turns voice.listening only while listening; never glows; send is lit (founder, 20 Oct, overrides composer rule 3).
O = json.load(open('../icons/outlined-20.json'))
def icon(n, colour, size=18):
    return (f'<svg layer-name="c:icon/{n}" width="{size}" height="{size}" viewBox="0 0 24 24" style="display:inline-block;flex-shrink:0">'
            f'<path fill="{C(colour)}" fill-rule="evenodd" d="{O[n]}"/></svg>')
def button(n, tier, colour='icon-default'):
    look = {'wash': f'background:{C("surface-wash")};',
            'raised': f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 1.5px {C("depth-shadow-contact")}, 0 4px 8px -3px {C("depth-shadow-cast")};',
            # founder 20 Oct (c-fjtbto, "this button needs color"): send is lit, the brief-card play recipe scaled to 32
            'lit': f'background-image:linear-gradient(180deg, {C("glow-primary-gradient-top")}, {C("glow-primary-gradient-bottom")});box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, inset 0 -1px 1.5px {C("glow-primary-edge")}, inset 0 0 4px {C("glow-primary-bloom")}, 0 0 0 1px {C("glow-primary-ring")}, 0 4px 10px -3px {C("glow-primary-halo")}, 0 1px 1.5px {C("glow-primary-cast")};'}[tier]
    guide = f'<div layer-name="hit area 44" style="position:absolute;left:-6px;top:-6px;width:44px;height:44px;outline:1px dashed {C("text-link")};outline-offset:-1px"></div>'
    return (f'<div layer-name="c:icon-button/{tier}/{n}" style="position:relative;width:32px;height:32px;flex-shrink:0;border-radius:{V("radius-control")};{look}display:flex;align-items:center;justify-content:center">'
            f'{icon(n, colour)}{guide}</div>')
def bars(colour, heights=(8, 14, 20, 12, 6)):
    return (f'<div layer-name="level" style="display:flex;align-items:center;gap:{V("spacing-size-voice-bar-gap")};height:20px;flex-shrink:0">'
            + ''.join(f'<div style="width:{V("spacing-size-voice-bar-width")};height:{h}px;border-radius:{V("radius-control")};background:{C(colour)}"></div>' for h in heights) + '</div>')
def text(s, colour='text-primary', w=None):
    return f'<div style="{f"width:{w}px;flex-shrink:0;" if w else "flex:1;min-width:0;"}font-family:{V("font-text")};font-size:{V("text-body")};letter-spacing:{V("tracking-card")};line-height:{V("leading-snug")};color:{C(colour)}">{s}</div>'
# Synced from the approved master (02 · components, c · voice composer, 20 Oct): raised white with the full depth stack in every
# state; listening adds a sky wash, the 1.5 listening hairline, a 4pt glow ring and a soft halo (founder: "more alive… like a glow").
RAISED_STACK = (f'inset 0 1px 0 {C("depth-stroke-inner-top")}, inset 0 0 0 1px {C("depth-stroke-inner")}, 0 0 0 0.5px {C("depth-stroke-outer")}, '
                f'0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}, 0 24px 60px -20px {C("depth-shadow-ambient")}')
# founder 20 Oct (c-qicsx0, "make this whole active listening state more elegant"): no hard 4pt ring; one fine 1pt
# listening line and a soft blue halo that settles below the bar
# founder 20 Oct (c-mi7i0c, third pass): no solid outline at all; a fine 0.5pt glow.primary.ring edge and an even soft halo all round
LISTEN_STACK = (f'inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("glow-primary-ring")}, '
                f'0 1px 2px {C("depth-shadow-contact")}, 0 0 24px -6px {C("glow-primary-halo")}')
def bar(name, inner, listening=False, extra_shadow=''):
    # founder 20 Oct (c-j2mszl): "the blue inside the card doesnt feel good" — no sky wash inside; the glow stays outside
    look = (f'background:{C("background-raised")};box-shadow:{LISTEN_STACK}'
            if listening else f'background:{C("background-raised")};box-shadow:{extra_shadow}{RAISED_STACK}')
    return (f'<div layer-name="c:voice-composer/{name}" style="width:342px;min-height:56px;flex-shrink:0;box-sizing:border-box;display:flex;align-items:flex-end;gap:{V("spacing-3")};'
            f'padding:{V("spacing-3")} {V("spacing-3")} {V("spacing-3")} {V("spacing-5")};border-radius:{V("radius-composer")};{look}">'
            f'<div style="flex:1;min-width:0;min-height:32px;display:flex;align-items:center;gap:{V("spacing-3")}">{inner[0]}</div>{inner[1]}</div>')
# the dashed 44 guide sits 6 outside the 32 button: the visual stays 32 and the pill stays 56; the guide shows the real tap area
LISTEN = bar('listening', (bars('voice-listening') + text('listening…', 'text-tertiary'), button('mic-off', 'wash')), listening=True)
SPEAK = bar('speaking', (bars('voice-speaking', (5, 10, 16, 10, 5)) + text('retro is speaking…', 'text-tertiary'), button('mic-off', 'wash')))
MUTED = bar('muted-empty', (text('message retro…', 'text-tertiary'), button('mic', 'wash')))
TYPING = bar('muted-typing', (text('i think it\'s the 9am standup. i dread it, every week.', w=266), button('send', 'lit', 'glow-primary-foreground')))
vis = (tile(LISTEN, 'listening · your turn: the hairline turns sky (1.5), five bars; your words stream onto the page, not into the bar')
       + tile(SPEAK, 'speaking · retro\'s turn: no ring, the bars in ink; tap anywhere to interrupt')
       + tile(MUTED, 'muted, empty · the well shows mic (tap to talk again); keyboard up')
       + tile(TYPING, 'muted, typing · grows upward; the button becomes send, lit'))
open('p07_tiles.html', 'w').write(vis)
