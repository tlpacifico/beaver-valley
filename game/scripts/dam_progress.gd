extends RefCounted
class_name DamProgress
## Mutable delivery progress for a configured dam recipe. The model validates
## object identity, per-type capacity and compatible slot availability. It never
## infers a material type from the identifier string; it uses the recipe's
## explicit object-to-type mapping.

const DamRecipe = preload("res://scripts/dam_recipe.gd")

var _recipe: Dictionary = {}
var _requirements: Dictionary = {}
var _placed_ids: Dictionary = {}
var _counts: Dictionary = {}
var _slot_occupant: Dictionary = {}
var _records: Array[Dictionary] = []


## Reset progress for the given recipe ID. Unknown IDs leave the progress empty.
func configure(recipe_id: String) -> void:
	_recipe = DamRecipe.for_id(recipe_id)
	_requirements = _recipe.get("requirements", {})
	_placed_ids.clear()
	_counts.clear()
	_slot_occupant.clear()
	_records.clear()


## True when the object is part of the recipe, has not been placed yet, and a
## compatible slot is still free for its material type.
func can_place(material_id: String) -> bool:
	if _recipe.is_empty():
		return false
	var type: String = _recipe.material_type_for_id.get(material_id, "")
	if type.is_empty():
		return false
	if _placed_ids.has(material_id):
		return false
	var required: int = _requirements.get(type, 0)
	if _counts.get(type, 0) >= required:
		return false
	return _first_free_slot(type) != -1


## Places the object if valid and returns the chosen slot index. Returns -1 and
## leaves state unchanged when the placement is invalid.
func place(material_id: String) -> int:
	if not can_place(material_id):
		return -1
	var type: String = _recipe.material_type_for_id[material_id]
	var slot_index := _first_free_slot(type)
	_placed_ids[material_id] = true
	_counts[type] = _counts.get(type, 0) + 1
	_slot_occupant[slot_index] = material_id
	var slot_def: Dictionary = _recipe.slots[slot_index]
	_records.append({
		"material_id": material_id,
		"material_type": type,
		"slot_index": slot_index,
		"zone": slot_def.get("zone", ""),
	})
	return slot_index


## Number of delivered objects of this material type.
func count_for(material_type: String) -> int:
	return _counts.get(material_type, 0)


## True only when every material type has reached its required count.
func is_complete() -> bool:
	if _recipe.is_empty():
		return false
	for type: String in _requirements.keys():
		if _counts.get(type, 0) != _requirements[type]:
			return false
	return true


## Ordered list of every successful placement, each with material_id,
## material_type, slot_index and zone.
func placement_records() -> Array[Dictionary]:
	return _records.duplicate()


func _first_free_slot(type: String) -> int:
	for slot_def: Dictionary in _recipe.slots:
		var index: int = slot_def.slot_index
		if _slot_occupant.has(index):
			continue
		var compatible: Array = slot_def.get("compatible_types", [])
		if compatible.has(type):
			return index
	return -1
