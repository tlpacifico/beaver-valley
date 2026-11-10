class_name ValleyTerrain
extends RefCounted
## Deterministic authored terrain for the playable valley relief preview.
## One height grid backs the visible mesh, height queries, water and later
## collision/navigation. R1 only renders it; no physics is created here.

const PLAYABLE_RECT := Rect2(-6.5, -5.5, 13.0, 11.0)
const VARIANTS: Array[StringName] = [&"gentle", &"pronounced", &"wide_bank"]
const ROUTE_SLOPE_LIMIT_DEGREES: float = 20.0
const GRID_STEP: float = 0.25
const GRID_ORIGIN := Vector2(-20.0, -20.0)
const GRID_COLUMNS: int = 160
const GRID_ROWS: int = 160
const WATER_GRID_STEP: float = 0.2
const OVAL_RADIUS_X: float = 19.0
const OVAL_RADIUS_Z: float = 18.5
const CHANNEL_HALF_WIDTH: float = 1.05
const BANK_RUN: float = 2.7
const INITIAL_WATER_LEVEL: float = -0.28
const INTERMEDIATE_WATER_LEVEL: float = -0.16
const FULL_WATER_LEVEL: float = -0.06

var variant: StringName = &"gentle"
var _config: Dictionary = {}
var _heights := PackedFloat32Array()
var _terrain_mesh_cache: ArrayMesh
var _water_mesh_cache: Dictionary = {}


func _init() -> void:
	configure(&"gentle")


func configure(new_variant: StringName) -> void:
	var configured_variant: StringName = new_variant if VARIANTS.has(new_variant) else &"gentle"
	if configured_variant == variant and not _heights.is_empty():
		return
	variant = configured_variant
	_terrain_mesh_cache = null
	_water_mesh_cache.clear()
	match variant:
		&"pronounced":
			_config = {
				"hill_height": 3.4,
				"channel_depth": 0.92,
				"lake_depth": 1.02,
				"river_x": -4.2,
				"curve": 0.50,
				"basin_rx": 4.10,
				"basin_rz": 4.60,
				"dam_z": -1.20,
			}
		&"wide_bank":
			_config = {
				"hill_height": 2.2,
				"channel_depth": 0.76,
				"lake_depth": 0.86,
				"river_x": -5.0,
				"curve": 0.28,
				"basin_rx": 3.50,
				"basin_rz": 3.90,
				"dam_z": -1.60,
			}
		_:
			_config = {
				"hill_height": 2.8,
				"channel_depth": 0.84,
				"lake_depth": 0.94,
				"river_x": -4.5,
				"curve": 0.35,
				"basin_rx": 3.90,
				"basin_rz": 4.30,
				"dam_z": -1.40,
			}
	_rebuild_height_grid()


func display_name() -> String:
	return String(variant).replace("_", " ").capitalize()


func contains(xz: Vector2) -> bool:
	if not xz.is_finite():
		return false
	var angle := atan2(xz.y, xz.x)
	var wobble := 1.0 + 0.035 * sin(3.0 * angle + 0.7) + 0.02 * sin(5.0 * angle + 2.1)
	var qx := xz.x / (OVAL_RADIUS_X * wobble)
	var qz := xz.y / (OVAL_RADIUS_Z * wobble)
	return qx * qx + qz * qz <= 1.0


## Height on the actual visible/collision triangles (linear interpolation over
## the same 0.25 m grid used by terrain_mesh). Same surface everywhere.
func height_at(xz: Vector2) -> float:
	if not xz.is_finite():
		return 0.0
	var fx := (xz.x - GRID_ORIGIN.x) / GRID_STEP
	var fz := (xz.y - GRID_ORIGIN.y) / GRID_STEP
	if fx < 0.0 or fz < 0.0 or fx >= float(GRID_COLUMNS) or fz >= float(GRID_ROWS):
		return _field_height_at(xz)
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var h00 := _grid_height(ix, iz)
	var h10 := _grid_height(ix + 1, iz)
	var h01 := _grid_height(ix, iz + 1)
	var h11 := _grid_height(ix + 1, iz + 1)
	if tx >= tz:
		return h00 + tx * (h10 - h00) + tz * (h11 - h10)
	return h00 + tz * (h01 - h00) + tx * (h11 - h01)


func normal_at(xz: Vector2) -> Vector3:
	var epsilon := 0.06
	var dx := (height_at(Vector2(xz.x + epsilon, xz.y)) - height_at(Vector2(xz.x - epsilon, xz.y))) / (2.0 * epsilon)
	var dz := (height_at(Vector2(xz.x, xz.y + epsilon)) - height_at(Vector2(xz.x, xz.y - epsilon))) / (2.0 * epsilon)
	return Vector3(-dx, 1.0, -dz).normalized()


func slope_degrees(xz: Vector2) -> float:
	var normal := normal_at(xz)
	return rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))


func river_center_x(z: float) -> float:
	var base: float = float(_config["river_x"])
	var curve: float = float(_config["curve"])
	return base + curve * sin((z + 1.0) * 0.42) + 0.12 * sin(z * 0.9)


func channel_half_width() -> float:
	return CHANNEL_HALF_WIDTH


func dam_z() -> float:
	return float(_config["dam_z"])


func lake_center() -> Vector2:
	return lake_xz()


func lake_xz() -> Vector2:
	return Vector2(river_center_x(dam_z()) - 0.15, dam_z() - float(_config["basin_rz"]) * 0.85)


func lodge_xz() -> Vector2:
	return Vector2(-0.7, -3.5)


func initial_water_level() -> float:
	return INITIAL_WATER_LEVEL


func intermediate_water_level() -> float:
	return INTERMEDIATE_WATER_LEVEL


func full_water_level() -> float:
	return FULL_WATER_LEVEL


## True where the maximum lake footprint and the channel cover the ground.
## Navigation must treat these cells as blocked from the first frame.
func is_water_footprint(xz: Vector2) -> bool:
	return height_at(xz) < FULL_WATER_LEVEL + 0.02


func is_blocked_for_walking(xz: Vector2) -> bool:
	if not PLAYABLE_RECT.has_point(xz):
		return true
	if is_water_footprint(xz):
		return true
	return slope_degrees(xz) > ROUTE_SLOPE_LIMIT_DEGREES


## Visible terrain surface with per-vertex colours and grid normals.
func terrain_mesh() -> ArrayMesh:
	if _terrain_mesh_cache != null:
		return _terrain_mesh_cache
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_terrain_material())
	for column in range(GRID_COLUMNS):
		for row in range(GRID_ROWS):
			var center := _grid_point(column, row) + Vector2(GRID_STEP, GRID_STEP) * 0.5
			if not contains(center):
				continue
			_append_terrain_vertex(surface, column, row)
			_append_terrain_vertex(surface, column + 1, row)
			_append_terrain_vertex(surface, column + 1, row + 1)
			_append_terrain_vertex(surface, column, row)
			_append_terrain_vertex(surface, column + 1, row + 1)
			_append_terrain_vertex(surface, column, row + 1)
	_terrain_mesh_cache = surface.commit()
	return _terrain_mesh_cache


## Static collision from the exact visible triangles. The body uses layer 1 so
## the actor and terrain rays agree with the rendered ground.
func build_collision_body(node_name: String = "ValleyCollision") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh().get_faces())
	collision.shape = shape
	body.add_child(collision)
	return body


## Water surface at the requested level. Only cells whose ground is below the
## level are emitted, so the same call renders the initial marsh and the
## maximum-water overlay.
func water_mesh(level: float) -> ArrayMesh:
	if _water_mesh_cache.has(level):
		return _water_mesh_cache[level]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_water_material())
	var x_start := -19.0
	var z_start := -18.5
	var columns := int(round(38.0 / WATER_GRID_STEP))
	var rows := int(round(37.0 / WATER_GRID_STEP))
	for column in range(columns):
		for row in range(rows):
			var x0 := x_start + float(column) * WATER_GRID_STEP
			var x1 := x0 + WATER_GRID_STEP
			var z0 := z_start + float(row) * WATER_GRID_STEP
			var z1 := z0 + WATER_GRID_STEP
			var center := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if not contains(center):
				continue
			var ground := height_at(center)
			if ground >= level - 0.005:
				continue
			var depth := level - ground
			var color := _water_color(depth)
			for corner in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z0), Vector2(x1, z1), Vector2(x0, z1)]:
				surface.set_color(color)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(corner.x, level + 0.008, corner.y))
	var mesh := surface.commit()
	_water_mesh_cache[level] = mesh
	return mesh


func _rebuild_height_grid() -> void:
	_heights.resize((GRID_COLUMNS + 1) * (GRID_ROWS + 1))
	for row in range(GRID_ROWS + 1):
		var z := GRID_ORIGIN.y + float(row) * GRID_STEP
		for column in range(GRID_COLUMNS + 1):
			var x := GRID_ORIGIN.x + float(column) * GRID_STEP
			_heights[row * (GRID_COLUMNS + 1) + column] = _field_height_at(Vector2(x, z))


func _grid_height(column: int, row: int) -> float:
	return _heights[row * (GRID_COLUMNS + 1) + column]


func _grid_point(column: int, row: int) -> Vector2:
	return GRID_ORIGIN + Vector2(float(column), float(row)) * GRID_STEP


func _grid_normal(column: int, row: int) -> Vector3:
	var left := _grid_height(maxi(column - 1, 0), row)
	var right := _grid_height(mini(column + 1, GRID_COLUMNS), row)
	var down := _grid_height(column, maxi(row - 1, 0))
	var up := _grid_height(column, mini(row + 1, GRID_ROWS))
	return Vector3(-(right - left) / (2.0 * GRID_STEP), 1.0, -(up - down) / (2.0 * GRID_STEP)).normalized()


## Analytic authored field. Only the grid samples and out-of-grid fallbacks use
## it; every public query uses the triangles that are actually visible.
func _field_height_at(xz: Vector2) -> float:
	if not xz.is_finite():
		return 0.0
	var x := xz.x
	var z := xz.y
	var height := 0.30 + 0.10 * sin(x * 0.60 + 0.3) * cos(z * 0.50 - 0.1)
	var shore_x := river_center_x(z) + CHANNEL_HALF_WIDTH + BANK_RUN
	height += 0.55 * smoothstep(0.0, 1.0, clampf((x - shore_x) / 7.0, 0.0, 1.0))
	height += 0.04 * sin(x * 1.15 - 0.7) * sin(z * 0.95 + 1.1)
	height += 0.06 * (0.5 + 0.5 * sin(x * 0.55 + 0.4)) * (0.5 + 0.5 * cos(z * 0.45 - 0.2))
	var river_x := river_center_x(z)
	var distance := absf(x - river_x)
	height += float(_config["hill_height"]) * _hill_weight(x, z, distance)

	var channel := 1.0 - smoothstep(CHANNEL_HALF_WIDTH, CHANNEL_HALF_WIDTH + BANK_RUN, distance)
	var carve := float(_config["channel_depth"]) * channel
	carve = maxf(carve, float(_config["lake_depth"]) * _lake_weight(x, z))
	height -= carve

	var mound := 0.35 * exp(-2.0 * pow(xz.distance_to(lodge_xz()) / 1.9, 2.0))
	mound *= 1.0 - _lake_weight(x, z)
	height += mound
	return height


func _hill_weight(x: float, z: float, distance_from_river: float) -> float:
	var west := 1.0 - smoothstep(-8.8, -5.8, x)
	var north := 1.0 - smoothstep(-8.0, -5.4, z)
	var weight := maxf(west, north)
	weight = maxf(weight, west * north * 1.15)
	weight *= smoothstep(2.2, 5.5, distance_from_river)
	weight *= 0.85 + 0.15 * sin(z * 0.55 + 0.9)
	return weight


func _lake_weight(x: float, z: float) -> float:
	var center := lake_xz()
	var dx := (x - center.x) / float(_config["basin_rx"])
	var dz := (z - center.y) / float(_config["basin_rz"])
	var q := sqrt(dx * dx + dz * dz)
	var bowl := 1.0 - smoothstep(0.15, 1.0, q)
	var upstream := 1.0 - smoothstep(dam_z() - 0.2, dam_z() + 0.6, z)
	return bowl * upstream


func _append_terrain_vertex(surface: SurfaceTool, column: int, row: int) -> void:
	var point := _grid_point(column, row)
	var height := _grid_height(column, row)
	var normal := _grid_normal(column, row)
	surface.set_color(_terrain_color(height, normal, point))
	surface.set_normal(normal)
	surface.add_vertex(Vector3(point.x, height, point.y))


func _terrain_color(height: float, normal: Vector3, xz: Vector2) -> Color:
	var slope := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
	if height < initial_water_level() - 0.02:
		var bed := Color("4f584a")
		if xz.y < dam_z():
			bed = bed.lerp(Color("4a5445"), 0.35)
		return bed
	if height < initial_water_level() + 0.06:
		return Color("9c8a60").lerp(Color("ab986c"), clampf((height - initial_water_level()) * 8.0, 0.0, 1.0))
	if height < full_water_level() + 0.02:
		return Color("6d7f5c").lerp(Color("7d8f66"), clampf((height - initial_water_level()) * 2.0, 0.0, 1.0))
	if slope > 30.0:
		return Color("6d7562")
	var variation := 0.5 + 0.5 * sin(xz.x * 0.45 + 0.8) * sin(xz.y * 0.38 - 0.4)
	var low := Color("738c60").lerp(Color("4f6b45"), variation * 0.8)
	var high := Color("809a6b").lerp(Color("5c774f"), variation * 0.7)
	return low.lerp(high, clampf((height - 0.15) / 2.6, 0.0, 1.0))


func _water_color(depth: float) -> Color:
	var marsh := Color("7f9f74")
	var deep := Color("2f86b5")
	var t := clampf((depth - 0.08) / 0.55, 0.0, 1.0)
	return marsh.lerp(deep, t)


func _terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.88)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
