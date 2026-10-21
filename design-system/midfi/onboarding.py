from mf import *
S = []
QSTATES = [('retro speaking', 'bar shows the speaking level; the question streams in, line by line'),
           ('listening', 'your words appear under the question, blurring in'),
           ('thinking', 'words settle; three dots in the bar, under 1.2 s'),
           ('typed (muted)', 'keyboard up; bar becomes a text field with send'),
           ('offline', 'answer kept, queued; "we\'ll pick up here"')]
def qscreen(code, prog, label, q, words, purpose, why, ledger, extra=''):
    S.append(screen(code, purpose, why,
        ['progress bar (global)', 'question title (inky)', 'your words (live)', 'voice composer'] + (['quick answers (chips)'] if extra else []),
        QSTATES, ledger,
        top('', True, prog), col(title(q), (t(words, 'text-xl', 'text-secondary') if words else ''), extra, gap='spacing-6', extra='padding-top:var(--spacing-4)'), composer()))

S.append(screen('ON-1/2 · splash + sign-in', 'Something beautiful, and you sign in on it.',
  'one screen instead of welcome then sign-in (founder: the splash is the sign-in) keeps the first tap meaningful; the constellation shows what the product is (everything about you, connected) before a word is read.',
  ['constellation (K1)', 'title + one line', 'Sign in with Apple', 'Continue with Google', 'terms · privacy'],
  [('idle', 'as drawn'), ('signing in', 'pressed button keeps its label, a spinner beside it'), ('failed', 'one plain line above the buttons, what to try'), ('offline', '"you\'re offline" line; buttons wait'), ('reduced motion', 'a still constellation')],
  ['#10 north star', '#11 splash is sign-in · Google at once', 'K1 chosen', 'closes W1–W7, C5'],
  box('constellation · you at the centre, people, places, goals, a card, an image (bleeds to the edges, under the status bar)', 380, extra='width:390px;align-self:center;border-radius:0'),
  col(title('everything about you, finally connected.'), t('retrospect gets to know you, and tells you what it sees.', 'text-body', 'text-secondary'), gap='spacing-2'),
  bottom(box('Sign in with Apple', 56), box('Continue with Google', 56), t('terms · privacy', 'text-sm', 'text-label', extra='text-align:center'))))

S.append(screen('ON-3 · retro says hello', 'Retro speaks first: who it is, what it is for, then talk or type.',
  'voice first, words on screen one line at a time so it works muted; talk or type asked once, with the segmented control (the quality bar), instead of a mode switch on every turn.',
  ['the mark (speaking)', 'one spoken line at a time', 'segmented: talk | type', 'replay', 'voice composer'],
  [('speaking', 'line by line, the mark breathes'), ('muted', 'same words, no audio; "sound off" note'), ('typed chosen', 'next turns open with the keyboard'), ('replay', 'starts the lines again')],
  ['#7 "hello, my name is retro"', '#8 not a person, says so', '#12 talk default', 'mission under 30 s, true today', 'K14'],
  top('', False, 0.05),
  col(col(box('the mark (breathes while speaking)', 64, extra='width:64px;align-self:center'), title("hello, my name is retro.", 'text-align:center'), gap='spacing-6', extra='flex:1;justify-content:flex-end'),
      col(t('(spoken, one line at a time) "i want to understand you, and help you live a bit better. you save things you never go back to; i won\'t forget them. we don\'t have to be friends: i\'m not a person."', 'text-md', 'text-tertiary', extra='text-align:center'), gap='spacing-6', extra='flex:1'),
      gap='spacing-4', extra='flex-grow:1;min-height:0'),
  bottom(box('segmented · talk | type', 44, extra='width:220px;align-self:center'), composer('retro is speaking…', anchor=False))))

qscreen('ON-4a · your name', 0.1, 'getting to know you', 'first, what should i call you, and where are you based?', 'sam. london.',
  'The first, easy question; the name prefills from Apple or Google.',
  'the app today opens with this; easy and personal first builds the rhythm; prefilled from sign-in so you only confirm.',
  ['question 0 (covers #5)', '#12 iOS feel', '#30 one title'])
S.append(screen('ON-4b · retro replies', 'A real acknowledgement after each answer, then the next question.',
  "retro's reply sits on the page in the inky face (its words are content), not in a bubble; specific to what you said, so you know it heard you.",
  ['retro reply (inky, unboxed)', 'next question', 'voice composer'],
  [('speaking', 'reply streams in, then the next question'), ('deeper later', 'later replies reference earlier answers'), ('follow-up', 'at most one, only when it settles a lot')],
  ['#13 deeper acknowledgements', '#8 never claims to be human'],
  top('', True, 0.16),
  col(title("nice to meet you, sam. london in october: i'll make sure your brief knows about the rain."), gap='spacing-4', extra='padding-top:var(--spacing-4)'), composer('retro is speaking…')))
qscreen('ON-4c · a year from now', 0.24, 'getting to know you', 'picture a year from now, and everything has gone as well as it realistically could. what does your life look like?', "i'd have shipped the thing, and i'd see my family more…",
  'Open inspiring: the question that teaches the most first.', 'a story, not an opinion; it covers seven of the 36 at once and sets a hopeful tone before the heavier ones.',
  ['question 1 (6, 10, 11, 4, 5, 23, 21)', '#14 aspiration, feel seen', '#15 opens inspiring'])
qscreen('ON-4d · lately', 0.32, 'getting to know you', "what's been taking up most of your head lately?", 'honestly, whether to leave my job…',
  'What is live for you right now.', 'it gives the first episode something present to start from; asked after the inspiring one so it doesn\'t open heavy.',
  ['question 3 (27–29, 24, 10)', 'K23 next-best question'])
qscreen('ON-4e · the news you follow', 0.38, 'getting to know you', 'what news do you actually follow?', '',
  'So your brief can carry the news you care about.', 'quick answers (chips) make it a few taps, and voice or typing still works for anything else.',
  ['#14 asks what news they follow', '#6 the brief'], extra=f'<div style="display:flex;flex-wrap:wrap;gap:var(--spacing-3)">' + ''.join(pill(x) for x in ['tech', 'world', 'markets', 'sport', 'science', 'culture', 'local']) + '</div>')
S.append(screen('ON-5 · privacy', 'Earn trust before asking for data.',
  'one title, one description and one picture (founder: simplify, then make it much nicer); retro reads it aloud, so the facts are heard, not hunted for.',
  ['privacy moment (lock in rings)', 'title', 'description', 'privacy policy link', 'voice composer (speaking)'],
  [('reading aloud', 'bar shows retro speaking'), ('muted', 'words only'), ('policy open', 'the full policy in a sheet')],
  ['#16 privacy', '#30 one title', '#34 purpose shown visually', 'callback: "here\'s why i ask"', 'closes D1, N13'],
  top('privacy', True, 0.44),
  col(box('lock in soft rings', 200, extra='width:240px;align-self:center'), title('what you tell me stays yours.', 'text-align:center'),
      t('i only read what you connect and tell me. a few trusted companies help me understand it, and more of it moves onto your phone over time. i never sell it. delete everything, anytime.', 'text-body', 'text-secondary', extra='text-align:center'),
      t('read the privacy policy', 'text-md', 'text-link', extra='text-align:center'), gap='spacing-6', extra='flex-grow:1;justify-content:center'), composer('retro is speaking…')))
S.append(screen('ON-6 · connect', 'Connect what helps it understand you: everything on one page.',
  'one page (founder) beats a second "more" page; cards for the launch set because each says what it lets retro see; rows below for accounts, files and public profiles; no skip (connecting is core), continue is always there.',
  ['title', 'what retro can see (meter)', 'source cards (logo, what it shows, connect pill)', 'rows: accounts · files · public profiles', 'progressive blur', 'voice composer'],
  [('connecting', 'pill turns, keeps its width'), ('connected', '✓ connected; the meter fills, retro says what it can now see'), ('failed', 'what happened, try again'), ('denied', 'how to allow it in Settings'), ('waiting on approval', 'TikTok, X, LinkedIn in words')],
  ['#17 one page, real logos, obvious connect', 'K15 nothing connectable before it works', 'callback: "what these let me understand"', 'closes C1–C10, N14–N16'],
  top('connect', True, 0.52), col(title("let me see what words can't."), box('what retro can see · ink meter', 12), gap='spacing-4'),
  scroll(row(box('health · ✓ connected', 104, extra='flex:1'), box('calendar · ✓ connected', 104, extra='flex:1'), gap='spacing-3'),
    row(box('google · + connect', 104, extra='flex:1'), box('contacts · + connect', 104, extra='flex:1'), gap='spacing-3'),
    row(box('screen time · + connect', 104, extra='flex:1'), box('photos · + connect', 104, extra='flex:1'), gap='spacing-3'),
    t('then spotify, apple music, reddit, youtube… accounts, files and public profiles, on this same scroll', 'text-md', 'text-secondary')),
  bottom(box('continue (raised neutral pill)', 48), composer(anchor=False))))
qscreen('ON-8a · what you care about', 0.6, "where you're headed", "what do you care about most: the things you'd protect even if they cost you?", '',
  'The heavier questions, once trust is built.', 'values come after privacy and connect, when you know what happens to your words.',
  ['question 2 (6, 11, 23, 29, 32)', '#15 heavier once trust is built'])
qscreen('ON-8b · one thing to change', 0.66, "where you're headed", "what's one thing you keep meaning to change, and what's gotten in the way so far?", '',
  'Where you are stuck, asked gently.', 'framed as "keep meaning to" so it reads as kind, not a judgement; feeds goals said vs did from day one.',
  ['question 5 (6, 8, 9, 31–33)', '#14 regret, looking for', 'fallbacks f1/f2 only if calendar/health or screen time/youtube aren\'t connected'])
S.append(screen('ON-9 · how straight', "Here's what retro thinks you're ready for, with the others as options.",
  'leading with its recommendation and the reason (founder) makes it one tap for most people, and shows retro listened.',
  ['title', 'recommended card (with reason)', '"or choose another" rows', 'voice composer'],
  [('recommended', 'as drawn'), ('changed', 'your pick moves into the card'), ('said aloud', '"gentler, please" picks it')],
  ['question 8 (34–36)', '#18 recommendation first', 'K20'],
  top('how straight', True, 0.72),
  col(title("here's what i think you're ready for."), raised('recommended (raised) · honest observations · i say what i see, and how sure i am · because you said you want to be challenged', 120), gap='spacing-4', extra='padding-top:var(--spacing-4)'),
  col(t('or choose another', 'text-md', 'text-label'), box('just what happened', 48), box('gentle questions', 48), box("don't hold back", 48), gap='spacing-2', extra='padding-top:var(--spacing-4)'),
  composer()))
S.append(screen('ON-8c · your morning brief', 'Your brief is on: confirm the time, and allow the one notification that says it is ready.',
  'the brief is on by default (founder), so this turn confirms rather than asks; the notification permission is asked here, in context, where its use is obvious.',
  ['title', 'brief card preview', 'time (8:30 local)', 'notification ask (system prompt)', 'voice composer'],
  [('on', 'as drawn'), ('time changed', 'wheel picker in a sheet'), ('asking', 'the system alert, centred over the page'), ('notifications allowed', 'one quiet line: "i\'ll tell you when it\'s ready"'), ('not now', 'brief still plays in the app'), ('turned off', 'the card disappears from journal')],
  ['#19 brief on by default, permission in conversation', '#28 notifications about you, max one a day', 'K4 local time'],
  top('your brief', True, 0.8), title('every morning, a few minutes on what changed, and why it matters to you.', 'padding-top:var(--spacing-4)'),
  col(box('brief card preview · tomorrow · ~4 min', 110), box('one grouped row · time 8:30 am ›   on ●', 52), gap='spacing-2'),
  box('system alert over the page (after you confirm): "Retrospect would like to send you notifications"', 120, extra='width:270px;align-self:center;margin-top:var(--spacing-8)'),
  composer()))
S.append(screen('ON-10 · getting ready', 'Your first episode is made while the conversation carries on.',
  'no dead wait: the real stages in one small panel while retro keeps asking the warm, ending question; no percentage.',
  ['stages (real, no %)', 'question title', 'voice composer'],
  [('making', 'as drawn'), ('quiet wait', 'a line from your own words and "close the app; i\'ll tell you"'), ('ready', 'retro says so; the tease starts on its own'), ('slow', '"taking longer; i\'ll notify you"'), ('failed', 'plain words; answers kept; retry or tonight')],
  ['question 7 (22–25), ends warm', 'readiness stages', 'K12, K21', '#5 every wait names itself'],
  top('your first episode', True, 0.88),
  col(title('one more while i put it together: who would you call if something went wrong? anyone you wish you saw more?'), gap='spacing-4', extra='padding-top:var(--spacing-4)'),
  bottom(box('reading your calendar ✓ · writing your episode ◌ · recording the voice', 44), composer(anchor=False))))
S.append(screen('ON-11 · the tease', 'The first thing it gives back: your first episode starts on its own.',
  'it plays without a tap (founder) the moment it is ready; the transcript follows the voice so it works muted; honest about day one.',
  ['callback line', 'episode title (inky)', 'transcript following the voice', 'scrubber', 'transport'],
  [('playing', 'as drawn'), ('buffering', 'scrubber shows buffered; words wait'), ('failed', 'plain words; try again; notified when fixed')],
  ['#20 ~5 min, arrives without a tap', 'opening line asked, not stated', 'closes E1, L2, N20, N21'],
  top('', False, 0.95),
  col(title('the week you started'), t("here's the first thing i noticed. it's narrow, because it's day one.", 'text-body', 'text-secondary'), gap='spacing-2', extra='padding-top:var(--spacing-4)'),
  box('transcript · current line sharp, earlier lines blurred and fading', grow=True),
  bottom(box('scrubber 0:31 / 5:02', 40), box('↺15   ‖   30↻', 72), gap='spacing-4')))
S.append(screen('ON-12 · the paywall', 'Choose to subscribe, seeing everything you get.',
  'it rises out of the episode at its strongest line (the paywall moment, 1.22 s), so the value is felt, not described; value first, the decision in the thumb zone with subscribe as the one lit action; every benefit uses your own data where it exists.',
  ['mini player (keeps playing)', 'one line', 'six benefits with your examples (scroll, progressive blur)', 'yearly (selected) · monthly', 'subscribe (lit)', 'not now · restore · privacy · terms'],
  [('loading prices', 'plans wait; no fake prices'), ('purchasing', 'dots over the label'), ('purchased', 'settles away to home'), ('failed', '"nothing was charged"'), ('not now', 'home, free: journal, talk, search; no listening')],
  ['#20 strongest line, $19.99 / $199.99, no trial, not now keeps the free tier', 'K13', 'closes N19, L3–L5, Y41'],
  box('mini player · the week you started · 0:38', 56), title('hear the rest, and one every week.'),
  scroll(box('benefits, with your own examples: a brief every morning · an episode every week · ask your own mind · goals said vs did · talk to retro anytime · everything you save, remembered', 180)),
  bottom(row(box('yearly · $199.99 · save 17% (selected)', 70, extra='flex:1'), box('monthly · $19.99', 70, extra='flex:1'), gap='spacing-3'),
    box('subscribe (the one lit action)', 56), t('not now · restore · privacy · terms', 'text-sm', 'text-label', extra='text-align:center'))))
S.append(screen('ON-13 · home, first visit', 'Land on journal: your brief anchored on top, your first conversation already in the thread.',
  'journal is a conversation with retro (founder); the brief card is anchored at the top and is the one lit thing; your onboarding answers are your first entry, so the thread is never empty; three one-time hints, shown one at a time so the screen never crowds: the brief, then talking, then searching your mind in you.',
  ['journal top bar (drawer button)', 'brief card (anchored, lit play)', 'thread: your first conversation (one card) · retro reply', 'hints (once, dismissible)', 'voice composer', 'tab bar'],
  [('hint 1', 'press play for your brief'), ('hint 2', 'after play: talk to me here, at the bar'), ('hint 3', 'then: search your mind, at the you tab'), ('hints done', 'never again'), ('not subscribed', 'the brief card says it\'s part of premium')],
  ['#10 then home', '#22 guidance on first visit', '#6 brief is your inbox', 'rules 27–29 journal'],
  jtop(), col(brief_anchor(), t('↑ press play for your brief (hint 1 of 3)', 'text-sm', 'text-label'), gap='spacing-2'),
  thread(exchange('today', recap(t('what you told retro while setting up', 'text-body', 'text-primary', 'font-weight-medium') + t('9 answers · tap to read or change them ›', 'text-sm', 'text-label')),
         retro("that's enough to start. your first episode is waiting in podcasts, and tomorrow's brief will know you a little better."))),
  bottom(composer("message retro…", anchor=False), tabbar('journal'), gap='spacing-3')))
S.append(screen('AC-1 · sign in (returning)', 'Get back into your account, and land where you were.',
  'shown only when silent renewal fails, so most people never see it; the same buttons as the splash, so it is familiar.',
  ['the mark', 'title', 'Sign in with Apple', 'Continue with Google', 'new here? get started'],
  [('signing in', 'spinner beside the pressed button'), ('restoring', '"bringing back your entries and episodes"'), ('failed', 'one plain line why'), ('offline', 'waits, says so')],
  ['accounts: renew silently, restore, land where you were', '#28 Face ID with passcode, never locks you out', 'closes Q1, W3, W7, A4'],
  col(box('the mark', 64, extra='width:64px;align-self:center'), title('welcome back.', 'text-align:center'), gap='spacing-6', extra='flex-grow:1;justify-content:center'),
  col(box('Sign in with Apple', 56), box('Continue with Google', 56), t('new here? get started', 'text-md', 'text-link', extra='text-align:center'), gap='spacing-3')))
S.append(screen('AC-2 · signing out', 'Leave cleanly, and know what stays.',
  'a sheet over settings, so you never lose your place; unsent entries are sent first, so nothing is lost.',
  ['sheet over settings', 'what stays', 'unsent warning', 'send, then sign out', 'cancel'],
  [('unsent entries', 'as drawn'), ('nothing unsent', 'just "sign out"'), ('signing out', 'lands on sign in')],
  ['#4 nothing lost', 'sign out everywhere · delete account live in ST-9'],
  box('settings, scaled and dimmed behind', grow=True), box('sheet (edge to edge, from the bottom)', None, col(title('sign out?'), t('your entries and episodes stay in your account. this phone forgets them.', 'text-body', 'text-secondary'),
      t('1 entry not sent yet', 'text-md', 'text-primary', 'font-weight-medium'), box('send, then sign out', 52), t('cancel', 'text-md', 'text-label', extra='text-align:center'), gap='spacing-3'), extra='width:390px;align-self:center;padding:var(--spacing-6)')))

for i, s in enumerate(S):
    open(f'on{i:02d}.html', 'w').write(s.replace('\n', ''))
print(len(S))
