# The 02b review board: one block per sub-component, drawn from tokens only, with its checks written beside it.
def V(n): return f"var(--{n})"
def C(n): return V("color-" + n)
def label(s): return f'<div style="font-family:{V("font-label")};font-size:{V("text-xs")};line-height:{V("leading-snug")};color:{C("text-label")}">{s}</div>'
CHECKS = ['purpose', 'colour', 'type', 'space', 'shape', 'depth', 'texture', 'icon', 'tokens', 'optical centring', 'contrast', 'hit area', 'states', 'motion', 'haptic']
def checks(rows):  # rows: {check: (mark, note)}; every one of the 15 is listed, so nothing is skipped silently
    out = []
    for c in CHECKS + [k for k in rows if k not in CHECKS]:
        mark, note = rows.get(c, ('—', 'not checked'))
        out.append(f'<div style="display:flex;gap:{V("spacing-3")}"><div style="width:120px;flex-shrink:0;font-family:{V("font-label")};font-size:{V("text-xs")};color:{C("text-label")}">{mark} {c}</div>'
                   f'<div style="flex:1;font-family:{V("font-text")};font-size:{V("text-sm")};line-height:{V("leading-snug")};color:{C("text-secondary")}">{note}</div></div>')
    return f'<div layer-name="checks" style="width:520px;display:flex;flex-direction:column;gap:{V("spacing-1")}">' + ''.join(out) + '</div>'
def part(n, name, says, visuals, rows, verdict):
    head = (f'<div style="display:flex;gap:{V("spacing-3")};align-items:baseline">' + label(f'part {n:02d}')
            + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};color:{C("text-primary")}">{name}</div>'
            + f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};color:{C("text-secondary")}">{says}</div></div>')
    body = f'<div style="display:flex;gap:{V("spacing-16")};align-items:flex-start"><div style="display:flex;gap:{V("spacing-10")};align-items:flex-end;flex-wrap:wrap;flex:1">{visuals}</div>{checks(rows)}</div>'
    foot = f'<div style="font-family:{V("font-text")};font-size:{V("text-md")};color:{C("text-primary")}">verdict · {verdict}</div>'
    return f'<div layer-name="part {n:02d} · {name}" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">' + head + body + foot + '</div>'
def tile(inner, cap, extra=''):
    return f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}">{inner}{label(cap)}</div>'
