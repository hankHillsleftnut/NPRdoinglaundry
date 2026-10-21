from review import *
# Part 10 · in context (founder c-a1xxrk, "what is the context of use of these components"): now/next is what the player sheet
# shows when it plays the daily brief (JR-2), in place of the episode transcript; the recap card is a past conversation folded
# into the Journal thread (JR-1). Built from the part 08 and part 10 pieces so nothing new is invented here.
import importlib.util, sys
def load(n):
    spec = importlib.util.spec_from_file_location(n, f'{n}.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
c8, c10 = load('p08_conversation'), load('p10_brief_items')
BRIEF = (f'<div layer-name="brief · now + next" style="display:flex;flex-direction:column;gap:{V("spacing-6")};padding-top:{V("spacing-6")}">'
         f'{c10.NOW}{c10.NEXT}</div>')
THREAD = (f'<div layer-name="phone · journal thread" style="width:390px;height:844px;box-sizing:border-box;flex-shrink:0;display:flex;flex-direction:column;justify-content:flex-end;gap:{V("spacing-6")};'
          f'padding:{V("spacing-6")};background:{C("background-canvas")};border-radius:{V("radius-sheet")};box-shadow:inset 0 0 0 1px {C("border-subtle")};overflow:clip">'
          + c8.day('sunday') + c10.RECAP
          + c8.day('today') + c8.mine('slept badly, long day of meetings', w=232)
          + c8.retro("third monday like that. what's different about mondays?", False, because='from your last 3 mondays') + '</div>')
open('p10_brief_ctx.html', 'w').write(BRIEF)
open('p10_thread_ctx.html', 'w').write(THREAD)
