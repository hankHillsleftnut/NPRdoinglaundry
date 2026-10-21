from review import *
import importlib.util
# M3 · brief card D · every state, built from the approved part 03 D recipe (p03_briefcard.py), placed inside part 03.
# Founder 20 Oct: "I still prefer this" — the card stays the same while playing; the mini-player and sheet carry playback.
def load(n, f):
    s = importlib.util.spec_from_file_location(n, f); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
p03 = load('p03', 'p03_briefcard.py'); p30 = load('p30', 'p30_message_states.py')
icon, headline, body, RAISED, column = p03.icon, p03.headline, p03.body, p03.RAISED, p30.column
H = p03.H
MESH = (f'background-color:{C("sky-500")};background-image:radial-gradient(circle farthest-corner at 85% 10% in oklab, {C("amber-300")} 0%, transparent 55%), '
        f'radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("sky-800")} 0%, transparent 80%)')
def label(s, colour, on_art=False):
    return (f'<div style="font-family:{V("font-label")};font-weight:{V("font-weight-medium")};font-size:{V("text-sm")};line-height:{V("leading-snug")};'
            f'color:{C("glow-primary-foreground" if on_art else colour)}">{s}</div>')
def lit(pressed=False):
    top, bot = ('glow-primary-gradient-top-pressed', 'glow-primary-gradient-bottom-pressed') if pressed else ('glow-primary-gradient-top', 'glow-primary-gradient-bottom')
    return (f'<div layer-name="c:button/lit/play{"/pressed" if pressed else ""}" style="width:44px;height:44px;flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;'
            f'background:linear-gradient(180deg, {C(top)}, {C(bot)});'
            f'box-shadow:inset 0 1px 0 {C("glow-primary-rim")}, inset 0 -1px 1.5px {C("glow-primary-edge")}, inset 0 0 6px {C("glow-primary-bloom")}, 0 0 0 1.5px {C("glow-primary-ring")}, 0 6px 14px -4px {C("glow-primary-halo")}, 0 2px 2px {C("glow-primary-cast")}">'
            f'{icon("play", 18, C("glow-primary-foreground"))}</div>')
def raised_well(glyph):
    return (f'<div layer-name="c:button/raised/{glyph}" style="width:44px;height:44px;flex-shrink:0;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;'
            f'background:{C("background-raised")};box-shadow:inset 0 1px 0 {C("depth-stroke-inner-top")}, 0 0 0 0.5px {C("depth-stroke-outer")}, 0 1px 2px {C("depth-shadow-contact")}, 0 6px 14px -6px {C("depth-shadow-cast")}">'
            f'{icon(glyph, 18, C("icon-default"))}</div>')
def pending_play():
    # the play with a quarter ring turning around it while the audio starts (the ring is drawn as a stroked arc, accent.border)
    ring = (f'<svg layer-name="turning ring" width="56" height="56" viewBox="0 0 56 56" style="position:absolute;left:-6px;top:-6px">'
            f'<circle cx="28" cy="28" r="26" fill="none" stroke="{C("accent-border")}" stroke-width="2" stroke-linecap="round" stroke-dasharray="40 200"/></svg>')
    return f'<div style="position:relative;width:44px;height:44px">{lit()}{ring}</div>'
def art(top_label, corner=None, look=MESH):
    c = f'<div style="position:absolute;right:{V("spacing-4")};bottom:-22px">{corner}</div>' if corner else ''
    on_art = look == MESH
    return (f'<div layer-name="artwork" style="height:132px;border-radius:{V("radius-panel")};position:relative;{look}">'
            f'<div style="position:absolute;left:{V("spacing-4")};top:{V("spacing-3")}">{label(top_label, "text-label", on_art)}</div>{c}</div>')
def card(name, artwork, inner, extra=''):
    return (f'<div layer-name="c:brief-card/artwork/{name}" style="width:342px;display:flex;flex-direction:column;gap:{V("spacing-3")};padding:{V("spacing-2")};{RAISED};{extra}">'
            f'{artwork}<div style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-2")}">{inner}</div></div>')
WASH = f'background:{C("surface-wash")}'
SKEL = f'background:{C("surface-skeleton")}'
def bar(w):
    return f'<div style="width:{w}px;height:20px;border-radius:{V("radius-control")};{SKEL}"></div>'
def pill(t, glyph):
    return (f'<div layer-name="c:pill/neutral/rest" style="align-self:flex-start;height:36px;display:flex;align-items:center;gap:{V("spacing-2")};padding:0 {V("spacing-4")};border-radius:{V("radius-control")};{WASH}">'
            f'{icon(glyph, 16, C("icon-default"))}<div style="width:max-content;font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};line-height:{V("leading-snug")};color:{C("text-primary")}">{t}</div></div>')
SUB = 'Your sister, the job question, and a quieter Sunday.'
quiet_headline = (f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};'
                  f'letter-spacing:{V("tracking-card")};color:{C("text-secondary")}">{H}</div>')
AX3_HEAD = (f'<div layer-name="headline" style="width:310px;font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-ax3-xl")};'
            f'line-height:{V("leading-ax3-xl")};letter-spacing:{V("tracking-card")};color:{C("text-primary")}">{H}</div>')

# every line grows at AX3, not only the headline (caught at 1×): subline → ax3.md, the date label → ax3.sm
AX3_SUB = f'<div style="width:310px;font-family:{V("font-text")};font-size:{V("text-ax3-md")};line-height:{V("leading-ax3-md")};color:{C("text-secondary")}">{SUB}</div>'
AX3_LABEL = 'tue 21 oct · 2 min'
cols = [
    column('pressed · play', card('pressed', art('tue 21 oct · 2 min', lit(True)), headline(H) + body(SUB)),
           'Touching play: the glow deepens to its pressed shade (and it shrinks a touch, which Paper can\'t show). The card itself stays still.'),
    column('starting', card('pending', art('tue 21 oct · 2 min', pending_play()), headline(H) + body(SUB)),
           'If the audio takes a moment to start, a thin ring turns around the play. Nothing else moves.'),
    column('played', card('played', art('tue 21 oct · played', raised_well('retry')), quiet_headline + body(SUB)),
           "Once heard: the headline steps back a shade, the corner says played, and the play becomes a quiet replay with no glow."),
    column('quiet day', card('quiet', art('tue 21 oct', look=WASH), headline('nothing much moved. enjoy the quiet.')),
           "When there's nothing worth saying, the card says so in one line. No artwork colours, no play."),
    column('being made', card('making', art('tue 21 oct', look=SKEL), bar(260) + bar(180) + label('your brief is being made · ready by 8:30', 'text-label')),
           'Before it\'s ready: the shapes of the headline shimmer softly, and one line says when it will be ready. No play yet.'),
    column("couldn't load", card('error', art('tue 21 oct', look=WASH), label("couldn't load today's brief", 'status-danger-text') + pill('try again', 'retry')),
           "If loading fails: one plain line and a quiet try-again pill. Nothing red except the words."),
    column('offline', card('offline', art('tue 21 oct', look=WASH), label("it'll be here when you're back online", 'text-label')),
           "No connection and not downloaded yet: it says when it'll appear. A brief that was downloaded just plays."),
    column('largest text (accessibility 3)', card('ax3', art(AX3_LABEL), AX3_HEAD + AX3_SUB + lit()),
           'At the largest text the headline wraps over several lines at 44, and the play moves under the words so it never covers them.'),
    column('increase contrast', card('contrast', art('tue 21 oct · 2 min', lit()), headline(H) + body(SUB), extra=f'box-shadow:inset 0 0 0 1px {C("border-control")}, 0 1px 2px {C("depth-shadow-contact")}, 0 12px 28px -12px {C("depth-shadow-cast")}'),
           'With Increase Contrast on, the card gets a 1pt control edge, so its shape holds without relying on the shadow.'),
]
NOT = (f'<div layer-name="states not drawn, and why" style="width:390px;display:flex;flex-direction:column;gap:{V("spacing-2")}">'
       f'<div style="font-family:{V("font-label")};font-size:{V("text-md")};font-weight:{V("font-weight-medium")};color:{C("text-primary")}">not drawn, and why</div>'
       + ''.join(f'<div style="width:390px;font-family:{V("font-text")};font-size:{V("text-md")};line-height:{V("leading-normal")};color:{C("text-secondary")}">{s}</div>' for s in [
           'playing: the card stays exactly as it is (your call, 20 Oct: "I still prefer this"). The mini-player and the sheet show playback.',
           'pressed (card body): the card only shrinks a touch, which Paper can\'t show.',
           'focused: iOS draws the Full Keyboard Access ring itself (your call, 20 Oct).',
           'disabled: a card that can\'t play shows quiet day, being made, couldn\'t load or offline instead.',
           'reduce motion: changes cross-fade in 140ms; reduce transparency: the card is opaque, so nothing changes.',
           'dark: drawn in M12 with the dark token pairs.']) + '</div>')
open('p32_briefcard_states.html', 'w').write(
    f'<div layer-name="states grid" style="display:flex;flex-wrap:wrap;gap:{V("spacing-10")};align-items:flex-start;width:1720px">' + ''.join(cols) + NOT + '</div>')
