extends HBSongListMenu

@onready var lobby_title_label = get_node("VBoxContainer/LobbyTitleLabel")
func _on_menu_enter(force_hard_transition=false, args = {}):
	super._on_menu_enter(force_hard_transition, args)
	if args.has("lobby"):
		var lobby := args.lobby as HeartbeatSteamLobby
		lobby_title_label.text = "Selecting song for %s" % [lobby.lobby_data.lobby_name]

func _on_difficulty_selected(song: HBSong, difficulty: String):
	change_to_menu("lobby", false, {"action": LobbyMenu.LobbyMenuAction.CHANGE_SONG, "song": song, "difficulty": difficulty})
	
func _unhandled_input(event):
	if event.is_action_pressed("gui_cancel"):
		HBGame.fire_and_forget_sound(HBGame.menu_back_sfx, HBGame.sfx_group)
		get_viewport().set_input_as_handled()
		change_to_menu("lobby")
		return
	super._unhandled_input(event)
