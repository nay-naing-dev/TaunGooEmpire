extends RefCounted
class_name QuestLog
## The player's quests. Lives in Game.quests, so it survives scene changes; Tab
## shows it (quest_menu.gd). A quest goes ACTIVE -> COMPLETED (every objective
## done; go back to the giver) -> FINISHED (reward claimed).
## Quest givers call start / finish, whatever finishes an objective calls
## complete_objective (e.g. a DeliverySpot). Game shows "Quest Added: <name>" and
## "Quest Completed: <name>" over the player on `started` / `completed`.

signal changed
signal started(id: String)
## Every objective is done (the reward is still to be claimed).
signal completed(id: String)
## The reward was claimed.
signal finished(id: String)

enum State { ACTIVE, COMPLETED, FINISHED }


class Quest:
	var id: String
	var title: String
	## Who gave it (the reward is claimed from them).
	var giver: String
	var objectives: PackedStringArray
	var done: Array[bool] = []
	var state := State.ACTIVE


## In the order they were started.
var _quests: Array[Quest] = []


func start(id: String, title: String, objectives: PackedStringArray, giver := "") -> void:
	if has(id):
		return
	var q := Quest.new()
	q.id = id
	q.title = title
	q.giver = giver
	q.objectives = objectives
	q.done.resize(objectives.size())
	q.done.fill(false)
	_quests.append(q)
	started.emit(id)
	changed.emit()


func complete_objective(id: String, index := 0) -> void:
	var q := get_quest(id)
	if q == null or q.state != State.ACTIVE or index >= q.done.size() or q.done[index]:
		return
	q.done[index] = true
	if not q.done.has(false):
		q.state = State.COMPLETED
		completed.emit(id)
	changed.emit()


## The giver handed out the reward.
func finish(id: String) -> void:
	var q := get_quest(id)
	if q == null or q.state != State.COMPLETED:
		return
	q.state = State.FINISHED
	finished.emit(id)
	changed.emit()


func get_quest(id: String) -> Quest:
	for q in _quests:
		if q.id == id:
			return q
	return null


func list() -> Array[Quest]:
	return _quests


func has(id: String) -> bool:
	return get_quest(id) != null


func is_active(id: String) -> bool:
	return has(id) and get_quest(id).state == State.ACTIVE


func is_completed(id: String) -> bool:
	return has(id) and get_quest(id).state == State.COMPLETED


func is_finished(id: String) -> bool:
	return has(id) and get_quest(id).state == State.FINISHED


## For saving: [[id, title, giver, objectives, done, state], ...].
func to_save() -> Array:
	var out := []
	for q in _quests:
		out.append([q.id, q.title, q.giver, q.objectives, q.done, q.state])
	return out


func load_save(data: Array) -> void:
	_quests.clear()
	for row in data:
		var q := Quest.new()
		q.id = row[0]
		q.title = row[1]
		q.giver = row[2]
		q.objectives = row[3]
		q.done.assign(row[4])
		q.state = row[5]
		_quests.append(q)
	changed.emit()
