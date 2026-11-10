extends Node3D
## Playable valley chapter on the accepted authored terrain. Visible ground,
## collision, placement heights and routes all derive from ValleyTerrain.

const Shapes = preload("res://scripts/prototype_shapes.gd")
const Actor = preload("res://scripts/prototype_actor.gd")
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
const BRANCH_IDS: Array[String] = ["branch_thick_01", "branch_rotten_01", "branch_normal_01", "branch_normal_02", "branch_normal_03"]
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
var branch_cues: Array[MeshInstance3D] = []
var placement_cue: MeshInstance3D
var dam_target_cue: MeshInstance3D
var finish_trim: MeshInstance3D
var completion_feedback: Label
var message_band: ColorRect
var home_completion_feedback: Label
var home_invite: Label
var home_stage: HomeStage
var food_stage: FoodStage
var winter_scene: WinterScene
var winter_active: bool = false
var food_progress: Label
var food_completion_feedback: Label
var ending_overlay: ColorRect
var ending_title: Label
var ending_message: Label
var continue_button: Button
var ending_new_adventure_button: Button
var winter_new_adventure_button: Button
var finish_prompt: Label
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
	var capture_mode := "--capture-initial" in OS.get_cmdline_user_args() or "--capture-home" in OS.get_cmdline_user_args() or "--capture-food" in OS.get_cmdline_user_args() or "--capture-ending" in OS.get_cmdline_user_args() or "--capture-water" in OS.get_cmdline_user_args()
	if "--fresh-save" in OS.get_cmdline_user_args():
		# Interactive playtest from the beginning, isolated from the normal save.
		save_directory = "user://playtest_save/"
		DamSave.clear_save(save_directory)
	if capture_mode:
		# Debug captures must never alter the player's chapter save.
		save_directory = "user://capture_save/"
		DamSave.clear_save(save_directory)
	voice.play_event("dam_start")
	_restore_dam_save()
	_update_branch_cues()
	if "--capture-ending" in OS.get_cmdline_user_args():
		_capture_ending()
	elif "--capture-food" in OS.get_cmdline_user_args():
		_capture_food()
	elif "--capture-home" in OS.get_cmdline_user_args():
		_capture_home()
	elif "--capture-water" in OS.get_cmdline_user_args():
		_capture_water()
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
	status.text = "Clica no chão para andar."
	status.position = Vector2(24, 54)
	status.add_theme_font_size_override("font_size", 17)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	var progress := Label.new()
	progress.name = "DamProgress"
	progress.position = Vector2(24, 88)
	progress.add_theme_font_size_override("font_size", 28)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(progress)
	food_progress = Label.new()
	food_progress.name = "FoodProgress"
	food_progress.position = Vector2(24, 88)
	food_progress.add_theme_font_size_override("font_size", 28)
	food_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_progress.visible = false
	layer.add_child(food_progress)
	message_band = ColorRect.new()
	message_band.name = "MessageBand"
	message_band.position = Vector2(0, 460)
	message_band.size = Vector2(960, 140)
	message_band.color = Color(0.035, 0.065, 0.075, 0.38)
	message_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_band.visible = false
	layer.add_child(message_band)
	completion_feedback = Label.new()
	completion_feedback.name = "CompletionFeedback"
	completion_feedback.text = "Fizeste uma represa!"
	completion_feedback.position = Vector2(0, 515)
	completion_feedback.size = Vector2(960, 80)
	completion_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_feedback.add_theme_font_size_override("font_size", 42)
	completion_feedback.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	completion_feedback.add_theme_constant_override("outline_size", 6)
	completion_feedback.add_theme_color_override("font_color", Color("fff0a3"))
	completion_feedback.visible = false
	completion_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(completion_feedback)
	home_invite = Label.new()
	home_invite.name = "HomeInvite"
	home_invite.text = "Agora vamos construir a casa!"
	home_invite.position = Vector2(0, 420)
	home_invite.size = Vector2(960, 40)
	home_invite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_invite.add_theme_font_size_override("font_size", 24)
	home_invite.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	home_invite.add_theme_constant_override("outline_size", 4)
	home_invite.visible = false
	home_invite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(home_invite)
	home_completion_feedback = Label.new()
	home_completion_feedback.name = "HomeCompletionFeedback"
	home_completion_feedback.text = "A casa está pronta!"
	home_completion_feedback.position = Vector2(0, 515)
	home_completion_feedback.size = Vector2(960, 70)
	home_completion_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_completion_feedback.add_theme_font_size_override("font_size", 38)
	home_completion_feedback.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	home_completion_feedback.add_theme_constant_override("outline_size", 6)
	home_completion_feedback.add_theme_color_override("font_color", Color("fff0a3"))
	home_completion_feedback.visible = false
	home_completion_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(home_completion_feedback)
	food_completion_feedback = Label.new()
	food_completion_feedback.name = "FoodCompletionFeedback"
	food_completion_feedback.text = "A comida está guardada!"
	food_completion_feedback.position = Vector2(0, 515)
	food_completion_feedback.size = Vector2(960, 70)
	food_completion_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	food_completion_feedback.add_theme_font_size_override("font_size", 38)
	food_completion_feedback.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	food_completion_feedback.add_theme_constant_override("outline_size", 6)
	food_completion_feedback.add_theme_color_override("font_color", Color("fff0a3"))
	food_completion_feedback.visible = false
	food_completion_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(food_completion_feedback)
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
	finish_prompt = Label.new()
	finish_prompt.name = "FinishPrompt"
	finish_prompt.text = "Escolhe o acabamento da represa:"
	finish_prompt.position = Vector2(24, 270)
	finish_prompt.visible = false
	layer.add_child(finish_prompt)
	for option in [["finish_golden", "Dourado", Color("d6a83e")], ["finish_moss", "Verde", Color("668b59")]]:
		var finish_button := Button.new()
		finish_button.text = option[1]
		finish_button.toggle_mode = true
		finish_button.position = Vector2(24 + finish_choice_buttons.size() * 126, 298)
		finish_button.custom_minimum_size = Vector2(116, 44)
		finish_button.visible = false
		var choice_id: String = option[0]
		finish_button.pressed.connect(func() -> void: select_finish_choice(choice_id))
		layer.add_child(finish_button)
		finish_choice_buttons[choice_id] = finish_button
	winter_new_adventure_button = Button.new()
	winter_new_adventure_button.name = "WinterNewAdventure"
	winter_new_adventure_button.text = "Nova aventura"
	winter_new_adventure_button.position = Vector2(700, 72)
	winter_new_adventure_button.custom_minimum_size = Vector2(220, 36)
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
	_update_progress_cue()


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
	if click_pending:
		click_pending = false
		_move_from_screen(click_position)
	if pending_branch != null and actor.is_arrived():
		if carried_branch != null and carried_branch != pending_branch:
			carried_branch.return_to_origin(self)
			carried_branch = null
		carried_branch = pending_branch
		var was_bent := carried_branch.bent
		carried_branch.carry(actor)
		var newly_bent := not was_bent and carried_branch.bent and carried_branch.kind == CollectibleBranch.Kind.ROTTEN
		var carry_save_ok := true
		if newly_bent:
			carry_save_ok = _save_dam_state()
		pending_branch = null
		sfx.play_event("collect")
		incompatible_place_attempts = 0
		help_highlight_active = false
		status.text = _collection_comment(carried_branch)
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
			actor.play_place_action()
			carried_branch.place(self, placement_center, placed_count, true)
			carried_branch = null
			_update_obstacle_controls()
			placed_count += 1
			sfx.play_event("complete" if placed_count == DAM_BRANCH_COUNT else "place")
			var placement_save_ok := _save_dam_state()
			incompatible_place_attempts = 0
			help_highlight_active = false
			_update_water()
			if placed_count == 1:
				voice.play_event("first_placement")
			status.text = "Boa! A água está a mudar. Escolhe mais um ramo."
			_update_branch_cues()
			_update_progress_cue()
			if placed_count == DAM_BRANCH_COUNT:
				voice.play_event("dam_completed")
				status.text = "A represa está completa!"
				completion_feedback.visible = true
				home_invite.visible = true
				_update_finish_choices(true)
				_cancel_pending_collection()
				var pulse := create_tween()
				pulse.tween_property(completion_feedback, "scale", Vector2(1.08, 1.08), 0.22).from(Vector2.ONE)
				pulse.tween_property(completion_feedback, "scale", Vector2.ONE, 0.22)
				_play_celebration()
				home_stage.activate()
				_update_branch_cues()
			if not placement_save_ok:
				_show_save_failure()


func _process(delta: float) -> void:
	if camera_follow_enabled and actor != null and camera != null:
		_update_follow_camera(delta)
	if message_band != null and completion_feedback != null:
		message_band.visible = completion_feedback.visible or home_completion_feedback.visible or food_completion_feedback.visible


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
			_cancel_pending_collection()
			placement_pending = false
			if food_stage != null:
				food_stage.cancel_pending()
			return home_stage.request_place(slot_index)
	var food_target_query := PhysicsRayQueryParameters3D.create(origin, end, FoodStage.TARGET_LAYER)
	food_target_query.collide_with_areas = true
	if not get_world_3d().direct_space_state.intersect_ray(food_target_query).is_empty():
		_cancel_pending_collection()
		placement_pending = false
		if home_stage != null:
			home_stage.cancel_pending()
		return food_stage.request_place()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not navigation.is_walkable(Vector2(hit.position.x, hit.position.z)):
		status.text = "Escolhe um sítio livre no chão."
		return false
	return request_move(hit.position)


func request_collect(branch: CollectibleBranch) -> bool:
	if not branches.has(branch):
		return false
	if home_stage != null and home_stage.is_active:
		status.text = "A represa está pronta. Vamos construir a casa!"
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
			status.text = "O castor continua a levar o mesmo ramo."
			return true
		status.text = "O ramo já está com o castor."
		return true
	if branch == pending_branch:
		return true
	if pending_branch != null and pending_branch != carried_branch:
		pending_branch.cancel_reservation()
		pending_branch = null
	var path := navigation.find_approach(actor.global_position, Vector2(branch.position.x, branch.position.z), 3)
	if path.is_empty():
		status.text = "Esse ramo está longe demais para chegar."
		return false
	actor.follow_path(path)
	voice.cancel()
	branch.reserve()
	pending_branch = branch
	destination.position = path[path.size() - 1] + Vector3.UP * 0.04
	destination.visible = true
	status.text = "O castor vai buscar o ramo."
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
		status.text = "Escolhe um sítio livre no chão."
		return false
	var path := navigation.find_path(actor.global_position, world_position)
	if path.is_empty():
		return false
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
	status.text = "O círculo amarelo mostra o destino. Podes escolher outro."
	return true


func _build_placement_target() -> void:
	var bank_spot: Vector3 = layout.anchor(&"dam_approach")
	placement_cue = _add_ground_ring(bank_spot, 0.9, Color("ffe17d"))
	dam_target_cue = MeshInstance3D.new()
	dam_target_cue.name = "DamTargetCue"
	var dam_ring := TorusMesh.new()
	dam_ring.inner_radius = 0.34
	dam_ring.outer_radius = 0.48
	dam_ring.material = Shapes.material(Color("ffe17d"))
	dam_target_cue.mesh = dam_ring
	dam_target_cue.position = placement_center + Vector3(0.0, 0.30, 0.0)
	dam_target_cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dam_target_cue)
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


func request_place() -> bool:
	if placement_pending:
		return true
	if placed_count >= DAM_BRANCH_COUNT:
		status.text = "A represa está completa!"
		return false
	if home_stage != null:
		home_stage.cancel_pending()
	if food_stage != null:
		food_stage.cancel_pending()
	if carried_branch == null:
		status.text = "Toca no ramo e depois na zona amarela."
		voice.play_event("help_collect")
		return false
	if not _carried_branch_is_suitable():
		incompatible_place_attempts += 1
		if carried_branch.kind == CollectibleBranch.Kind.THICK:
			status.text = "Este ramo é grosso. Roê-o primeiro ou escolhe outro."
		else:
			status.text = "Este ramo está podre e dobra. Escolhe outro ramo."
		if incompatible_place_attempts >= 2:
			status.text = "Ajuda: escolhe o ramo marcado a verde."
			help_highlight_active = true
			support_characters.show_hint()
			voice.play_event("help_compatible")
			_update_branch_cues()
		return false
	var bank_spot: Vector3 = layout.anchor(&"dam_approach")
	var path := navigation.find_path(actor.global_position, bank_spot)
	if path.is_empty():
		status.text = "A zona da represa está fora do caminho."
		return false
	# Keep an in-progress pickup intact unless placement has a valid route.
	_cancel_pending_collection()
	voice.cancel()
	actor.follow_path(path)
	placement_pending = true
	incompatible_place_attempts = 0
	help_highlight_active = false
	placement_help_active = false
	destination.position = bank_spot + Vector3.UP * 0.04
	destination.visible = true
	status.text = "O castor vai colocar o ramo."
	_update_branch_cues()
	return true


func _update_water(animate: bool = true) -> void:
	if water_surface == null or terrain == null or layout == null:
		return
	var levels: Array[float] = [terrain.initial_water_level(), terrain.intermediate_water_level(), terrain.full_water_level(), terrain.full_water_level()]
	var target: float = levels[mini(placed_count, 3)]
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
		visual_environment.set_dam_state(placed_count, finish_choice)
		visual_environment.set_water_level(target)
	if food_stage != null:
		food_stage.set_water_level(target)


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
	status.text = "Não foi possível guardar o progresso. Pede ajuda a um adulto."


func _set_status(text: String) -> void:
	if _save_failure_visible:
		return
	status.text = text


func _on_stage_status(text: String) -> void:
	_set_status(text)


func _on_home_completed() -> void:
	completion_feedback.visible = false
	home_invite.visible = false
	home_completion_feedback.position = Vector2(0, 515)
	home_completion_feedback.visible = true
	var pulse := create_tween()
	pulse.tween_property(home_completion_feedback, "scale", Vector2(1.08, 1.08), 0.22).from(Vector2.ONE)
	pulse.tween_property(home_completion_feedback, "scale", Vector2.ONE, 0.22)
	food_stage.activate()


func _on_home_part_placed(_count: int) -> void:
	if not _save_dam_state():
		_show_save_failure()


func _on_food_activated() -> void:
	get_node("CanvasLayer/DamProgress").visible = false
	food_progress.visible = true
	_update_food_progress()
	home_invite.text = "Agora vamos guardar comida para o inverno!"
	home_invite.visible = true


func _on_food_placed(_count: int) -> void:
	_update_food_progress()
	if not _save_dam_state():
		_show_save_failure()


func _update_food_progress() -> void:
	if food_progress == null or food_stage == null:
		return
	var symbols := "●".repeat(food_stage.placed_count) + "○".repeat(FoodStage.REQUIRED_COUNT - food_stage.placed_count)
	food_progress.text = "Comida guardada: " + symbols


func _on_food_completed() -> void:
	home_completion_feedback.visible = false
	home_invite.visible = false
	food_completion_feedback.position = Vector2(0, 515)
	food_completion_feedback.visible = true
	var pulse := create_tween()
	pulse.tween_property(food_completion_feedback, "scale", Vector2(1.08, 1.08), 0.22).from(Vector2.ONE)
	pulse.tween_property(food_completion_feedback, "scale", Vector2.ONE, 0.22)
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree() and food_stage.is_complete() and not winter_active:
		_show_winter(true)


func _show_winter(show_overlay: bool) -> void:
	winter_active = true
	winter_scene.set_winter(true)
	if home_stage != null:
		home_stage.set_snow(true)
	_set_winter_lighting(true)
	completion_feedback.visible = false
	home_completion_feedback.visible = false
	food_completion_feedback.visible = false
	home_invite.visible = false
	get_node("CanvasLayer/DamProgress").visible = false
	food_progress.visible = true
	_update_food_progress()
	_update_finish_choices(false)
	winter_new_adventure_button.visible = true
	_set_status("O inverno chegou! A família do castor está reunida.")
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
	_set_status("Podes visitar o vale. A família está em casa.")


func _restore_dam_save() -> void:
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
	_update_progress_cue()
	finish_choice = state["finish_choice"]
	_update_finish_choices(state["stage_completed"])
	completion_feedback.visible = false
	home_completion_feedback.visible = false
	food_completion_feedback.visible = false
	if not state["stage_completed"]:
		home_invite.visible = false
		food_progress.visible = false
		get_node("CanvasLayer/DamProgress").visible = true
		status.text = "Clica no chão para andar."
		return
	for sparkle in celebration_sparkles:
		sparkle.visible = true
	home_stage.activate()
	home_stage.restore_slots(state["home_slots"])
	_update_branch_cues()
	if not home_stage.is_complete():
		completion_feedback.visible = true
		home_invite.text = "Agora vamos construir a casa!"
		home_invite.visible = true
		food_progress.visible = false
		get_node("CanvasLayer/DamProgress").visible = true
		status.text = "Agora vamos construir a casa! Escolhe uma peça."
		voice.play_event("home_invite")
		return
	completion_feedback.visible = false
	home_invite.visible = false
	get_node("CanvasLayer/DamProgress").visible = false
	food_stage.activate_silent()
	food_stage.restore_placements(state["food_placements"])
	food_progress.visible = true
	_update_food_progress()
	if food_stage.is_complete():
		_show_winter(false)
	else:
		home_invite.text = "Agora vamos guardar comida para o inverno!"
		home_invite.visible = true
		status.text = "Agora vamos guardar comida para o inverno! Escolhe um feixe."
		voice.play_event("food_invite")


func _add_ground_ring(at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var cue := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.72
	ring.outer_radius = radius
	ring.material = Shapes.material(color)
	cue.mesh = ring
	cue.position = at + Vector3.UP * 0.035
	add_child(cue)
	return cue


func _update_branch_cues() -> void:
	var home_active: bool = home_stage != null and home_stage.is_active
	for index in range(branches.size()):
		var cue := branch_cues[index]
		var available: bool = branches[index].state == 0 or branches[index].state == 1
		cue.visible = available and not home_active
		branches[index].visible = not (home_active and available)
		if available and not home_active:
			branches[index].hit_area.collision_layer = 4
		elif branches[index].state == 0 or branches[index].state == 1:
			branches[index].hit_area.collision_layer = 0
		if branches[index] == pending_branch:
			cue.scale = Vector3.ONE * 1.22
			(cue.mesh as TorusMesh).material.albedo_color = Color("ffca45")
		else:
			cue.scale = Vector3.ONE
			(cue.mesh as TorusMesh).material.albedo_color = Color("fff0a3")
		if help_highlight_active and branches[index] != carried_branch and branches[index].state == branches[index].State.FREE and _is_suitable_material(branches[index]):
			(cue.mesh as TorusMesh).material.albedo_color = Color("70e6a1")
	if placement_cue != null:
		placement_cue.visible = placed_count < DAM_BRANCH_COUNT
		(placement_cue.mesh as TorusMesh).material.albedo_color = Color("70e6a1") if placement_help_active else Color("ffe17d")
	if dam_target_cue != null:
		dam_target_cue.visible = placed_count < DAM_BRANCH_COUNT
		(dam_target_cue.mesh as TorusMesh).material.albedo_color = Color("70e6a1") if placement_help_active else Color("ffe17d")
	if placement_area != null:
		placement_area.collision_layer = 8 if placed_count < DAM_BRANCH_COUNT else 0


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
	gnaw_button.visible = carried_branch != null and carried_branch.kind == CollectibleBranch.Kind.THICK and not carried_branch.gnawed
	gnaw_button.modulate = Color.WHITE


func request_gnaw() -> bool:
	if carried_branch == null or carried_branch.kind != CollectibleBranch.Kind.THICK or carried_branch.gnawed:
		return false
	actor.play_gnaw_action()
	carried_branch.gnaw()
	sfx.play_event("gnaw")
	var save_ok := _save_dam_state()
	incompatible_place_attempts = 0
	help_highlight_active = false
	gnaw_button.visible = false
	status.text = "O ramo ficou pronto para a represa!"
	if not save_ok:
		_show_save_failure()
	_update_branch_cues()
	return true


func request_help() -> bool:
	support_characters.show_hint()
	if winter_active:
		status.text = "O inverno chegou! Podes visitar o vale ou começar uma nova aventura."
		return true
	if home_stage != null and home_stage.is_active and not home_stage.is_complete():
		return home_stage.request_help()
	if food_stage != null and food_stage.is_active and not food_stage.is_complete():
		return food_stage.request_help()
	if placed_count >= DAM_BRANCH_COUNT:
		status.text = "Podes mudar o acabamento da represa nos botões abaixo."
		return true
	if pending_branch != null and carried_branch == null:
		status.text = "O castor vai buscar o ramo. Podes esperar ou escolher outro."
		voice.play_event("help_collect")
		return true
	if carried_branch == null:
		status.text = "Escolhe um ramo verde para levar até à represa."
		help_highlight_active = true
		placement_help_active = false
		voice.play_event("help_collect")
		_update_branch_cues()
		return true
	if carried_branch.kind == CollectibleBranch.Kind.THICK and not carried_branch.gnawed:
		if incompatible_place_attempts >= 2:
			status.text = "Ajuda: escolhe o ramo marcado a verde."
			help_highlight_active = true
			placement_help_active = false
			voice.play_event("help_compatible")
		else:
			status.text = "Este ramo é grosso. Podes roê-lo ou escolher outro."
			gnaw_button.modulate = Color("fff0a3")
			var pulse := create_tween()
			pulse.tween_property(gnaw_button, "scale", Vector2(1.08, 1.08), 0.12).from(Vector2.ONE)
			pulse.tween_property(gnaw_button, "scale", Vector2.ONE, 0.12)
			voice.play_event("thick_branch")
		_update_branch_cues()
		return true
	if carried_branch.kind == CollectibleBranch.Kind.ROTTEN:
		if incompatible_place_attempts >= 2:
			status.text = "Ajuda: escolhe o ramo marcado a verde."
			help_highlight_active = true
			voice.play_event("help_compatible")
		else:
			status.text = "O ramo podre dobrou! Escolhe outro ramo."
			help_highlight_active = true
			voice.play_event("rotten_branch")
		placement_help_active = false
		_update_branch_cues()
		return true
	status.text = "Leva o ramo até à zona amarela da represa."
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
	return true


func _apply_finish_choice() -> void:
	if visual_environment != null:
		visual_environment.set_dam_state(placed_count, finish_choice)
	if finish_trim == null:
		return
	finish_trim.visible = not finish_choice.is_empty()
	if finish_choice == "finish_golden":
		(finish_trim.mesh as BoxMesh).material.albedo_color = Color("d6a83e")
	elif finish_choice == "finish_moss":
		(finish_trim.mesh as BoxMesh).material.albedo_color = Color("668b59")


func _update_finish_choices(is_complete: bool) -> void:
	if finish_prompt == null:
		return
	finish_prompt.visible = is_complete
	for choice_id: String in finish_choice_buttons:
		var finish_button: Button = finish_choice_buttons[choice_id]
		finish_button.visible = is_complete
		finish_button.button_pressed = choice_id == finish_choice
	_apply_finish_choice()


func _update_progress_cue() -> void:
	var progress: Label = get_node("CanvasLayer/DamProgress")
	var symbols := "●".repeat(placed_count) + "○".repeat(DAM_BRANCH_COUNT - placed_count)
	progress.text = "Ramos na represa: " + symbols


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
	_update_progress_cue()
	_update_branch_cues()
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
		_update_progress_cue()
		_update_branch_cues()
		await get_tree().create_timer(1.0).timeout
		var saved: bool = await _save_camera_capture(names[index])
		ok = saved and ok
	if placed_count == DAM_BRANCH_COUNT:
		home_stage.activate()
		_update_finish_choices(true)
		ok = _save_dam_state() and ok
	if ok:
		print("CASTOR_GRAPHICS_OK water_capture")
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
	_update_branch_cues()
	home_invite.visible = true
	home_invite.text = "Agora vamos construir a casa!"
	status.text = "Agora vamos construir a casa! Escolhe uma peça."
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
	_update_branch_cues()
	home_invite.text = "Agora vamos guardar comida para o inverno!"
	home_invite.visible = true
	status.text = "Agora vamos guardar comida para o inverno! Escolhe um feixe."
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
	_update_progress_cue()
	_update_branch_cues()
	_update_finish_choices(false)
	if placed_count != DAM_BRANCH_COUNT or not _save_dam_state():
		push_error("Capture setup could not save a valid completed dam in the isolated capture save.")
		return false
	return true


func _wait_for_capture(condition: Callable) -> void:
	for _frame in range(360):
		if condition.call():
			return
		await get_tree().process_frame
