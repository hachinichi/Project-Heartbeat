extends HBEditorModule

signal show_transform(transformation)
signal hide_transform()
signal apply_transform(transformation)

onready var arrange_menu := get_node("ArrangeMenu")
onready var arrange_angle_spinbox := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/HBEditorSpinBox")
onready var reverse_arrange_checkbox := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer2/CheckBox")
onready var circle_size_slider := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer2/HSlider")
onready var circle_size_spinbox := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer2/HBoxContainer/HBEditorSpinBox")
onready var circle_cw_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer3/VBoxContainer/HBoxContainer/VBoxContainer/Button")
onready var circle_ccw_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer3/VBoxContainer/HBoxContainer/VBoxContainer2/Button")
onready var circle_cw_inside_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer3/VBoxContainer2/HBoxContainer/VBoxContainer/Button")
onready var circle_ccw_inside_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer3/VBoxContainer2/HBoxContainer/VBoxContainer2/Button")
onready var mirror_vertically_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer4/VBoxContainer/Button")
onready var mirror_horizontally_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer4/VBoxContainer2/Button")
onready var flip_vertically_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer4/VBoxContainer3/Button")
onready var flip_horizontally_button := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer4/VBoxContainer4/Button")
onready var rotation_angle_slider := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer5/HSlider")
onready var rotation_angle_spinbox := get_node("MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer5/HBoxContainer/HBEditorSpinBox")

var autoarrange_shortcuts = [
	"editor_arrange_r",
	"editor_arrange_dr",
	"editor_arrange_d",
	"editor_arrange_dl",
	"editor_arrange_l",
	"editor_arrange_ul",
	"editor_arrange_u",
	"editor_arrange_ur",
]

var cw_circle_transform := HBEditorTransforms.MakeCircleTransform.new(1)
var ccw_circle_transform := HBEditorTransforms.MakeCircleTransform.new(-1)
var size_testing_circle_transform := HBEditorTransforms.MakeCircleTransform.new(1)

var flip_h_transform := HBEditorTransforms.FlipHorizontallyTransformation.new()
var flip_v_transform := HBEditorTransforms.FlipVerticallyTransformation.new()

var rotate_center_transform := HBEditorTransforms.RotateTransformation.new(HBEditorTransforms.RotateTransformation.PIVOT_MODE_RELATIVE_CENTER)
var rotate_left_transform := HBEditorTransforms.RotateTransformation.new(HBEditorTransforms.RotateTransformation.PIVOT_MODE_RELATIVE_LEFT)
var rotate_right_transform := HBEditorTransforms.RotateTransformation.new(HBEditorTransforms.RotateTransformation.PIVOT_MODE_RELATIVE_RIGHT)
var rotate_absolute_transform := HBEditorTransforms.RotateTransformation.new(HBEditorTransforms.RotateTransformation.PIVOT_MODE_ABSOLUTE)


func _ready():
	for i in range(autoarrange_shortcuts.size()):
		add_shortcut(autoarrange_shortcuts[i], "_apply_arrange_shortcut", null, [i])
	add_shortcut("editor_arrange_center", "arrange_selected_notes_by_time", null, [null, false])
	
	add_shortcut("editor_make_circle_cw", "create_circle_cw", circle_cw_button)
	add_shortcut("editor_make_circle_ccw", "create_circle_ccw", circle_ccw_button)
	add_shortcut("editor_make_circle_cw_inside", "create_circle_cw", circle_cw_inside_button, [true])
	add_shortcut("editor_make_circle_ccw_inside", "create_circle_ccw", circle_ccw_inside_button, [true])
	add_shortcut("editor_circle_size_bigger", "increase_circle_size", null, [], true)
	add_shortcut("editor_circle_size_smaller", "decrease_circle_size", null, [], true)
	
	add_shortcut("editor_mirror_h", "flip_horizontally", mirror_horizontally_button)
	add_shortcut("editor_mirror_v", "flip_vertically", mirror_vertically_button)
	add_shortcut("editor_flip_h", "flip_horizontally", flip_horizontally_button, [true])
	add_shortcut("editor_flip_v", "flip_vertically", flip_vertically_button, [true])
	
	update_shortcuts()
	
	arrange_menu.connect("angle_changed", self, "arrange_selected_notes_by_time", [true])
	arrange_menu.connect("angle_changed", self, "_update_slope_info")
	
	circle_size_slider.connect("value_changed", cw_circle_transform, "set_epr")
	circle_size_slider.connect("value_changed", ccw_circle_transform, "set_epr")
	circle_size_slider.connect("value_changed", self, "preview_size")
	circle_size_slider.connect("drag_started", self, "_toggle_dragging_size_slider")
	circle_size_slider.connect("drag_ended", self, "_toggle_dragging_size_slider")
	circle_size_slider.connect("drag_ended", self, "hide_transform")
	circle_size_slider.share(circle_size_spinbox)
	
	circle_size_spinbox.connect("value_changed", cw_circle_transform, "set_epr")
	circle_size_spinbox.connect("value_changed", ccw_circle_transform, "set_epr")
	circle_size_spinbox.connect("value_changed", self, "_set_circle_size")
	
	rotation_angle_slider.connect("value_changed", self, "_set_rotation_angle")
	rotation_angle_slider.connect("value_changed", self, "preview_angle")
	rotation_angle_slider.connect("drag_started", self, "_toggle_dragging_angle_slider")
	rotation_angle_slider.connect("drag_ended", self, "_toggle_dragging_angle_slider")
	rotation_angle_slider.connect("drag_ended", self, "hide_transform")
	rotation_angle_slider.share(rotation_angle_spinbox)
	
	rotation_angle_spinbox.connect("value_changed", self, "_set_rotation_angle")

var arranging := false
func _input(event: InputEvent):
	var selected = get_selected()
	
	if event.is_action_pressed("editor_show_arrange_menu"):
		if selected and editor.game_preview.get_global_rect().has_point(get_global_mouse_position()):
			arranging = true
			arrange_menu.popup()
			arrange_menu.set_global_position(get_global_mouse_position())
			
			selected.sort_custom(self, "_order_items")
			first_note = selected[0].data.clone()
			last_note = selected[-1].data.clone()
	elif event.is_action_released("editor_show_arrange_menu") and arranging:
		arranging = false
		arrange_menu.hide()
		
		undo_redo.create_action("Arrange selected notes by time")
		commit_selected_property_change("position", false)
		commit_selected_property_change("entry_angle", false)
		commit_selected_property_change("oscillation_frequency", false)
		undo_redo.commit_action()
		
		first_note = null
		last_note = null

func set_editor(_editor: HBEditor):
	.set_editor(_editor)
	
	connect("show_transform", editor, "_show_transform_on_current_notes")
	connect("hide_transform", editor.game_preview.transform_preview, "hide")
	connect("apply_transform", editor, "_apply_transform_on_current_notes")

func song_editor_settings_changed(settings: HBPerSongEditorSettings):
	circle_size_spinbox.value = get_song_settings().circle_size
	cw_circle_transform.separation = settings.circle_separation
	ccw_circle_transform.separation = settings.circle_separation
	size_testing_circle_transform.separation = get_song_settings().circle_separation

func update_shortcuts():
	.update_shortcuts()
	
	var arrange_event_list = InputMap.get_action_list("editor_show_arrange_menu")
	var arrange_ev = arrange_event_list[0] if arrange_event_list else null
	
	if arrange_ev:
		$MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/Label.show()
		$MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/Label.text = \
			"Hold " + get_event_text(arrange_ev) + " for quick placing."
		$MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/Label.hint_tooltip = \
			"The arrange wheel helps you place notes quickly. \nHold Shift for reverse arranging. \nShortcut: " + get_event_text(arrange_ev)
	else:
		$MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer/VBoxContainer/Label.hide()
	
	var size_up_event_list = InputMap.get_action_list("editor_circle_size_bigger")
	var size_down_event_list = InputMap.get_action_list("editor_circle_size_smaller")
	var size_up_ev = size_up_event_list[0] if size_up_event_list else null
	var size_down_ev = size_down_event_list[0] if size_down_event_list else null
	
	$MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer2.hint_tooltip = "Amount of 8th notes required for \na full revolution."
	$MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer2.hint_tooltip += "\nShortcut (increase): " + get_event_text(size_up_ev)
	$MarginContainer/ScrollContainer/VBoxContainer/HBoxContainer2.hint_tooltip += "\nShortcut (decrease): " + get_event_text(size_down_ev)


func _update_slope_info(angle: float, reverse: bool):
	arrange_angle_spinbox.value = rad2deg(fmod(-angle + 2*PI, 2*PI))
	reverse_arrange_checkbox.pressed = reverse

func _apply_arrange():
	arrange_selected_notes_by_time(deg2rad(-arrange_angle_spinbox.value), reverse_arrange_checkbox.pressed)

func _apply_arrange_shortcut(direction: int):
	var angle = 45
	
	if direction % 2:
		if direction > 3:
			angle = -angle 

		if direction in [3, 5]:
			angle = -angle
			angle += 180

		arrange_selected_notes_by_time(deg2rad(angle), reverse_arrange_checkbox.pressed)
	else:
		arrange_selected_notes_by_time(direction * deg2rad(90) / 2.0, reverse_arrange_checkbox.pressed)


func _order_items(a, b):
	return a.data.time < b.data.time

# Arranges the selected notes in the playarea by a certain distances
var first_note: HBBaseNote
var last_note: HBBaseNote
func arrange_selected_notes_by_time(angle, reverse: bool, preview_only: bool = false):
	if reverse:
		angle += PI
	
	var selected = get_selected()
	selected.sort_custom(self, "_order_items")
	if not preview_only:
		first_note = selected[0].data
		last_note = selected[-1].data
		undo_redo.create_action("Arrange selected notes by time")
	
	var separation : Vector2 = Vector2.ZERO
	var slide_separation : Vector2 = Vector2.ZERO
	var eight_separation = get_song_settings().separation
	
	var autoslide = get_song_settings().autoslide
	
	if angle != null:
		separation.x = eight_separation * cos(angle)
		separation.y = eight_separation * sin(angle)
		slide_separation.x = 32 * cos(angle)
		slide_separation.y = 32 * sin(angle)
	
	# Never remove these, it makes the mikuphile mad
	var direction = Vector2.ZERO
	if abs(direction.x) > 0 and abs(direction.y) > 0:
		pass
	
	var pos_compensation: Vector2
	var time_compensation := 0
	var slide_index := 0
	var interval = get_timing_interval(1.0/16.0) * 2
	
	var anchor = first_note
	if reverse:
		anchor = last_note
	
	pos_compensation = anchor.position
	time_compensation = anchor.time
	
	for selected_item in selected:
		if selected_item.data is HBBaseNote:
			if selected_item.data is HBNoteData and selected_item.data.is_slide_note() and autoslide:
				slide_index = 1
			elif selected_item.data is HBNoteData and slide_index and selected_item.data.is_slide_hold_piece():
				slide_index += 1
			elif slide_index:
				slide_index = 0
			
			# Real snapping hours
			var diff
			if not reverse:
				diff = selected_item.data.time - time_compensation
			else:
				diff = time_compensation - selected_item.data.time
				diff = selected_item.data.time - time_compensation
			
			var new_pos = pos_compensation + (separation * (float(diff) / float(interval)))
			
			if selected_item.data is HBNoteData and selected_item.data.is_slide_hold_piece() and slide_index and autoslide:
				if slide_index == 2:
					new_pos = pos_compensation + separation / 2
				else:
					new_pos = pos_compensation + slide_separation
			
			if not preview_only:
				undo_redo.add_do_property(selected_item.data, "position", new_pos)
				undo_redo.add_do_property(selected_item.data, "pos_modified", true)
				undo_redo.add_undo_property(selected_item.data, "position", selected_item.data.position)
				undo_redo.add_undo_property(selected_item.data, "pos_modified", selected_item.data.pos_modified)
				
				undo_redo.add_do_method(selected_item, "update_widget_data")
				undo_redo.add_undo_method(selected_item, "update_widget_data")
			else:
				change_selected_property_single_item(selected_item, "position", new_pos)
			
			pos_compensation = new_pos
			if selected_item.data is HBSustainNote:
				time_compensation = selected_item.data.end_time
			else:
				time_compensation = selected_item.data.time
	
	for selected_item in selected:
		if selected_item.data is HBBaseNote and selected.size() > 2:
			var new_angle_params = autoangle(selected_item.data, selected[0].data.position, angle)
			
			if not preview_only:
				undo_redo.add_do_property(selected_item.data, "entry_angle", new_angle_params[0])
				undo_redo.add_undo_property(selected_item.data, "entry_angle", selected_item.data.entry_angle)
				undo_redo.add_do_property(selected_item.data, "oscillation_frequency", new_angle_params[1])
				undo_redo.add_undo_property(selected_item.data, "oscillation_frequency", selected_item.data.oscillation_frequency)
				
				undo_redo.add_do_method(selected_item, "update_widget_data")
				undo_redo.add_undo_method(selected_item, "update_widget_data")
			else:
				change_selected_property_single_item(selected_item, "entry_angle", new_angle_params[0])
				change_selected_property_single_item(selected_item, "oscillation_frequency", new_angle_params[1])
	
	if not preview_only:
		undo_redo.add_do_method(self, "timing_points_changed")
		undo_redo.add_undo_method(self, "timing_points_changed")
		undo_redo.add_do_method(self, "sync_inspector_values")
		undo_redo.add_undo_method(self, "sync_inspector_values")
		
		undo_redo.commit_action()
		
		first_note = null
		last_note = null
	else:
		timing_points_params_changed()

func autoangle(note: HBBaseNote, new_pos: Vector2, arrange_angle):
	if get_song_settings().autoangle and arrange_angle != null:
		var new_angle: float
		var oscillation_frequency = abs(note.oscillation_frequency)
		
		# Normalize the arrange angle to be between 0 and 2PI
		arrange_angle = fmod(fmod(arrange_angle, 2*PI) + 2*PI, 2*PI)
		
		# Get the quadrant and rotated quadrant
		var quadrant = int(arrange_angle / (PI/2.0))
		var rotated_quadrant = int((arrange_angle + PI/4.0) / (PI/2.0)) % 4
		
		new_angle = arrange_angle + PI/2.0
		
		if rotated_quadrant in [1, 3]:
			new_angle += PI if quadrant in [0, 1] else 0.0
			
			var left_point = Geometry.get_closest_point_to_segment_2d(new_pos, Vector2(0, 0), Vector2(0, 1080))
			var right_point = Geometry.get_closest_point_to_segment_2d(new_pos, Vector2(1920, 0), Vector2(1920, 1080))
			
			var left_distance = new_pos.distance_to(left_point)
			var right_distance = new_pos.distance_to(right_point)
			
			# Point towards closest side
			new_angle += PI if right_distance > left_distance else 0.0
		else:
			new_angle += PI if quadrant in [1, 2] else 0.0
			
			var top_point = Geometry.get_closest_point_to_segment_2d(new_pos, Vector2(0, 0), Vector2(1920, 0))
			var bottom_point = Geometry.get_closest_point_to_segment_2d(new_pos, Vector2(0, 1080), Vector2(1920, 1080))
			
			var top_distance = new_pos.distance_to(top_point)
			var bottom_distance = new_pos.distance_to(bottom_point)
			
			# Point towards furthest side
			new_angle += PI if top_distance > bottom_distance else 0.0
		
		var positive_quadrants = []
		
		if new_pos.x > 960:
			positive_quadrants.append(3)
		else:
			positive_quadrants.append(1)
		
		if new_pos.y > 540:
			positive_quadrants.append(2)
		else:
			positive_quadrants.append(0)
		
		if not rotated_quadrant in positive_quadrants:
			oscillation_frequency = -oscillation_frequency
		
		oscillation_frequency *= sign(note.oscillation_amplitude)
		
		return [fmod(rad2deg(new_angle), 360.0), oscillation_frequency]
	else:
		return [note.entry_angle, note.oscillation_frequency]


func _set_circle_size(value: int):
	get_song_settings().set("circle_size", value)

func increase_circle_size():
	circle_size_spinbox.value += 1

func decrease_circle_size():
	circle_size_spinbox.value -= 1

var dragging_size_slider := false
# Having a catchall arg is stupid but we need it for drag_ended pokeKMS
func _toggle_dragging_size_slider(catchall = null):
	dragging_size_slider = not dragging_size_slider

func preview_size(value: int):
	if dragging_size_slider:
		size_testing_circle_transform.bpm = get_bpm()
		size_testing_circle_transform.set_epr(value)
		show_transform(size_testing_circle_transform)

func preview_circle(clockwise: bool, inside: bool = false):
	var transform = cw_circle_transform if clockwise else ccw_circle_transform
	transform.set_inside(inside)
	transform.bpm = get_bpm()
	emit_signal("show_transform", transform)

func create_circle_cw(inside: bool = false):
	cw_circle_transform.bpm = get_bpm()
	cw_circle_transform.set_inside(inside)
	emit_signal("apply_transform", cw_circle_transform)

func create_circle_ccw(inside: bool = false):
	ccw_circle_transform.bpm = get_bpm()
	ccw_circle_transform.set_inside(inside)
	emit_signal("apply_transform", ccw_circle_transform)


func preview_flip(vertical: bool, local: bool = false):
	var transform = flip_v_transform if vertical else flip_h_transform
	transform.local = local
	emit_signal("show_transform", transform)

func flip_horizontally(local: bool = false):
	flip_h_transform.local = local
	emit_signal("apply_transform", flip_h_transform)

func flip_vertically(local: bool = false):
	flip_v_transform.local = local
	emit_signal("apply_transform", flip_v_transform)


func _set_rotation_angle(new_value: float):
	rotate_center_transform.rotation = -new_value
	rotate_left_transform.rotation = -new_value
	rotate_right_transform.rotation = -new_value
	rotate_absolute_transform.rotation = -new_value

var dragging_angle_slider := false
# Having a catchall arg is stupid but we need it for drag_ended pokeKMS
func _toggle_dragging_angle_slider(catchall = null):
	dragging_angle_slider = not dragging_angle_slider

func preview_angle(value: float):
	if dragging_angle_slider:
		show_transform(rotate_center_transform)

func preview_rotate(id: int):
	var transforms = [rotate_center_transform, rotate_left_transform, rotate_right_transform, rotate_absolute_transform]
	emit_signal("show_transform", transforms[id])

func rotate(id: int):
	var transforms = [rotate_center_transform, rotate_left_transform, rotate_right_transform, rotate_absolute_transform]
	emit_signal("apply_transform", transforms[id])


func show_transform(transform: EditorTransformation, inside: bool = false, local: bool = false):
#	transform.use_stage_center = use_stage_center
	if transform is HBEditorTransforms.MakeCircleTransform:
		transform.set_inside(inside)
		transform.bpm = get_bpm()
	elif transform is HBEditorTransforms.FlipHorizontallyTransformation or transform is HBEditorTransforms.FlipVerticallyTransformation:
		transform.local = local
	
	emit_signal("show_transform", transform)

# Having a catchall arg is stupid but we need it for drag_ended pokeKMS
func hide_transform(catchall = null):
	emit_signal("hide_transform")