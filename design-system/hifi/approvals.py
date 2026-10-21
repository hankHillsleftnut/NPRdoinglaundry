# Gate A approval cards (one per part, founder's card format): status, what it is, how it works, what's settled, then the part
# in its real screen (cloned in Paper), and the one question: approve, or what to change.
from review import V, C
from review2 import _t, _kicker, chip
def approval(num, part, title, what, how, settled):
    top = (f'<div style="display:flex;align-items:center;gap:{V("spacing-3")}">' + _t('approve?', 'text-sm', 'text-inverse', 'font-label', 'font-weight-medium',
           f'padding:{V("spacing-1")} {V("spacing-3")};border-radius:{V("radius-control")};background:{C("ink-default")};white-space:nowrap')
           + _kicker(f'gate A · {num} of 8 · part {part}') + '</div>'
           + f'<div style="font-family:{V("font-display")};font-size:{V("text-2xl")};letter-spacing:{V("tracking-title")};line-height:{V("leading-tight")};color:{C("text-primary")}">{title}</div>')
    blk = lambda k, b: f'<div style="flex:1;display:flex;flex-direction:column;gap:{V("spacing-1")}">' + _kicker(k) + _t(b) + '</div>'
    ctx = f'<div layer-name="context" style="display:flex;gap:{V("spacing-8")}">' + blk('what it is', what) + blk('how it works', how) + blk('already settled', settled) + '</div>'
    vis = f'<div layer-name="in the app" style="display:flex;gap:{V("spacing-8")};align-items:flex-start;flex-wrap:wrap"></div>'
    ans = (f'<div layer-name="answer" style="display:flex;flex-direction:column;gap:{V("spacing-1")};padding:{V("spacing-4")} {V("spacing-5")};border-radius:{V("radius-panel")};background:{C("surface-wash")}">'
           + _t('approve and it becomes a master on 02 · components; anything you want changed, comment on the spot.', 'text-md', 'text-primary')
           + _t('to answer: comment "approve" on this card, or comment the change where it is', 'text-sm', 'text-label', 'font-label') + '</div>')
    return (f'<div style="display:flex;flex-direction:column;gap:{V("spacing-6")};padding:{V("spacing-10")};width:100%">'
            f'<div style="display:flex;flex-direction:column;gap:{V("spacing-2")}">{top}</div>' + ctx + vis + ans + '</div>')
CARDS = [
 (1, 20, 'pills: lit, raised, wash', 'the three button weights: lit (the one main action, blue glow), raised (a white pill you press, like "connect"), wash (a quiet grey pill, like "not right").', 'one lit pill per screen at most; everything else is raised or wash, so the main action is always obvious.', 'label weight is medium, not semibold (your call). the danger button got the quieter finish; blue keeps its glow (your call).'),
 (2, 21, 'labels: day and section', 'the small grey headings: "today" and "yesterday" in the journal and drawer, and group names on settings.', 'they name a group so you can find your place; they never act, so they never look tappable.', 'settings group names are Geist labels, not serif (your call).'),
 (3, 22, 'row and hairline', 'one line in a list: the settings rows, with the thin line between them.', 'tap a row to open or change that one thing; the line only separates, it never boxes.', 'every settings row leads with its icon in a soft square (decision 02); ↕ for a quick pick, › for a page (decision 04).'),
 (4, 23, 'journal drawer and search', 'the list under the journal: every conversation in your own words, by day, with search on top.', 'swipe right or tap the drawer button; tap a line to jump there; search finds any conversation by a word you said.', 'search field is darker than its background (your note); search words are blue (your call); body text tracked tighter (your note).'),
 (5, 24, 'entry page and delete', 'the page for one thing you said: your words, when and how, what retro took from it, and delete.', '"not right" fixes a belief on the spot; delete asks once in a dialog.', 'what retro took is cards with a pill (decision 01); dialog corners sharper, 12 (your note); delete button refined (your note).'),
 (6, 25, 'switch and segmented', 'the on/off switch and the 2-to-5-way picker.', 'both apply at once, no save; the switch snaps back if saving fails.', 'switch "on" is ink, not blue; no pending state (your note); segmented already approved ("looks good").'),
 (7, 26, 'settings rows', 'each kind of setting row: switch, choice tick, link out, link in, sources, delete account.', 'the control sits in the same place on every row, so the page reads top to bottom.', 'delete account has a red-tinted alert square (your pick); syncing is a grey 6pt rotating ring (decision 03).'),
 (8, 27, 'the settings page', 'the whole settings page (ST-1): your brief, listening, you, sources, privacy and account.', 'every row shows its current value, so you rarely need to open it.', 'icons on every row (02), ↕/› (04), Geist group names. "help" waits for its icon.'),
]
for c in CARDS:
    open(f'approval_{c[1]}.html', 'w').write(approval(*c))
