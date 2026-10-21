# The product after onboarding, chunk 1: Journal (the brief opened, an entry) and Podcasts (tiles, the player, why this is here).
from mf import *
S = []
def sheet_screen(code, purpose, why, components, states, ledger, ph):  # a screen whose phone is already built (a sheet over a page)
    return (f'<div layer-name="{code}" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">' + ph + notes(code, purpose, why, components, states, ledger) + '</div>')
def entry_top():  # back on the leading side, edit on the trailing side
    return col(t('9:41', 'text-md', 'text-secondary'), row(t('←', 'text-body', 'text-secondary', extra='width:24px'), t('', extra='flex:1'), t('edit', 'text-md', 'text-secondary')), gap='spacing-2')

def sheet_phone(*content, behind='journal'):  # a sheet over a page: the page behind shows as a scaled, dimmed strip; the sheet carries the content
    strip = f'<div style="height:24px;margin:0 {V("spacing-4")};flex-shrink:0;border-radius:{V("radius-sheet")} {V("radius-sheet")} 0 0;background:{C("background-canvas")};opacity:var(--opacity-disabled)"></div>'
    grab = f'<div style="width:36px;height:5px;flex-shrink:0;align-self:center;border-radius:{V("radius-control")};background:{C("border-strong")}"></div>'
    body = col(grab, *content, gap='spacing-6', extra=f'flex-grow:1;min-height:0;box-sizing:border-box;padding:{V("spacing-3")} {V("spacing-6")} {V("spacing-8")};border-radius:{V("radius-sheet")} {V("radius-sheet")} 0 0;background:{C("background-raised")};box-shadow:0 -1px 0 {C("border-strong")}')
    return (f'<div layer-name="phone" style="width:390px;height:844px;flex-shrink:0;box-sizing:border-box;padding-top:{V("spacing-10")};display:flex;flex-direction:column;gap:{V("spacing-2")};background:{C("surface-control")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-strong")};overflow:hidden">'
            + t(f'{behind}, scaled and dimmed behind', 'text-sm', 'text-label', extra=f'padding:0 {V("spacing-6")}') + strip + body + '</div>')
def head(left, right='share · ⌄'):
    return row(t(left, 'text-sm', 'text-label', extra='flex:1'), t(right, 'text-md', 'text-secondary'))
def guess(q):  # what it's wondering: a guess, unfinished (dashed), answered in place
    pills = row(pill('yes'), pill('not quite'), pill('why do you think that?'), gap='spacing-3', extra='flex-wrap:wrap')
    return (f'<div style="border-radius:{V("radius-default")};padding:{V("spacing-4")};background:{C("inference-surface")};box-shadow:inset 0 0 0 1px {C("inference-border")};display:flex;flex-direction:column;gap:{V("spacing-3")}">'
            + t("it's wondering · a guess", 'text-sm', 'text-label') + t(q, 'text-body', 'text-primary') + pills + '</div>')
def controls(scrub, chips=('chapters', 'not right')):
    return bottom(box(scrub, 40), box('transport · ↺15  ‖ (raised play well, no glow)  30↻ · 1x', 72), row(*[pill(c) for c in chips], gap='spacing-3', extra='justify-content:center'), gap='spacing-4')
def took(claim):  # one thing retro took from an entry: the claim, and its correction as a trailing control
    return row(t(claim, 'text-md', 'text-primary', extra='flex:1'), t('not right', 'text-md', 'text-secondary', extra='flex-shrink:0'), gap='spacing-3', extra=f'min-height:44px;box-sizing:border-box;align-items:center;padding:0 {V("spacing-4")};border-radius:{V("radius-default")};background:{C("surface-control")}')
def rests(date, what):  # one piece of evidence: when, what, and open as the trailing control
    return row(col(t(date, 'text-sm', 'text-label'), t(what, 'text-md', 'text-primary'), gap='spacing-1', extra='flex:1'), t('open ›', 'text-md', 'text-secondary', extra='flex-shrink:0'), gap='spacing-3', extra=f'min-height:44px;box-sizing:border-box;align-items:center;padding:{V("spacing-3")} {V("spacing-4")};border-radius:{V("radius-default")};background:{C("surface-control")}')
def item(n, what, why, here=False):
    bg = f'background:{C("background-canvas")};box-shadow:inset 0 0 0 1px {C("border-strong")};' if here else ''
    return (f'<div style="border-radius:{V("radius-default")};{bg}padding:{V("spacing-3")};display:flex;gap:{V("spacing-3")}">'
            + t(str(n), 'text-md', 'text-label', extra='width:16px;flex-shrink:0')
            + col(t(what, 'text-body', 'text-primary'), because(why), gap='spacing-1', extra='flex:1') + '</div>')

def now_item(pos, what, why, source):  # audio first: only the part being spoken is shown in full, with its source, so a glance answers "what is this and where is it from"
    src = row(t(source, 'text-sm', 'text-secondary', extra='flex:1'), t('open ›', 'text-sm', 'text-secondary', extra='flex-shrink:0'), gap='spacing-3', extra='min-height:44px;align-items:center')
    return (f'<div style="border-radius:{V("radius-default")};background:{C("background-canvas")};box-shadow:inset 0 0 0 1px {C("border-strong")};padding:{V("spacing-4")} {V("spacing-4")} {V("spacing-1")};display:flex;flex-direction:column;gap:{V("spacing-2")}">'
            + t(pos, 'text-sm', 'text-label') + t(what, 'text-lg', 'text-primary') + because(why) + src + '</div>')
def up_next(n, what):  # the rest of the brief, one quiet line each; its source shows when it plays
    return row(t(str(n), 'text-md', 'text-label', extra='width:16px;flex-shrink:0'), t(what, 'text-md', 'text-secondary', extra='flex:1'), gap='spacing-3', extra=f'min-height:44px;align-items:center;padding:0 {V("spacing-4")}')

# JR-2 · today's brief, opened: the player in brief mode, over Journal
S.append(sheet_screen('JR-2 · today\'s brief (open)', 'Hear today\'s brief and see why each part is in it.',
  'the brief is mostly heard, not read (founder), so the sheet is built for a glance: the part being spoken is the only one shown in full, with why it\'s here and its source (open ›); what comes next is one quiet line each, and its source shows when it plays; the brief opens in the player like every episode, so there is one way to listen; controls stay in the thumb zone; with the screen off, the lock screen carries the same: the part, and where it\'s from.',
  ['player sheet (page behind as a strip)', 'header: today\'s brief · date · share · close', 'title (inky): the through-line', 'why line (what it\'s made from)', 'now: the part being spoken, why, its source (open ›)', 'next: one line each, source shown when it plays', 'progressive blur into the controls', 'scrubber with item ticks', 'transport (raised well)', 'items · not right pills'],
  [('playing', 'as drawn; the item in play is raised and follows the voice'), ('paused', 'play shown; the item stays raised'), ('played', 'replay; the card on Journal reads "played"'), ('quiet day', 'one serif line, no items: "nothing much moved. enjoy the quiet."'), ('not made yet', 'the sheet says "your brief is being made · ready by 8:30"'), ('offline', 'a downloaded brief plays; otherwise "needs a connection" with the time it was made'), ('locked screen', 'lock-screen and Control Center controls, a now-playing Live Activity')],
  ['#6 the brief is your inbox', '#19 brief', 'goals doc: each item says why', 'O-3, O-10, O-24', 'player.md', 'closes Y26, N20'],
  sheet_phone(head("◆ today's brief · tue 21 oct"),
    col(title('a heavier week than usual, and it shows.'), because('from 2 links you sent · your calendar · 3 entries ›'), gap='spacing-2'),
    scroll(now_item('now · 1 of 3', 'the fundraise article you sent', 'goes with: raise the seed', 'from: the link you sent yesterday, 9:14'),
           col(t('next', 'text-sm', 'text-label', extra=f'padding:0 {V("spacing-4")}'), up_next(2, 'four meetings before noon'), up_next(3, 'five hours of sleep, two nights running'), gap='spacing-1'), gap='spacing-6'),
    controls('scrubber 0:48 / 4:10 · ticks per item', ('items', 'not right')))))

# JR-4 · an entry
S.append(screen('JR-4 · an entry', 'Read back, change or remove one thing you said.',
  'your words lead, large and inky, the date small under them (the current app had a 36pt date over small grey words); what retro took from it is listed so you can correct it where you see it (O-10); edit re-reads it; delete removes it from the brain too, behind a dialog, in the bottom zone.',
  ['top bar: back · edit', 'your words (inky)', 'date · kind · state', 'voice note player (voice entries)', 'retro\'s reply, with "see it in journal"', 'what i took from this: rows with not right', 'delete (destructive, bottom zone, dialog)'],
  [('editing', 'your words become a text field, keyboard up; save re-sends'), ('re-reading', '"retro is reading it again" under the date, then the list refreshes'), ('voice entry', 'a play row under the date; the words are the transcript'), ('nothing taken yet', '"retro hasn\'t read this yet" with the state'), ('deleting', 'a dialog: "this removes it and what retro took from it. it can\'t be undone."'), ('failed to send', '"didn\'t send · tap to retry" under the date'), ('offline', 'edits and deletes queue, marked')],
  ['#4 nothing lost', 'O-10 corrections', 'K7 edit/delete reach the brain', 'closes Y9–Y12, J3'],
  entry_top(),
  col(t("i think it's the 9am standup. i dread it.", 'text-xl', 'text-primary', extra=f'font-family:{V("font-display")}'), t('today · 9:12 · written · ✓ read', 'text-sm', 'text-label'), row(because('show it in the conversation ›'), extra='min-height:44px;align-items:center'), gap='spacing-2'),
  col(t('what i took from this', 'text-sm', 'text-label'), took('the monday standup is hard for you'), took('you feel dread before 9am meetings'), gap='spacing-2'),
  bottom(row(t('delete entry', 'text-md', 'status-danger-text'), extra='min-height:44px;align-items:center;justify-content:center'))))

# PC-1 · Podcasts
def tile(label, h=165, lit=False):
    return box(label, h, extra='flex:1')
hero = (f'<div style="height:220px;border-radius:{V("radius-default")};background:{C("surface-control")};padding:{V("spacing-4")};display:flex;flex-direction:column;gap:{V("spacing-2")}">'
        + lab('this week · hero tile (artwork mesh)') + col(extra='flex-grow:1')
        + t('the week you stopped rushing', 'text-xl', 'text-primary', extra=f'font-family:{V("font-display")}')
        + row(t('12 min · mornings, the standup, sleep', 'text-sm', 'text-secondary', extra='flex:1'), t('▶ (lit)', 'text-sm', 'text-link')) + '</div>')
S.append(screen('PC-1 · podcasts', 'Listen to what retro made for you.',
  'tiles, not rows (founder): this week\'s episode leads as a wide hero with its real title, length and what it covers, the screen\'s one lit play; today\'s brief and earlier episodes follow as square tiles two across, newest first; tiles lag and settle as you scroll; the mini-player floats above the tab bar while something plays.',
  ['page label', 'hero tile: this week (title inky, length, what it covers, lit play)', 'square tiles: today\'s brief, earlier episodes and briefs', 'section label: earlier', 'mini-player (when something plays)', 'progressive blur above the bar', 'tab bar'],
  [('first week', 'only your first episode, as the hero, and "your next one comes sunday"'), ('making this week\'s', 'the hero says "being made · ready sunday 9:00", no play'), ('quiet week', 'the hero: "a quiet week. a short one, 4 min"'), ('failed', 'the hero names it: "this week\'s didn\'t finish · try again"'), ('offline', 'downloaded tiles play; others dim with "needs a connection"'), ('not subscribed', 'tiles show; play opens the paywall'), ('playing', 'the mini-player floats 12 above the tab bar'), ('pull to refresh', 'refreshes, and does on opening the tab')],
  ['#24 tiles, player sheet', 'O-4, O-24, O-30', 'founder: tiles respond to scroll', 'closes Y22–Y25, Y30, Y31, L8'],
  jtop('podcasts').replace('☰', '·'),
  scroll(hero, row(tile("today's brief · tue · 4 min"), tile('your first episode · sun · 5 min'), gap='spacing-3'),
         t('earlier', 'text-sm', 'text-label', 'font-weight-medium', extra=f'margin-top:{V("spacing-3")}'),
         row(tile('what the sunday calls… · 11 min'), tile("monday's brief · 3 min"), gap='spacing-3'), gap='spacing-3'),
  bottom(box('mini-player · the week you stopped rushing · ‖', 64), tabbar('podcasts'), gap='spacing-3')))
# podcasts has no drawer button: an empty leading slot keeps the label centred
S[-1] = S[-1].replace('<div style="width:36px;height:36px;border-radius:var(--radius-control);background:var(--color-surface-control);display:flex;align-items:center;justify-content:center"><div style="font-family:var(--font-text);font-size:var(--text-body);color:var(--color-text-secondary);">·</div></div>', '<div style="width:36px"></div>', 1)

# PC-2 · the player
S.append(sheet_screen('PC-2 · the player', 'Listen to one episode, and understand it.',
  'the player spec\'s order: what it is (header, inky title, why line), then hear and read it (the transcript is the page), then control it (scrubber, transport, chapters · not right) in the thumb zone; the one thing it\'s wondering arrives as a dashed guess card at its moment, answered in place; the page behind reads as a page.',
  ['player sheet (page behind as a strip)', 'header: the mark · your weekly episode · this week · share · close', 'title (inky)', 'why line: what it was made from ›', 'transcript following the voice', 'guess card: yes · not quite · why do you think that?', 'scrubber with chapter ticks', 'transport (raised well, speed)', 'chapters · not right pills'],
  [('playing', 'as drawn'), ('paused', 'play shown'), ('buffering', 'the well shows a turning ring; time holds'), ('offline', 'downloaded: plays; else "needs a connection"'), ('failed', '"couldn\'t play · try again"'), ('older episode', 'no plan stored: the transcript alone, no why lines'), ('question answered', 'the card settles solid, "kept"; why do you think that opens the composer'), ('not right', 'long press any line: copy · not right · why')],
  ['#24 player sheet, inky title', '#3 evidence, question, answer', 'O-4, O-5, O-10, O-13, O-24', 'player.md · guess-card.md', 'closes Y26, Y27, Y45, N20, N21, R3'],
  sheet_phone(head('◆ your weekly episode · this week'),
    col(title('the week you stopped rushing'), because('from 6 entries · calendar · steps ›'), gap='spacing-2'),
    col(t('you moved the standup twice this week.', 'text-md', 'text-tertiary'), title('and both times, the morning after was your best one.', f'font-size:{V("text-xl")}'), t("so i've been wondering something.", 'text-md', 'text-secondary'), gap='spacing-4', extra='flex-grow:1;justify-content:center;overflow:hidden'),
    guess('are mornings when you do your best work?'),
    controls('scrubber 4:12 / 12:30 · chapter ticks · "the standup"'), behind='podcasts')))

# PC-3 · why this is here (pushed inside the player sheet; sheets never stack)
S.append(sheet_screen('PC-3 · why this is here', 'The evidence behind one part of an episode.',
  'it pushes inside the player sheet with a back arrow, because sheets never stack (sheet rule 3); the part\'s claim is the title, marked stated or asked with how sure; the evidence follows with dates, each openable and correctable.',
  ['player sheet, pushed page', 'back to the player', 'the claim (inky) · stated / asked · how sure', 'evidence rows: date · what · open ›', 'for an asked part: what it rests on', 'not right on any line'],
  [('stated', 'as drawn: "stated · from what you did"'), ('asked', 'a dashed guess: "asked · fairly sure · rests on 3 mornings"'), ('evidence opens', 'an entry opens JR-4; a link opens the reader; an event shows its day'), ('corrected', 'the line dims, "noted"; the next episode won\'t lean on it')],
  ['#3 facts stated, guesses asked, with how sure', 'O-10, O-13', 'goal 13, 21'],
  sheet_phone(head('‹ the week you stopped rushing', '⌄'),
    col(title('your best days start early.'), t('stated · from what you did · very sure', 'text-sm', 'text-label'), gap='spacing-2'),
    col(t('what it rests on', 'text-sm', 'text-label'),
        rests('14 oct', 'up at 6:40, a long focused morning'), rests('16 oct', '"felt sharp before anyone was online"'), rests('17 oct', 'ran at 7, then shipped the deck'), gap='spacing-2'),
    bottom(row(pill('not right'), gap='spacing-3', extra='justify-content:center')), behind='podcasts')))

for i, s in enumerate(S):
    open(f'pr{i:02d}.html', 'w').write(s.replace('\n', '').replace('font-weight:var(--font-weight-regular);', '').replace('line-height:var(--leading-snug);', ''))
print(len(S))
