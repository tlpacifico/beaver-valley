class_name ValleyLayout
extends RefCounted
## Named ground points and fit evidence shared by the relief preview and, later,
## the playable scene. Stable IDs stay independent from the visual coordinates.

const ANCHOR_IDS: Array[StringName] = [&"spawn", &"branch_clearing", &"dam_approach", &"lodge", &"food_bank"]
const ANCHOR_XZ: Dictionary = {
	&"spawn": Vector2(3.4, 3.9),
	&"branch_clearing": Vector2(1.7, 1.9),
	&"dam_approach": Vector2(0.0, -0.2),
	&"lodge": Vector2(-0.7, -3.5),
	&"food_bank": Vector2(2.5, -4.4),
}
const ZONE_RADII: Dictionary = {
	&"spawn": 0.6,
	&"branch_clearing": 1.3,
	&"dam_approach": 1.1,
	&"lodge": 1.7,
	&"food_bank": 1.1,
}
const CAMERA_ELEVATION_DEGREES: float = 36.97
const FIT_SAMPLE_STEP: float = 0.25
const LODGE_FLOOR_SIZE := Vector3(1.4, 0.12, 0.7)
const LODGE_BED_SAMPLE_STEP: float = 0.1
## The lodge itself stands in the lake; `lodge` remains the dry approach anchor.
const LODGE_SITE_XZ := Vector2(-5.5, -4.8)

var _terrain: ValleyTerrain
var _anchors: Dictionary = {}


func configure(terrain: ValleyTerrain) -> void:
	_terrain = terrain
	_anchors.clear()
	for id: StringName in ANCHOR_IDS:
		var xz: Vector2 = ANCHOR_XZ[id]
		_anchors[id] = Vector3(xz.x, terrain.height_at(xz), xz.y)


func anchor(id: StringName) -> Vector3:
	if _anchors.has(id):
		return _anchors[id]
	return Vector3.ZERO


func anchor_xz(id: StringName) -> Vector2:
	return ANCHOR_XZ.get(id, Vector2.ZERO)


func zone_radius(id: StringName) -> float:
	return float(ZONE_RADII.get(id, 1.0))


## Visual lodge centre in the lake. The floor sits below the water surface and
## the dry `lodge` anchor stays the actor's approach point.
func lodge_site() -> Vector3:
	if _terrain == null:
		return Vector3(LODGE_SITE_XZ.x, 0.0, LODGE_SITE_XZ.y)
	return Vector3(LODGE_SITE_XZ.x, _terrain.height_at(LODGE_SITE_XZ), LODGE_SITE_XZ.y)


func lodge_build_center() -> Vector3:
	var site := lodge_site()
	if _terrain == null:
		return Vector3(site.x, site.y - 0.10, site.z)
	var highest_bed := -INF
	var x_steps := int(ceil(LODGE_FLOOR_SIZE.x / LODGE_BED_SAMPLE_STEP))
	var z_steps := int(ceil(LODGE_FLOOR_SIZE.z / LODGE_BED_SAMPLE_STEP))
	for x_step in range(x_steps + 1):
		var x_ratio := float(x_step) / float(x_steps)
		for z_step in range(z_steps + 1):
			var z_ratio := float(z_step) / float(z_steps)
			var x := site.x - LODGE_FLOOR_SIZE.x * 0.5 + LODGE_FLOOR_SIZE.x * x_ratio
			var z := site.z - LODGE_FLOOR_SIZE.z * 0.5 + LODGE_FLOOR_SIZE.z * z_ratio
			highest_bed = maxf(highest_bed, _terrain.height_at(Vector2(x, z)))
	return Vector3(site.x, highest_bed - 0.10, site.z)


func route_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for id: StringName in ANCHOR_IDS:
		var point := anchor(id)
		point.y += 0.02
		points.append(point)
	return points


## Endpoints of the fixed dam on the two bank tops. The dam itself stays on the
## downstream side of the lake and never moves with the water.
func dam_span() -> PackedVector3Array:
	if _terrain == null:
		return PackedVector3Array()
	var z := _terrain.dam_z()
	var center := _terrain.river_center_x(z)
	var half_span := 3.0
	var points := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		var x: float = center + side * half_span
		points.append(Vector3(x, _terrain.height_at(Vector2(x, z)), z))
	return points


func fit_report() -> Dictionary:
	var report := {
		"variant": String(_terrain.variant) if _terrain != null else "",
		"playable_area_m2": 0.0,
	}
	if _terrain == null:
		return report
	report["playable_area_m2"] = snappedf(ValleyTerrain.PLAYABLE_RECT.get_area(), 0.01)

	var usable_area := 0.0
	var min_width := INF
	var near_bank_slope := 0.0
	var route_max_slope := 0.0
	var z := ValleyTerrain.PLAYABLE_RECT.position.y
	while z <= ValleyTerrain.PLAYABLE_RECT.end.y:
		var row_min: float = INF
		var row_max: float = -INF
		var x: float = ValleyTerrain.PLAYABLE_RECT.position.x
		while x <= ValleyTerrain.PLAYABLE_RECT.end.x:
			var xz := Vector2(x, z)
			if _is_usable_bank(xz):
				usable_area += FIT_SAMPLE_STEP * FIT_SAMPLE_STEP
				row_min = minf(row_min, x)
				row_max = maxf(row_max, x)
			x += FIT_SAMPLE_STEP
		if row_min != INF and row_max != -INF:
			min_width = minf(min_width, row_max - row_min)
		z += FIT_SAMPLE_STEP

	# The channel/lake bank is steeper than the route limit and is not walkable.
	# Measure it separately so the camera-occlusion check sees the real slope.
	var scan_z := ValleyTerrain.PLAYABLE_RECT.position.y
	while scan_z <= ValleyTerrain.PLAYABLE_RECT.end.y:
		var scan_x: float = ValleyTerrain.PLAYABLE_RECT.position.x
		while scan_x <= ValleyTerrain.PLAYABLE_RECT.end.x:
			var xz := Vector2(scan_x, scan_z)
			if not _terrain.is_water_footprint(xz) and xz.x > _terrain.river_center_x(xz.y) + ValleyTerrain.CHANNEL_HALF_WIDTH + 0.10:
				near_bank_slope = maxf(near_bank_slope, _terrain.slope_degrees(xz))
			scan_x += FIT_SAMPLE_STEP
		scan_z += FIT_SAMPLE_STEP

	var anchors := {}
	var valid_anchors := true
	for id: StringName in ANCHOR_IDS:
		var xz := anchor_xz(id)
		var info := {
			"xz": xz,
			"height": _terrain.height_at(xz),
			"slope_degrees": _terrain.slope_degrees(xz),
			"valid": _is_valid_anchor(xz),
		}
		anchors[String(id)] = info
		if not info["valid"]:
			valid_anchors = false

	var minimum_clearance := INF
	for first_index in range(ANCHOR_IDS.size()):
		for second_index in range(first_index + 1, ANCHOR_IDS.size()):
			var first_id: StringName = ANCHOR_IDS[first_index]
			var second_id: StringName = ANCHOR_IDS[second_index]
			var gap := anchor_xz(first_id).distance_to(anchor_xz(second_id))
			gap -= zone_radius(first_id) + zone_radius(second_id)
			minimum_clearance = minf(minimum_clearance, gap)
	if minimum_clearance == INF:
		minimum_clearance = 0.0

	var route_length := 0.0
	var previous := anchor(ANCHOR_IDS[0])
	for index in range(1, ANCHOR_IDS.size()):
		var current := anchor(ANCHOR_IDS[index])
		route_length += previous.distance_to(current)
		var samples := maxi(1, int(ceil(previous.distance_to(current) / 0.2)))
		for sample_index in range(samples + 1):
			var point := previous.lerp(current, float(sample_index) / float(samples))
			route_max_slope = maxf(route_max_slope, _terrain.slope_degrees(Vector2(point.x, point.z)))
		previous = current

	var lodge_xz := anchor_xz(&"lodge")
	var lodge_slope := 0.0
	for angle_index in range(24):
		var angle := deg_to_rad(-45.0 + 180.0 * float(angle_index) / 23.0)
		for radius: float in [0.9, 1.3, 1.7]:
			var sample: Vector2 = lodge_xz + Vector2(cos(angle), sin(angle)) * radius
			lodge_slope = maxf(lodge_slope, _terrain.slope_degrees(sample))

	var required_area := 0.0
	for id: StringName in ANCHOR_IDS:
		required_area += PI * zone_radius(id) * zone_radius(id)

	var notes := PackedStringArray()
	if usable_area < 35.0:
		notes.append("Usable near-bank area is below 35 m².")
	if min_width < 4.0:
		notes.append("Minimum near-bank width is below 4 m.")
	if route_max_slope > ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES:
		notes.append("A route segment exceeds 20°.")
	if minimum_clearance < 0.25:
		notes.append("Two activity zones overlap or nearly touch.")
	if not valid_anchors:
		notes.append("An anchor sits on water, outside the bank or above 20°.")
	var hidden_risk := maxf(near_bank_slope, lodge_slope) >= CAMERA_ELEVATION_DEGREES
	if hidden_risk:
		notes.append("A camera-facing slope is steeper than the camera elevation.")

	var fits := usable_area >= 35.0 and min_width >= 4.0 \
		and route_max_slope <= ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES \
		and minimum_clearance >= 0.25 and valid_anchors and not hidden_risk
	if fits:
		notes.append("The single near bank fits every required activity; a downstream crossing is not needed at this fit.")

	report["usable_bank_area_m2"] = snappedf(usable_area, 0.01)
	report["min_bank_width_m"] = snappedf(min_width, 0.01)
	report["route_length_m"] = snappedf(route_length, 0.01)
	report["route_max_slope_degrees"] = snappedf(route_max_slope, 0.01)
	report["anchors"] = anchors
	report["anchor_clearance_m"] = snappedf(minimum_clearance, 0.01)
	report["required_zone_area_m2"] = snappedf(required_area, 0.01)
	report["camera_elevation_degrees"] = CAMERA_ELEVATION_DEGREES
	report["near_bank_max_slope_degrees"] = snappedf(near_bank_slope, 0.01)
	report["lodge_near_side_max_slope_degrees"] = snappedf(lodge_slope, 0.01)
	report["hidden_ground_risk"] = hidden_risk
	report["crossing_recommended"] = not fits
	report["fits"] = fits
	report["notes"] = notes
	return report


func _is_usable_bank(xz: Vector2) -> bool:
	if not ValleyTerrain.PLAYABLE_RECT.has_point(xz):
		return false
	if _terrain.is_water_footprint(xz):
		return false
	if xz.x <= _terrain.river_center_x(xz.y) + ValleyTerrain.CHANNEL_HALF_WIDTH + 0.10:
		return false
	return _terrain.slope_degrees(xz) <= ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES


func _is_valid_anchor(xz: Vector2) -> bool:
	if not ValleyTerrain.PLAYABLE_RECT.has_point(xz):
		return false
	if _terrain.is_water_footprint(xz):
		return false
	if xz.x <= _terrain.river_center_x(xz.y) + ValleyTerrain.CHANNEL_HALF_WIDTH + 0.10:
		return false
	return _terrain.slope_degrees(xz) <= ValleyTerrain.ROUTE_SLOPE_LIMIT_DEGREES
