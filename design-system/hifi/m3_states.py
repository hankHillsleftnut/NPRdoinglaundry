# M3 · the key states left on my share (founder 20 Oct: key states only): drawer empty, search no results, entry editing.
import importlib.util
from review import V, C
from review2 import _t, _kicker
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
d, e = load('p23_drawer'), load('p24_entry')
def typed(word):
    return d.search('typing').replace('>standup<', f'>{word}<').replace('c:search-field/journal/typing', 'c:search-field/journal/typing')
def quiet(line1, line2):
    return (f'<div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:{V("spacing-1")};padding:{V("spacing-10")} {V("spacing-4")};text-align:center">'
            + _t(line1, 'text-body', 'text-secondary', extra=f'letter-spacing:{V("tracking-card")}') + _t(line2, 'text-md', 'text-tertiary') + '</div>')
under = lambda *x: (f'<div layer-name="drawer underlay" style="width:300px;height:420px;background:{C("surface-control")};border-radius:{V("radius-panel")};padding:{V("spacing-4")};'
                    f'display:flex;flex-direction:column;gap:{V("spacing-4")}">' + ''.join(x) + '</div>')
EMPTY = under(d.search('rest'), quiet('nothing yet. say anything.', 'what you say shows up here, by day'))
NONE = under(typed('kayak'), quiet('nothing with that word yet', 'try another word you might have said'))
# entry, editing: the words become a field on a sunken wash; the bar swaps to cancel · save; retro re-reads after save
bar = (f'<div style="height:{V("spacing-size-nav-bar")};display:flex;align-items:center;justify-content:space-between;padding:0 {V("spacing-6")}">'
       + _t('cancel', 'text-md', 'text-secondary', 'font-label', 'font-weight-medium', 'min-height:44px;display:flex;align-items:center')
       + _t('save', 'text-md', 'text-primary', 'font-label', 'font-weight-medium', 'min-height:44px;display:flex;align-items:center') + '</div>')
field = (f'<div layer-name="c:entry/words/editing" style="border-radius:{V("radius-field")};background:{C("surface-wash-pressed")};box-shadow:inset 0 1px 2px {C("depth-shadow-sunken")}, inset 0 0 0 0.5px {C("depth-stroke-outer")};'
         f'padding:{V("spacing-3")} {V("spacing-4")};display:flex;align-items:flex-end;flex-wrap:wrap">'
         + f'<div style="font-family:{V("font-display-inky")};font-size:{V("text-xl")};font-weight:{V("font-weight-ink-card")};line-height:{V("leading-snug")};letter-spacing:{V("tracking-card")};color:{C("text-primary")}">i think it\'s the 9am standup. i dread it, every monday</div>'
         + f'<div layer-name="caret" style="width:{V("spacing-size-border-ring")};height:24px;background:{C("ink-default")};border-radius:{V("radius-small")}"></div></div>')
EDIT = (f'<div layer-name="phone · entry editing" style="width:390px;height:520px;overflow:clip;display:flex;flex-direction:column;background:{C("background-canvas")};border-radius:{V("radius-sheet")} {V("radius-sheet")} 0 0;box-shadow:inset 0 0 0 1px {C("border-subtle")}">'
        + f'<div style="height:62px"></div>' + bar
        + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")};padding:{V("spacing-4")} {V("spacing-screen-margin")}">' + field
        + _t('retro reads it again when you save', 'text-sm', 'text-label', 'font-label') + '</div></div>')
tile = lambda inner, title, note: (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-3")};width:{390 if "phone" in inner[:80] else 300}px">{inner}'
                                   + _t(title, 'text-md', 'text-primary', 'font-label', 'font-weight-medium') + _t(note, 'text-md', 'text-secondary') + '</div>')
HTML = (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-10")};width:100%">'
        + f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}"><div style="display:flex;align-items:center;gap:{V("spacing-3")}">'
        + _t('approve?', 'text-sm', 'text-inverse', 'font-label', 'font-weight-medium', f'padding:{V("spacing-1")} {V("spacing-3")};border-radius:{V("radius-control")};background:{C("ink-default")}')
        + _kicker('M3 · key states · drawer and entry') + '</div>'
        + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};line-height:{V("leading-tight")};color:{C("text-primary")}">the three moments not drawn yet</div></div>'
        + _t('you cut M3 to the key states in each flow. for the drawer and the entry page, these are the only ones left: the rest (rest, in view, searching, unsent, re-reading, didn\'t send, delete) are already in the masters.', 'text-md', 'text-secondary', extra='max-width:820px')
        + f'<div layer-name="states" style="display:flex;gap:{V("spacing-8")};align-items:flex-start">'
        + tile(EMPTY, 'drawer · nothing yet', 'your first day: no conversations. one quiet line says what will appear here; no illustration, no button.')
        + tile(NONE, 'search · no results', 'says the word found nothing and suggests trying another; the field keeps your word so you can edit it.')
        + tile(EDIT, 'entry · editing your words', 'tap edit: your words become a sunken field (the recess recipe), the bar becomes cancel · save. save is plain ink, not lit: it\'s a quiet edit, not the screen\'s big action.')
        + '</div>'
        + f'<div layer-name="answer" style="padding:{V("spacing-4")} {V("spacing-5")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
        + _t('to answer: comment "yes" on this card, or the change on the state itself', 'text-md', 'text-primary') + '</div></div>')
open('m3_states.html', 'w').write(HTML)
