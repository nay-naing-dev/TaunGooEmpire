# Taungoo 1550: cleaned project

This is the whole project with only what the game uses: about 83 MB (was 104 MB).

## How to install
1. Close Godot.
2. Rename your old project folder (for example `yangon_game_old`) as a backup.
3. Unzip this into a new folder and open it in Godot. The first import takes a while.
4. Press Play, then Explore. You start in the village.
gg
## Maps
- **Village** (`scenes/village/village.tscn`): the MC's home. Houses can be entered.
  - East end of the road: Forest road.
- **Forest road** (`scenes/forest/forest_road.tscn`): new, 3000 x 2000.
  - a dirt road through a dense forest of gold, green and olive trees, with coconut palms along the creek
  - the PixelLab bushes along the road, plus ferns, saplings, dead trees, mossy rocks and logs
  - a creek with a plank bridge and rail fences
  - a side trail to a small shrine clearing
  - West end: Village. East end: Palace.
- **Palace** (`scenes/world/taungoo_world.tscn`): royal court with 5 enterable rooms, training ground, sea.
  - West road: Forest road.

## Characters kept
- MC (village boy), black cat (pick on the title screen)
- mother, village woman, rice porter, buffalo, crows

## Removed
- side-view stage and side-view characters
- the other top-down characters (swordsman, gunslinger, sky mage, burmese man, hero)
- the army (cavalry, war elephants, the old mounted king) and the Tabinshwehti boss
- all the old Yangon / Taungoo city buildings, forest, market and props that no map uses any more

## Performance
- Forest trees and bushes check for the player only a few times a second, not every frame.
- If the forest still feels slow on your PC, lower `density` on the `GrassField` node in `forest_road.tscn` (for example 0.4).
