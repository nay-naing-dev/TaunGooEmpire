# Sparring Partner (training tutorial bot)

A drill instructor in an indigo practice uniform. He has all of the MC warrior's moves
(8-direction run, sword slash, parry/block, lightning dodge, stun and kneel).
He is built to teach new players:

| Lesson | What he does | What the player must do |
|---|---|---|
| STRIKE | Holds a guard stance and takes your hits | Land 2 full combos (Attack ×3) |
| PARRY | Slow attacks, with a **white** flash before each blow | Parry 3 times (press Parry just before the blade lands) |
| DODGE | **Red** flash = a heavy blow that can't be parried | Dodge 3 times |
| SPAR | Free fight: attacks, blocks, dodges, mixes heavy blows in | Beat him; he kneels and yields |
| TUTORIAL | Runs all four lessons above in order (default) | — |
| IDLE | Just stands and smokes a cheroot | — |

- He never kills the MC. When the MC's health gets low, it is refilled.
- You can't beat him outside SPAR. He doesn't drop in the other lessons either.

## How to add him (no existing files change)
1. Copy the `characters/training/` folder into the project (it is a new folder, so it won't cause git conflicts).
2. Open the training-ground map and drag `characters/training/sparring_partner/sparring_partner.tscn`
   in next to the player under Objects/YSort.
3. In the Inspector, set `Lesson` (default TUTORIAL). You can tune `telegraph_time` (difficulty),
   `damage`, `goal_*`, `block_chance` and `dodge_chance`.

## For the story script
```gdscript
$SparringPartner.say("Recruit! Show me your stance.")       # text above his head
$SparringPartner.start_lesson($SparringPartner.Lesson.PARRY)
$SparringPartner.tutorial_complete.connect(_on_training_done)
$SparringPartner.yielded.connect(func(): print("beat the trainer"))
$SparringPartner.lesson_complete.connect(func(l): print("lesson done ", l))
```
Signals: `lesson_progress(lesson, count, goal)`, `lesson_complete(lesson)`, `tutorial_complete`, `yielded`.

The bot is in the "enemy" group, so the MC's attacks and parry-stun work on him automatically.
