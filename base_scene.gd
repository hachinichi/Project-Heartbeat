extends Control

onready var status_label = get_node("VBoxContainer/StatusLabel")
const MAIN_MENU_PATH = "res://menus/MainMenu3D.tscn"

const LOADINGU_SPEED = 0.5
var loadingu_t = 0
func _ready():
	SongLoader.connect("all_songs_loaded", self, "_on_songs_finished_loading")
	if OS.get_current_video_driver() == OS.VIDEO_DRIVER_GLES2:
		VisualServer.viewport_set_hdr(get_viewport().get_viewport_rid(), false)
func set_status(status: String):
	status_label.text = status

func _process(delta):
	loadingu_t += delta * LOADINGU_SPEED
	
	status_label.percent_visible = fmod(loadingu_t, 1.5)
func _load_main_menu_thread(userdata):
	call_deferred("_main_menu_loaded", userdata.thread, load(MAIN_MENU_PATH).instance())

func _input(event):
	if event.is_action_pressed("free_friends"):
		_on_songs_finished_loading()

func _main_menu_loaded(thread: Thread, scene):
	thread.wait_to_finish()
	var new_scene = scene
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

func _on_songs_finished_loading():
	yield(get_tree(), "idle_frame")
	print("LOADED")
	set_status("Loadingu...")
	var thread = Thread.new()
	var result = thread.start(self, "_load_main_menu_thread", { "thread": thread })
	if result != OK:
		Log.log(self, "Error starting thread for main menu loader: " + str(result), Log.LogLevel.ERROR)