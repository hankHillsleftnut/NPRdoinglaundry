# ON-12 paywall benefit rows, founder 20 Oct (c-fhi7m4): "add search, and then make the illustrations more detailed".
# Six rows now (search added third), each tile a small, more detailed drawing of the feature. Rows tighten to
# spacing-2 so all six fit above the plan pair on a 17 Pro. Writes p53_paywall_benefits.html.
from review import V, C

def tile(art, bg=None, raised=True):
    bg = bg or f'background-color:{C("background-raised")};'
    rim = f'{C("depth-stroke-inner-top")} 0px 1px 0px inset' if raised else f'{C("glow-primary-rim")} 0px 1px 0px inset'
    return (f'<div layer-name="illustration" style="position:relative;width:56px;height:56px;flex-shrink:0;overflow:clip;border-radius:{V("radius-panel")};{bg}'
            f'box-shadow:{rim}, {C("depth-stroke-outer")} 0px 0px 0px 0.5px, {C("depth-shadow-cast")} 0px 6px 14px -6px">'
            f'<svg width="56" height="56" viewBox="0 0 56 56" xmlns="http://www.w3.org/2000/svg" style="position:absolute;left:0;top:0">{art}</svg></div>')

def row(t, title, sub):
    return (f'<div layer-name="c:benefit-row" style="display:flex;align-items:center;gap:{V("spacing-4")};padding-block:{V("spacing-2")}">{t}'
            f'<div style="display:flex;flex-direction:column;flex:1 1 0%;min-width:0;gap:{V("spacing-size-border-ring")}">'
            f'<div style="font-family:{V("font-text")};font-size:{V("text-body")};font-weight:{V("font-weight-medium")};letter-spacing:{V("tracking-card")};line-height:{V("leading-snug")};color:{C("text-primary")}">{title}</div>'
            f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};font-weight:{V("font-weight-regular")};line-height:{V("leading-snug")};color:{C("text-secondary")}">{sub}</div></div></div>')

# 1 · the morning brief: a sun coming up over the day's line, the time, a voice already talking
brief_bg = (f'background-color:{C("sky-500")};background-image:radial-gradient(circle farthest-corner at 80% 30% in oklab, {C("amber-300")} 0%, #00000000 45%), '
            f'radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("sky-800")} 0%, #00000000 80%);')
brief = (f'<circle cx="38" cy="25" r="11" fill="{C("amber-200")}" fill-opacity="0.35"/><circle cx="38" cy="25" r="6.5" fill="{C("amber-200")}"/>'
         f'<path d="M0 33C10 29 18 31 28 33S46 36 56 31V56H0Z" fill="{C("sky-800")}" fill-opacity="0.55"/>'
         f'<path d="M0 33C10 29 18 31 28 33S46 36 56 31" fill="none" stroke="{C("text-inverse")}" stroke-width="0.75" stroke-opacity="0.7"/>'
         + ''.join(f'<rect x="{34 + i * 3.4:.1f}" y="{48 - h}" width="1.8" height="{h}" rx="0.9" fill="{C("text-inverse")}"/>' for i, h in enumerate([3, 6, 4, 8, 5, 3]))
         + f'<text x="7" y="50" font-family="{V("font-mono")}" font-size="9" fill="{C("text-inverse")}">8:30</text>')

# 2 · your life, connected: you in the middle, rings, people/places/goals at different weights, a couple of cross-links
nodes = [(13, 16, 4.5, 'person'), (43, 13, 3.5, 'theme'), (46, 35, 3, 'place'), (15, 42, 4, 'goal'), (31, 9, 2, 'person'), (8, 29, 2, 'place'), (36, 47, 2.5, 'goal')]
conn = (f'<circle cx="28" cy="28" r="12" fill="none" stroke="{C("map-edge")}" stroke-width="0.5"/>'
        f'<circle cx="28" cy="28" r="21" fill="none" stroke="{C("map-edge")}" stroke-width="0.5" stroke-dasharray="1.5 2"/>'
        + ''.join(f'<path d="M28 28L{x} {y}" stroke="{C("map-edge")}" stroke-width="{0.5 + r / 6:.2f}"/>' for x, y, r, _ in nodes)
        + f'<path d="M13 16L31 9M46 35L36 47M15 42L8 29" stroke="{C("map-edge")}" stroke-width="0.5" stroke-dasharray="1 1.5"/>'
        + ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{C("map-node-" + k)}"/>' for x, y, r, k in nodes)
        + f'<circle cx="28" cy="28" r="10" fill="{C("map-node-self")}" fill-opacity="0.18"/><circle cx="28" cy="28" r="6" fill="{C("map-node-self")}"/>'
        + f'<circle cx="26" cy="26" r="2" fill="{C("text-inverse")}" fill-opacity="0.6"/>')
conn_bg = f'background-color:{C("background-raised")};background-image:radial-gradient(circle farthest-corner at 50% 50% in oklab, {C("sky-100")} 0%, #00000000 70%);'

# 3 · ask anything (new): a question in the field, a written answer, the sources it came from
search = (f'<rect x="6" y="7" width="44" height="12" rx="6" fill="{C("surface-wash")}"/>'
          f'<circle cx="12.5" cy="12.6" r="2.3" fill="none" stroke="{C("text-secondary")}" stroke-width="1"/><path d="M14.2 14.3L15.8 15.9" stroke="{C("text-secondary")}" stroke-width="1" stroke-linecap="round"/>'
          f'<rect x="19" y="11.5" width="18" height="2.2" rx="1.1" fill="{C("text-tertiary")}"/><rect x="38.5" y="9.5" width="1" height="6.5" fill="{C("accent-default")}"/>'
          f'<rect x="8" y="25" width="38" height="3" rx="1.5" fill="{C("ink-default")}"/><rect x="8" y="31" width="30" height="3" rx="1.5" fill="{C("ink-default")}"/>'
          f'<rect x="8" y="37" width="20" height="3" rx="1.5" fill="{C("border-strong")}"/>'
          f'<rect x="8" y="44" width="13" height="6" rx="3" fill="{C("map-node-person")}" fill-opacity="0.35"/><circle cx="11" cy="47" r="1.5" fill="{C("map-node-person")}"/>'
          f'<rect x="23" y="44" width="13" height="6" rx="3" fill="{C("map-node-place")}" fill-opacity="0.35"/><circle cx="26" cy="47" r="1.5" fill="{C("map-node-place")}"/>'
          f'<rect x="38" y="44" width="10" height="6" rx="3" fill="{C("map-node-goal")}" fill-opacity="0.35"/><circle cx="41" cy="47" r="1.5" fill="{C("map-node-goal")}"/>')

# 4 · on track: this week's days, three goals with their own colour and progress, a check where one landed
days = ''.join(f'<circle cx="{9 + i * 4.6:.1f}" cy="11" r="1.6" fill="{C("ink-default" if i < 5 else "border-strong")}"/>' for i in range(7))
goals = ''.join(f'<circle cx="10" cy="{y + 2}" r="2.5" fill="{C("map-node-" + k)}"/><rect x="16" y="{y}" width="31" height="4" rx="2" fill="{C("border-subtle")}"/>'
                f'<rect x="16" y="{y}" width="{w}" height="4" rx="2" fill="{C("accent-default" if k != "goal" else "status-success")}"/>'
                for y, k, w in [(22, 'goal', 31), (32, 'person', 17), (42, 'place', 23)])
track = days + goals + (f'<circle cx="46" cy="11" r="5.5" fill="{C("status-success")}"/>'
                        f'<path d="M43.6 11.2L45.4 13L48.4 9.6" fill="none" stroke="{C("text-inverse")}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>')

# 5 · the weekly podcast: sunday-evening artwork, the play button, the episode's waveform
pod_bg = (f'background-color:{C("night-800")};background-image:radial-gradient(ellipse 110% 120% at 92% 0% in oklab, {C("amber-200")} 0%, #00000000 55%), '
          f'radial-gradient(ellipse 90% 90% at 55% 40% in oklab, color-mix(in oklab, {C("amber-600")} 70%, #00000000) 0%, #00000000 100%), '
          f'radial-gradient(ellipse 100% 100% at 0% 100% in oklab, {C("night-950")} 0%, #00000000 90%);')
pod = (f'<circle cx="28" cy="23" r="11" fill="{C("alpha-white12")}" stroke="{C("glow-primary-rim")}" stroke-width="0.5"/>'
       f'<path d="M25 18.5v9a.7.7 0 0 0 1.05.6l7.6-4.5a.7.7 0 0 0 0-1.2l-7.6-4.5A.7.7 0 0 0 25 18.5Z" fill="{C("text-inverse")}"/>'
       + ''.join(f'<rect x="{8 + i * 3.6:.1f}" y="{46 - h / 2:.1f}" width="1.8" height="{h}" rx="0.9" fill="{C("text-inverse")}" fill-opacity="{0.9 if i < 6 else 0.4}"/>'
                 for i, h in enumerate([3, 5, 8, 6, 10, 7, 4, 8, 5, 9, 4, 3])))

# 6 · a journal that talks back: what you said, its question back, the mic ready for your answer
journal = (f'<rect x="20" y="8" width="28" height="11" rx="5.5" fill="{C("ink-default")}"/><rect x="24" y="12.5" width="16" height="2" rx="1" fill="{C("text-inverse")}" fill-opacity="0.7"/>'
           f'<rect x="7" y="23" width="33" height="15" rx="6" fill="{C("accent-subtle")}"/>'
           f'<rect x="11" y="27" width="24" height="2.2" rx="1.1" fill="{C("accent-text")}"/><rect x="11" y="32" width="15" height="2.2" rx="1.1" fill="{C("accent-text")}"/>'
           f'<circle cx="13" cy="46" r="6" fill="{C("accent-default")}"/><rect x="11.6" y="42.5" width="2.8" height="5" rx="1.4" fill="{C("text-inverse")}"/>'
           f'<path d="M10.5 46.2a2.5 2.5 0 0 0 5 0M13 48.7v1.3" fill="none" stroke="{C("text-inverse")}" stroke-width="0.8" stroke-linecap="round"/>'
           + ''.join(f'<circle cx="{24 + i * 4}" cy="46" r="1.3" fill="{C("text-tertiary")}"/>' for i in range(3)))

rows = [
    row(tile(brief, brief_bg, raised=False), 'wake up to what moved', 'a 4-minute brief, made from yesterday'),
    row(tile(conn, conn_bg), 'see your life, connected', 'the people and threads you return to'),
    row(tile(search), 'ask your life anything', 'answers from your days, with sources'),
    row(tile(track), "know if you're on track", 'your goals, checked against your real days'),
    row(tile(pod, pod_bg, raised=False), 'a podcast about your week', 'every sunday, like the one you just heard'),
    row(tile(journal), 'a journal that talks back', "talk or type; it asks what's next"),
]
html = (f'<div layer-name="benefits · scroll" style="display:flex;flex-direction:column;padding-inline:{V("spacing-screen-margin")}">' + ''.join(rows) + '</div>')
if __name__ == '__main__':
    open('p53_paywall_benefits.html', 'w').write(html)
