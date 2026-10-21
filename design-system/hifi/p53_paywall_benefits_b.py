# ON-12 paywall benefit tiles, take 2. Founder 20 Oct (c-nroyoq): "these images are too detailed, use more from the
# design system, a little less detailed but much more elegant". Each tile is now one thing from the system: the
# feature's own icon from the shipped set (design-system/icons/shipped), at 26pt on a raised tile, and the two
# features that have artwork (the brief, the weekly episode) sit on their real artwork meshes. Writes p53_paywall_tiles.html.
import re
from review import V, C

def icon(name, colour, size=26):
    svg = open(f'../icons/shipped/{name}.svg').read()
    inner = re.search(r'<svg[^>]*>(.*)</svg>', svg, re.S).group(1).replace('currentColor', C(colour))
    off = (56 - size) / 2
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
            f'style="position:absolute;left:{off}px;top:{off}px">{inner}</svg>')

RAISED = f'background-color:{C("background-raised")};'
MORNING = (f'background-color:{C("sky-500")};background-image:radial-gradient(circle farthest-corner at 85% 10% in oklab, {C("amber-300")} 0%, #00000000 55%), '
           f'radial-gradient(circle farthest-corner at 0% 100% in oklab, {C("sky-800")} 0%, #00000000 80%);')
EVENING = (f'background-color:{C("night-800")};background-image:radial-gradient(ellipse 110% 120% at 92% 0% in oklab, {C("amber-200")} 0%, #00000000 55%), '
           f'radial-gradient(ellipse 100% 100% at 0% 100% in oklab, {C("night-950")} 0%, #00000000 90%);')

def tile(name, colour, bg=RAISED, art=False):
    rim = f'{C("glow-primary-rim")} 0px 1px 0px inset' if art else f'{C("depth-stroke-inner-top")} 0px 1px 0px inset'
    return (f'<div layer-name="illustration · {name}" style="position:relative;width:56px;height:56px;flex-shrink:0;overflow:clip;border-radius:{V("radius-panel")};{bg}'
            f'box-shadow:{rim}, {C("depth-stroke-outer")} 0px 0px 0px 0.5px, {C("depth-shadow-cast")} 0px 6px 14px -6px">{icon(name, colour)}</div>')

TILES = {
    'brief': tile('brief', 'text-inverse', MORNING, art=True),
    'you': tile('you', 'text-primary'),
    'search': tile('search', 'text-primary'),
    'goals': tile('goals', 'text-primary'),
    'podcasts': tile('podcasts', 'text-inverse', EVENING, art=True),
    'journal': tile('journal', 'text-primary'),
}
if __name__ == '__main__':
    open('p53_paywall_tiles.html', 'w').write('\n'.join(f'<!-- {k} -->{v}' for k, v in TILES.items()))
