from mf import *
S = []
S.append(screen('JR-1 · journal', 'Message retro, and hear back; today\'s brief stays anchored on top.',
  'a messaging thread is the most familiar way to talk to something (founder: you can message it); the brief is anchored so the day\'s one lit thing is always a tap away; replies are short and sometimes none; guesses come as questions with what they rest on; a message\'s state shows on your latest one and on anything not yet sent.',
  ['journal top bar (drawer button)', 'brief card (anchored; compacts on scroll)', 'thread: your messages (raised, trailing; saved → sent → read on your latest) · retro replies (inky, leading)', 'day labels', 'progressive blur (under the brief and above the bar)', 'voice composer', 'tab bar'],
  [('scrolled up', 'older conversations, back to day one; the brief compacts to a slim bar that keeps play'), ('brief making', '"making your brief · ready by 8:30"'), ('brief quiet', '"a quiet day; nothing new"'), ('nothing today', 'retro asks one question to start'), ('talking', 'your words form a bubble as you speak, each word blurring in'), ('retro thinking', 'three dots on the leading side'), ('unsent or failed', 'its state stays visible on that message until it\'s sent'), ('no reply', 'a message can stand alone; retro answers only when it has something worth saying'), ('offline', 'messages kept, "sends when you\'re back"'), ('server failing', 'named, with what happens next'), ('ambient off', 'the card says the brief is off, with turn on')],
  ['rules 27–29', '#23 retro replies when it has something worth saying', '#6 brief is your inbox', '#4 saved → sent → read', '#3 guesses asked, with what they rest on', 'closes Y1, Y2, Y4–Y6, Y28, Y29, J1, J2, L6, L7'],
  jtop(), brief_anchor(),
  thread(exchange('yesterday', voice_mine('1:42', 'on the walk home i kept thinking about…'), mine('slept badly, long day of meetings'),
                  col(retro("third monday like that. what's different about mondays?"), because('from your last 3 mondays ›'), gap='spacing-1')),
         exchange('today', mine("i think it's the 9am standup. i dread it."), retro('want me to keep an eye on how mondays go for the next few weeks?'), mine('yes', '↻ sending'))),
  bottom(composer('message retro…', anchor=False), tabbar('journal'), gap='spacing-3')))

def drow(words, meta, here=False):  # a conversation or note: your words lead, two lines; the one in view sits on a raised row
    inner = col(t(words, 'text-body', 'text-primary'), t(meta, 'text-sm', 'text-label'), gap='spacing-1')
    bg = f'background:{C("background-canvas")};' if here else ''
    return f'<div style="border-radius:{V("radius-default")};{bg}padding:{V("spacing-3")}">' + inner + '</div>'
dday = lambda x: t(x, 'text-sm', 'text-label', 'font-weight-medium', extra=f'padding:0 {V("spacing-3")}')
search = f'<div style="height:44px;border-radius:{V("radius-control")};background:{C("background-canvas")};padding:0 {V("spacing-4")};display:flex;align-items:center;gap:{V("spacing-2")}">' + t('⌕', 'text-body', 'text-label') + t('search your journal', 'text-body', 'text-tertiary') + '</div>'
listing = col(col(dday('today'), drow("i think it's the 9am standup. i dread it.", '3 messages · retro replied · 9:12', here=True), gap='spacing-1'),
              col(dday('yesterday'), drow('slept badly, long day of meetings', '2 messages · 22:40'), drow('on the walk home i kept thinking about…', 'voice note · 1:42'), drow('the fundraise article you shared', 'link · shared from safari · retro asked why'), gap='spacing-1'),
              col(dday('sunday'), drow('my first conversation with retro', '9 answers · 12 min'), gap='spacing-1'),
              t('↓ older days, under a progressive blur', 'text-sm', 'text-tertiary'),
              gap='spacing-6', extra='flex-grow:1;min-height:0;overflow:hidden')
foot = row(t('settings', 'text-md', 'text-secondary', extra='flex:1'), t('v1.0', 'text-sm', 'text-label'), gap='spacing-2')
drawer = col(t('9:41', 'text-md', 'text-secondary'), search, listing, foot,
             gap='spacing-6', extra=f'width:276px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-4")} {V("spacing-8")}')
peek = col(t('9:41', 'text-md', 'text-secondary'), box('brief', 64), col(gap='spacing-2', extra='flex-grow:1'),
           f'<div style="align-self:flex-end;width:70px;height:36px;border-radius:{V("radius-default")};background:{C("surface-control")}"></div>',
           box('bar', 44),
           extra=f'width:390px;flex-shrink:0;box-sizing:border-box;padding:{V("spacing-4")} {V("spacing-6")} {V("spacing-8")};border-radius:{V("radius-sheet")};background:{C("background-canvas")};box-shadow:0 0 0 1px {C("border-subtle")}, 0 4px 16px {C("depth-shadow-cast")}')
S.append(f'<div layer-name="JR-3 · all journals (drawer)" style="display:flex;flex-direction:column;gap:{V("spacing-4")}">'
  + f'<div layer-name="phone" style="width:390px;height:844px;flex-shrink:0;box-sizing:border-box;display:flex;background:{C("surface-control")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-strong")};overflow:hidden">'
  + drawer + peek + '</div>'
  + notes('JR-3 · all journals (drawer)', 'Every conversation and note, by day; tap one to jump the thread there.',
    'refined from the drawer the app has today (founder): the same slide-aside page (276pt, rounded, hairline, shadow, follows your finger, spring settle) and the same grey underlay; the five tab rows go (the tab bar has them now), so the drawer is only your journal\'s index; mono becomes plain text; one-line titles become your own words over two lines with what each was; days group them; search sits on top; the conversation you are in is marked; the bottom fade becomes the progressive blur; settings and the version stay at the foot.',
    ['all-journals button (top-left; needs a sidebar icon in the set)', 'slide-aside page (as today)', 'search field', 'day labels', 'rows: your words · what it was · time (the one in view raised)', 'progressive blur at the foot', 'settings · version'],
    [('opening', 'tap the button or swipe from the edge; the page follows your finger, rubber-bands past the end'), ('searching', 'results replace the days, matched words marked'), ('empty', 'warm: "nothing yet. say anything."'), ('some unsent', 'marked; one tap retries'), ('jump', 'tap a row: the page slides back and the thread scrolls to it'), ('reduced motion', 'a short fade instead of the slide')],
    ['rule 29 drawer (founder)', 'rule 4 almost no mono', 'founder: a place for your entries', 'O-21 states', 'K7 edit/delete reach the brain', 'closes Y7, Y9, Y15, J4']) + '</div>')
for i, s in enumerate(S):
    open(f'jr{i:02d}.html', 'w').write(s.replace('\n', '').replace('font-weight:var(--font-weight-regular);', ''))
print(len(S))
