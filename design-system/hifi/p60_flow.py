# 05 · the app in order: every finished hi-fi screen in one row, in the order someone uses the app; each screen's key
# states stacked in order below it (founder, 20 Oct). Columns are slots; the phones are duplicated in from 04b / 02b.
from review import V, C
from review2 import _t
COLS = [  # (code, name, status, [(slot, caption)])
 ('ON-1/2', 'splash + sign in', 'waiting · option A shown', [('main', '')]),
 ('ON-3–9', 'onboarding questions', 'waiting', [('main', 'listening'), ('s1', 'quick answers')]),
 ('ON-5', 'privacy', 'waiting', [('main', '')]),
 ('ON-12', 'paywall', 'waiting · option A shown', [('main', '')]),
 ('JR-1', 'journal', 'approved', [('main', 'at rest'), ('s1', 'talking'), ('s2', 'retro thinking'), ('s3', 'scrolled'), ('s4', 'brief being made'), ('s5', 'first day')]),
 ('JR-2', "today's brief", 'waiting', [('main', 'playing'), ('s1', 'paused'), ('s2', 'played'), ('s3', 'quiet day')]),
 ('JR-3', 'journal drawer', 'approved', [('main', 'at rest'), ('s1', 'empty'), ('s2', 'searching'), ('s3', 'no results'), ('s4', 'offline')]),
 ('JR-4', 'an entry', 'approved', [('main', 'at rest'), ('s1', 'voice note'), ('s2', 'nothing taken yet'), ('s3', 'editing'), ('s4', "offline · didn't send"), ('s5', 'delete')]),
 ('PC-1', 'podcasts', 'waiting', [('main', 'at rest'), ('s1', 'playing'), ('s2', 'being made')]),
 ('PC-2', 'the player', 'waiting', [('main', 'playing'), ('s1', 'a guess arrives'), ('s2', 'chapters')]),
 ('PC-3', 'why this is here', 'approved', [('main', 'stated'), ('s1', 'asked')]),
 ('GL-1', 'goals', 'waiting', [('main', 'at rest'), ('s1', 'none yet')]),
 ('GL-2', 'one goal', 'waiting', [('main', 'at rest'), ('s1', 'turned off')]),
 ('YO-1', 'you', 'waiting', [('main', 'at rest'), ('s1', 'day one')]),
 ('YO-2', 'search results', 'waiting', [('main', 'found'), ('s1', 'nothing found')]),
 ('YO-4', 'a node', 'waiting', [('main', 'a person'), ('s1', 'a guess')]),
 ('YO-3', 'a source', 'waiting', [('main', '')]),
 ('YO-5', 'what i know about you', 'waiting', [('main', '')]),
 ('ST-1', 'settings', 'approved', [('main', '')]), ('ST-2', 'daily brief', 'approved', [('main', '')]), ('ST-3', 'sources', 'approved', [('main', '')]),
 ('ST-4', 'a source', 'approved', [('main', '')]), ('ST-5', 'privacy', 'approved', [('main', '')]), ('ST-6', 'how straight i am with you', 'approved', [('main', '')]),
 ('ST-7', 'voice and listening', 'approved', [('main', '')]), ('ST-8', "what i've learned", 'approved', [('main', '')]), ('ST-9', 'account', 'approved', [('main', '')]),
 ('AC-1', 'sign in, returning', 'waiting', [('main', 'at rest'), ('s1', 'restoring'), ('s2', 'failed')]),
 ('EX-1', 'share to retrospect', 'waiting', [('main', '')]), ('EX-2', 'lock screen', 'waiting', [('main', '')]),
 ('EX-3', 'notifications', 'waiting', [('main', '')]), ('EX-4', 'widgets', 'waiting', [('main', '')]),
]
def col(code, name, status, slots):
    ok = status.startswith('approved')
    dot = f'<div style="width:10px;height:10px;border-radius:{V("radius-control")};background:{C("status-success" if ok else "status-danger")}"></div>'
    head = (f'<div layer-name="head" style="display:flex;flex-direction:column;gap:{V("spacing-1")};height:72px">'
            + f'<div style="display:flex;align-items:center;gap:{V("spacing-2")}">' + _t(code, 'text-md', 'text-label', 'font-mono') + dot + _t(status, 'text-sm', 'text-label', 'font-label') + '</div>'
            + f'<div style="font-family:{V("font-display-inky")};font-weight:{V("font-weight-ink-card")};font-size:{V("text-xl")};line-height:{V("leading-tight")};color:{C("text-primary")}">{name}</div></div>')
    cells = ''.join(f'<div layer-name="{code} · {k}" style="display:flex;flex-direction:column;gap:{V("spacing-2")}">'
                    + (_t(c, 'text-sm', 'text-label', 'font-label', 'font-weight-medium') if c else '') + f'<div layer-name="slot · {code} · {k}" style="width:402px"></div></div>' for k, c in slots)
    return f'<div layer-name="col · {code}" style="width:440px;flex-shrink:0;display:flex;flex-direction:column;gap:{V("spacing-8")}">' + head + cells + '</div>'
HTML = f'<div layer-name="row" style="display:flex;gap:{V("spacing-10")};align-items:flex-start">' + ''.join(col(*c) for c in COLS) + '</div>'
open('p60_flow.html', 'w').write(HTML)
