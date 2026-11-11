extends Node3D
## Playable valley chapter on the accepted authored terrain. Visible ground,
## collision, placement heights and routes all derive from ValleyTerrain.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const Actor = preload("res://scripts/prototype_actor.gd")
const CastorScene = preload("res://assets/characters/castor/Castor.glb")
const BranchScene = preload("res://scenes/collectible_branch.tscn")
const VoiceScript = preload("res://scripts/provisional_voice.gd")
const VisualEnvironmentScript = preload("res://scripts/visual_environment.gd")
const SupportCharactersScript = preload("res://scripts/support_characters.gd")
const SfxScript = preload("res://scripts/provisional_sfx.gd")
const HomeStageScript = preload("res://scripts/home_stage.gd")
const FoodStageScript = preload("res://scripts/food_stage.gd")
const WinterSceneScript = preload("res://scripts/winter_scene.gd")
const DamSave = preload("res://scripts/dam_save.gd")
const TerrainScript = preload("res://scripts/valley_terrain.gd")
const LayoutScript = preload("res://scripts/valley_layout.gd")
const NavigationScript = preload("res://scripts/valley_navigation.gd")
const ASSET_TEST_FLAG: String = "user://open-asset-test"
const CAMERA_POSITION := Vector3(9.5, 14.5, 13.0)
const CAMERA_TARGET := Vector3(-1.5, 0.5, -2.0)
const CAMERA_FOV := 36.0
const CAMERA_FOLLOW_OFFSET := Vector3(9.5, 14.5, 13.0)
const CAMERA_FOLLOW_SPEED: float = 4.0
const DAM_BRANCH_COUNT: int = 3
const DAM_CREST_LAYER: int = 256
const PICKUP_CUE_COLOR := Color("e4d9a0")
const PICKUP_MUTED_CUE_COLOR := Color("b8b18a")
const PICKUP_ACTIVE_CUE_COLOR := Color("ffca45")
const HELP_CUE_COLOR := Color("70e6a1")
const DESTINATION_CUE_COLOR := Color("ffe17d")
const DESTINATION_CARRY_CUE_COLOR := Color("b7f2c2")
const BRANCH_IDS: Array[String] = ["branch_thick_01", "branch_rotten_01", "branch_normal_01", "branch_normal_02", "branch_normal_03"]
const SAVE_FAILURE_TEXT: String = "Não foi possível guardar o progresso. Pede ajuda a um adulto."
var actor: CharacterBody3D
var camera: Camera3D
var camera_follow_enabled: bool = false
var terrain: ValleyTerrain
var layout: ValleyLayout
var navigation: ValleyNavigation
var terrain_mesh: MeshInstance3D
var terrain_collision: StaticBody3D
var terrain_skirt: MeshInstance3D
var destination: MeshInstance3D
var status: Label
var click_pending: bool = false
var click_position := Vector2.ZERO
var branches: Array[CollectibleBranch] = []
var pending_branch: CollectibleBranch
var carried_branch: CollectibleBranch
var placement_pending: bool = false
var placed_count: int = 0
var placement_center := Vector3(2.5, 0.0, -4.4)
var water_surface: MeshInstance3D
var stream_surface: MeshInstance3D
var water_level: float = 0.0
var water_rise_tween: Tween
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var sky_material: ProceduralSkyMaterial
var visual_environment: VisualEnvironment
var support_characters: Node3D
var placement_area: Area3D
var dam_placement_area: Area3D
var branch_cues: Array[MeshInstance3D] = []
var placement_cue: Node3D
var dam_target_cue: Node3D
var dam_crest_area: Area3D
var finish_trim: MeshInstance3D
var stage_completion: Label
var message_band: ColorRect
var progress_label: Label
var home_stage: HomeStage
var food_stage: FoodStage
var winter_scene: WinterScene
var winter_active: bool = false
var ending_overlay: ColorRect
var ending_title: Label
var ending_message: Label
var ending_save_warning: Label
var continue_button: Button
var ending_new_adventure_button: Button
var winter_new_adventure_button: Button
var finish_panel: PanelContainer
var finish_prompt: Label
var finish_close_button: Button
var celebration_sparkles: Array[MeshInstance3D] = []
var adult_restart_button: Button
var title_control: Label
var title_hold_started: float = -1.0
var title_touch_active: bool = false
var restart_dialog: ConfirmationDialog
var voice: Node
var sfx: Node
var gnaw_button: Button
var help_button: Button
var finish_choice_buttons: Dictionary = {}
var finish_choice: String = ""
var incompatible_place_attempts: int = 0
var help_highlight_active: bool = false
var placement_help_active: bool = false
var save_directory: String = DamSave.DEFAULT_DIRECTORY
var _save_failure_visible: bool = false
var _last_chapter_signature: String = ""
var _transient_generation: int = 0
var _transient_tween: Tween
var _transient_kind: String = ""
var _completion_active: bool = false
var _completion_callback: Callable = Callable()
## Scene-local presentation state. The durable placement count commits at the
## beaver's arrival; logs, water and the finish control advance only when the
## material's animated flight reports that it reached the dam.
var _presented_dam_count: int = 0
var _presentation_generation: int = 0


func _ready() -> void:
	# Exported executables do not accept a scene path; this option opens the asset test.
	# On Android the activity ignores external arguments: debug builds use the marker
	# file instead (created and removed via ADB, see docs/castor/how-to-run.md).
	var flag_file := OS.is_debug_build() and FileAccess.file_exists(ASSET_TEST_FLAG)
	if "--asset-test" in OS.get_cmdline_user_args() or flag_file:
		get_tree().change_scene_to_file.call_deferred("res://scenes/asset_import_test.tscn")
		return
	camera_follow_enabled = "--camera-follow" in OS.get_cmdline_user_args()
	terrain = TerrainScript.new()
	terrain.configure(&"wide_bank")
	layout = LayoutScript.new()
	layout.configure(terrain)
	var dam_center := layout.dam_center()
	placement_center = Vector3(dam_center.x, dam_center.y - 0.14, dam_center.z)
	navigation = NavigationScript.new()
	navigation.configure(terrain)
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.name = "ValleyTerrainMesh"
	terrain_mesh.mesh = terrain.terrain_mesh()
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain_mesh)
	terrain_skirt = MeshInstance3D.new()
	terrain_skirt.name = "ValleyBoundarySkirt"
	terrain_skirt.mesh = terrain.boundary_skirt_mesh()
	terrain_skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain_skirt)
	terrain_collision = terrain.build_collision_body("ValleyCollision")
	add_child(terrain_collision)
	var clear_cache_xz := layout.food_cache_xz()
	water_level = terrain.initial_water_level()
	water_surface = MeshInstance3D.new()
	water_surface.name = "ValleyLake"
	water_surface.mesh = terrain.water_mesh_reach(water_level, true, clear_cache_xz, 1.15)
	water_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_surface)
	stream_surface = MeshInstance3D.new()
	stream_surface.name = "ValleyStream"
	stream_surface.mesh = terrain.water_mesh_reach(terrain.initial_water_level(), false)
	stream_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream_surface)
	var branch_spots: Array[Vector2] = [Vector2(3.2, 3.0), Vector2(0.8, 3.2), Vector2(2.6, 1.0), Vector2(0.2, 1.2), Vector2(4.2, 2.0)]
	var branch_kinds: Array[CollectibleBranch.Kind] = [CollectibleBranch.Kind.THICK, CollectibleBranch.Kind.ROTTEN, CollectibleBranch.Kind.NORMAL, CollectibleBranch.Kind.NORMAL, CollectibleBranch.Kind.NORMAL]
	for branch_index in range(branch_spots.size()):
		var spot := branch_spots[branch_index]
		var branch_position := Vector3(spot.x, terrain.height_at(spot) + 0.02, spot.y)
		var branch: CollectibleBranch = BranchScene.instantiate()
		branch.position = branch_position
		branch.configure_branch(branch_kinds[branch_index], BRANCH_IDS[branch_index])
		add_child(branch)
		branches.append(branch)
		branch_cues.append(_add_ground_ring(branch_position, 0.55, Color("fff0a3")))
	visual_environment = VisualEnvironmentScript.new() as VisualEnvironment
	visual_environment.configure(terrain, layout)
	add_child(visual_environment)
	support_characters = SupportCharactersScript.new()
	support_characters.configure(terrain, layout)
	add_child(support_characters)
	_build_placement_target()
	actor = Actor.new()
	actor.model_scene = CastorScene
	actor.model_scale = 0.72
	actor.carry_offset = Vector3(-0.11, 0.44, -0.48)
	actor.position = layout.anchor(&"spawn") + Vector3.UP * 0.05
	add_child(actor)
	home_stage = HomeStageScript.new()
	home_stage.name = "HomeStage"
	home_stage.configure(terrain, layout)
	add_child(home_stage)
	home_stage.bind(actor, navigation)
	food_stage = FoodStageScript.new()
	food_stage.name = "FoodStage"
	food_stage.configure(terrain, layout)
	add_child(food_stage)
	food_stage.bind(actor, navigation)
	winter_scene = WinterSceneScript.new()
	winter_scene.name = "WinterScene"
	winter_scene.configure(terrain, layout)
	add_child(winter_scene)
	destination = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.24
	ring.outer_radius = 0.32
	ring.material = Shapes.material(Color("ffda76"))
	destination.mesh = ring
	destination.position.y = 0.04
	destination.visible = false
	add_child(destination)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	camera.current = true
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	world_environment = WorldEnvironment.new()
	world_environment.environment = Environment.new()
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("5f8fa8")
	sky_material.sky_horizon_color = Color("cfe0cf")
	sky_material.ground_horizon_color = Color("9db6a0")
	sky_material.ground_bottom_color = Color("2a3f3c")
	sky.sky_material = sky_material
	world_environment.environment.background_mode = Environment.BG_SKY
	world_environment.environment.sky = sky
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment.ambient_light_color = Color("d4e4e0")
	world_environment.environment.ambient_light_energy = 0.45
	add_child(world_environment)
	_build_interface()
	voice = VoiceScript.new()
	voice.name = "ProvisionalVoice"
	add_child(voice)
	sfx = SfxScript.new()
	sfx.name = "ProvisionalSfx"
	add_child(sfx)
	home_stage.status_changed.connect(_on_stage_status)
	home_stage.voice_requested.connect(voice.play_event)
	home_stage.sound_requested.connect(sfx.play_event)
	home_stage.completed.connect(_on_home_completed)
	home_stage.part_placed.connect(_on_home_part_placed)
	food_stage.status_changed.connect(_on_stage_status)
	food_stage.voice_requested.connect(voice.play_event)
	food_stage.sound_requested.connect(sfx.play_event)
	food_stage.placed.connect(_on_food_placed)
	food_stage.completed.connect(_on_food_completed)
	food_stage.activated.connect(_on_food_activated)
	voice.event_finished.connect(_on_voice_event_finished)
	var capture_mode := "--capture-initial" in OS.get_cmdline_user_args() or "--capture-home" in OS.get_cmdline_user_args() or "--capture-food" in OS.get_cmdline_user_args() or "--capture-ending" in OS.get_cmdline_user_args() or "--capture-water" in OS.get_cmdline_user_args() or "--capture-finish" in OS.get_cmdline_user_args() or "--capture-placement" in OS.get_cmdline_user_args()
	if "--fresh-save" in OS.get_cmdline_user_args():
		# Interactive playtest from the beginning, isolated from the normal save.
		save_directory = "user://painted_beaver_playtest_save/" if "--beaver-playtest" in OS.get_cmdline_user_args() else "user://playtest_save/"
		DamSave.clear_save(save_directory)
	if capture_mode:
		# Debug captures must never alter the player's chapter save.
		save_directory = "user://capture_save/"
		DamSave.clear_save(save_directory)
	_restore_dam_save()
	_update_branch_cues()
	if _current_stage() == "dam" and placed_count == 0:
		voice.play_event("dam_start")
	if "--capture-ending" in OS.get_cmdline_user_args():
		_capture_ending()
	elif "--capture-food" in OS.get_cmdline_user_args():
		_capture_food()
	elif "--capture-home" in OS.get_cmdline_user_args():
		_capture_home()
	elif "--capture-water" in OS.get_cmdline_user_args():
		_capture_water()
	elif "--capture-finish" in OS.get_cmdline_user_args():
		_capture_finish()
	elif "--capture-placement" in OS.get_cmdline_user_args():
		_capture_placement()
	elif "--capture-initial" in OS.get_cmdline_user_args():
		_capture_initial()
	elif "--capture-movement" in OS.get_cmdline_user_args():
		_capture()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	add_child(layer)
	title_control = Label.new()
	title_control.text = "CASTOR / PRIMEIROS PASSOS"
	title_control.position = Vector2(24, 18)
	title_control.add_theme_font_size_override("font_size", 24)
	title_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title_control)
	status = Label.new()
	status.name = "ObjectiveLine"
	status.text = "Escolhe um ramo para a represa."
	status.position = Vector2(24, 54)
	status.add_theme_font_size_override("font_size", 20)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	progress_label = Label.new()
	progress_label.name = "ChapterProgress"
	progress_label.position = Vector2(24, 88)
	progress_label.add_theme_font_size_override("font_size", 28)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(progress_label)
	message_band = ColorRect.new()
	message_band.name = "MessageBand"
	message_band.position = Vector2(0, 460)
	message_band.size = Vector2(960, 140)
	message_band.color = Color(0.035, 0.065, 0.075, 0.38)
	message_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_band.visible = false
	layer.add_child(message_band)
	stage_completion = Label.new()
	stage_completion.name = "StageCompletion"
	# The transient region stays inside the 960 x 600 reference view: long
	# movement and winter help lines wrap instead of running off the screen.
	stage_completion.position = Vector2(40, 468)
	stage_completion.size = Vector2(880, 120)
	stage_completion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_completion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_completion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_completion.add_theme_font_size_override("font_size", 38)
	stage_completion.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	stage_completion.add_theme_constant_override("outline_size", 6)
	stage_completion.add_theme_color_override("font_color", Color("fff0a3"))
	stage_completion.visible = false
	stage_completion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stage_completion)
	_build_celebration_sparkles()
	adult_restart_button = Button.new()
	adult_restart_button.text = "Recomeçar (adulto)"
	adult_restart_button.position = Vector2(720, 18)
	adult_restart_button.visible = false
	adult_restart_button.pressed.connect(_confirm_restart)
	layer.add_child(adult_restart_button)
	gnaw_button = Button.new()
	gnaw_button.text = "Roer o ramo"
	gnaw_button.position = Vector2(24, 132)
	gnaw_button.custom_minimum_size = Vector2(140, 48)
	gnaw_button.visible = false
	gnaw_button.pressed.connect(request_gnaw)
	layer.add_child(gnaw_button)
	help_button = Button.new()
	help_button.name = "HelpButton"
	help_button.text = "?"
	help_button.tooltip_text = "Ajuda"
	help_button.custom_minimum_size = Vector2(48, 48)
	help_button.position = Vector2(660, 18)
	help_button.add_theme_font_size_override("font_size", 26)
	help_button.pressed.connect(request_help)
	layer.add_child(help_button)
	_build_finish_panel(layer)
	winter_new_adventure_button = Button.new()
	winter_new_adventure_button.name = "WinterNewAdventure"
	winter_new_adventure_button.text = "Nova aventura"
	winter_new_adventure_button.position = Vector2(700, 72)
	winter_new_adventure_button.custom_minimum_size = Vector2(220, 48)
	winter_new_adventure_button.add_theme_font_size_override("font_size", 16)
	winter_new_adventure_button.visible = false
	winter_new_adventure_button.pressed.connect(_confirm_restart)
	layer.add_child(winter_new_adventure_button)
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "Começar uma nova aventura?"
	restart_dialog.dialog_text = "A represa, a casa e a comida voltam ao início."
	restart_dialog.min_size = Vector2i(520, 200)
	restart_dialog.ok_button_text = "Começar de novo"
	restart_dialog.cancel_button_text = "Cancelar"
	restart_dialog.confirmed.connect(_restart_experiment)
	layer.add_child(restart_dialog)
	_build_ending_overlay(layer)
	_refresh_chapter_interface()


## Compact optional dam-finish panel. It only appears after the celebration (or
## when the child taps the completed dam) and owns its own click/touch input.
func _build_finish_panel(layer: CanvasLayer) -> void:
	finish_panel = PanelContainer.new()
	finish_panel.name = "FinishPanel"
	finish_panel.position = Vector2(24, 224)
	finish_panel.custom_minimum_size = Vector2(360, 0)
	finish_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	finish_panel.visible = false
	layer.add_child(finish_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	finish_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	finish_prompt = Label.new()
	finish_prompt.name = "FinishPrompt"
	finish_prompt.text = "Escolhe o acabamento da represa:"
	finish_prompt.add_theme_font_size_override("font_size", 18)
	box.add_child(finish_prompt)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	box.add_child(choices)
	for option in [["finish_golden", "Dourado"], ["finish_moss", "Verde"]]:
		var finish_button := Button.new()
		finish_button.text = option[1]
		finish_button.toggle_mode = true
		finish_button.custom_minimum_size = Vector2(140, 48)
		var choice_id: String = option[0]
		finish_button.pressed.connect(func() -> void: select_finish_choice(choice_id))
		choices.add_child(finish_button)
		finish_choice_buttons[choice_id] = finish_button
	finish_close_button = Button.new()
	finish_close_button.name = "FinishClose"
	finish_close_button.text = "Fechar"
	finish_close_button.custom_minimum_size = Vector2(140, 48)
	finish_close_button.pressed.connect(_close_finish_panel)
	box.add_child(finish_close_button)


## Stage by progression order: winter, food, home, dam. Earlier stages can stay
## active internally; only the furthest stage drives the interface.
func _current_stage() -> String:
	if winter_active:
		return "winter"
	if food_stage != null and food_stage.is_active:
		return "food"
	if home_stage != null and home_stage.is_active:
		return "home"
	return "dam"


func _objective_text() -> String:
	match _current_stage():
		"winter":
			return "O inverno chegou! A família do castor está reunida."
		"food":
			if food_stage != null and food_stage.carried_bundle != null and food_stage.is_bundle_suitable(food_stage.carried_bundle):
				return "Guarda o feixe junto à casa."
			return "Escolhe um feixe de comida."
		"home":
			if home_stage != null and home_stage.carried_part != null:
				return "Leva a peça até à casa."
			return "Escolhe uma peça para a casa."
		_:
			if _carried_branch_is_suitable():
				return "Leva o ramo até à represa."
			return "Escolhe um ramo para a represa."


func _progress_text(stage: String) -> String:
	match stage:
		"winter", "food":
			var food_symbols := "●".repeat(food_stage.placed_count) + "○".repeat(FoodStage.REQUIRED_COUNT - food_stage.placed_count)
			return "Comida guardada: " + food_symbols
		"home":
			var home_symbols := "●".repeat(home_stage.placed_slot_count) + "○".repeat(home_stage.slot_count - home_stage.placed_slot_count)
			return "Peças na casa: " + home_symbols
		_:
			var dam_symbols := "●".repeat(placed_count) + "○".repeat(DAM_BRANCH_COUNT - placed_count)
			return "Ramos na represa: " + dam_symbols


func _chapter_signature() -> String:
	var branch_state := ""
	if carried_branch != null:
		branch_state = "%s:%s" % [carried_branch.stable_id, str(carried_branch.gnawed)]
	var part_id := home_stage.carried_part.stable_id if home_stage != null and home_stage.carried_part != null else ""
	var bundle_id := food_stage.carried_bundle.stable_id if food_stage != null and food_stage.carried_bundle != null else ""
	var home_slots := home_stage.placed_slot_count if home_stage != null else 0
	var food_count := food_stage.placed_count if food_stage != null else 0
	return "%s|%s|%s|%s|%d|%d|%d" % [_current_stage(), branch_state, part_id, bundle_id, placed_count, home_slots, food_count]


## Derives the permanent objective, the current-stage progress and the
## contextual controls from committed stage/carry state. Never advances a stage
## and never saves.
func _refresh_chapter_interface() -> void:
	if status == null or progress_label == null:
		return
	var stage := _current_stage()
	_last_chapter_signature = _chapter_signature()
	status.text = SAVE_FAILURE_TEXT if _save_failure_visible else _objective_text()
	progress_label.text = _progress_text(stage)
	progress_label.visible = true
	_update_obstacle_controls()
	_update_finish_choices(_presented_dam_count >= DAM_BRANCH_COUNT)
	_update_branch_cues()


func _show_stage_completion(text: String, duration: float = 2.0) -> void:
	_show_transient(text, duration, true)


## Contextual messages share the transient region but never replace a
## celebration or become a second permanent instruction.
func _show_feedback(text: String, duration: float = 2.5) -> void:
	if _completion_active:
		return
	_show_transient(text, duration, false)


func _show_transient(text: String, duration: float, is_completion: bool) -> void:
	if stage_completion == null:
		return
	_transient_generation += 1
	var generation := _transient_generation
	_transient_kind = "completion" if is_completion else "feedback"
	_completion_active = is_completion
	_completion_callback = Callable()
	stage_completion.text = text
	stage_completion.visible = true
	if is_completion:
		var pulse := create_tween()
		pulse.tween_property(stage_completion, "scale", Vector2(1.08, 1.08), 0.22).from(Vector2.ONE)
		pulse.tween_property(stage_completion, "scale", Vector2.ONE, 0.22)
	if _transient_tween != null and _transient_tween.is_valid():
		_transient_tween.kill()
	_transient_tween = create_tween()
	_transient_tween.tween_interval(duration)
	_transient_tween.tween_callback(func() -> void: _expire_transient(generation))


func _expire_transient(generation: int) -> void:
	if generation != _transient_generation:
		return
	var was_completion := _transient_kind == "completion"
	var callback := _completion_callback
	_transient_kind = ""
	_completion_active = false
	_completion_callback = Callable()
	stage_completion.visible = false
	if was_completion and callback.is_valid():
		callback.call()


## Invalidates any pending celebration, so an older expiry or the delayed
## finish-panel opening can never act after a newer action.
func _clear_stage_completion() -> void:
	_transient_generation += 1
	if _transient_tween != null and _transient_tween.is_valid():
		_transient_tween.kill()
	_transient_tween = null
	_transient_kind = ""
	_completion_active = false
	_completion_callback = Callable()
	if stage_completion != null:
		stage_completion.visible = false


## Changes only the optional panel visibility: never a carried item, never a
## walking command. The ending and restart modals take precedence.
func _set_finish_panel_open(is_open: bool) -> void:
	if finish_panel == null:
		return
	var modal_visible := (ending_overlay != null and ending_overlay.visible) or (restart_dialog != null and restart_dialog.visible)
	var allowed := _presented_dam_count >= DAM_BRANCH_COUNT and not modal_visible
	finish_panel.visible = is_open and allowed


func _open_finish_panel_after_celebration() -> void:
	_set_finish_panel_open(true)


## Closing the panel is a child action: it also cancels the pending automatic
## opening, so "Fechar" or a choice cannot be undone by the celebration timer.
func _close_finish_panel() -> void:
	_set_finish_panel_open(false)
	if _completion_callback.is_valid() and _completion_callback.get_method() == &"_open_finish_panel_after_celebration":
		_completion_callback = Callable()


func _update_dam_crest_hit_target() -> void:
	if dam_crest_area != null:
		dam_crest_area.collision_layer = DAM_CREST_LAYER if _presented_dam_count >= DAM_BRANCH_COUNT else 0


func _is_new_action_in_progress() -> bool:
	if pending_branch != null or placement_pending:
		return true
	if home_stage != null and (home_stage.pending_part != null or home_stage.pending_slot >= 0):
		return true
	if food_stage != null and (food_stage.pending_bundle != null or food_stage.target_pending):
		return true
	return false


## Audio completion only reports an event. The world decides whether a home
## invitation is still valid for the current stage.
func _on_voice_event_finished(event_id: String) -> void:
	if event_id != "dam_completed":
		return
	if winter_active:
		return
	if food_stage != null and food_stage.is_active:
		return
	if home_stage == null or not home_stage.is_active or home_stage.is_complete():
		return
	voice.play_event("home_invite")


func _build_ending_overlay(layer: CanvasLayer) -> void:
	ending_overlay = ColorRect.new()
	ending_overlay.name = "EndingOverlay"
	ending_overlay.color = Color(0.04, 0.08, 0.09, 0.88)
	ending_overlay.position = Vector2.ZERO
	ending_overlay.size = Vector2(960, 600)
	ending_overlay.visible = false
	ending_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(ending_overlay)
	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = Vector2(960, 600)
	ending_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	ending_title = Label.new()
	ending_title.name = "EndingTitle"
	ending_title.text = "O inverno chegou!"
	ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_title.add_theme_font_size_override("font_size", 44)
	ending_title.add_theme_color_override("font_color", Color("fff0a3"))
	box.add_child(ending_title)
	ending_message = Label.new()
	ending_message.name = "EndingMessage"
	ending_message.text = "A família do castor está reunida. A casa está quente e a comida está guardada."
	ending_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_message.custom_minimum_size = Vector2(700, 0)
	ending_message.add_theme_font_size_override("font_size", 24)
	box.add_child(ending_message)
	# A failed final save must stay readable above this overlay: the child's
	# progress is the one thing the ending screen must not hide.
	ending_save_warning = Label.new()
	ending_save_warning.name = "EndingSaveWarning"
	ending_save_warning.text = SAVE_FAILURE_TEXT
	ending_save_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_save_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_save_warning.custom_minimum_size = Vector2(700, 0)
	ending_save_warning.add_theme_font_size_override("font_size", 22)
	ending_save_warning.add_theme_color_override("font_color", Color("ffb4a8"))
	ending_save_warning.visible = false
	box.add_child(ending_save_warning)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	continue_button = Button.new()
	continue_button.text = "Continuar a visitar"
	continue_button.custom_minimum_size = Vector2(260, 58)
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.pressed.connect(_continue_visiting)
	buttons.add_child(continue_button)
	ending_new_adventure_button = Button.new()
	ending_new_adventure_button.text = "Nova aventura"
	ending_new_adventure_button.custom_minimum_size = Vector2(220, 58)
	ending_new_adventure_button.add_theme_font_size_override("font_size", 22)
	ending_new_adventure_button.pressed.connect(_confirm_restart)
	buttons.add_child(ending_new_adventure_button)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and event.ctrl_pressed:
		_confirm_restart()
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_position = event.position
		click_pending = true
	elif event is InputEventScreenTouch and event.pressed:
		if event.position.y <= 48 and event.position.x <= 380:
			title_touch_active = true
			title_hold_started = Time.get_ticks_msec() / 1000.0
		else:
			click_position = event.position
			click_pending = true
	elif event is InputEventScreenTouch and not event.pressed and title_touch_active:
		title_touch_active = false
		title_hold_started = -1.0


func _physics_process(_delta: float) -> void:
	_update_adult_restart_hold(Time.get_ticks_msec() / 1000.0)
	# Any meaningful new action invalidates the previous celebration and its
	# pending finish-panel opening, even when a stage request is called directly.
	if _completion_active and _is_new_action_in_progress():
		_clear_stage_completion()
	if _chapter_signature() != _last_chapter_signature:
		_refresh_chapter_interface()
	if click_pending:
		click_pending = false
		_move_from_screen(click_position)
	if pending_branch != null and actor.is_arrived():
		# A pickup reserved before the final commit must not finish in the home
		# stage: release it and keep the current stage objective.
		if placed_count >= DAM_BRANCH_COUNT:
			_cancel_pending_collection()
			_show_feedback("A represa está pronta. Vamos construir a casa!")
			return
		if carried_branch != null and carried_branch != pending_branch:
			carried_branch.return_to_origin(self)
			carried_branch = null
		carried_branch = pending_branch
		var was_bent := carried_branch.bent
		var carry_roll := deg_to_rad(-15.0) if carried_branch.kind == CollectibleBranch.Kind.ROTTEN else 0.0
		carried_branch.carry(actor, actor.carry_offset, carry_roll)
		var newly_bent := not was_bent and carried_branch.bent and carried_branch.kind == CollectibleBranch.Kind.ROTTEN
		var carry_save_ok := true
		if newly_bent:
			carry_save_ok = _save_dam_state()
		pending_branch = null
		sfx.play_event("collect")
		incompatible_place_attempts = 0
		help_highlight_active = false
		_show_feedback(_collection_comment(carried_branch))
		if not carry_save_ok:
			_show_save_failure()
		_update_obstacle_controls()
		if carried_branch.kind == CollectibleBranch.Kind.ROTTEN:
			voice.play_event("rotten_branch")
		elif carried_branch.kind == CollectibleBranch.Kind.THICK and not carried_branch.gnawed:
			voice.play_event("thick_branch")
		else:
			voice.play_event("help_place")
		_update_branch_cues()
	if placement_pending and actor.is_arrived():
		placement_pending = false
		if carried_branch != null and placed_count < DAM_BRANCH_COUNT:
			if not _carried_branch_is_suitable():
				_update_branch_cues()
				return
			var placed_branch := carried_branch
			var slot_index := placed_count
			# Scene-local presentation generation: an older response cannot act
			# after a newer commit, a reload or scene disposal.
			_presentation_generation += 1
			var sequence_id := _presentation_generation
			actor.play_place_action()
			placed_branch.placement_visual_finished.connect(_on_dam_placement_visual_finished.bind(sequence_id), CONNECT_ONE_SHOT)
			placed_branch.place(self, placement_center, slot_index, true)
			carried_branch = null
			_update_obstacle_controls()
			placed_count += 1
			incompatible_place_attempts = 0
			help_highlight_active = false
			# Persist exactly once, at the beaver's arrival. Sound, structure,
			# water and the stage celebration wait for the material to arrive.
			var placement_save_ok := _save_dam_state()
			if not placement_save_ok:
				_show_save_failure()
			_refresh_chapter_interface()
			if placed_count == DAM_BRANCH_COUNT:
				_cancel_pending_collection()


## Consumes the branch's material-arrival signal for the current presentation
## generation. A callback from an older commit is ignored, so a new placement,
## reload or freed scene never replays an older response or invitation.
func _on_dam_placement_visual_finished(slot_index: int, sequence_id: int) -> void:
	if sequence_id != _presentation_generation:
		return
	if not is_inside_tree():
		return
	if slot_index < 0 or slot_index >= placed_count:
		return
	if placed_count <= _presented_dam_count:
		return
	_present_dam_arrival()


## Presentation only: reveal the committed structure one step, play the impact,
## animate the prepared upstream rise and show the matching acknowledgement.
## It never changes durable state and never saves.
func _present_dam_arrival() -> void:
	var committed := placed_count
	var previous_level := water_level
	var target_level := _water_level_for(committed)
	# Reconciliation after overlapping commits must never lower visible water.
	if target_level < previous_level - 0.001:
		target_level = previous_level
	_presented_dam_count = committed
	water_level = target_level
	if water_surface != null:
		water_surface.mesh = terrain.water_mesh_reach(target_level, true, layout.food_cache_xz(), 1.15)
	if stream_surface != null:
		stream_surface.mesh = terrain.water_mesh_reach(terrain.initial_water_level(), false)
	if target_level > previous_level + 0.001 and is_inside_tree():
		_animate_water_rise(previous_level, target_level)
	else:
		if water_rise_tween != null:
			water_rise_tween.kill()
			water_rise_tween = null
		if water_surface != null:
			water_surface.position.y = 0.0
		# The final placement has no further rise, so a brief ripple still
		# confirms that the structure reached the water.
		_spawn_water_ripples(target_level)
	if visual_environment != null:
		visual_environment.set_dam_state(_presented_dam_count, finish_choice)
		visual_environment.set_water_level(target_level)
	if food_stage != null:
		food_stage.set_water_level(target_level)
	sfx.play_event("complete" if committed >= DAM_BRANCH_COUNT else "place")
	if committed >= DAM_BRANCH_COUNT:
		_clear_stage_completion()
		_show_stage_completion("A represa está pronta!")
		# The optional panel waits for the celebration; an early action clears
		# this callback, so it cannot open later.
		_completion_callback = _open_finish_panel_after_celebration
		home_stage.activate()
		_cancel_pending_collection()
		_refresh_chapter_interface()
		voice.play_event("dam_completed")
		_play_celebration()
		return
	if committed == 1:
		voice.play_event("first_placement")
	_show_feedback("Boa! A água está a mudar. Escolhe mais um ramo.")
	_refresh_chapter_interface()


func _process(delta: float) -> void:
	if camera_follow_enabled and actor != null and camera != null:
		_update_follow_camera(delta)
	if message_band != null and stage_completion != null:
		message_band.visible = stage_completion.visible


func _update_follow_camera(delta: float) -> void:
	var target := actor.global_position + Vector3.UP * 0.35
	var desired_position := target + CAMERA_FOLLOW_OFFSET
	var blend := 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta)
	camera.global_position = camera.global_position.lerp(desired_position, blend)


func _update_adult_restart_hold(now_seconds: float) -> void:
	if title_touch_active and title_hold_started >= 0.0 and now_seconds - title_hold_started >= 1.2:
		_show_adult_restart()


func _move_from_screen(screen_position: Vector2) -> bool:
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 100.0
	# The completed dam is its own optional control. Handle it before the
	# placement target and before any path that cancels a pending collection or
	# returns a carried item: opening the panel must not disturb the paws.
	var crest_query := PhysicsRayQueryParameters3D.create(origin, end, DAM_CREST_LAYER)
	crest_query.collide_with_areas = true
	if _presented_dam_count >= DAM_BRANCH_COUNT and not get_world_3d().direct_space_state.intersect_ray(crest_query).is_empty():
		_set_finish_panel_open(true)
		return finish_panel != null and finish_panel.visible
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var branch_query := PhysicsRayQueryParameters3D.create(origin, end, 4)
	branch_query.collide_with_areas = true
	var branch_hit := get_world_3d().direct_space_state.intersect_ray(branch_query)
	if not branch_hit.is_empty():
		var selected := branch_hit.collider.get_parent() as CollectibleBranch
		if home_stage != null:
			home_stage.cancel_pending()
			home_stage.return_carried()
		if food_stage != null:
			food_stage.cancel_pending()
			food_stage.return_carried()
		return request_collect(selected)
	var home_part_query := PhysicsRayQueryParameters3D.create(origin, end, HomeStage.PART_LAYER)
	home_part_query.collide_with_areas = true
	var home_part_hit := get_world_3d().direct_space_state.intersect_ray(home_part_query)
	if not home_part_hit.is_empty():
		var home_part := home_part_hit.collider.get_parent() as HomePart
		if home_part != null:
			_begin_world_action()
			_cancel_pending_collection()
			placement_pending = false
			if food_stage != null:
				food_stage.cancel_pending()
			if carried_branch != null:
				carried_branch.return_to_origin(self)
				carried_branch = null
				_update_branch_cues()
			return home_stage.request_collect(home_part)
	var food_bundle_query := PhysicsRayQueryParameters3D.create(origin, end, FoodStage.BUNDLE_LAYER)
	food_bundle_query.collide_with_areas = true
	var food_bundle_hit := get_world_3d().direct_space_state.intersect_ray(food_bundle_query)
	if not food_bundle_hit.is_empty():
		var food_bundle := food_bundle_hit.collider.get_parent() as FoodBundle
		if food_bundle != null:
			_begin_world_action()
			_cancel_pending_collection()
			placement_pending = false
			if home_stage != null:
				home_stage.cancel_pending()
			if carried_branch != null:
				carried_branch.return_to_origin(self)
				carried_branch = null
				_update_branch_cues()
			return food_stage.request_collect(food_bundle)
	var target_query := PhysicsRayQueryParameters3D.create(origin, end, 8)
	target_query.collide_with_areas = true
	if not get_world_3d().direct_space_state.intersect_ray(target_query).is_empty():
		if home_stage != null:
			home_stage.cancel_pending()
		if food_stage != null:
			food_stage.cancel_pending()
		return request_place()
	var home_slot_query := PhysicsRayQueryParameters3D.create(origin, end, HomeStage.SLOT_LAYER)
	home_slot_query.collide_with_areas = true
	var home_slot_hit := get_world_3d().direct_space_state.intersect_ray(home_slot_query)
	if not home_slot_hit.is_empty():
		var slot_index := home_stage.resolve_slot_at(screen_position, camera)
		if slot_index < 0:
			slot_index = int(home_slot_hit.collider.get_meta("home_slot_index", -1))
		if slot_index >= 0:
			_begin_world_action()
			_cancel_pending_collection()
			placement_pending = false
			if food_stage != null:
				food_stage.cancel_pending()
			return home_stage.request_place(slot_index)
	var food_target_query := PhysicsRayQueryParameters3D.create(origin, end, FoodStage.TARGET_LAYER)
	food_target_query.collide_with_areas = true
	if not get_world_3d().direct_space_state.intersect_ray(food_target_query).is_empty():
		_begin_world_action()
		_cancel_pending_collection()
		placement_pending = false
		if home_stage != null:
			home_stage.cancel_pending()
		return food_stage.request_place()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not navigation.is_walkable(Vector2(hit.position.x, hit.position.z)):
		_show_feedback("Escolhe um sítio livre no chão.")
		return false
	return request_move(hit.position)


## Closing the optional panel and dismissing an old celebration belongs to every
## new world action, but never to opening the panel.
func _begin_world_action() -> void:
	_set_finish_panel_open(false)
	_clear_stage_completion()


func request_collect(branch: CollectibleBranch) -> bool:
	if not branches.has(branch):
		return false
	# The durable dam completion closes dam-material collection immediately,
	# even while the last branch is still flying to the structure.
	if placed_count >= DAM_BRANCH_COUNT:
		_show_feedback("A represa está pronta. Vamos construir a casa!")
		return false
	if home_stage != null and home_stage.is_active:
		_show_feedback("A represa está pronta. Vamos construir a casa!")
		return false
	if home_stage != null:
		home_stage.cancel_pending()
		home_stage.return_carried()
	help_highlight_active = false
	placement_help_active = false
	placement_pending = false
	if branch == carried_branch:
		if pending_branch != null:
			_cancel_pending_collection()
			actor.follow_path(PackedVector3Array())
			destination.visible = false
			_show_feedback("O castor continua a levar o mesmo ramo.")
			return true
		_show_feedback("O ramo já está com o castor.")
		return true
	if branch == pending_branch:
		return true
	if pending_branch != null and pending_branch != carried_branch:
		pending_branch.cancel_reservation()
		pending_branch = null
	var path := navigation.find_approach(actor.global_position, Vector2(branch.position.x, branch.position.z), 3)
	if path.is_empty():
		_show_feedback("Esse ramo está longe demais para chegar.")
		return false
	_begin_world_action()
	actor.follow_path(path)
	voice.cancel()
	branch.reserve()
	pending_branch = branch
	destination.position = path[path.size() - 1] + Vector3.UP * 0.04
	destination.visible = true
	_show_feedback("O castor vai buscar o ramo.")
	_update_branch_cues()
	return true


func _cancel_pending_collection() -> void:
	if pending_branch == null:
		return
	pending_branch.cancel_reservation()
	pending_branch = null
	_update_branch_cues()


func request_move(world_position: Vector3) -> bool:
	if not world_position.is_finite():
		return false
	if not navigation.is_walkable(Vector2(world_position.x, world_position.z)):
		_show_feedback("Escolhe um sítio livre no chão.")
		return false
	var path := navigation.find_path(actor.global_position, world_position)
	if path.is_empty():
		return false
	_begin_world_action()
	_cancel_pending_collection()
	if home_stage != null:
		home_stage.cancel_pending()
	if food_stage != null:
		food_stage.cancel_pending()
	placement_pending = false
	help_highlight_active = false
	placement_help_active = false
	voice.cancel()
	actor.follow_path(path)
	destination.position = Vector3(world_position.x, terrain.height_at(Vector2(world_position.x, world_position.z)) + 0.04, world_position.z)
	destination.visible = true
	_show_feedback("O círculo amarelo mostra o destino. Podes escolher outro.")
	return true


func _build_placement_target() -> void:
	var bank_spot: Vector3 = layout.anchor(&"dam_approach")
	# Destination cues are broken outlines: shape, not colour alone, separates a
	# destination from the quiet closed pickup rings.
	placement_cue = _add_destination_outline(bank_spot, 0.9, Color("ffe17d"))
	dam_target_cue = _add_destination_outline(placement_center + Vector3(0.0, 0.30, 0.0), 0.55, Color("ffe17d"))
	var finish_mesh := BoxMesh.new()
	finish_mesh.size = Vector3(1.4, 0.07, 0.12)
	var finish_material := StandardMaterial3D.new()
	finish_material.albedo_color = Color("d6a83e")
	finish_mesh.material = finish_material
	finish_trim = MeshInstance3D.new()
	finish_trim.name = "DamFinishTrim"
	finish_trim.mesh = finish_mesh
	finish_trim.position = placement_center + Vector3(0, 0.36, 0.0)
	finish_trim.visible = false
	add_child(finish_trim)
	placement_area = Area3D.new()
	placement_area.collision_layer = 8
	placement_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 1.0, 2.2)
	collision.shape = shape
	collision.position = bank_spot + Vector3.UP * 0.5
	placement_area.add_child(collision)
	add_child(placement_area)
	# The visible crest is also a placement target before completion: tapping the
	# marked dam shape routes the beaver to the dry work position like the bank
	# target, instead of rejecting the tap as invalid ground.
	dam_placement_area = Area3D.new()
	dam_placement_area.name = "DamCrestPlacementArea"
	dam_placement_area.collision_layer = 8
	dam_placement_area.collision_mask = 0
	var crest_place_shape := BoxShape3D.new()
	crest_place_shape.size = Vector3(5.6, 0.9, 1.1)
	var crest_place_collision := CollisionShape3D.new()
	crest_place_collision.shape = crest_place_shape
	crest_place_collision.position = layout.dam_center() + Vector3(0.0, -0.12, 0.08)
	dam_placement_area.add_child(crest_place_collision)
	add_child(dam_placement_area)
	# Optional finish control target: the visible crest of the completed dam.
	# It stays disabled (layer 0) until the dam is complete, so the existing
	# placement behaviour is unchanged before that point.
	dam_crest_area = Area3D.new()
	dam_crest_area.name = "DamCrestArea"
	dam_crest_area.collision_layer = 0
	dam_crest_area.collision_mask = 0
	var crest_shape := BoxShape3D.new()
	crest_shape.size = Vector3(5.6, 0.9, 1.1)
	var crest_collision := CollisionShape3D.new()
	crest_collision.shape = crest_shape
	crest_collision.position = layout.dam_center() + Vector3(0.0, -0.12, 0.08)
	dam_crest_area.add_child(crest_collision)
	add_child(dam_crest_area)


func request_place() -> bool:
	if placement_pending:
		return true
	if placed_count >= DAM_BRANCH_COUNT:
		_show_feedback("A represa está completa!")
		return false
	if home_stage != null:
		home_stage.cancel_pending()
	if food_stage != null:
		food_stage.cancel_pending()
	if carried_branch == null:
		_show_feedback("Toca no ramo e depois na zona amarela.")
		voice.play_event("help_collect")
		return false
	if not _carried_branch_is_suitable():
		incompatible_place_attempts += 1
		if carried_branch.kind == CollectibleBranch.Kind.THICK:
			_show_feedback("Este ramo é grosso. Roê-o primeiro ou escolhe outro.")
		else:
			_show_feedback("Este ramo está podre e dobra. Escolhe outro ramo.")
		if incompatible_place_attempts >= 2:
			_show_feedback("Ajuda: escolhe o ramo marcado a verde.")
			help_highlight_active = true
			support_characters.show_hint()
			voice.play_event("help_compatible")
			_update_branch_cues()
		return false
	var bank_spot: Vector3 = layout.anchor(&"dam_approach")
	var path := navigation.find_path(actor.global_position, bank_spot)
	if path.is_empty():
		_show_feedback("A zona da represa está fora do caminho.")
		return false
	# Keep an in-progress pickup intact unless placement has a valid route.
	_begin_world_action()
	_cancel_pending_collection()
	voice.cancel()
	actor.follow_path(path)
	placement_pending = true
	incompatible_place_attempts = 0
	help_highlight_active = false
	placement_help_active = false
	destination.position = bank_spot + Vector3.UP * 0.04
	destination.visible = true
	_show_feedback("O castor vai colocar o ramo.")
	_update_branch_cues()
	return true


func _update_water(animate: bool = true) -> void:
	if water_surface == null or terrain == null or layout == null:
		return
	# Immediate apply path used by restore, captures and tests. It also syncs the
	# presented count because those paths show the committed result at once.
	_presented_dam_count = placed_count
	var target: float = _water_level_for(placed_count)
	var previous := water_level
	water_level = target
	var clear_cache_xz := layout.food_cache_xz()
	water_surface.mesh = terrain.water_mesh_reach(target, true, clear_cache_xz, 1.15)
	if stream_surface != null:
		stream_surface.mesh = terrain.water_mesh_reach(terrain.initial_water_level(), false)
	if animate and target > previous + 0.001 and is_inside_tree():
		_animate_water_rise(previous, target)
	else:
		if water_rise_tween != null:
			water_rise_tween.kill()
			water_rise_tween = null
		water_surface.position.y = 0.0
	if visual_environment != null:
		visual_environment.set_dam_state(_presented_dam_count, finish_choice)
		visual_environment.set_water_level(target)
	if food_stage != null:
		food_stage.set_water_level(target)


## Prepared upstream levels: initial, intermediate, full, then full again for the
## third structural placement, which confirms the dam without another rise.
func _water_level_for(count: int) -> float:
	var levels: Array[float] = [terrain.initial_water_level(), terrain.intermediate_water_level(), terrain.full_water_level(), terrain.full_water_level()]
	return levels[mini(count, 3)]


## The upstream mesh is authored at its target level. Offsetting it to the old
## level and lifting it floods the new shore progressively while the downstream
## stream mesh stays at the initial level.
func _animate_water_rise(previous: float, target: float) -> void:
	if water_rise_tween != null:
		water_rise_tween.kill()
	water_surface.position.y = previous - target
	water_rise_tween = create_tween()
	water_rise_tween.tween_property(water_surface, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_spawn_water_ripples(target)


func _spawn_water_ripples(level: float) -> void:
	var lake := terrain.lake_center()
	var spots: Array[Vector2] = [lake, lake + Vector2(0.9, 0.6), lake + Vector2(-1.1, 0.2)]
	for spot in spots:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.22
		torus.outer_radius = 0.30
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.92, 0.97, 0.94, 0.62)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		torus.material = material
		ring.mesh = torus
		ring.position = Vector3(spot.x, level + 0.03, spot.y)
		ring.scale = Vector3.ONE * 0.25
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector3.ONE * 2.6, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "position:y", level + 0.02, 0.9)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_callback(ring.queue_free)


func _save_dam_state() -> bool:
	var placed: Array[String] = []
	var gnawed: Array[String] = []
	var bent: Array[String] = []
	var placed_branches: Array[CollectibleBranch] = []
	for branch in branches:
		if branch.gnawed:
			gnawed.append(branch.stable_id)
		if branch.bent:
			bent.append(branch.stable_id)
		if branch.state == CollectibleBranch.State.PLACED:
			placed_branches.append(branch)
	placed_branches.sort_custom(func(a: CollectibleBranch, b: CollectibleBranch) -> bool:
		if a.placed_slot == b.placed_slot:
			return a.position.x < b.position.x
		return a.placed_slot < b.placed_slot
	)
	for branch in placed_branches:
		placed.append(branch.stable_id)
	var solved: Array[String] = []
	if not gnawed.is_empty():
		solved.append("branch_thick_01")
	if not bent.is_empty():
		solved.append("branch_rotten_01")
	var state := DamSave.empty_state()
	state["placed_materials"] = placed
	state["solved_obstacles"] = solved
	state["gnawed_materials"] = gnawed
	state["bent_materials"] = bent
	state["finish_choice"] = finish_choice
	state["stage_completed"] = placed.size() == DAM_BRANCH_COUNT
	var home_slots: Array[String] = ["", ""]
	for index in range(2):
		var part := home_stage.part_at_slot(index)
		if part != null:
			home_slots[index] = part.stable_id
	state["home_slots"] = home_slots
	state["food_placements"] = food_stage.get_placed_bundle_ids()
	var saved := DamSave.save_state(state, save_directory)
	if not saved:
		push_warning("Failed to save dam progress.")
	else:
		_save_failure_visible = false
	return saved


func _show_save_failure() -> void:
	_save_failure_visible = true
	status.text = SAVE_FAILURE_TEXT


## Stage guidance is temporary feedback: it never replaces the permanent
## objective line or a running celebration.
func _on_stage_status(text: String) -> void:
	_show_feedback(text)


func _on_home_completed() -> void:
	_clear_stage_completion()
	_show_stage_completion("A casa está pronta!")
	food_stage.activate()


func _on_home_part_placed(_count: int) -> void:
	var saved := _save_dam_state()
	if not saved:
		_show_save_failure()
	_refresh_chapter_interface()


func _on_food_activated() -> void:
	_refresh_chapter_interface()


func _on_food_placed(_count: int) -> void:
	var saved := _save_dam_state()
	if not saved:
		_show_save_failure()
	_refresh_chapter_interface()


func _on_food_completed() -> void:
	_clear_stage_completion()
	_show_stage_completion("A comida está guardada!")
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree() and food_stage.is_complete() and not winter_active:
		_show_winter(true)


func _show_winter(show_overlay: bool) -> void:
	winter_active = true
	winter_scene.set_winter(true)
	if home_stage != null:
		home_stage.set_snow(true)
	_set_winter_lighting(true)
	_set_finish_panel_open(false)
	_clear_stage_completion()
	_refresh_chapter_interface()
	winter_new_adventure_button.visible = true
	if ending_save_warning != null:
		ending_save_warning.visible = _save_failure_visible
	if show_overlay and not ending_overlay.visible:
		ending_overlay.visible = true
		voice.play_event("winter_arrived")


## Cool, softer light for the ending. The valley stays readable; this is the
## same geography, not a separate winter scene.
func _set_winter_lighting(active: bool) -> void:
	if sun != null:
		sun.light_energy = 0.72 if active else 0.85
		sun.light_color = Color("dbe8ff") if active else Color.WHITE
	if world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		environment.ambient_light_color = Color("c9dce8") if active else Color("d4e4e0")
		environment.ambient_light_energy = 0.52 if active else 0.45
	if sky_material != null:
		sky_material.sky_top_color = Color("587c92") if active else Color("5f8fa8")
		sky_material.sky_horizon_color = Color("c7d7dc") if active else Color("cfe0cf")


func _continue_visiting() -> void:
	ending_overlay.visible = false
	_refresh_chapter_interface()


func _restore_dam_save() -> void:
	# Restoring is an immediate, silent apply path: invalidate any scene-local
	# presentation callback before showing the saved result.
	_presentation_generation += 1
	var result := DamSave.load_state(save_directory)
	var state: Dictionary = result["state"]
	var by_id: Dictionary = {}
	for branch in branches:
		by_id[branch.stable_id] = branch
		branch.return_to_origin(self)
		branch.gnawed = false
		branch.bent = false
		if branch.kind == CollectibleBranch.Kind.THICK:
			branch._set_color(Color("9b653b"))
		elif branch.kind == CollectibleBranch.Kind.ROTTEN:
			branch._set_color(Color("6f7950"))
	for material_id: String in state["gnawed_materials"]:
		var gnawed_branch: CollectibleBranch = by_id.get(material_id)
		if gnawed_branch != null:
			gnawed_branch.gnaw()
	for material_id: String in state["bent_materials"]:
		var bent_branch: CollectibleBranch = by_id.get(material_id)
		if bent_branch != null:
			bent_branch.bent = true
			bent_branch.rotation.z = deg_to_rad(18.0)
	placed_count = 0
	for material_id: String in state["placed_materials"]:
		var placed_branch: CollectibleBranch = by_id.get(material_id)
		if placed_branch == null:
			continue
		placed_branch.place(self, placement_center, placed_count)
		placed_count += 1
	actor.position = layout.anchor(&"spawn") + Vector3.UP * 0.05
	actor.follow_path(PackedVector3Array())
	carried_branch = null
	pending_branch = null
	placement_pending = false
	_update_water(false)
	finish_choice = state["finish_choice"]
	_update_finish_choices(state["stage_completed"])
	# Restoring is silent: no celebration, no completion narration, no panel.
	_set_finish_panel_open(false)
	_clear_stage_completion()
	if not state["stage_completed"]:
		_refresh_chapter_interface()
		return
	home_stage.activate()
	home_stage.restore_slots(state["home_slots"])
	if not home_stage.is_complete():
		_refresh_chapter_interface()
		return
	food_stage.activate_silent()
	food_stage.restore_placements(state["food_placements"])
	if food_stage.is_complete():
		_show_winter(false)
	else:
		_refresh_chapter_interface()


func _add_ground_ring(at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var cue := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.82
	ring.outer_radius = radius
	ring.material = Shapes.material(color)
	cue.mesh = ring
	cue.position = at + Vector3.UP * 0.035
	cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cue)
	return cue


## Destination cue: a broken outline made of small segments, so shape (not
## colour alone) separates it from the quiet closed pickup rings.
func _add_destination_outline(at: Vector3, radius: float, color: Color) -> Node3D:
	var cue := Node3D.new()
	cue.position = at + Vector3.UP * 0.035
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var segment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(radius * 0.48, 0.035, maxf(radius * 0.10, 0.04))
		mesh.material = Shapes.material(color)
		segment.mesh = mesh
		segment.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		segment.rotation.y = -angle - PI * 0.5
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cue.add_child(segment)
	add_child(cue)
	return cue


func _set_destination_cue_color(cue: Node3D, color: Color) -> void:
	for child in cue.get_children():
		var segment := child as MeshInstance3D
		if segment == null:
			continue
		var mesh := segment.mesh as BoxMesh
		if mesh != null and mesh.material is StandardMaterial3D:
			(mesh.material as StandardMaterial3D).albedo_color = color


func _update_branch_cues() -> void:
	var home_active: bool = home_stage != null and home_stage.is_active
	# Materials stop being collectable the moment the third placement is
	# durable, not only when the home stage activates after the flight. This
	# closes the window where a reserved branch could be picked up during the
	# home stage.
	var branches_done: bool = home_active or placed_count >= DAM_BRANCH_COUNT
	var carrying := _carried_branch_is_suitable()
	for index in range(branches.size()):
		var cue := branch_cues[index]
		var available: bool = branches[index].state == 0 or branches[index].state == 1
		cue.visible = available and not branches_done
		branches[index].visible = not (branches_done and available)
		if available and not branches_done:
			branches[index].hit_area.collision_layer = 4
		elif branches[index].state == 0 or branches[index].state == 1:
			branches[index].hit_area.collision_layer = 0
		if branches[index] == pending_branch:
			cue.scale = Vector3.ONE * 1.18
			(cue.mesh as TorusMesh).material.albedo_color = PICKUP_ACTIVE_CUE_COLOR
		else:
			cue.scale = Vector3.ONE
			(cue.mesh as TorusMesh).material.albedo_color = PICKUP_MUTED_CUE_COLOR if carrying else PICKUP_CUE_COLOR
		if help_highlight_active and branches[index] != carried_branch and branches[index].state == branches[index].State.FREE and _is_suitable_material(branches[index]):
			(cue.mesh as TorusMesh).material.albedo_color = HELP_CUE_COLOR
	var destination_color := DESTINATION_CUE_COLOR
	var destination_scale := Vector3.ONE
	if placement_help_active:
		destination_color = HELP_CUE_COLOR
		destination_scale = Vector3.ONE * 1.18
	elif carrying:
		destination_color = DESTINATION_CARRY_CUE_COLOR
		destination_scale = Vector3.ONE * 1.08
	for destination_cue: Node3D in [placement_cue, dam_target_cue]:
		if destination_cue == null:
			continue
		destination_cue.visible = placed_count < DAM_BRANCH_COUNT
		destination_cue.scale = destination_scale
		_set_destination_cue_color(destination_cue, destination_color)
	if placement_area != null:
		placement_area.collision_layer = 8 if placed_count < DAM_BRANCH_COUNT else 0
	if dam_placement_area != null:
		dam_placement_area.collision_layer = 8 if placed_count < DAM_BRANCH_COUNT else 0
	_update_dam_crest_hit_target()


func _is_suitable_material(branch: CollectibleBranch) -> bool:
	if branch.kind == CollectibleBranch.Kind.ROTTEN:
		return false
	return branch.kind != CollectibleBranch.Kind.THICK or branch.gnawed


func _carried_branch_is_suitable() -> bool:
	return carried_branch != null and _is_suitable_material(carried_branch)


func _collection_comment(branch: CollectibleBranch) -> String:
	if branch.kind == CollectibleBranch.Kind.ROTTEN:
		return "O ramo podre dobra! Vamos escolher outro."
	if branch.kind == CollectibleBranch.Kind.THICK and not branch.gnawed:
		return "Este ramo é grosso. Podes roê-lo ou escolher outro."
	return "O castor leva um ramo. Escolhe outro para o trocar."


func _update_obstacle_controls() -> void:
	gnaw_button.visible = _current_stage() == "dam" and carried_branch != null and carried_branch.kind == CollectibleBranch.Kind.THICK and not carried_branch.gnawed
	gnaw_button.modulate = Color.WHITE


func request_gnaw() -> bool:
	if _current_stage() != "dam":
		return false
	if carried_branch == null or carried_branch.kind != CollectibleBranch.Kind.THICK or carried_branch.gnawed:
		return false
	_begin_world_action()
	actor.play_gnaw_action()
	carried_branch.gnaw()
	sfx.play_event("gnaw")
	var save_ok := _save_dam_state()
	incompatible_place_attempts = 0
	help_highlight_active = false
	gnaw_button.visible = false
	_refresh_chapter_interface()
	_show_feedback("O ramo ficou pronto para a represa!")
	if not save_ok:
		_show_save_failure()
	_update_branch_cues()
	return true


func request_help() -> bool:
	# Explicit help cancels obsolete guidance, including a running celebration.
	if _completion_active:
		_clear_stage_completion()
	support_characters.show_hint()
	if winter_active:
		_show_feedback("O inverno chegou! Podes visitar o vale ou começar uma nova aventura.", 3.0)
		return true
	if home_stage != null and home_stage.is_active and not home_stage.is_complete():
		return home_stage.request_help()
	if food_stage != null and food_stage.is_active and not food_stage.is_complete():
		return food_stage.request_help()
	if placed_count >= DAM_BRANCH_COUNT:
		_show_feedback("Toca na represa para mudar o acabamento.", 3.0)
		return true
	if pending_branch != null and carried_branch == null:
		_show_feedback("O castor vai buscar o ramo. Podes esperar ou escolher outro.", 3.0)
		voice.play_event("help_collect")
		return true
	if carried_branch == null:
		_show_feedback("Escolhe um ramo verde para levar até à represa.", 3.0)
		help_highlight_active = true
		placement_help_active = false
		voice.play_event("help_collect")
		_update_branch_cues()
		return true
	if carried_branch.kind == CollectibleBranch.Kind.THICK and not carried_branch.gnawed:
		if incompatible_place_attempts >= 2:
			_show_feedback("Ajuda: escolhe o ramo marcado a verde.", 3.0)
			help_highlight_active = true
			placement_help_active = false
			voice.play_event("help_compatible")
		else:
			_show_feedback("Este ramo é grosso. Podes roê-lo ou escolher outro.", 3.0)
			gnaw_button.modulate = Color("fff0a3")
			var pulse := create_tween()
			pulse.tween_property(gnaw_button, "scale", Vector2(1.08, 1.08), 0.12).from(Vector2.ONE)
			pulse.tween_property(gnaw_button, "scale", Vector2.ONE, 0.12)
			voice.play_event("thick_branch")
		_update_branch_cues()
		return true
	if carried_branch.kind == CollectibleBranch.Kind.ROTTEN:
		if incompatible_place_attempts >= 2:
			_show_feedback("Ajuda: escolhe o ramo marcado a verde.", 3.0)
			help_highlight_active = true
			voice.play_event("help_compatible")
		else:
			_show_feedback("O ramo podre dobrou! Escolhe outro ramo.", 3.0)
			help_highlight_active = true
			voice.play_event("rotten_branch")
		placement_help_active = false
		_update_branch_cues()
		return true
	_show_feedback("Leva o ramo até à zona amarela da represa.", 3.0)
	help_highlight_active = false
	placement_help_active = true
	voice.play_event("help_place")
	_update_branch_cues()
	return true


func select_finish_choice(choice_id: String) -> bool:
	if placed_count != DAM_BRANCH_COUNT or not finish_choice_buttons.has(choice_id):
		return false
	finish_choice = choice_id
	_apply_finish_choice()
	_update_finish_choices(true)
	var save_ok := _save_dam_state()
	if not save_ok:
		_show_save_failure()
	_close_finish_panel()
	_refresh_chapter_interface()
	return true


func _apply_finish_choice() -> void:
	if visual_environment != null:
		visual_environment.set_dam_state(_presented_dam_count, finish_choice)
	if finish_trim == null:
		return
	finish_trim.visible = not finish_choice.is_empty()
	if finish_choice == "finish_golden":
		(finish_trim.mesh as BoxMesh).material.albedo_color = Color("d6a83e")
	elif finish_choice == "finish_moss":
		(finish_trim.mesh as BoxMesh).material.albedo_color = Color("668b59")


## The finish remains optional and can be changed during later stages. This only
## updates the control states; it never opens or closes the panel by itself.
func _update_finish_choices(is_complete: bool) -> void:
	if finish_panel == null:
		return
	var available := is_complete and _presented_dam_count >= DAM_BRANCH_COUNT
	for choice_id: String in finish_choice_buttons:
		var finish_button: Button = finish_choice_buttons[choice_id]
		finish_button.disabled = not available
		finish_button.button_pressed = choice_id == finish_choice
	if not available:
		_set_finish_panel_open(false)
	_apply_finish_choice()


func _build_celebration_sparkles() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff0a3")
	material.emission_enabled = true
	material.emission = Color("ffcf45")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(5):
		var sparkle := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		sphere.material = material
		sparkle.mesh = sphere
		sparkle.visible = false
		add_child(sparkle)
		celebration_sparkles.append(sparkle)


func _play_celebration() -> void:
	support_characters.celebrate()
	for index in range(celebration_sparkles.size()):
		var sparkle := celebration_sparkles[index]
		sparkle.position = placement_center + Vector3((index - 2) * 0.48, 0.55, 0.0)
		sparkle.scale = Vector3.ONE * 0.05
		sparkle.visible = true
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position:y", sparkle.position.y + 0.55, 0.55)
		tween.tween_property(sparkle, "scale", Vector3.ONE, 0.25)
		tween.tween_property(sparkle, "scale", Vector3.ZERO, 0.3).set_delay(0.55)
		tween.chain().tween_callback(sparkle.hide)


func _confirm_restart() -> void:
	_set_finish_panel_open(false)
	restart_dialog.popup_centered()


func _show_adult_restart() -> void:
	title_touch_active = false
	adult_restart_button.visible = true


func _restart_experiment() -> void:
	if not _clear_progress_for_restart():
		_show_save_failure()
		return
	get_tree().reload_current_scene()


func _clear_progress_for_restart() -> bool:
	return DamSave.clear_save(save_directory)


func _capture_initial() -> void:
	_set_capture_window_size()
	# Fresh isolated save: the baseline view before any branch is placed.
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("user://initial_valley.png")
	if error == OK:
		print("CASTOR_GRAPHICS_OK initial_valley_capture")
	get_tree().quit(0 if error == OK else 1)


## R4 evidence: the same play camera before the dam, after one and two
## placements and with the complete lake. Uses the isolated capture save.
func _capture_water() -> void:
	_set_capture_window_size()
	await get_tree().create_timer(0.4).timeout
	if save_directory != "user://capture_save/":
		push_error("Water capture refused to use a non-isolated save directory.")
		get_tree().quit(1)
		return
	if not DamSave.clear_save(save_directory):
		push_error("Water capture could not clear the isolated capture save.")
		get_tree().quit(1)
		return
	placed_count = 0
	_update_water(false)
	_refresh_chapter_interface()
	await get_tree().create_timer(0.2).timeout
	var ok: bool = await _save_camera_capture("water_initial.png")
	var thick: CollectibleBranch = branches[0]
	var first_normal: CollectibleBranch = branches[2]
	var second_normal: CollectibleBranch = branches[3]
	thick.gnaw()
	var sequence: Array[CollectibleBranch] = [thick, first_normal, second_normal]
	var names: Array[String] = ["water_one.png", "water_two.png", "water_complete.png"]
	for index in range(sequence.size()):
		var branch := sequence[index]
		if branch.state != CollectibleBranch.State.FREE:
			push_error("Water capture found a branch that was not free: %s." % branch.stable_id)
			ok = false
			break
		branch.place(self, placement_center, placed_count)
		placed_count += 1
		_update_water(true)
		_refresh_chapter_interface()
		await get_tree().create_timer(1.0).timeout
		var saved: bool = await _save_camera_capture(names[index])
		ok = saved and ok
	if placed_count == DAM_BRANCH_COUNT:
		home_stage.activate()
		_refresh_chapter_interface()
		_set_finish_panel_open(false)
		ok = _save_dam_state() and ok
	if ok:
		print("CASTOR_GRAPHICS_OK water_capture")
	get_tree().quit(0 if ok else 1)


## P1 evidence: the same completed-dam view with the optional finish panel open
## and after closing it. Uses the isolated capture save and never the player save.
func _capture_finish() -> void:
	_set_capture_window_size()
	await get_tree().create_timer(0.4).timeout
	if save_directory != "user://capture_save/":
		push_error("Finish capture refused to use a non-isolated save directory.")
		get_tree().quit(1)
		return
	if not _prepare_capture_completed_dam():
		get_tree().quit(1)
		return
	home_stage.activate()
	_refresh_chapter_interface()
	_set_finish_panel_open(true)
	await get_tree().process_frame
	var open_ok: bool = await _save_camera_capture("finish_panel_open.png")
	_set_finish_panel_open(false)
	await get_tree().process_frame
	var closed_ok: bool = await _save_camera_capture("finish_panel_closed.png")
	if open_ok and closed_ok:
		print("CASTOR_GRAPHICS_OK finish_capture")
	get_tree().quit(0 if open_ok and closed_ok else 1)


## P2 evidence: the first placement while the branch is still in flight, the
## same placement after its response, and the completed dam after the final
## celebration. All from the play camera on the isolated capture save.
func _capture_placement() -> void:
	_set_capture_window_size()
	await get_tree().create_timer(0.4).timeout
	if save_directory != "user://capture_save/":
		push_error("Placement capture refused to use a non-isolated save directory.")
		get_tree().quit(1)
		return
	var normal_branches: Array[CollectibleBranch] = []
	for branch in branches:
		if branch.stable_id in ["branch_normal_01", "branch_normal_02", "branch_normal_03"]:
			normal_branches.append(branch)
	if normal_branches.size() != 3:
		push_error("Placement capture could not find three normal branches for a complete dam.")
		get_tree().quit(1)
		return
	var ok := true
	var first := normal_branches[0]
	request_collect(first)
	await _wait_for_capture(func() -> bool: return carried_branch == first)
	request_place()
	await _wait_for_capture(func() -> bool: return placed_count == 1)
	# The 0.45 s flight starts at the commit; capture it part-way through.
	await get_tree().create_timer(0.16).timeout
	ok = await _save_camera_capture("placement_first_flight.png") and ok
	await _wait_for_capture(func() -> bool: return visual_environment.get_visible_dam_log_count() == 1)
	await get_tree().create_timer(0.75).timeout
	ok = await _save_camera_capture("placement_first_done.png") and ok
	for index in range(1, 3):
		var expected: int = index + 1
		var branch := normal_branches[index]
		request_collect(branch)
		await _wait_for_capture(func() -> bool: return carried_branch == branch)
		request_place()
		await _wait_for_capture(func() -> bool: return placed_count == expected)
		await _wait_for_capture(func() -> bool: return visual_environment.get_visible_dam_log_count() == expected)
	# The final response celebrates for 2.0 s; capture after it, with the
	# optional panel closed so the completed structure stays readable.
	await get_tree().create_timer(2.2).timeout
	_set_finish_panel_open(false)
	await get_tree().process_frame
	ok = await _save_camera_capture("placement_final_done.png") and ok
	if ok:
		print("CASTOR_GRAPHICS_OK placement_capture")
	get_tree().quit(0 if ok else 1)


func _save_camera_capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("user://" + file_name)
	if error != OK:
		push_error("Could not save capture %s: %s" % [file_name, error_string(error)])
	return error == OK


func _set_capture_window_size() -> void:
	# Captures are compared at the 960 × 600 reference view even if the window
	# manager remembered a different size.
	DisplayServer.window_set_size(Vector2i(960, 600))


func _capture() -> void:
	_set_capture_window_size()
	await get_tree().create_timer(0.5).timeout
	var initial_position := actor.position
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(Vector3(4, 0, 0))
	Input.parse_input_event(click)
	await get_tree().create_timer(0.8).timeout
	if not destination.visible or actor.position.distance_to(initial_position) < 0.5:
		push_error("Click did not start movement in the graphical run.")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("user://movement.png")
	if error == OK:
		print("CASTOR_GRAPHICS_OK mouse_movement_capture")
	get_tree().quit(0 if error == OK else 1)


func _capture_home() -> void:
	_set_capture_window_size()
	await get_tree().create_timer(0.4).timeout
	if not _prepare_capture_completed_dam():
		get_tree().quit(1)
		return
	home_stage.activate()
	_refresh_chapter_interface()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var initial_error := get_viewport().get_texture().get_image().save_png("user://home.png")
	await _capture_build_home()
	await RenderingServer.frame_post_draw
	var completed_error := get_viewport().get_texture().get_image().save_png("user://home_complete.png")
	var success := initial_error == OK and completed_error == OK
	if success:
		print("CASTOR_GRAPHICS_OK home_capture")
	get_tree().quit(0 if success else 1)


func _capture_build_home() -> void:
	var first_part := home_stage.parts[0]
	home_stage.request_collect(first_part)
	await _wait_for_capture(func() -> bool: return home_stage.carried_part == first_part)
	home_stage.request_place(0)
	await _wait_for_capture(func() -> bool: return home_stage.placed_slot_count >= 1)
	var second_part := home_stage.parts[1]
	home_stage.request_collect(second_part)
	await _wait_for_capture(func() -> bool: return home_stage.carried_part == second_part)
	home_stage.request_place(1)
	await _wait_for_capture(func() -> bool: return home_stage.placed_slot_count == 2)


func _capture_food() -> void:
	_set_capture_window_size()
	await get_tree().create_timer(0.4).timeout
	if not _prepare_capture_completed_dam():
		get_tree().quit(1)
		return
	home_stage.activate()
	_update_branch_cues()
	await _capture_build_home()
	_refresh_chapter_interface()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var initial_error := get_viewport().get_texture().get_image().save_png("user://food.png")
	for _index in range(FoodStage.REQUIRED_COUNT):
		var bundle := _capture_first_suitable_food_bundle()
		if bundle == null:
			break
		food_stage.request_collect(bundle)
		await _wait_for_capture(func() -> bool: return food_stage.carried_bundle == bundle)
		food_stage.request_place()
		var expected_count: int = food_stage.placed_count + 1
		await _wait_for_capture(func() -> bool: return food_stage.placed_count == expected_count)
	await RenderingServer.frame_post_draw
	var completed_error := get_viewport().get_texture().get_image().save_png("user://food_complete.png")
	var success := initial_error == OK and completed_error == OK and food_stage.is_complete()
	if success:
		print("CASTOR_GRAPHICS_OK food_capture")
	get_tree().quit(0 if success else 1)


func _capture_ending() -> void:
	_set_capture_window_size()
	await get_tree().create_timer(0.4).timeout
	if not _prepare_capture_completed_dam():
		get_tree().quit(1)
		return
	home_stage.activate()
	_update_branch_cues()
	await _capture_build_home()
	_update_branch_cues()
	for _index in range(FoodStage.REQUIRED_COUNT):
		var bundle := _capture_first_suitable_food_bundle()
		if bundle == null:
			break
		food_stage.request_collect(bundle)
		await _wait_for_capture(func() -> bool: return food_stage.carried_bundle == bundle)
		food_stage.request_place()
		var expected_count: int = food_stage.placed_count + 1
		await _wait_for_capture(func() -> bool: return food_stage.placed_count == expected_count)
	await _wait_for_capture(func() -> bool: return ending_overlay.visible)
	await RenderingServer.frame_post_draw
	var overlay_error := get_viewport().get_texture().get_image().save_png("user://ending.png")
	_continue_visiting()
	await RenderingServer.frame_post_draw
	var valley_error := get_viewport().get_texture().get_image().save_png("user://ending_valley.png")
	var success := overlay_error == OK and valley_error == OK and winter_active
	if success:
		print("CASTOR_GRAPHICS_OK ending_capture")
	get_tree().quit(0 if success else 1)


func _capture_first_suitable_food_bundle() -> FoodBundle:
	for bundle in food_stage.bundles:
		if bundle.state <= FoodBundle.State.RESERVED and food_stage.is_bundle_suitable(bundle):
			return bundle
	return null


func _prepare_capture_completed_dam() -> bool:
	# Captures use the same durable dam state as gameplay, while _ready has
	# already redirected persistence to the isolated user://capture_save/ folder.
	if save_directory != "user://capture_save/":
		push_error("Capture setup refused to use a non-isolated save directory.")
		return false
	var thick_branch: CollectibleBranch
	var rotten_branch: CollectibleBranch
	var normal_branches: Array[CollectibleBranch] = []
	for branch in branches:
		match branch.stable_id:
			"branch_thick_01":
				thick_branch = branch
			"branch_rotten_01":
				rotten_branch = branch
			"branch_normal_01", "branch_normal_02":
				normal_branches.append(branch)
	if thick_branch == null or rotten_branch == null or normal_branches.size() != 2:
		push_error("Capture setup could not find the branches required for a complete dam.")
		return false
	if not DamSave.clear_save(save_directory):
		push_error("Capture setup could not clear the isolated capture save.")
		return false
	thick_branch.gnaw()
	rotten_branch.bend()
	var placed_branches: Array[CollectibleBranch] = [thick_branch]
	placed_branches.append_array(normal_branches)
	placed_count = 0
	for branch in placed_branches:
		if branch.state != CollectibleBranch.State.FREE:
			push_error("Capture setup found a branch that was not available for dam placement: %s." % branch.stable_id)
			return false
		branch.place(self, placement_center, placed_count)
		placed_count += 1
	finish_choice = "finish_golden"
	_update_water(false)
	_refresh_chapter_interface()
	_set_finish_panel_open(false)
	if placed_count != DAM_BRANCH_COUNT or not _save_dam_state():
		push_error("Capture setup could not save a valid completed dam in the isolated capture save.")
		return false
	return true


func _wait_for_capture(condition: Callable) -> void:
	for _frame in range(360):
		if condition.call():
			return
		await get_tree().process_frame
