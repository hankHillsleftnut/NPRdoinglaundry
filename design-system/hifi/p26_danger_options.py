from review import *
# Part 26 · the danger row, two richer options (founder c-b7r0uw: "i would want a little more here, this feels flat").
import importlib.util
spec = importlib.util.spec_from_file_location('p26', 'p26_settings_rows.py'); s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
well = (f'<div layer-name="icon well 32 · danger" style="width:32px;height:32px;border-radius:{V("radius-default")};background:{C("status-danger-subtle")};'
        f'display:flex;align-items:center;justify-content:center;flex-shrink:0">{s.glyph("alert", 20, C("status-danger-text"))}</div>')
A = s.stack(s.row('danger', well + s.words('delete my account', 'removes everything, after a confirmation', 'status-danger-text')))
B = (f'<div style="width:390px;padding:0 {V("spacing-4")}"><div layer-name="c:settings-row/danger-panel/rest" style="border-radius:{V("radius-default")};background:{C("status-danger-subtle")};'
     f'min-height:{V("spacing-size-row-default")};padding:{V("spacing-3")} {V("spacing-4")};display:flex;align-items:center;gap:{V("spacing-3")}">'
     + s.glyph('alert', 20, C('status-danger-text')) + s.words('delete my account', 'removes everything, after a confirmation', 'status-danger-text') + '</div></div>')
HTML = (f'<div layer-name="part 26 · danger row · two options" style="display:flex;gap:{V("spacing-10")};align-items:flex-end">'
        + s.tile(A, 'option A · a red-tinted well with the alert glyph, like the source rows: same row, more presence')
        + s.tile(B, 'option B · the row on a soft red panel, inset 16: reads as its own zone at the end of the page')
        + '</div>')
open('p26_danger.html', 'w').write(HTML)
