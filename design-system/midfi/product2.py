# The product after onboarding, chunk 2: Goals, You, Settings and outside the app (plan: docs/design/midfi-product-plan-2.md).
from mf import *
from product import sheet_phone, sheet_screen, head, guess, rests
S = []

# shared pieces for this chunk
def ptop(label='', lead='←', trail=''):  # status, then leading (back or your picture), the page label centred, a trailing action
    if lead == 'pic':
        lead_el = f'<div style="width:36px;height:36px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-strong")};display:flex;align-items:center;justify-content:center">' + t('sn', 'text-sm', 'text-secondary') + '</div>'
    else:
        lead_el = t(lead, 'text-body', 'text-secondary', extra='width:36px;flex-shrink:0')
    return col(t('9:41', 'text-md', 'text-secondary'),
               row(lead_el, t(label, 'text-md', 'text-label', extra='flex:1;text-align:center;align-self:center'), t(trail, 'text-md', 'text-secondary', extra='min-width:36px;text-align:right;align-self:center'), extra='min-height:44px;align-items:center'), gap='spacing-2')
def section(s):  # a group's title: lowercase serif, 12 above its rows
    return f'<div style="font-family:{V("font-display")};font-size:{V("text-lg")};color:{C("text-primary")}">{s}</div>'
def group(title_, *rows):
    return col(*( [section(title_)] if title_ else []), col(*rows, gap='spacing-1'), gap='spacing-3')
def srow(title_, sub=None, trail='›', danger=False):  # a settings row: what it does, what it means, its control or value
    left = col(t(title_, 'text-body', 'status-danger-text' if danger else 'text-primary'), *( [t(sub, 'text-md', 'text-secondary')] if sub else []), gap='spacing-1', extra='flex:1')
    tr = trail if trail.startswith('<') else t(trail, 'text-md', 'text-label', extra='flex-shrink:0')
    return row(left, tr, gap='spacing-3', extra=f'min-height:56px;align-items:center;box-shadow:inset 0 -1px 0 {C("border-subtle")}')
def sw(on=True):  # the switch, in grey: the thumb's side carries on/off
    return (f'<div style="width:51px;height:31px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-size-border-ring")};border-radius:{V("radius-control")};background:{C("surface-strong" if on else "surface-track")};display:flex;justify-content:{"flex-end" if on else "flex-start"}">'
            f'<div style="width:27px;height:27px;border-radius:{V("radius-control")};background:{C("surface-thumb")};box-shadow:0 1px 3px {C("depth-shadow-cast")}"></div></div>')
def seg(opts, sel):  # segmented: the chosen one lifted
    cell = lambda o: (f'<div style="flex:1;height:32px;border-radius:{V("radius-control")};display:flex;align-items:center;justify-content:center;'
                      + (f'background:{C("background-canvas")};box-shadow:0 1px 3px {C("depth-shadow-cast")};' if o == sel else '') + '">' + t(o, 'text-md', 'text-primary' if o == sel else 'text-secondary') + '</div>')
    return f'<div style="display:flex;padding:{V("spacing-size-border-ring")};border-radius:{V("radius-control")};background:{C("surface-control")}">' + ''.join(cell(o) for o in opts) + '</div>'
def tick(title_, sub, chosen=False):  # choice row: the tick is the only mark
    return srow(title_, sub, trail='✓' if chosen else ' ')
def how(word, n):  # how sure: the word carries it, four dots are the one quiet visual
    return t(f'{word} ' + '●' * n + '○' * (4 - n), 'text-sm', 'text-label')
def evid(date, what, ctl='not right'):  # evidence row: when, what, and the correction (or open) as the trailing control
    return row(col(t(date, 'text-sm', 'text-label'), t(what, 'text-md', 'text-primary'), gap='spacing-1', extra='flex:1'), t(ctl, 'text-md', 'text-secondary', extra='flex-shrink:0'), gap='spacing-3',
               extra=f'min-height:44px;box-sizing:border-box;align-items:center;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-default")};background:{C("surface-control")}')
def dashed(*items):  # a guess: unfinished, so it has the inference border
    return f'<div style="border-radius:{V("radius-default")};padding:{V("spacing-4")};background:{C("inference-surface")};box-shadow:inset 0 0 0 1px {C("inference-border")};display:flex;flex-direction:column;gap:{V("spacing-3")}">' + ''.join(items) + '</div>'
def bar(pct):
    return f'<div style="flex:1;height:4px;border-radius:{V("radius-control")};background:{C("surface-track")};overflow:hidden"><div style="width:{pct}%;height:100%;background:{C("text-secondary")}"></div></div>'
def goal_card(name, said, said_pct, did, did_pct, line):  # goal: your words, said against did in words and two bars, one line from retro
    sd = lambda k, pct, v: row(t(k, 'text-sm', 'text-label', extra='width:32px;flex-shrink:0'), bar(pct), t(v, 'text-sm', 'text-secondary', extra='width:120px;text-align:right;flex-shrink:0'), gap='spacing-3', extra='align-items:center')
    return (f'<div style="border-radius:{V("radius-card")};background:{C("background-raised")};box-shadow:0 1px 3px {C("depth-shadow-cast")}, inset 0 0 0 1px {C("border-subtle")};padding:{V("spacing-4")};display:flex;flex-direction:column;gap:{V("spacing-3")}">'
            + t(name, 'text-body', 'text-primary', 'font-weight-semibold') + col(sd('said', said_pct, said), sd('did', did_pct, did), gap='spacing-2') + t(line, 'text-md', 'text-secondary') + '</div>')
def search_field(text='ask anything about yourself', typed=False):  # mic first; one leading glyph
    mic = f'<div style="width:32px;height:32px;flex-shrink:0;border-radius:{V("radius-control")};background:{C("surface-control")};display:flex;align-items:center;justify-content:center">' + t('◉', 'text-md', 'text-secondary') + '</div>'
    return (f'<div style="height:48px;box-sizing:border-box;border-radius:{V("radius-control")};background:{C("background-canvas")};box-shadow:0 1px 3px {C("depth-shadow-cast")}, inset 0 0 0 1px {C("border-strong")};padding:0 {V("spacing-2")};display:flex;align-items:center;gap:{V("spacing-3")}">'
            + mic + t(text, 'text-body', 'text-primary' if typed else 'text-tertiary', extra='flex:1') + (t('✕', 'text-md', 'text-label', extra=f'padding-right:{V("spacing-2")}') if typed else '') + '</div>')
def node(x, y, d, label, kind='', you=False, waiting=False):  # one thing on the map, sized by how much it shows up
    ring = f'box-shadow:inset 0 0 0 1px {C("inference-border")};background:{C("inference-surface")};' if waiting else (f'background:{C("background-canvas")};box-shadow:0 1px 3px {C("depth-shadow-cast")}, inset 0 0 0 1px {C("border-strong")};' if you else f'background:{C("surface-strong")};')
    lab_ = t(label, 'text-sm', 'text-primary' if you else 'text-secondary', extra='text-align:center;white-space:nowrap')
    return (f'<div style="position:absolute;left:{x}px;top:{y}px;display:flex;flex-direction:column;align-items:center;gap:{V("spacing-1")};transform:translateX(-50%)">'
            f'<div style="width:{d}px;height:{d}px;border-radius:{V("radius-control")};{ring}"></div>' + lab_ + '</div>')
def youmap(h=360):
    ns = [node(171, 150, 56, 'you', you=True), node(80, 60, 40, 'priya'), node(270, 70, 44, 'work'), node(60, 230, 28, 'sleep'), node(290, 220, 36, 'ship v1'),
          node(175, 20, 20, 'mum'), node(190, 285, 24, 'running'), node(320, 150, 16, 'london'), node(40, 150, 20, 'sam?', waiting=True)]
    return (f'<div layer-name="you map" style="position:relative;height:{h}px;flex-shrink:0">' + ''.join(ns)
            + f'<div style="position:absolute;left:0;right:0;bottom:0">' + lab('lines join what relates · dashed: waiting for you') + '</div></div>')
def answer_row(q, a, sure, n, frm):
    return row(col(t(q, 'text-sm', 'text-label'), t(a, 'text-body', 'text-primary'), row(how(sure, n), t('· ' + frm, 'text-sm', 'text-label'), gap='spacing-2'), gap='spacing-1', extra='flex:1'), t('›', 'text-md', 'text-label', extra='flex-shrink:0'),
               gap='spacing-3', extra=f'min-height:56px;align-items:center;padding:{V("spacing-2")} 0;box-shadow:inset 0 -1px 0 {C("border-subtle")}')
def cite(n):
    return f'<span style="font-family:{V("font-mono")};font-size:{V("text-xs")};color:{C("text-link")}">[{n}]</span>'
def numbered(n, kind, what):  # a numbered source under an answer
    return row(t(str(n), 'text-sm', 'text-link', extra='width:16px;flex-shrink:0'), col(t(kind, 'text-sm', 'text-label'), t(what, 'text-md', 'text-primary'), gap='spacing-1', extra='flex:1'), t('open ›', 'text-md', 'text-secondary', extra='flex-shrink:0'),
               gap='spacing-3', extra=f'min-height:56px;align-items:center;box-shadow:inset 0 -1px 0 {C("border-subtle")}')
def system_phone(*content, bg='surface-strong'):  # a phone showing iOS, not the app
    return (f'<div layer-name="phone" style="width:390px;height:844px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-4")} {V("spacing-8")};display:flex;flex-direction:column;gap:{V("spacing-4")};background:{C(bg)};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-strong")};overflow:hidden">'
            + ''.join(content) + '</div>')
def os_card(*items, extra=''):  # a system-drawn card (notification, live activity, widget)
    return f'<div style="border-radius:{V("radius-widget")};background:{C("background-raised")};box-shadow:0 1px 3px {C("depth-shadow-cast")};padding:{V("spacing-4")};display:flex;flex-direction:column;gap:{V("spacing-2")};{extra}">' + ''.join(items) + '</div>'
def lock_clock(day='tuesday 21 october', time='9:02'):
    return col(t(day, 'text-md', 'text-secondary', extra='text-align:center'), f'<div style="font-family:{V("font-display")};font-size:{V("text-4xl")};color:{C("text-primary")};text-align:center">{time}</div>', gap='spacing-1', extra=f'padding-top:{V("spacing-10")}')

# ── Goals ─────────────────────────────────────────────
S.append(screen('GL-1 · goals', "What you're working toward, as it sees it.",
  "reading comes first, so the goals are the page: each card puts what you said beside what you did, in words and two quiet bars, with one line from retro (goal rule 1: both, with words); a goal retro only heard is a dashed guess until you say yes (goals are proposed, never assumed); faded and merged goals wait in one row below, revivable; adding is a quiet + because a goal can also start from anything you say.",
  ['top bar: goals · + (add by voice or text)', 'goal cards: your words · said vs did (words + bars) · one line', 'guess card: a goal retro heard · yes · not quite', 'row: faded 2 · merged 1 ›', 'mini-player (when playing)', 'tab bar'],
  [('none yet', '"nothing yet. say what you\'re working toward, or wait and i\'ll notice."'), ('too early', '"too early to tell" in place of did, for the first two weeks of a goal'), ('loading', 'card skeletons after 400 ms'), ('server failing', 'the last known numbers, marked "as of monday"'), ('offline', 'the same, marked'), ('a goal ended', 'it moves to faded, said as "you turned this off", never "failed"')],
  ['O-6 goals', 'O-23 server owns goals', 'K2 said-vs-did', 'goals 7, 8: stated vs real', 'goal.md', 'closes G1–G3, Y17–Y21'],
  ptop('goals', lead='', trail='+'),
  col(goal_card('ship the first version', '6× this month', 80, '4h a week, usually 2', 60, 'you work on it most on tuesdays.'),
      goal_card('sleep before midnight', '3× this month', 45, '1 night this week', 15, "late nights cluster before demos."),
      dashed(t("it's wondering · a goal?", 'text-sm', 'text-label'), t('you keep saying you want to see your family more. is that a goal?', 'text-body', 'text-primary'), row(pill('yes'), pill('not quite'), gap='spacing-3')),
      srow('faded 2 · merged 1', None), gap='spacing-3'),
  bottom(tabbar('goals'))))

S.append(screen('GL-2 · a goal', 'Everything behind one goal.',
  "the goal in your words is the title; said comes first (when you first said it, when last, how often), then what you did this week as dated evidence you can correct; a pattern retro sees is marked as a guess; rename and turn off are quiet, because turning a goal off is a choice, not a failure (goal rule 3).",
  ['top bar: back', 'title: the goal (your words)', 'said: first · last · how often', 'did this week: evidence rows · not right', 'a pattern (guess, dashed)', 'rename · turn off (quiet pills)'],
  [('too early', '"too early to tell" under did'), ('nothing done yet', '"nothing this week yet", no shame'), ('turned off', 'a line "you turned this off on 2 nov" and turn back on'), ('corrected', 'the row dims, "noted"; the numbers update')],
  ['O-6 goals', 'O-10 corrections', 'goal 8: real vs stated', 'closes G3'],
  ptop(),
  col(title('ship the first version'), t('said 6× · first on 6 oct · last on monday', 'text-md', 'text-secondary'), gap='spacing-2'),
  col(t('did this week · 4 hours', 'text-sm', 'text-label'), evid('tue 14 oct', '2 hours of deep work, calendar'), evid('thu 16 oct', 'demo with priya'), evid('fri 17 oct', '"finally fixed the sync bug", journal'), gap='spacing-2'),
  dashed(t('a guess', 'text-sm', 'text-label'), t('you get most done after a late night, then sleep badly the next day.', 'text-body', 'text-primary'), row(pill('yes'), pill('not quite'), gap='spacing-3')),
  bottom(row(pill('rename'), pill('turn off'), gap='spacing-3', extra='justify-content:center'))))

# ── You ───────────────────────────────────────────────
S.append(screen('YO-1 · you', 'See the picture it has of you, and ask it anything.',
  "asking is the most direct use, so the search field (mic first) is on top; the map is the page: you in the middle, the dozen things that show up most around you, sized by how much, joined by what relates; one thing waiting for you is dashed and quiet, never a badge; your picture opens settings (founder: settings live behind it); the list view is in the top bar for voiceover and for a faster read.",
  ['top bar: your picture (settings) · you · list', 'search field (mic first)', 'you map: up to 24 nodes, one waiting (dashed)', 'what i know about you ›', 'one question waiting › (when there is one)', 'tab bar'],
  [('day one', 'a thin map that says so: "this fills in as you talk to me"'), ('loading', 'nodes fade in, strongest first'), ('offline', 'the last map, marked; search waits'), ('failing', 'the last map, "couldn\'t refresh"'), ('a node tapped', 'it lifts, the rest dim, YO-4 rises'), ('list view', 'the same things as rows, by kind')],
  ['O-7 search', 'O-8 the map', 'O-11/12/13', 'K2 map route', 'you-map.md', 'goal 10 current state'],
  ptop('you', lead='pic', trail='list'),
  search_field(),
  youmap(),
  col(srow('what i know about you'), srow('one question waiting', 'about sam'), gap='spacing-1'),
  bottom(tabbar('you'))))

S.append(screen('YO-2 · search results', 'An answer from your own mind, with its receipts.',
  "the search v1 shape: the written answer on top, the sources below, every claim numbered to one; facts are plain, a guess is labelled; only what's certain hides guesses; when nothing answers, it says so and shows what the sources do say (abstains); sources arrive first (~1 s) and light their part of the map, then the answer writes in.",
  ['field: the query, kept', 'what i found: 2–5 sentences, numbered claims, guess labelled', "switch: only what's certain", 'sources: numbered rows · open ›', 'not right (long press any line)'],
  [('searching', 'sources appear first, the answer writes in after'), ('found', 'as drawn'), ('abstained', '"nothing you\'ve said answers this." then what the sources do show'), ('only certain', 'guesses hidden, a line says how many'), ('offline', '"search needs a connection", the query kept'), ('failing', '"couldn\'t search · try again"')],
  ['O-7 search', 'goal 6 receipts, abstains', 'memory: search v1 shape'],
  ptop(),
  search_field('when do i sleep best?', typed=True),
  col(t('what i found', 'text-sm', 'text-label'),
      f'<div style="font-family:{V("font-text")};font-size:{V("text-body")};color:{C("text-primary")}">after days you run {cite(1)}, and when work stops before 9 {cite(2)}. </div>',
      f'<div style="font-family:{V("font-text")};font-size:{V("text-body")};color:{C("text-secondary")}">a guess: weekends help less than you think {cite(3)}.</div>', gap='spacing-2'),
  srow("only what's certain", 'hides the guess', trail=sw(False)),
  col(t('sources', 'text-sm', 'text-label'), numbered(1, 'apple health', '14 nights after a run'), numbered(2, 'journal · 3 entries', '"stopped at 8, slept like a rock"'), numbered(3, 'calendar', '4 weekends, no early events'), gap='spacing-1')))

S.append(screen('YO-3 · a source', 'One thing you said, did or saved, in full.',
  "your words come first and large, the same form as an entry (JR-4), so a source never looks like a database row; where and when sit under them; a saved link adds your reason and, for a video, its transcript.",
  ['top bar: back · kind and date', 'the thing, in full (inky)', 'where it came from · when', 'for a link: your reason · transcript (video)', 'what it supports ›'],
  [('loading', 'a skeleton of the text'), ('not found', '"this was deleted" and what used to rest on it'), ('a saved link', 'title, site, your reason, transcript (collapsed)'), ('an event', 'the calendar entry, its time, who was there')],
  ['goal 6 open any source', 'O-14 saved links'],
  ptop('journal · 14 oct'),
  col(f'<div style="font-family:{V("font-display")};font-size:{V("text-xl")};line-height:{V("leading-snug")};color:{C("text-primary")}">went to bed at 10 for once. woke up before the alarm and actually wanted to run.</div>', t('written in journal · tue 14 oct, 7:40', 'text-sm', 'text-label'), gap='spacing-2'),
  col(t('this supports', 'text-sm', 'text-label'), srow('you sleep best after days you run', 'what i know about you'), srow('sleep before midnight', 'a goal'), gap='spacing-1')))

S.append(sheet_screen('YO-4 · a node', 'Everything it knows about one thing, and why.',
  "it rises as a sheet over the map so you keep your place; the kind and name lead, then what it believes in its own words (inky), how sure in a word and four dots, the quotes it rests on with dates, then still true · not right; for a person it asks once if they're the same as someone in your contacts; linked things are chips.",
  ['sheet over the map', 'kind · name', 'what it believes (inky) · how sure · from how many', 'what it rests on: evidence rows', 'still true · not right', 'linked: chips', 'person: same as … in your contacts?'],
  [('a person', 'as drawn'), ('a goal', 'said vs did instead of quotes, and open goal ›'), ('a guess', 'dashed, with yes / not quite instead of still true'), ('corrected', '"noted" and the belief rewrites or goes'), ('thin', '"i only know one thing about this so far"')],
  ['O-10 corrections', 'O-12 people', 'O-14 saved links', 'you-map.md'],
  sheet_phone(head('person · priya', '⌄'),
    col(f'<div style="font-family:{V("font-display")};font-size:{V("text-xl")};line-height:{V("leading-snug")};color:{C("text-primary")}">a close colleague. you come back lighter after time with her.</div>', row(how('fairly sure', 3), t('· from 5 things · moved last week', 'text-sm', 'text-label'), gap='spacing-2'), gap='spacing-2'),
    col(t('what it rests on', 'text-sm', 'text-label'), evid('12 oct', '"coffee with priya, felt lighter"'), evid('16 oct', 'demo together, calendar'), gap='spacing-2'),
    row(pill('still true'), pill('not right'), gap='spacing-3'),
    col(t('linked', 'text-sm', 'text-label'), row(pill('work'), pill('ship v1'), gap='spacing-3'), gap='spacing-2'), behind='you, the map')))

S.append(screen('YO-5 · what i know about you', 'Its answers to the questions about you.',
  "what moved since last week is the news, so it leads; then each area of life is a serif section with its answers: the question small, the answer in plain words, how sure and from how many things; an area it knows nothing about says so warmly (goal 10: it admits what it doesn't know); each answer opens its evidence.",
  ['top bar: back', 'moved this week · 2 ›', 'areas (serif sections): answer rows · question · answer · how sure · from n', 'silent area: one warm line', 'answer → its evidence (YO-4 form)'],
  [('thin (day one)', 'most areas silent, "this fills in as we talk"'), ('loading', 'skeleton rows'), ('offline', 'the last read, marked'), ('corrected', 'the answer rewrites, "noted"')],
  ['O-9 the answers', 'K2 read contract', 'goal 10 admits what it doesn\'t know'],
  ptop('what i know about you'),
  srow('moved this week', '2 answers changed'),
  group('work', answer_row('what drives you most?', 'building things people use.', 'fairly sure', 3, 'from 9 things'), answer_row('when do you work best?', 'early, before anyone is online.', 'very sure', 4, 'from 14 things')),
  group('health', t("i don't know much about your health yet. it fills in if you connect apple health, or just tell me.", 'text-md', 'text-secondary')),
  group('people', answer_row('who do you lean on?', 'priya at work, your mum on sundays.', 'fairly sure', 3, 'from 6 things'))))

S.append(sheet_screen('YO-6 · a question waiting', "Answer one thing it's unsure of.",
  "one question at a time, never a pile (a sheet with one card); it is a guess, so it has the dashed card; the choices are equal, none is lit, because pushing an answer would bias it; not sure is always allowed.",
  ['sheet', 'one question waiting', 'guess card (large): the question · what it rests on', 'same · different · not sure (person) or yes · not quite · why do you think that? (hypothesis)'],
  [('person', 'as drawn'), ('hypothesis', 'yes · not quite · why do you think that?'), ('answered', 'the card settles, "thanks, noted", the sheet closes'), ('none waiting', 'the row on You disappears; no empty sheet')],
  ['O-12 people', 'O-13 hypotheses', 'dial: speak off by default'],
  sheet_phone(head('one question waiting', '⌄'),
    dashed(t('a guess', 'text-sm', 'text-label'), f'<div style="font-family:{V("font-display")};font-size:{V("text-xl")};line-height:{V("leading-snug")};color:{C("text-primary")}">is the sam in your writing sam ortiz from your contacts?</div>', t('you mention sam 4 times, always about the gym.', 'text-md', 'text-secondary'), row(pill('same'), pill('different'), pill('not sure'), gap='spacing-3', extra='flex-wrap:wrap')),
    behind='you, the map')))

# ── Settings (behind your picture on You) ───────────
S.append(screen('ST-1 · settings', 'Control, in one calm list.',
  "the founder's production settings: simple, nothing for developers; groups are separated by space with lowercase serif titles (settings-row spec, over the blueprint's capitals); every row shows its current value so you rarely need to open it; account and help come last.",
  ['top bar: back · settings', 'your brief · listening · you · sources · privacy · account · help', 'value rows with the current value', 'sources row says when one needs attention'],
  [('a source needs attention', 'the row says "1 needs you" in status-warning text'), ('offline', 'values from the last read, changes queue')],
  ['founder: production settings, nothing dev', 'O-17/18', 'O-28 no dev tools', 'settings-row.md', 'closes T1–T6, L9–L13, K4'],
  ptop('settings'),
  col(group('your brief', srow('daily brief', None, '8:30 · on ›')),
      group('listening', srow('voice', None, 'warm ›'), srow('talk or read', None, 'talk ›')),
      group('you', srow('how straight i am with you', None, 'honest ›'), srow("what i've learned", None, '›')),
      group('sources', srow('connected sources', '4 connected · 1 needs you', '›')),
      group('', srow('privacy'), srow('account'), srow('help')), gap='spacing-6')))

S.append(screen('ST-2 · daily brief', 'When, and whether, your brief arrives.',
  "the switch applies at once (switch rule 1); time is your local time (K4); length is three plain choices, capped at 12 minutes; play today's lets you hear what the settings make.",
  ['top bar: back', 'switch row: each morning', 'value row: time (local)', 'segmented: short · standard · long', "action: play today's"],
  [('off', 'time and length dim; the brief card on Journal goes'), ('saving', 'the switch thumb turns while it saves'), ('not made yet', "play today's says \"ready at 8:30\"")],
  ['O-3 brief', 'K4 local time', 'closes L6'],
  ptop('daily brief'),
  col(srow('each morning', 'a short brief, made from yesterday', trail=sw(True)), srow('time', 'your time, london', '8:30 am ›'), gap='spacing-1'),
  col(t('length', 'text-sm', 'text-label'), seg(['short', 'standard', 'long'], 'standard'), t('standard is about 4 minutes.', 'text-sm', 'text-label'), gap='spacing-2'),
  srow("play today's", 'tuesday · 4 min', '▶')))

S.append(screen('ST-3 · sources', "What you've connected, and how it's going.",
  "each source says what it's for (source-row rule 1: purpose, not permission) and its status in words; one that needs you says exactly what to do, with a reconnect pill; adding and importing come after what you have.",
  ['top bar: back', 'source rows: name · what it\'s for · status in words', 'needs attention: what happened · reconnect', 'add a source', 'import a file (with how-to)'],
  [('syncing', '"reading now"'), ('expired', 'the row says when it stopped, reconnect'), ('none', '"nothing connected. retro still learns from what you tell it."'), ('coming soon', 'listed under add, marked')],
  ['O-17 sources', 'O-22 plain states', 'source-row.md', 'closes Y32–Y35, L14, C6'],
  ptop('sources'),
  col(srow('google', 'mail, docs, calendar · read 2 min ago'), srow('apple health', 'sleep, steps, runs · read today'), srow('spotify', 'stopped reading on monday', trail=pill('reconnect', align='center')), srow('calendar', 'your week · read today'), gap='spacing-1'),
  col(srow('add a source', None, '+'), srow('import a file', 'notes, a journal, an export', '›'), gap='spacing-1')))

S.append(screen('ST-4 · a source', 'One source: what it reads, and control over it.',
  "plain sentences first: what it reads and what that helps retro see; then when it last read and sync now; disconnecting and deleting are separate, last, in danger text, each behind a dialog that says what happens.",
  ['top bar: back · the source', 'reads: plain sentence', 'helps me see: plain sentence', 'last read · sync now', 'disconnect… · delete what it read… (danger, dialogs)'],
  [('syncing', 'sync now becomes "reading…"'), ('failed', 'what happened, and reconnect'), ('disconnected', 'connect again; what it read stays until you delete it')],
  ['O-17 sources', 'safety: confirm before disconnect', 'closes Y32'],
  ptop('google'),
  col(t('reads', 'text-sm', 'text-label'), t('your mail subjects, docs you edit, your calendar and youtube history.', 'text-body', 'text-primary'), gap='spacing-2'),
  col(t('helps me see', 'text-sm', 'text-label'), t('what your work weeks are really like, and what you keep coming back to.', 'text-body', 'text-primary'), gap='spacing-2'),
  srow('last read 2 min ago', None, trail=pill('sync now', align='center')),
  bottom(col(srow('disconnect…', 'stops reading; keeps what it read', '', danger=True), srow('delete what it read…', 'removes it from what retro knows', '', danger=True), gap='spacing-1'))))

S.append(screen('ST-5 · privacy', 'What it reads, where, and how to stop it.',
  "the founder's ambient switch is the first row, with what off means in the subline (only what you send); where your data is processed is named, not hidden; download and delete are last, delete in danger text behind a dialog.",
  ['top bar: back', 'switch: read in the background (subline: off = only what you send)', 'where it\'s processed ›', 'download my data', 'delete my data… (danger, dialog)'],
  [('off', 'a line: "retro only learns from what you send it now"'), ('master switch off (founder)', 'the row is disabled, "paused for everyone"'), ('exporting', '"we\'ll email you a link"')],
  ['O-17 privacy', 'memory: ambient switch', 'closes D1'],
  ptop('privacy'),
  col(srow('read in the background', 'off means retro only learns from what you send it', trail=sw(True)), srow("where it's processed", 'europe · named providers', '›'), srow('download my data', None, trail=pill('export', align='center')), gap='spacing-1'),
  bottom(srow('delete my data…', 'everything retro knows about you', '', danger=True))))

S.append(screen('ST-6 · how straight i am with you', 'How bold it may be.',
  "four plain choices with a tick (the only mark); retro says which it picked and why, so its guess is visible; your choice outranks its guess, and let it decide hands it back.",
  ['top bar: back', 'choice rows: just what happened · gentle questions · honest observations · don\'t hold back', 'why it picked this', 'let it decide'],
  [('retro decides', 'the tick sits on its pick, "picked by retro"'), ('you chose', '"your choice" under the tick; let it decide appears')],
  ['O-16 how bold', 'goal 22'],
  ptop('how straight i am with you'),
  col(tick('just what happened', 'no reading between the lines'), tick('gentle questions', 'i ask, i don\'t tell'), tick('honest observations', 'i say what i see, kindly', True), tick("don't hold back", 'i say it plainly'), gap='spacing-1'),
  t('i picked honest observations because you answer the hard questions, and say "not quite" when i\'m wrong.', 'text-md', 'text-secondary'),
  srow('let it decide', None, '›')))

S.append(screen('ST-7 · voice and listening', 'How it sounds, and how you take things in.',
  "voice is a value with a sample you can play in place; talk or read is a two-way choice (segmented); speed is a value; when a voice made for you exists, it becomes a row here and a step after ON-8.",
  ['top bar: back', 'voice: value · play sample', 'talk or read: segmented', 'speed: value'],
  [('sample playing', 'the play becomes pause'), ('your own voice (later)', 'a row "a voice made for you"')],
  ['O-19 voice', 'K14 listening preference', 'K17', 'closes P1, P2, L9'],
  ptop('voice and listening'),
  col(srow('voice', 'warm · one voice behind every show', trail=pill('▶ sample', align='center')), srow('speed', 'for briefs and episodes', '1× ›'), gap='spacing-1'),
  col(t('talk or read', 'text-sm', 'text-label'), seg(['talk', 'read'], 'talk'), t('talk: retro speaks its replies. read: words only.', 'text-sm', 'text-label'), gap='spacing-2')))

S.append(screen("ST-8 · what i've learned", "How it's learning to ask you better.",
  "read only, in plain sentences, so learning is visible (O-18 transparency) without a dashboard; it says what it changed because of it.",
  ['top bar: back', 'sentences: what you answer · what you skip · what it changed', 'when it last changed'],
  [('too early', '"i\'ll know after a couple of weeks of questions."'), ('off (switch)', '"learning is off" and nothing else')],
  ['O-18 transparency', 'switch ENABLE_LEARNING', 'goal 19'],
  ptop("what i've learned"),
  col(f'<div style="font-family:{V("font-display")};font-size:{V("text-xl")};line-height:{V("leading-snug")};color:{C("text-primary")}">you answer questions about work most, 8 of 10.</div>',
      t("you skip ones about family (1 of 5), so i ask those less, and only when you bring it up first.", 'text-body', 'text-secondary'),
      t('last changed on sunday', 'text-sm', 'text-label'), gap='spacing-4')))

S.append(screen('ST-9 · account', 'Your plan, and your account.',
  "the plan and when it renews lead; managing leaves the app (↗, Apple); sign out is ordinary; delete account is last, alone, in danger text, with a dialog that lists what's removed (App Review requires it).",
  ['top bar: back', 'plan · renews', 'manage subscription ↗', 'restore purchases', 'sign out (AC-2)', 'delete account… (danger, dialog)'],
  [('not subscribed', 'the plan row says "free" and see plans opens the paywall'), ('restoring', '"checking with apple…"'), ('deleting', 'a dialog: what goes, that it can\'t be undone, and type nothing: one confirm')],
  ['O-29 subscriptions', 'App Review: account deletion', 'closes L4'],
  ptop('account'),
  col(srow('yearly', 'renews on 3 march · $199.99', ''), srow('manage subscription', 'in apple settings', '↗'), srow('restore purchases', None, ''), srow('sign out', None, ''), gap='spacing-1'),
  bottom(srow('delete account…', 'your entries, episodes and everything retro knows', '', danger=True))))

# ── Outside the app ──────────────────────────────────
S.append(sheet_screen('EX-1 · share to retrospect', 'Send anything, and it knows what it is and where it goes.',
  "founder: send a link and retro knows what it is and how to file it; so retro reads it first and shows its read (what it is, the goal it goes with) before you type anything; your reason is optional, voice first, and makes it better later; save is the one action; offline it queues; a video's transcript is fetched for you.",
  ['share extension (system sheet)', 'the thing: title · site', "retro's read: what it is · goes with (a goal chip, changeable)", 'add why (optional): voice composer, mic first', 'save (lit)'],
  [('reading', '"reading it…" for under a second, then its read'), ('saving', 'save shows a ring'), ('saved', '"saved · it\'ll be in tomorrow\'s brief", then the sheet closes'), ('offline', '"saved on your phone · i\'ll read it when you\'re back"'), ('video', '"i\'ll fetch the transcript"'), ('no goal fits', 'goes with: nothing yet, and "just keep it"')],
  ['O-31 share', 'K9 save-link', 'K19 link and note types', 'brief: what you send leads'],
  sheet_phone(head('save to retrospect', 'cancel'),
    box('youtube · "how to raise a seed round in 2026" · youtube.com', 72),
    col(t("retro's read", 'text-sm', 'text-label'), t('a 40-minute talk on raising a seed round, mostly about angels.', 'text-body', 'text-primary'), row(t('goes with', 'text-sm', 'text-label'), pill('raise the seed', align='center'), t('change', 'text-md', 'text-secondary'), gap='spacing-3', extra='align-items:center'), gap='spacing-2'),
    col(t('add why (optional)', 'text-sm', 'text-label'), box('voice composer (pill) · mic first', None, row(t('for the raise, the bit on angels…', 'text-body', 'text-primary', extra='flex:1'), t('◎', 'text-sm', 'text-label'))), gap='spacing-2'),
    bottom(box('save (the one lit action)', 52)), behind='safari')))

S.append(screen('EX-2 · lock screen', 'Keep listening without the app open.',
  "audio first (founder): the card shows the part being spoken and where it's from, the same as the open brief; the transport is the system's; the Live Activity carries the same on the Dynamic Island.",
  ['now playing (system): retrospect · tuesday\'s brief', 'the part being spoken · its source', '↺15 ‖ 30↻ · scrubber', 'live activity (same content)'],
  [('playing', 'as drawn'), ('paused', 'play shown'), ('private', 'the part line hides until unlocked if you turned on "hide on lock screen"')],
  ['O-24 background playback', 'O-32 live activity', 'lock-screen-and-widget.md', 'closes N20, Y26'],
  lock_clock(),
  os_card(row(box('art', 48, extra='width:48px;box-sizing:border-box;flex-shrink:0'), col(t("retrospect · tuesday's brief", 'text-sm', 'text-label'), t('the fundraise article you sent', 'text-body', 'text-primary'), t('from the link you sent yesterday', 'text-sm', 'text-secondary'), gap='spacing-1', extra='flex:1'), gap='spacing-3'),
          bar(20), t('↺15        ‖        30↻', 'text-lg', 'text-primary', extra='text-align:center'), extra='margin-top:auto')))

S.append(screen('EX-3 · notifications', 'Tell you when something is ready, then get out of the way.',
  "three kinds, at most one a day, never at night (local time, K4); private by default, so they say that something is ready, not what's in it (lock-screen rule 2); each opens its page: brief → the brief sheet, episode → the player, question → the question sheet.",
  ['notification (system): retrospect · one line we write', 'opens: brief sheet · player · question sheet', 'settings: which kinds, and quiet hours'],
  [('brief ready', '"your brief is ready · 4 min" → JR-2'), ("episode", '"this week\'s episode is here" → PC-2'), ('question', '"one question for you, when you have a minute" → YO-6'), ('previews on (opt in)', 'the title shows: "the week you stopped rushing"')],
  ['O-30 notifications', 'K10 APNs', 'K4 local time', 'closes A6, L11'],
  lock_clock('sunday 26 october', '9:00'),
  col(os_card(row(t('retrospect', 'text-sm', 'text-label', extra='flex:1'), t('now', 'text-sm', 'text-label')), t("this week's episode is here.", 'text-body', 'text-primary')),
      lab('one a day at most · these are the other two kinds:'),
      os_card(row(t('retrospect', 'text-sm', 'text-label', extra='flex:1'), t('8:30', 'text-sm', 'text-label')), t('your brief is ready · 4 min', 'text-body', 'text-primary'), extra='opacity:var(--opacity-disabled)'),
      os_card(row(t('retrospect', 'text-sm', 'text-label', extra='flex:1'), t('6:10 pm', 'text-sm', 'text-label')), t('one question for you, when you have a minute.', 'text-body', 'text-primary'), extra='opacity:var(--opacity-disabled)'),
      gap='spacing-3', extra=f'padding-top:{V("spacing-6")}')))

S.append(screen('EX-4 · widget', "Play today's brief, or talk to it, in one tap.",
  "the medium widget carries the brief's headline in the serif with play and talk; the small one is just talk (tell me…); both stay legible in tinted and clear home screens; before the brief exists it says when it will be ready.",
  ['widget small: the mark · tell me… (opens the composer)', "widget medium: today's brief · headline (serif) · play · talk"],
  [('brief ready', 'as drawn'), ('being made', '"ready at 8:30", no play'), ('played', 'headline secondary, "played"'), ('quiet day', '"a quiet day"')],
  ['O-32 widget', 'lock-screen-and-widget.md'],
  t('9:41', 'text-md', 'text-secondary'),
  row(os_card(f'<div layer-name="the mark" style="width:32px;height:32px;border-radius:{V("radius-control")};background:{C("surface-strong")}"></div>', t('tell me…', 'text-body', 'text-primary', extra='margin-top:auto'), extra='width:160px;height:160px;box-sizing:border-box'),
      col(*[box('app', 64, extra='width:64px;box-sizing:border-box') for _ in range(2)], gap='spacing-4'), col(*[box('app', 64, extra='width:64px;box-sizing:border-box') for _ in range(2)], gap='spacing-4'), gap='spacing-4'),
  os_card(t("today's brief · 4 min", 'text-sm', 'text-label'), f'<div style="font-family:{V("font-display")};font-size:{V("text-lg")};line-height:{V("leading-snug")};color:{C("text-primary")}">a heavier week than usual, and it shows.</div>',
          row(pill('▶ play'), pill('talk'), gap='spacing-3', extra='margin-top:auto'), extra='height:160px;box-sizing:border-box')))

for i, s in enumerate(S):
    open(f'pq{i:02d}.html', 'w').write(s.replace('\n', '').replace('font-weight:var(--font-weight-regular);', '').replace('line-height:var(--leading-snug);', ''))
print(len(S))
