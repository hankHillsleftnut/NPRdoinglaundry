# Every state of every page, drawn: one row per page, the default first, then each state named in its notes.
from mf import *

def kb(): return box('keyboard', 270)
def typed(text): return box('voice composer · typing (text field, send lit)', None, row(t(text, 'text-body', 'text-primary', extra='flex:1'), t('send ↑', 'text-sm', 'text-link')))
def line(s, c='text-secondary'): return t(s, 'text-md', c)
def words(settled, fresh): return f'<div style="font-family:{V("font-text")};font-size:{V("text-xl")};line-height:{V("leading-snug")};color:{C("text-secondary")}">{settled} <span>{fresh}</span></div>'
def blurwords(settled, fresh):  # spoken words: settled ones secondary, the newest still blurring in (drawn tertiary)
    return row(t(settled, 'text-xl', 'text-secondary', extra='flex-shrink:0'), t(fresh, 'text-xl', 'text-tertiary', extra='flex-shrink:0'), gap='spacing-2', extra='flex-wrap:wrap')
def inset(label, h): return box(label, h, extra=f'background:{C("background-canvas")}')
def sheet(*content): return box('sheet (edge to edge, from the bottom)', None, col(*content, gap='spacing-3'), extra=f'width:390px;align-self:center;padding:{V("spacing-6")};margin-top:auto')
def dimmed(label, grow=True): return box(label, grow=grow, extra='opacity:var(--opacity-disabled)')
def alert(s): return box('system alert, centred over the page', 140, col(t(s, 'text-md', 'text-primary', extra='text-align:center'), row(t("don't allow", 'text-md', 'text-link', extra='flex:1;text-align:center'), t('allow', 'text-md', 'text-link', 'font-weight-semibold', extra='flex:1;text-align:center')), gap='spacing-3'), extra='width:270px;align-self:center')

def v(name, *content, bare=False):
    ph = content[0] if bare else phone(*content)
    return col(t(name, 'text-md', 'text-primary', 'font-weight-semibold'), ph, gap='spacing-2')
def page(code, *variants):
    return (f'<div layer-name="states · {code}" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">'
            + t(code, 'text-xl', 'text-primary', 'font-weight-semibold') + row(*variants, gap='spacing-8') + '</div>')

P = []
# ON-1/2 splash
def splash(note=None, apple='Sign in with Apple', dim=False, still=False):
    btns = [box(apple, 56), box('Continue with Google', 56, extra='opacity:var(--opacity-disabled)' if dim else '')]
    return [box(('still constellation (reduced motion)' if still else 'constellation'), 380, extra='width:390px;align-self:center;border-radius:0'),
            col(title('everything about you, finally connected.'), t('retrospect gets to know you, and tells you what it sees.', 'text-body', 'text-secondary'), gap='spacing-2'),
            bottom(*( [line(note)] if note else []), *btns, t('terms · privacy', 'text-sm', 'text-label', extra='text-align:center'))]
P.append(page('ON-1/2 · splash + sign-in',
  v('idle', *splash()), v('signing in', *splash(apple='Sign in with Apple  ◌', dim=True)),
  v('failed', *splash("couldn't sign you in. check your connection and try again.")),
  v('offline', *splash("you're offline. sign-in waits until you're back.", dim=True)), v('reduced motion', *splash(still=True))))

# ON-3 hello
def hello(spoken, seg='segmented · talk (selected) | type', bar='retro is speaking…', extra=None, kbd=False):
    # the name holds the screen's centre line in every state: the mark sits above it, what retro says hangs below, so neither pushes it
    upper = col(box('the mark', 64, extra='width:64px;align-self:center'), title('hello, my name is retro.', 'text-align:center'), gap='spacing-6', extra='flex:1;justify-content:flex-end')
    lower = col(t(spoken, 'text-md', 'text-tertiary', extra='text-align:center'), *([extra] if extra else []), gap='spacing-6', extra='flex:1')
    tail = bottom(box(seg, 44, extra='width:220px;align-self:center'), typed('type anything…'), kb()) if kbd else bottom(box(seg, 44, extra='width:220px;align-self:center'), composer(bar, anchor=False))
    return [top('', False, 0.05), col(upper, lower, gap='spacing-4', extra='flex-grow:1;min-height:0'), tail]
P.append(page('ON-3 · retro says hello',
  v('speaking (lines arrive one at a time)', *hello('"i want to understand you, and help you live a bit better."')),
  v('muted (same words, no sound)', *hello('"i want to understand you, and help you live a bit better. you save things you never go back to; i won\'t forget them. we don\'t have to be friends: i\'m not a person."', bar='sound off · words only')),
  v('type chosen', *hello('"i want to understand you…"', seg='segmented · talk | type (selected)', kbd=True)),
  v('replay', *hello('"i want to understand you…"', extra=pill('↺ replay', align='center')))))

# the five question pages share the question template
def stage(s):  # where you are in onboarding: a small tag with a message corner, shown as a page opens, then it fades
    return (f'<div style="align-self:flex-start;padding:{V("spacing-1")} {V("spacing-3")};background:{C("surface-control")};'
            f'border-radius:{V("radius-message")} {V("radius-message")} {V("radius-message")} {V("radius-small")}">' + t(s, 'text-sm', 'text-secondary') + '</div>')
def q(prog, label, question, body=None, bar=None, extra=None, kbd=False, partial=False, tag=False):
    w = question.split(' ')
    ask = title(question if not partial else ' '.join(w[:max(3, len(w) // 2)]) + '…')
    if tag: ask = col(stage(label), ask, gap='spacing-3')
    head = col(ask, *( [body] if body else []), *( [extra] if extra else []), gap='spacing-6', extra='padding-top:var(--spacing-4)')
    tail = bottom(typed(bar), kb()) if kbd else composer(bar or 'listening…')
    return [top('', True, prog), head, tail]
QS = [('ON-4a · your name', 0.1, 'getting to know you', 'first, what should i call you, and where are you based?', 'sam.', 'london'),
      ('ON-4c · a year from now', 0.24, 'getting to know you', 'picture a year from now, and everything has gone as well as it realistically could. what does your life look like?', "i'd have shipped the thing,", 'and i\'d see my family more'),
      ('ON-4d · lately', 0.32, 'getting to know you', "what's been taking up most of your head lately?", 'honestly, whether to', 'leave my job'),
      ('ON-8a · what you care about', 0.6, "where you're headed", "what do you care about most: the things you'd protect even if they cost you?", 'my family, and', 'my time'),
      ('ON-8b · one thing to change', 0.66, "where you're headed", "what's one thing you keep meaning to change, and what's gotten in the way so far?", 'going to bed earlier;', 'my phone')]
for code, prog, label, question, settled, fresh in QS:
    P.append(page(code,
      v('retro speaking (the question streams in; the stage tag shows, then fades)', *q(prog, label, question, bar='retro is speaking…', partial=True, tag=True)),
      v('listening (your words blur in)', *q(prog, label, question, body=blurwords(settled, fresh))),
      v('thinking (words settle; under 1.2 s)', *q(prog, label, question, body=t(settled + ' ' + fresh + '.', 'text-xl', 'text-secondary'), bar='· · ·')),
      v('typed (muted)', *q(prog, label, question, bar=settled + ' ' + fresh, kbd=True)),
      v('offline (answer kept)', *q(prog, label, question, body=t(settled + ' ' + fresh + '.', 'text-xl', 'text-secondary'), extra=line("you're offline. your answer is kept; we'll pick up here."), bar='offline · your answer is saved'))))

# ON-4b reply
def reply(s): return [top('', True, 0.16), col(title(s), gap='spacing-4', extra='padding-top:var(--spacing-4)'), composer('retro is speaking…')]
P.append(page('ON-4b · retro replies',
  v('speaking', *reply("nice to meet you, sam. london in october: i'll make sure your brief knows about the rain.")),
  v('deeper later (refers back)', *reply('you said family twice now, once as the thing you\'d protect. i\'ll remember that.')),
  v('one follow-up (at most)', *reply('when you say "the thing", is that the company, or something you\'re making on the side?'))))

# ON-4e news
def news(sel, extra=None, tag=False):
    chips = f'<div style="display:flex;flex-wrap:wrap;gap:var(--spacing-3)">' + ''.join(pill(('✓ ' if x in sel else '') + x, lit=x in sel) for x in ['tech', 'world', 'markets', 'sport', 'science', 'culture', 'local']) + '</div>'
    return q(0.38, 'getting to know you', 'what news do you actually follow?', body=chips, extra=extra, bar='or say which outlets…', tag=tag)
P.append(page('ON-4e · the news you follow',
  v('nothing picked yet (the stage tag shows, then fades)', *news([], tag=True)), v('chips picked (raised, ticked)', *news(['tech', 'markets'])),
  v('none (fine)', *news([], extra=line("that's fine; your brief will carry only your own things.")))))

# ON-5 privacy
def privacy(bar='retro is speaking…', extra=None):
    return [top('privacy', True, 0.44), col(box('lock in soft rings', 200, extra='width:240px;align-self:center'), title('what you tell me stays yours.', 'text-align:center'),
            t('i only read what you connect and tell me. a few trusted companies help me understand it, and more of it moves onto your phone over time. i never sell it. delete everything, anytime.', 'text-body', 'text-secondary', extra='text-align:center'),
            t('read the privacy policy', 'text-md', 'text-link', extra='text-align:center'), gap='spacing-6', extra='flex-grow:1;justify-content:center'), composer(bar)]
P.append(page('ON-5 · privacy',
  v('reading aloud', *privacy()), v('muted (words only)', *privacy('sound off · words only')),
  v('policy open', top('privacy', True, 0.44), dimmed('privacy page, dimmed behind'), sheet(title('privacy policy'), t('the full policy, plain and searchable…', 'text-body', 'text-secondary'), inset('policy text (scrolls)', 300), t('done', 'text-md', 'text-link', extra='text-align:center')))))

# ON-6 connect
def connect(cards, meter='what retro can see · ink meter (two sources)', note=None):
    rows = [row(*[box(c, 104, extra='flex:1') for c in cards[i:i + 2]], gap='spacing-3') for i in range(0, len(cards), 2)]
    return [top('connect', True, 0.52), col(title("let me see what words can't."), box(meter, 12), gap='spacing-4'),
            scroll(*rows, *( [line(note)] if note else [])), bottom(box('continue (raised neutral pill)', 48), composer(anchor=False))]
base = ['health · ✓ connected', 'calendar · ✓ connected', 'google · + connect', 'contacts · + connect']
P.append(page('ON-6 · connect',
  v('default', *connect(base + ['screen time · + connect', 'photos · + connect'])),
  v('connecting (pill keeps its width)', *connect(['health · ✓ connected', 'calendar · ✓ connected', 'google · connecting ◌', 'contacts · + connect', 'screen time · + connect', 'photos · + connect'])),
  v('connected (meter fills; retro says what it sees)', *connect(['health · ✓ connected', 'calendar · ✓ connected', 'google · ✓ connected', 'contacts · + connect', 'screen time · + connect', 'photos · + connect'], meter='what retro can see · ink meter (three sources)', note='"now i can see your mail and drive, so your brief can carry what\'s in them."')),
  v('failed', *connect(['health · ✓ connected', 'calendar · ✓ connected', "google · couldn't connect · try again", 'contacts · + connect', 'screen time · + connect', 'photos · + connect'])),
  v('denied', *connect(['health · ✓ connected', 'calendar · ✓ connected', 'google · + connect', 'contacts · not allowed · allow in settings ›', 'screen time · + connect', 'photos · + connect'])),
  v('waiting on approval', *connect(base + ['tiktok · waiting on their approval', 'x · waiting on their approval'], note='retro will tell you when they open.'))))

# ON-9 how straight
def straight(pick, reason, others, extra=None):
    return [top('how straight', True, 0.72), col(title("here's what i think you're ready for."), *( [extra] if extra else []), raised(f'{pick} · {reason}', 120), gap='spacing-4', extra='padding-top:var(--spacing-4)'),
            col(t('or choose another', 'text-md', 'text-label'), *[box(o, 48) for o in others], gap='spacing-2', extra='padding-top:var(--spacing-4)'), composer()]
P.append(page('ON-9 · how straight',
  v('recommended', *straight('recommended (raised) · honest observations', 'because you said you want to be challenged', ['just what happened', 'gentle questions', "don't hold back"])),
  v('changed (your pick moves into the card)', *straight('your pick (raised) · gentle questions', '', ['just what happened', "honest observations (retro's suggestion)", "don't hold back"])),
  v('said aloud', *straight('your pick (raised) · gentle questions', 'you said it', ['just what happened', "honest observations (retro's suggestion)", "don't hold back"], extra=t('"gentler, please"', 'text-xl', 'text-secondary')))))

# ON-8c brief
def brief(card='brief card preview · tomorrow · ~4 min', rowl='one grouped row · time 8:30 am ›   on ●', extra=None, over=None):
    c = [top('your brief', True, 0.8), title('every morning, a few minutes on what changed, and why it matters to you.', 'padding-top:var(--spacing-4)'),
         col(box(card, 110), box(rowl, 52), gap='spacing-2'), *( [extra] if extra else []), *( [over] if over else []), composer()]
    return c
P.append(page('ON-8c · your morning brief',
  v('on (by default)', *brief()),
  v('time changed', top('your brief', True, 0.8), dimmed('brief page, dimmed behind'), sheet(title('when should it be ready?'), inset('wheel picker · 7:45 am', 160), t('done', 'text-md', 'text-link', extra='text-align:center'))),
  v('asking for notifications', *brief(over=alert('"Retrospect" would like to send you notifications'))),
  v('allowed', *brief(extra=line("i'll tell you when it's ready."))),
  v('not now (it still plays in the app)', *brief(extra=line('no notifications. your brief still waits for you in journal.'))),
  v('turned off', *brief(card='brief card · off', rowl='one grouped row · daily brief   off ○', extra=line('your brief is off. turn it on here or in settings, anytime.')))))

# ON-10 getting ready
def ready(stages, q_='one more while i put it together: who would you call if something went wrong? anyone you wish you saw more?', extra=None):
    return [top('your first episode', True, 0.88), col(title(q_), *( [extra] if extra else []), gap='spacing-4', extra='padding-top:var(--spacing-4)'), bottom(box(stages, 44), composer(anchor=False))]
P.append(page('ON-10 · getting ready',
  v('making', *ready('reading your calendar ✓ · writing your episode ◌ · recording the voice')),
  v('quiet wait (questions done)', *ready('writing your episode ◌ · recording the voice', q_='"you said mornings are for thinking." i\'m still writing. close the app if you like; i\'ll tell you.')),
  v('ready (the tease starts on its own)', *ready('reading ✓ · writing ✓ · recording ✓', q_="it's ready. here's the first thing i noticed.")),
  v('slow', *ready('writing your episode ◌ (longer than usual)', q_="this is taking longer than usual. i'll notify you the moment it's ready.")),
  v('failed', *ready("something went wrong making it · your answers are kept", q_="i couldn't finish your episode. your answers are safe.", extra=row(pill('try again'), pill('make it tonight'), gap='spacing-3')))))

# ON-11 tease
def tease(transcript='transcript · current line sharp, earlier lines blurred and fading', scrub='scrubber 0:31 / 5:02', extra=None):
    return [top('', False, 0.95), col(title('the week you started'), t("here's the first thing i noticed. it's narrow, because it's day one.", 'text-body', 'text-secondary'), gap='spacing-2', extra='padding-top:var(--spacing-4)'),
            box(transcript, grow=True), *( [extra] if extra else []), bottom(box(scrub, 40), box('↺15   ‖   30↻', 72), gap='spacing-4')]
P.append(page('ON-11 · the tease',
  v('playing', *tease()), v('buffering', *tease(transcript='transcript waits at the last line heard', scrub='scrubber 0:31 / 5:02 · buffered to 0:40 ◌')),
  v('failed', *tease(transcript="it stopped playing. your episode is saved.", extra=row(pill('try again'), pill('tell me when fixed'), gap='spacing-3')))))

# ON-12 paywall
def pay(plans=('yearly · $199.99 · save 17% (selected)', 'monthly · $19.99'), cta='subscribe (the one lit action)', extra=None):
    return [box('mini player · the week you started · 0:38', 56), title('hear the rest, and one every week.'),
            scroll(box('benefits, with your own examples: a brief every morning · an episode every week · ask your own mind · goals said vs did · talk to retro anytime · everything you save, remembered', 180)),
            bottom(*( [line(extra)] if extra else []), row(box(plans[0], 70, extra='flex:1'), box(plans[1], 70, extra='flex:1'), gap='spacing-3'), box(cta, 56), t('not now · restore · privacy · terms', 'text-sm', 'text-label', extra='text-align:center'))]
P.append(page('ON-12 · the paywall',
  v('choosing', *pay()), v('loading prices (no fake prices)', *pay(plans=('yearly · ◌', 'monthly · ◌'), cta='subscribe (waits for prices)')),
  v('purchasing', *pay(cta='subscribe · · ·')),
  v('purchased (settles away to home)', box('mini player · the week you started · 0:38', 56), col(title("you're in."), t('the rest of your episode is playing. one every week from now on.', 'text-body', 'text-secondary'), gap='spacing-2', extra='flex-grow:1;justify-content:center')),
  v('failed', *pay(extra='that didn\'t go through. nothing was charged.'))))

# ON-13 home first visit
def home(hint=None, card="today's brief · 4 min · ▶ (lit) · leads with what you sent, each item with why", hint_at_bar=None, hint_at_tab=None):
    return [jtop(), col(brief_anchor(card), *( [t(hint, 'text-sm', 'text-label')] if hint else []), gap='spacing-2'),
            thread(exchange('today', recap(t('your first conversation with retro', 'text-body', 'text-primary', 'font-weight-medium') + t('9 answers · 12 min · open ›', 'text-sm', 'text-label')),
                   retro("that's enough to start. your first episode is waiting in podcasts, and tomorrow's brief will know you a little better."))),
            bottom(*( [t(hint_at_bar, 'text-sm', 'text-label')] if hint_at_bar else []), composer('message retro…', anchor=False), *( [t(hint_at_tab, 'text-sm', 'text-label', extra='text-align:right')] if hint_at_tab else []), tabbar('journal'), gap='spacing-3')]
P.append(page('ON-13 · home, first visit',
  v('hint 1 · the brief', *home('↑ press play for your brief (1 of 3)')), v('hint 2 · talking', *home(hint_at_bar='talk to me here, anytime ↓ (2 of 3)')),
  v('hint 3 · search your mind', *home(hint_at_tab='search your mind in you ↓ (3 of 3)')), v('hints done', *home()),
  v('not subscribed', *home(card="today's brief · part of premium · see what's in it ›"))))

# AC-1 / AC-2
def signin(note=None, apple='Sign in with Apple'):
    return [col(box('the mark', 64, extra='width:64px;align-self:center'), title('welcome back.', 'text-align:center'), *( [line(note)] if note else []), gap='spacing-6', extra='flex-grow:1;justify-content:center'),
            bottom(box(apple, 56), box('Continue with Google', 56), t('new here? get started', 'text-md', 'text-link', extra='text-align:center'))]
P.append(page('AC-1 · sign in (returning)',
  v('default', *signin()), v('signing in', *signin(apple='Sign in with Apple  ◌')), v('restoring', *signin('bringing back your entries and episodes…')),
  v('failed', *signin("that didn't work. try again, or use the other account.")), v('offline', *signin("you're offline. this waits until you're back."))))
def signout(lines, cta):
    return [dimmed('settings, scaled and dimmed behind'), sheet(title('sign out?'), t('your entries and episodes stay in your account. this phone forgets them.', 'text-body', 'text-secondary'), *lines, inset(cta, 52), t('cancel', 'text-md', 'text-label', extra='text-align:center'))]
P.append(page('AC-2 · signing out',
  v('unsent entries', *signout([t('1 entry not sent yet', 'text-md', 'text-primary', 'font-weight-medium')], 'send, then sign out')),
  v('nothing unsent', *signout([], 'sign out')),
  v('signing out', col(box('the mark', 64, extra='width:64px;align-self:center'), line('signing you out…'), gap='spacing-4', extra='flex-grow:1;justify-content:center;align-items:center'))))

# JR-1 journal
def journal(card="today's brief · 4 min · ▶ (lit) · leads with what you sent, each item with why", items=None, bar='message retro…', above_bar=None, compact=False):
    items = items or [exchange('today', mine("i think it's the 9am standup. i dread it."), retro('want me to keep an eye on how mondays go for the next few weeks?'), mine('yes', '✓ read'))]
    b = box('brief · slim bar · ▶ (lit)', 48) if compact else brief_anchor(card)
    return [jtop(), b, thread(*items), bottom(*( [above_bar] if above_bar else []), composer(bar, anchor=False), tabbar('journal'), gap='spacing-3')]
older = [exchange('sunday', recap(t('your first conversation with retro', 'text-body', 'text-primary', 'font-weight-medium') + t('9 answers · 12 min · open ›', 'text-sm', 'text-label'))),
         exchange('monday', mine('slept badly, long day of meetings'), col(retro("third monday like that. what's different about mondays?"), because('from your last 3 mondays ›'), gap='spacing-1'))]
P.append(page('JR-1 · journal',
  v('default', *journal()),
  v('scrolled up (the brief compacts)', *journal(items=older, compact=True)),
  v('brief making', *journal(card='making your brief · ready by 8:30 · ◌')),
  v('brief quiet', *journal(card="today's brief · a quiet day; nothing new · ▶ 40 s")),
  v('nothing today', *journal(items=[exchange('today', retro("morning, sam. how did the standup go?"))])),
  v('talking (your words blur in)', *journal(items=[exchange('today', mine("i think it's the 9am standup.")), col(t('i dread it, and i', 'text-body', 'text-secondary', extra='align-self:flex-end'), t('think it…', 'text-body', 'text-tertiary', extra='align-self:flex-end'), gap='spacing-1')], bar='listening…')),
  v('retro thinking', *journal(items=[exchange('today', mine("i think it's the 9am standup. i dread it.", '✓ read'), t('· · ·', 'text-xl', 'text-secondary'))])),
  v('unsent or failed', *journal(items=[exchange('today', mine("i think it's the 9am standup. i dread it.", "didn't send · tap to retry"))])),
  v('offline', *journal(items=[exchange('today', mine("i think it's the 9am standup. i dread it.", "saved · sends when you're back"))], above_bar=line("you're offline. everything you say is kept."))),
  v('server failing', *journal(above_bar=line("retro can't reply right now. your messages are saved; replies will come when it's back."))),
  v('ambient off', *journal(card='your brief is off · turn on ›'))))

# JR-3 drawer
def drawer_v(listing_rows, search_text='search your journal', peek_x=True):
    srch = f'<div style="height:44px;border-radius:{V("radius-control")};background:{C("background-canvas")};padding:0 {V("spacing-4")};display:flex;align-items:center;gap:{V("spacing-2")}">' + t('⌕', 'text-body', 'text-label') + t(search_text, 'text-body', 'text-tertiary' if search_text.startswith('search') else 'text-primary') + '</div>'
    dr = col(t('9:41', 'text-md', 'text-secondary'), srch, col(*listing_rows, gap='spacing-6', extra='flex-grow:1;min-height:0;overflow:hidden'),
             row(t('settings', 'text-md', 'text-secondary', extra='flex:1'), t('v1.0', 'text-sm', 'text-label'), gap='spacing-2', extra=f'padding:0 {V("spacing-3")}'),
             gap='spacing-6', extra=f'width:276px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-4")} {V("spacing-8")}')
    pk = col(t('9:41', 'text-md', 'text-secondary'), box('brief', 64), col(extra='flex-grow:1'), box('bar', 44),
             extra=f'width:390px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-6")} {V("spacing-8")};border-radius:{V("radius-sheet")};background:{C("background-canvas")};box-shadow:0 0 0 1px {C("border-subtle")}, 0 4px 16px {C("depth-shadow-cast")}')
    return (f'<div layer-name="phone" style="width:390px;height:844px;flex-shrink:0;box-sizing:border-box;display:flex;background:{C("surface-control")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-strong")};overflow:hidden">' + dr + pk + '</div>')
def drow(words, meta, here=False):
    bg = f'background:{C("background-canvas")};' if here else ''
    return f'<div style="border-radius:{V("radius-default")};{bg}padding:{V("spacing-3")}">' + col(t(words, 'text-body', 'text-primary'), t(meta, 'text-sm', 'text-label'), gap='spacing-1') + '</div>'
dday = lambda x: t(x, 'text-sm', 'text-label', 'font-weight-medium', extra=f'padding:0 {V("spacing-3")}')
days = [col(dday('today'), drow("i think it's the 9am standup. i dread it.", '3 messages · retro replied · 9:12', True), gap='spacing-1'),
        col(dday('yesterday'), drow('slept badly, long day of meetings', '2 messages · 22:40'), drow('on the walk home i kept thinking about…', 'voice note · 1:42'), drow('the fundraise article you shared', 'link · shared from safari · retro asked why'), gap='spacing-1'),
        col(dday('sunday'), drow('my first conversation with retro', '9 answers · 12 min'), gap='spacing-1')]
half = (f'<div layer-name="phone" style="width:390px;height:844px;flex-shrink:0;box-sizing:border-box;display:flex;background:{C("surface-control")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-strong")};overflow:hidden">'
        + col(lab('drawer fading in (opacity follows the page)'), extra=f'width:138px;flex-shrink:0;padding:{V("spacing-4")};opacity:var(--opacity-disabled)')
        + col(t('9:41', 'text-md', 'text-secondary'), box('brief', 64), col(extra='flex-grow:1'), box('bar', 44), extra=f'width:390px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-6")} {V("spacing-8")};border-radius:{V("radius-sheet")};background:{C("background-canvas")};box-shadow:0 4px 16px {C("depth-shadow-cast")}') + '</div>')
P.append(page('JR-3 · all journals (drawer)',
  v('open', drawer_v(days), bare=True),
  v('opening (follows your finger)', half, bare=True),
  v('searching', drawer_v([col(dday('2 results for "standup"'), drow("i think it's the 9am [standup]. i dread it.", 'today · 9:12'), drow('the [standup] ran long again', 'last tuesday'), gap='spacing-1')], search_text='standup'), bare=True),
  v('empty', drawer_v([t('nothing yet. say anything.', 'text-body', 'text-secondary', extra=f'padding:0 {V("spacing-3")}')]), bare=True),
  v('some unsent', drawer_v([col(dday('today'), drow("i think it's the 9am standup. i dread it.", "didn't send · tap to retry", True), gap='spacing-1')] + days[1:]), bare=True),
  v('jump (thread scrolled to it)', *journal(items=older, compact=True))))

open('states.html', 'w').write('\n'.join(P).replace('font-weight:var(--font-weight-regular);', ''))
for i, p in enumerate(P):
    open(f'st{i:02d}.html', 'w').write(p.replace('font-weight:var(--font-weight-regular);', ''))
print(len(P), sum(p.count('layer-name="phone"') for p in P))
