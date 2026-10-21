from review import *
G = '<rect x="3.25" y="5.25" width="17.5" height="13.5" rx="3"/><path d="M9.25 5.25v13.5"/>'
J = '<rect x="5.25" y="3.75" width="13.5" height="16.5" rx="3"/><path d="M8.75 8.5h6.5M8.75 12h6.5M8.75 15.5h3.75"/>'
def big(glyph, key):
    grid = (f'<rect x="2" y="2" width="20" height="20" fill="none" stroke="{C("border-strong")}" stroke-width="0.06"/>' + key
            + f'<line x1="12" y1="0" x2="12" y2="24" stroke="{C("border-subtle")}" stroke-width="0.04"/><line x1="0" y1="12" x2="24" y2="12" stroke="{C("border-subtle")}" stroke-width="0.04"/>')
    return (f'<svg width="192" height="192" viewBox="0 0 24 24" style="background:{C("background-raised")};border-radius:{V("radius-default")}">' + grid
            + f'<g fill="none" stroke="{C("icon-default")}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{glyph}</g></svg>')
def small(glyph, px, col='icon-default', sw='1.75'):
    return f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" fill="none" stroke="{C(col)}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{glyph}</svg>'
dash = lambda x, y, w, h: f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none" stroke="{C("text-link")}" stroke-width="0.06" stroke-dasharray="0.3 0.3"/>'
vis = (tile(big(G, dash(2, 4, 20, 16)), '4× · landscape keyline 20 × 16 · stroke 0.375 inside it')
       + tile(big(J, dash(4, 2, 16, 20)), '4× · journal, portrait 16 × 20 · the weight to match')
       + tile(f'<div style="display:flex;gap:{V("spacing-6")};align-items:center;height:48px">' + small(G, 24) + small(J, 24) + small(G, 16, 'icon-muted', '2') + '</div>', '1× · drawer · journal · drawer at 16 (stroke 2)'))
rows = {
 'purpose': ('✓', 'opens all journals; nothing else on the top bar says that, so it earns its place'),
 'colour': ('✓', 'currentColor → icon.default (paper.900) at rest; icon.muted at 16'),
 'type': ('—', 'no text'),
 'space': ('✓', 'on the 24 grid, 20 live area, 2 padding'),
 'shape': ('✓', 'rx 3, the same as journal, so the set reads as one family; round caps and joins'),
 'depth': ('—', 'a glyph has no tier; its button decides (part 02)'),
 'texture': ('—', 'under 44pt, no grain'),
 'icon': ('✓', 'landscape keyline 20 × 16, inset 0.375 like journal; stroke 1.75 (2 at 16)'),
 'tokens': ('✓', 'stroke uses var(--color-icon-default); geometry is icon art (allowed raw)'),
 'optical centring': ('✓', 'symmetric mass about the centre lines; the divider sits left, which balances the open panel'),
 'contrast': ('✓', 'paper.900 on canvas ≈ 15 : 1 (marks need 3 : 1)'),
 'hit area': ('—', 'set by its button: 44 × 44 (part 02)'),
 'states': ('—', 'rest only; pressed and focused belong to the button'),
 'motion': ('—', 'none of its own'),
 'haptic': ('—', 'none'),
 'goals': ('✓', 'Journal is a conversation, and the drawer is its index (screen rule 29); this is the door to it'),
 'wireframe': ('✓', 'replaces the ☰ placeholder on JR-1'),
}
html = part(1, 'icon · drawer', 'all journals: a panel that slides in from the leading edge', vis, rows,
            'matched to journal\'s weight after the first look (inset 0.375, rx 3). ready for your review.')
open('p01.html', 'w').write(html)
