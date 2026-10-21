# M11 journey map: one row per path, every hi-fi screen as a node (a slot the real phone is
# duplicated into), labelled moves between them, failure branches dashed below.
# Slots are named "slot · <code>"; the phones are duplicated in afterwards.
import json, sys

LBL = "font-family:var(--font-label);font-size:var(--text-sm);line-height:var(--leading-snug);color:var(--color-text-label)"
LBLM = LBL.replace("color:var(--color-text-label)", "font-weight:var(--font-weight-medium);color:var(--color-text-primary)")
TXT = "font-family:var(--font-text);font-size:var(--text-md);line-height:var(--leading-snug);color:var(--color-text-secondary)"

def node(code, name):
    return (f'<div layer-name="node · {code}" style="display:flex;flex-direction:column;gap:var(--spacing-3);width:402px;flex-shrink:0">'
            f'<div style="{LBLM}">{code} · {name}</div>'
            f'<div layer-name="slot · {code}" style="width:402px;height:874px;flex-shrink:0"></div></div>')

def ghost(code, name, why):
    # a screen in the path that has no approved hi-fi design yet
    return (f'<div layer-name="node · {code} (not drawn)" style="display:flex;flex-direction:column;gap:var(--spacing-3);width:402px;flex-shrink:0">'
            f'<div style="{LBLM}">{code} · {name}</div>'
            f'<div style="width:402px;height:874px;box-sizing:border-box;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:var(--spacing-2);padding:var(--spacing-8);border-radius:var(--radius-sheet);outline:1px dashed var(--color-border-strong);outline-offset:-1px">'
            f'<div style="{LBLM};text-align:center">not drawn yet</div><div style="{LBL};text-align:center;text-wrap:balance">{why}</div></div></div>')

def ref(text):
    # an end point that lives in another row
    return (f'<div layer-name="goes to" style="align-self:center;flex-shrink:0;margin-top:var(--spacing-8);padding:var(--spacing-3) var(--spacing-4);border-radius:var(--radius-control);background:var(--color-surface-wash)">'
            f'<div style="{LBLM};white-space:nowrap">{text}</div></div>')

def edge(move, how):
    # move = what you do; how = tap / push / sheet / back / system
    return (f'<div layer-name="move · {move.replace(chr(34), "")}" style="align-self:center;width:144px;flex-shrink:0;display:flex;flex-direction:column;align-items:center;gap:var(--spacing-2);margin-top:var(--spacing-8)">'
            f'<div style="{LBLM};text-align:center;text-wrap:balance">{move}</div>'
            f'<svg width="120" height="12" viewBox="0 0 120 12"><path d="M2 6H114" stroke="var(--color-ink-default)" stroke-width="1.5" fill="none" stroke-linecap="round"/><path d="M108 1.5L114 6L108 10.5" stroke="var(--color-ink-default)" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'
            f'<div style="{LBL};text-align:center">{how}</div></div>')

def fail(title, body):
    return (f'<div layer-name="failure · {title}" style="width:402px;flex-shrink:0;box-sizing:border-box;display:flex;flex-direction:column;gap:var(--spacing-2);padding:var(--spacing-4);border-radius:var(--radius-card);outline:1.5px dashed var(--color-status-danger);outline-offset:-1.5px">'
            f'<div style="{LBLM}">if {title}</div><div style="{TXT};text-wrap:pretty">{body}</div></div>')

def row(n, title, sub, items, fails=()):
    fl = ''
    if fails:
        fl = (f'<div layer-name="failure branches" style="display:flex;flex-wrap:wrap;gap:var(--spacing-6);padding-top:var(--spacing-2)">'
              f'<div style="width:240px;flex-shrink:0;{LBL}">failure branches (dashed)</div>' + ''.join(fails) + '</div>')
    return (f'<div layer-name="path · {title}" style="display:flex;flex-direction:column;gap:var(--spacing-6)">'
            f'<div style="display:flex;align-items:baseline;gap:var(--spacing-4)"><div style="font-family:var(--font-mono);font-size:var(--text-sm);color:var(--color-text-label)">{n:02d}</div>'
            f'<div style="font-family:var(--font-display);font-size:var(--text-2xl);letter-spacing:var(--tracking-title);line-height:var(--leading-tight);color:var(--color-text-primary)">{title}</div>'
            f'<div style="{TXT}">{sub}</div></div>'
            f'<div layer-name="flow" style="display:flex;align-items:flex-start;gap:var(--spacing-4)">' + ''.join(items) + '</div>' + fl + '</div>')

rows = [
  row(1, 'first run', 'from the App Store to a journal that already knows you', [
    node('ON-1/2', 'splash + sign-in'), edge('continue with apple', 'tap'),
    node('ON-3–9', 'the questions'), edge('answer, or skip', 'push · one per question'),
    node('ON-5', 'privacy'), edge('that\'s fine', 'tap'),
    ghost('ON-6', 'connect', 'waiting on your call on logos (from the internet, or SF Symbols)'), edge('connect, or later', 'tap'),
    node('ON-10', 'getting ready'), edge('ready', 'automatic'),
    node('ON-11', 'the tease'), edge('its strongest line', 'sheet rises'),
    ghost('ON-12', 'paywall', 'decision 06 was archived; no plan-picking design is approved yet'), edge('subscribe', 'Apple sheet'),
    node('ON-13', 'first home')],
    [fail('sign-in fails', 'stay on the splash; one line above the buttons: "that didn\'t work. nothing is lost; try again." (AC-1 failed state)'),
     fail('calendar access denied', 'connect shows the row as "not connected" with "open settings"; onboarding carries on without it'),
     fail('payment fails or is cancelled', 'back to the paywall with nothing lost and one line saying what happened; the tease can be played again')]),
  row(2, 'daily', 'the brief in the morning, the journal all day', [
    node('EX-3', 'notification'), edge('tap "your brief is ready"', 'opens the app'),
    node('JR-2', "today's brief"), edge('close', 'sheet down'),
    node('JR-1', 'journal'), edge('open the drawer', 'tap · edge swipe'),
    node('JR-3', 'all entries'), edge('an entry', 'push'),
    node('JR-4', 'one entry')],
    [fail('offline', 'entries save on the phone and show "not sent yet"; they send by themselves (JR-3 and JR-4 offline states)'),
     fail('microphone denied', 'the composer stays typed-only; the mic shows a slash and opens a one-line ask with "open settings"')]),
  row(3, 'the weekly episode', 'sunday morning: the week, played back', [
    node('PC-1', 'podcasts'), edge('play', 'tap · mini-player, then sheet'),
    node('PC-2', 'the player'), edge('why is this here?', 'tap a line'),
    node('PC-3', 'why this is here'), edge('lock the phone', 'keeps playing'),
    node('EX-2', 'lock screen'), ref('tap it → back to PC-2')],
    [fail('episode not ready', 'the hero shows "being made" with when (PC-1 key state); nothing to tap yet'),
     fail('offline, not downloaded', 'the play button says "needs a connection"; downloaded episodes play as normal')]),
  row(4, 'ask and look', 'the you tab: the map, search and what it knows', [
    node('YO-1', 'you'), edge('ask a question', 'type or talk · in place'),
    node('YO-2', 'search results'), edge('a source', 'push'),
    node('YO-3', 'a source'), ref('back to YO-1'),
    edge('tap a node on the map', 'sheet'),
    node('YO-4', 'a node'), edge('"what i know about you"', 'push from YO-1'),
    node('YO-5', 'what i know about you')],
    [fail('nothing found', 'it says so and doesn\'t guess (YO-2 key state)')]),
  row(5, 'goals', 'what you are working toward', [
    node('GL-1', 'goals'), edge('a goal', 'push'),
    node('GL-2', 'one goal')]),
  row(6, 'settings and account', 'from your picture on the you tab', [
    node('ST-1', 'settings'), edge('daily brief', 'push'), node('ST-2', 'daily brief'), edge('back · sources', 'push'),
    node('ST-3', 'sources'), edge('a source', 'push'), node('ST-4', 'a source'), edge('back · privacy', 'push'),
    node('ST-5', 'privacy'), edge('back · honesty', 'push'), node('ST-6', 'how straight i am with you'), edge('back · voice', 'push'),
    node('ST-7', 'voice and listening'), edge('back · learned', 'push'), node('ST-8', "what i've learned"), edge('back · account', 'push'),
    node('ST-9', 'account'), edge('sign out', 'sheet'), node('AC-2', 'signing out'), edge('send, then sign out', 'tap'),
    node('AC-1', 'sign in, returning')],
    [fail('sending fails while signing out', 'the sheet stays; "couldn\'t send 1 entry. it\'s still on this phone." with "try again" and "sign out anyway"')]),
  row(7, 'outside the app', 'retrospect where you already are', [
    node('EX-1', 'share to retrospect'), edge('save', 'sheet closes'), ref('→ a new entry in JR-1, row 02'),
    node('EX-4', 'widgets'), edge('tell me…', 'opens the app'), ref('→ JR-1 with the composer listening, row 02')]),
]

html = (f'<div layer-name="header" style="display:flex;flex-direction:column;gap:var(--spacing-2);max-width:1200px">'
        f'<div style="display:flex;align-items:center;gap:var(--spacing-3)"><div style="font-family:var(--font-label);font-size:var(--text-sm);font-weight:var(--font-weight-medium);line-height:var(--leading-snug);color:var(--color-text-inverse);padding:var(--spacing-1) var(--spacing-3);border-radius:var(--radius-control);background:var(--color-ink-default)">approve?</div>'
        f'<div style="font-family:var(--font-label);font-size:var(--text-lg);font-weight:var(--font-weight-medium);line-height:var(--leading-snug);color:var(--color-text-primary)">M11 · gate D · the journey map</div>'
        f'<div layer-name="needs you · red dot" style="width:var(--spacing-3);height:var(--spacing-3);flex-shrink:0;border-radius:var(--radius-control);background:var(--color-status-danger)"></div></div>'
        f'<div style="font-family:var(--font-display);font-size:var(--text-3xl);letter-spacing:var(--tracking-title);line-height:var(--leading-tight);color:var(--color-text-primary)">every screen, every path</div>'
        f'<div style="{TXT}">seven paths, left to right in the order you live them. each node is the real 17 Pro screen; the words between are what you do and how it moves (tap, push, sheet). dashed outlines are screens with no approved design yet; red dashed boxes are what happens when something fails. each screen\'s other states sit under it on 05 · the app in order. once approved, this moves to its own page, 06 · journey.</div></div>'
        + ''.join(rows))
open(sys.argv[1], 'w').write(html)
head = html[:len(html)-len(''.join(rows))]
for i, part in enumerate([head] + rows):
    open(sys.argv[1].replace('.html', f'.{i}.html'), 'w').write(part)
