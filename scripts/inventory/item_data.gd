extends Resource
class_name ItemData
## One kind of item (rice sack, letter, spear...). Make one per item as a .tres in
## res://items/, named after its id (res://items/rice_sack.tres has id "rice_sack"),
## then Game.inventory.add(item) / Game.inventory.add_id("rice_sack").
## Add new fields here when items need more (price, edible, equip slot...).

## Unique name used by code, quests and saves. Same as the file name.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
## Shown in the inventory slot. No icon: the slot shows the name's first letters.
@export var icon: Texture2D
## How many fit in one slot. 1 = never stacks (tools, quest letters).
@export_range(1, 999) var max_stack := 99
## What kind of item it is (shown in the tooltip). Quest items can't be dropped
## or sold (for later systems to respect).
@export var type := Type.MISC
## Food: how much of the player's max health eating one gives back, in percent.
@export var heal_percent := 0.0

enum Type { QUEST, FOOD, WEAPON, ARMOR, MEDICINE, MISC }
const TYPE_NAMES := ["Quest item", "Food", "Weapon", "Armor", "Medicine", "Misc"]


func type_name() -> String:
	return TYPE_NAMES[type]


## Health one of these gives back to someone with max_health (at least 1 if it heals at all).
func heal_amount(max_health: int) -> int:
	return maxi(1, roundi(max_health * heal_percent / 100.0)) if heal_percent > 0.0 else 0


func is_quest_item() -> bool:
	return type == Type.QUEST


## The item res://items/<id>.tres, or null.
static func find(item_id: String) -> ItemData:
	var path := "res://items/%s.tres" % item_id
	return load(path) as ItemData if ResourceLoader.exists(path) else null
