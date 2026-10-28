extends RefCounted
class_name Inventory
## The player's bag: a row of slots, each empty (null) or a Stack of one ItemData.
## Lives in Game.inventory, so it survives scene changes. Press B to see it.
## Quests and pickups talk to it with add / remove / count / has; the menu
## (inventory_menu.gd) redraws on `changed`.

signal changed
## After add() put items in (count = how many actually fit). Quests can listen for this.
signal item_added(item: ItemData, count: int)
signal item_removed(item: ItemData, count: int)

const DEFAULT_SIZE := 36


## A pile of one item in one slot.
class Stack:
	var item: ItemData
	var count: int

	func _init(i: ItemData, n: int) -> void:
		item = i
		count = n


var slots: Array = []


func _init(slot_count := DEFAULT_SIZE) -> void:
	slots.resize(slot_count)


func size() -> int:
	return slots.size()


## Bigger bag (an upgrade later). Never drops items: it can't shrink below the last used slot.
func resize(new_size: int) -> void:
	var last := slots.size() - 1
	while last >= 0 and slots[last] == null:
		last -= 1
	slots.resize(maxi(new_size, last + 1))
	changed.emit()


func get_stack(i: int) -> Stack:
	return slots[i]


## Puts count of item in: tops up stacks of it first, then empty slots (left to right).
## Returns how many did NOT fit (0 = all in).
func add(item: ItemData, count := 1) -> int:
	if item == null or count <= 0:
		return count
	var left := count
	for s in slots:
		if left > 0 and s != null and s.item == item and s.count < item.max_stack:
			var n := mini(left, item.max_stack - s.count)
			s.count += n
			left -= n
	for i in slots.size():
		if left > 0 and slots[i] == null:
			var n := mini(left, item.max_stack)
			slots[i] = Stack.new(item, n)
			left -= n
	if left < count:
		item_added.emit(item, count - left)
		changed.emit()
	return left


## add() by id (res://items/<id>.tres).
func add_id(item_id: String, count := 1) -> int:
	var item := ItemData.find(item_id)
	if item == null:
		push_warning("Inventory: no item res://items/%s.tres" % item_id)
		return count
	return add(item, count)


## Takes count of item out (from the last slots first). False, and nothing taken, if there isn't enough.
func remove(item: ItemData, count := 1) -> bool:
	if item == null or count_of(item) < count:
		return false
	var left := count
	for i in range(slots.size() - 1, -1, -1):
		var s: Stack = slots[i]
		if left > 0 and s != null and s.item == item:
			var n := mini(left, s.count)
			s.count -= n
			left -= n
			if s.count == 0:
				slots[i] = null
	item_removed.emit(item, count)
	changed.emit()
	return true


## remove() by id.
func remove_id(item_id: String, count := 1) -> bool:
	return remove(ItemData.find(item_id), count)


func count_of(item: ItemData) -> int:
	var n := 0
	for s in slots:
		if s != null and s.item == item:
			n += s.count
	return n


func has(item: ItemData, count := 1) -> bool:
	return count_of(item) >= count


func has_id(item_id: String, count := 1) -> bool:
	for s in slots:
		if s != null and s.item.id == item_id:
			count -= s.count
	return count <= 0


func is_full() -> bool:
	return not slots.has(null)


## Takes the whole stack out of slot i (for the menu's "hold it under the mouse").
func take(i: int) -> Stack:
	var s: Stack = slots[i]
	slots[i] = null
	if s:
		changed.emit()
	return s


## Takes up to count from slot i as a new stack (right click takes one).
func split(i: int, count: int) -> Stack:
	var s: Stack = slots[i]
	if s == null:
		return null
	if count >= s.count:
		return take(i)
	s.count -= count
	changed.emit()
	return Stack.new(s.item, count)


## Drops held into slot i: into an empty slot, onto the same item (as much as fits),
## or swaps with a different item. Returns what is left in hand (null = nothing).
func put(i: int, held: Stack) -> Stack:
	if held == null:
		return null
	var s: Stack = slots[i]
	var rest: Stack = null
	if s == null:
		slots[i] = held
	elif s.item == held.item:
		var n := mini(held.count, s.item.max_stack - s.count)
		s.count += n
		held.count -= n
		rest = held if held.count > 0 else null
	else:
		slots[i] = held
		rest = s
	changed.emit()
	return rest


## For saving: [[slot, item id, count], ...].
func to_save() -> Array:
	var out := []
	for i in slots.size():
		if slots[i] != null:
			out.append([i, slots[i].item.id, slots[i].count])
	return out


func load_save(data: Array) -> void:
	slots.fill(null)
	for row in data:
		var item := ItemData.find(row[1])
		if item and row[0] < slots.size():
			slots[row[0]] = Stack.new(item, row[2])
	changed.emit()
