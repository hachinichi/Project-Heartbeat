extends Node

class_name HBRhythmGameBase

signal time_changed(time)
signal song_cleared(results)
signal note_judged(judgement)
signal intro_skipped(new_time)
signal show_multi_hint(new_closest_multi_notes)
signal hide_multi_hint
signal toggle_ui
signal size_changed

const BASE_SIZE = Vector2(1920, 1080)
const MAX_SCALE = 1.5
const MAX_NOTE_SFX = 4
const INTRO_SKIP_MARGIN = 5000 # the time before the first note we warp to when doing intro skip 

var timing_points = [] setget _set_timing_points
# TPs that were previously hit
var last_hit_index = 0
var result = HBResult.new()
var judge = preload("res://rythm_game/judge.gd").new()
var time_begin: int
var time_delay: float
var time: float
var current_combo = 0
var disable_intro_skip = false

# Notes currently being shown to the user
var notes_on_screen = []
var current_song: HBSong = HBSong.new()
var current_difficulty: String = ""

# size for scaling
var size = Vector2(1280, 720) setget set_size

# editor stuff
var editing = false
var previewing = false

# Contains a dictionary that maps HBTimingPoint -> its drawer (if it has one)
var timing_point_to_drawer_map = {}

var modifiers = []

var closest_multi_notes = []

var earliest_note_time = 0

# cached values for speed
var playing_field_size
var playing_field_size_length

# If we've played an sfx in this cycle
var _sfx_played_this_cycle = false
var _intro_skip_enabled = false
# Prevents the song from finishing once
var _prevent_finishing = false
var _finished = false
var _song_volume = 0.0

const SFX_DEBOUNCE_TIME = 0.016*2.0

var _sfx_debounce_t = SFX_DEBOUNCE_TIME

var audio_stream_player: AudioStreamPlayer
var audio_stream_player_voice: AudioStreamPlayer

var game_ui: HBRhythmGameUIBase
var game_input_manager: HBGameInputManager = HBGameInputManager.new()

var bpm_changes = {}

# Initial BPM
var base_bpm = 180.0

var sfx_player_queue = []

func _game_ready():
	get_viewport().connect("size_changed", self, "_on_viewport_size_changed")
	_on_viewport_size_changed()
	set_current_combo(0)
	
	# Despite using end time audio stream player's finished signal is used as fallback just in case
	
	audio_stream_player = AudioStreamPlayer.new()
	audio_stream_player.bus = "Music"
	
	audio_stream_player_voice = AudioStreamPlayer.new()
	audio_stream_player_voice.bus = "Vocals"
	
	add_child(audio_stream_player)
	add_child(audio_stream_player_voice)
	
	audio_stream_player.connect("finished", self, "_on_game_finished")
	
	pause_mode = Node.PAUSE_MODE_STOP

func _ready():
	_game_ready()

func set_game_input_manager(manager: HBGameInputManager):
	game_input_manager = manager
	add_child(game_input_manager)

# TODO: generalize this
func set_chart(chart: HBChart):
	game_ui._on_reset()
	audio_stream_player.seek(0)
	audio_stream_player_voice.seek(0)
	result = HBResult.new()
	current_combo = 0
	var tp = chart.get_timing_points()
	for modifier in modifiers:
		modifier._preprocess_timing_points(tp)
	_set_timing_points(tp)
	# Find slide hold chains
	result.max_score = chart.get_max_score()
	game_ui._on_chart_set(chart)

# Override this
func get_chart_from_song(song: HBSong, difficulty) -> HBChart:
	return song.get_chart_for_difficulty(difficulty)

# TODO: generalize this
func set_song(song: HBSong, difficulty: String, assets = null, modifiers = []):
	self.modifiers = modifiers
	current_song = song
	base_bpm = song.bpm
	if assets:
		audio_stream_player.stream = assets.audio
		if song.voice:
			audio_stream_player_voice.stream = assets.voice
	else:
		audio_stream_player.stream = song.get_audio_stream()
		if song.voice:
			audio_stream_player_voice.stream = song.get_voice_stream()

	var chart: HBChart
	
	current_difficulty = difficulty

	chart = get_chart_from_song(song, difficulty)

	set_chart(chart)
	
	earliest_note_time = -1
	for i in range(timing_points.size() - 1, -1, -1):
		var group = timing_points[i]
		if group is NoteGroup:
			earliest_note_time = group.time
			break
	if song.allows_intro_skip and not disable_intro_skip:
		if earliest_note_time / 1000.0 > song.intro_skip_min_time:
			_intro_skip_enabled = true
		else:
			Log.log(self, "Disabling intro skip")
			_intro_skip_enabled = false
	audio_stream_player.stream_paused = true
	audio_stream_player_voice.stream_paused = true
	
	if current_song.id in UserSettings.user_settings.per_song_settings:
		var user_song_settings = UserSettings.user_settings.per_song_settings[current_song.id] as HBPerSongSettings
		_song_volume = linear2db(song.volume * user_song_settings.volume)
	else:
		_song_volume = linear2db(song.volume)
	audio_stream_player.volume_db = _song_volume
	audio_stream_player_voice.volume_db = _song_volume
	# todo: call ui on set song
	game_ui._on_song_set(song, difficulty, assets, modifiers)

func _create_sfx_player(sample, volume, bus="SFX"):
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.stream = sample
	player.volume_db = volume
	return player

func make_group(notes: Array, extra_notes: Array, group_position, time):
	var group = NoteGroup.new()
	group.notes = notes + extra_notes
	group.time = time
	
	var highest_time_out = 0

	for point in group.notes:
		point.set_meta("group_position", group_position)
		point.set_meta("group", group)
	group.hit_notes.resize(group.notes.size())
	var array = PoolByteArray()
	array.resize(group.notes.size())
	group.hit_notes = array
	if group.hit_notes.size() == 0:
		breakpoint
	for i in range(group.hit_notes.size()):
		group.hit_notes[i] = 0
	for note in group.notes:
		highest_time_out = max(highest_time_out, note.get_time_out(get_bpm_at_time(note.time)))
	group.precalculated_timeout = highest_time_out
	
	return group
	
func _process_timing_points_into_groups(points):
	# Group related notes for performance reasons, so we can precompute stuff
	var timing_points_grouped = []
	var last_notes = []
	var group_position = 0
	var extra_notes = []
	
	for i in range(points.size()):
		var own_extra_notes = []
		var point = points[i]
		if point is HBBaseNote:
			if point is HBNoteData:
				if point.is_slide_hold_piece():
					continue
			var should_make_group = i == timing_points.size()-1 \
					or timing_points[i+1].time != point.time

			if should_make_group:
				var group = make_group(last_notes + [point], own_extra_notes + extra_notes, group_position, point.time)
				group_position += 1
				last_notes = []
				own_extra_notes = []
				extra_notes = []
				timing_points_grouped.append(group)
			if not should_make_group:
				extra_notes += own_extra_notes
				last_notes.append(point)
	return timing_points_grouped
	
func _set_timing_points(points):
	timing_points = points
	timing_points.sort_custom(self, "_sort_notes_by_appear_time")
	# When timing points change, we might introduce new BPM change events
	bpm_changes = {}
	for point in timing_points:
		if point is HBBPMChange:
			bpm_changes[point.time] = point.bpm
			print("FOUND BPM CHANGE at ", point.time)
	timing_points = _process_timing_points_into_groups(points)
	last_hit_index = timing_points.size()
	timing_point_to_drawer_map = {}
func get_bpm_at_time(time):
	var current_time = null
	for c_t in bpm_changes:
		if (current_time == null and c_t <= time) or (c_t <= time and c_t > current_time):
			current_time = c_t
	if current_time == null:
		return base_bpm
	return bpm_changes[current_time]
	
func _sort_notes_by_appear_time(a: HBTimingPoint, b: HBTimingPoint):
	var ta = 0
	var tb = 0
	
	if a is HBBaseNote:
		ta = a.get_time_out(get_bpm_at_time(a.time))
	if b is HBBaseNote:
		tb = b.get_time_out(get_bpm_at_time(b.time))
	
	return (a.time - ta) > (b.time - tb)

# Stores playing field size in memory to mape remap_coords faster
func cache_playing_field_size():
	playing_field_size = Vector2(size.y * 16.0 / 9.0, size.y)
	playing_field_size_length = playing_field_size.length()

# Called when the game size is changed
func set_size(value):
	size = value
	cache_playing_field_size()

func _on_viewport_size_changed():
	cache_playing_field_size()
	emit_signal("size_changed")

func _input(event):
	if event.is_action_pressed(HBGame.NOTE_TYPE_TO_ACTIONS_MAP[HBNoteData.NOTE_TYPE.UP][0]) or event.is_action_pressed(HBGame.NOTE_TYPE_TO_ACTIONS_MAP[HBNoteData.NOTE_TYPE.LEFT][0]):
		if Input.is_action_pressed(HBGame.NOTE_TYPE_TO_ACTIONS_MAP[HBNoteData.NOTE_TYPE.UP][0]) and Input.is_action_pressed(HBGame.NOTE_TYPE_TO_ACTIONS_MAP[HBNoteData.NOTE_TYPE.LEFT][0]):
			if current_song.allows_intro_skip and _intro_skip_enabled and audio_stream_player.playing:
				if time*1000.0 < earliest_note_time - INTRO_SKIP_MARGIN:
					_intro_skip_enabled = false

					play_from_pos((earliest_note_time - INTRO_SKIP_MARGIN) / 1000.0)
					# HACK: For note time precision
					_process(0)
					# call ui on intro skip
					emit_signal("intro_skipped", time)
	if event.is_action_pressed("free_friends"):
		for group in timing_points:
			var res = ""
			for note in group.hit_notes:
				res += str(note)
			print(res)

func _process_note_group(group: NoteGroup):
	var multi_notes = []
	for i in range(group.notes.size()):
		if group.hit_notes[i] == 1:
			continue
		var timing_point = group.notes[i] as HBBaseNote
		if not timing_point in notes_on_screen:
			# Prevent older notes from being re-created, although this shouldn't happen...
			var time_out = timing_point.get_time_out(get_bpm_at_time(timing_point.time))
			if time * 1000.0 < (timing_point.time - time_out):
				break
			if judge.judge_note(time, (timing_point.time) / 1000.0) == judge.JUDGE_RATINGS.WORST:
				break
			if timing_point.has_meta("ignored"):
				if timing_point.get_meta("ignored"):
					continue
			create_note_drawer(timing_point)
			# multi-note detection
			if multi_notes.size() > 0:
				if multi_notes[0].time == timing_point.time:
					if timing_point is HBBaseNote and timing_point.is_multi_allowed():
						multi_notes.append(timing_point)
				elif multi_notes.size() > 1:
					hookup_multi_notes(multi_notes)
					multi_notes = [timing_point]
				else:
					multi_notes = [timing_point]
			elif timing_point is HBBaseNote and timing_point.is_multi_allowed():
				multi_notes.append(timing_point)
	if multi_notes.size() > 1:
		hookup_multi_notes(multi_notes)

# We need to split _process into it's own function so we can override it because
# godot is stupid and calls _process on both parent and child
func _process_game(_delta):
	_sfx_debounce_t += _delta
	var latency_compensation = UserSettings.user_settings.lag_compensation
	if current_song.id in UserSettings.user_settings.per_song_settings:
		latency_compensation += UserSettings.user_settings.per_song_settings[current_song.id].lag_compensation

	if audio_stream_player.playing and (not editing or previewing):
		# Obtain current time from ticks, offset by the time we began playing music.
		time = (OS.get_ticks_usec() - time_begin) / 1000000.0
		time = time * audio_stream_player.pitch_scale
		# Compensate for latency.
		time -= time_delay

		# User entered compensation
		time -= latency_compensation / 1000.0

		# May be below 0 (did not being yet).
		time = max(0, time)
		if not editing:
			var end_time = audio_stream_player.stream.get_length() * 1000.0
			if current_song.end_time > 0:
				end_time = float(current_song.end_time)
			if time*1000.0 >= end_time and not _finished:
				_on_game_finished()
	for i in range(timing_points.size() - 1 - (timing_points.size() - last_hit_index), -1, -1):
		var group = timing_points[i]
		if group is NoteGroup:
			# Ignore timing points that are not happening now
			var time_out = group.precalculated_timeout
			if time * 1000.0 < (group.time - time_out):
				break
			if time * 1000.0 >= (group.time - time_out):
				_process_note_group(group)
#				if not editing or previewing:
#					timing_points.remove(i)
	emit_signal("time_changed", time)
	
	var new_closest_multi_notes = []
	var last_note_time = 0
	for note in notes_on_screen:
		if note is HBBaseNote:
			if note.time == last_note_time:
				new_closest_multi_notes.append(note)
			elif new_closest_multi_notes.size() > 1:
				break
			else:
				new_closest_multi_notes = [note]
			last_note_time = note.time
	if UserSettings.user_settings.enable_multi_hint:
		if new_closest_multi_notes.size() > 1:
			if not new_closest_multi_notes[0] in closest_multi_notes:
				closest_multi_notes = new_closest_multi_notes
				emit_signal("show_multi_hint", new_closest_multi_notes)
#				hold_hint.show()
		
	if new_closest_multi_notes.size() < 2:
		emit_signal("hide_multi_hint")
		
	closest_multi_notes = new_closest_multi_notes
	if _intro_skip_enabled:
		if time*1000.0 >= earliest_note_time - INTRO_SKIP_MARGIN:
			emit_signal("end_intro_skip_period")
			_intro_skip_enabled = false
func _process(delta):
	_process_game(delta)

func toggle_ui():
	emit_signal("toggle_ui")

func set_current_combo(combo: int):
	current_combo = combo

# removes a note from screen (and from the timing points list if not in the editor)
func remove_note_from_screen(i, update_last_hit = true):
	if i != -1:
		if not editing or previewing:
			if update_last_hit:
				if notes_on_screen[i].has_meta("group_position"):
					var group = notes_on_screen[i].get_meta("group")
					group.hit_notes[group.notes.find(notes_on_screen[i])] = 1
		game_ui.get_notes_node().remove_child(get_note_drawer(notes_on_screen[i]))
		notes_on_screen.remove(i)

# Used by editor to reset hit notes and allow them to appear again
func reset_hit_notes():
	last_hit_index = timing_points.size()
	for group in timing_points:
		var g = group as NoteGroup
		var array = PoolByteArray()
		array.resize(group.notes.size())
		for i in range(array.size()):
			array.set(i, 0)
		group.hit_notes = array

		for note in group.notes:
			note.set_meta("ignored", false)
func delete_rogue_notes(pos_override = null):
	pass
		
func restart():
	remove_all_notes_from_screen()
	_prevent_finishing = true
	get_tree().paused = false
	set_song(SongLoader.songs[current_song.id], current_difficulty, null, modifiers)
	audio_stream_player_voice.volume_db = _song_volume
	set_current_combo(0)
	time = current_song.start_time / 1000.0
	audio_stream_player.stream_paused = true
	audio_stream_player_voice.stream_paused = true
	reset_hit_notes()

			
func _on_note_removed(note):
	remove_note_from_screen(notes_on_screen.find(note))

func pause_game():
	audio_stream_player.stream_paused = true
	audio_stream_player_voice.stream_paused = true

func resume():
	play_from_pos(audio_stream_player.get_playback_position())
	
func play_from_pos(position: float):
	audio_stream_player.stream_paused = false
	audio_stream_player_voice.stream_paused = false
	audio_stream_player.play()
	audio_stream_player_voice.play()
	audio_stream_player.seek(position)
	audio_stream_player_voice.seek(position)
	time_begin = OS.get_ticks_usec() - int((position / audio_stream_player.pitch_scale) * 1000000.0)
	time_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	
func add_score(score_to_add):
	if not previewing:
		result.score += score_to_add
		emit_signal("score_added", score_to_add)
		
func _on_game_finished():
	if not _finished:
		if not _prevent_finishing:
			for modifier in modifiers:
				modifier._post_game(current_song, self)
			emit_signal("song_cleared", result)
			_finished = true
		else:
			_prevent_finishing = false

# Connects multi notes to their respective master notes
func hookup_multi_notes(notes: Array):
	for note in notes:
		var note_drawer = get_note_drawer(note)
		note_drawer.connected_notes = notes
		note_drawer.note_master = false
	get_note_drawer(notes[0]).note_master = true

# returns the note drawer for the given timing point
func get_note_drawer(timing_point):
	var drawer = null
	if timing_point_to_drawer_map.has(timing_point):
		drawer = timing_point_to_drawer_map[timing_point]
	return drawer
	
# Plays the provided sfx creating a clone of an audio player (maybe we should
# use the AudioServer for this...
func play_sfx(player: AudioStreamPlayer, debounce_enabled = true):
	if _sfx_debounce_t > SFX_DEBOUNCE_TIME or not debounce_enabled:
		var new_player := player.duplicate() as AudioStreamPlayer
		add_child(new_player)
		new_player.play(0)
		new_player.connect("finished", new_player, "queue_free")
		_sfx_debounce_t = 0.0
		sfx_player_queue.append(new_player)
		
func remove_all_notes_from_screen():
	for i in range(notes_on_screen.size() - 1, -1, -1):
		var drawer = get_note_drawer(notes_on_screen[i])
		if drawer:
			game_ui.get_notes_node().remove_child(get_note_drawer(notes_on_screen[i]))
			get_note_drawer(notes_on_screen[i]).free()
	for note in game_ui.get_notes_node().get_children():
		game_ui.get_notes_node().remove_child(note)
		note.queue_free()
	notes_on_screen = []
	timing_point_to_drawer_map = {}
	
func play_song():
	play_from_pos(max(current_song.start_time/1000.0, 0.0))
func get_closest_notes():
	var closest_notes = []
	for note_c in notes_on_screen:
		var note = get_note_drawer(note_c).note_data
		if note is HBSustainNote and get_note_drawer(note_c).pressed:
			continue
		if closest_notes.size() > 0:
			if closest_notes[0].time > note.time:
				closest_notes = [note]
			elif note.time == closest_notes[0].time:
				closest_notes.append(note)
		else:
			closest_notes = [note]
	return closest_notes
	
func get_closest_notes_of_type(note_type: int) -> Array:
	var closest_notes = []
	for note_c in notes_on_screen:
		var note = get_note_drawer(note_c).note_data
		if note.note_type == note_type:
			var time_diff = abs(note.time + note.get_duration() - time * 1000.0)
			if closest_notes.size() > 0:
				if closest_notes[0].time > note.time:
					closest_notes = [note]
				elif note.time == closest_notes[0].time:
					closest_notes.append(note)
			else:
				closest_notes = [note]
	return closest_notes

func get_note_scale():
	return UserSettings.user_settings.note_size * ((playing_field_size_length / BASE_SIZE.length()) * 0.95)


func remap_coords(coords: Vector2):
	coords = coords / BASE_SIZE
	var pos = coords * playing_field_size
	coords.x = (size.x - playing_field_size.x) * 0.5 + pos.x
	coords.y = pos.y
	return coords
func inv_map_coords(coords: Vector2):
	var x = (coords.x - ((size.x - playing_field_size.x) / 2.0)) / playing_field_size.x * BASE_SIZE.x
	var y = (coords.y - ((size.y - playing_field_size.y) / 2.0)) / playing_field_size.y * BASE_SIZE.y
	return Vector2(x, y)
# creates and connects a new note drawer
func create_note_drawer(timing_point: HBBaseNote):
	var note_drawer
	note_drawer = timing_point.get_drawer().instance()
	note_drawer.note_data = timing_point
	note_drawer.game = self
	game_ui.get_notes_node().add_child(note_drawer)
	note_drawer.connect("notes_judged", self, "_on_notes_judged")
	note_drawer.connect("note_removed", self, "_on_note_removed", [timing_point])
	timing_point_to_drawer_map[timing_point] = note_drawer
	notes_on_screen.append(timing_point)
	connect("time_changed", note_drawer, "_on_game_time_changed")
	return note_drawer
func set_game_ui(ui: HBRhythmGameUIBase):
	game_ui = ui
	ui.game = self
	connect("note_judged", ui, "_on_note_judged")
	connect("intro_skipped", ui, "_on_intro_skipped")
	connect("end_intro_skip_period", ui, "_on_end_intro_skip_period")
	connect("score_added", ui, "_on_score_added")
	connect("toggle_ui", ui, "_on_toggle_ui")
	connect("hide_multi_hint", ui, "_on_hide_multi_hint")
	connect("show_multi_hint", ui, "_on_show_multi_hint")

# called when a note or group of notes is judged
# this doesn't take care of adding the score
# todo: generalize this
func _on_notes_judged(notes: Array, judgement, wrong):
	print("JUDGED %d notes, with judgement %d %s" % [notes.size(), judgement, str(wrong)])
	var note = notes[0] as HBBaseNote
	
	# Simultaneous slides are a special case...
	# we have to process each note individually
#	for n in notes:
#		if n is HBNoteData:
#			if n != note and n.is_slide_note():
#				_on_notes_judged([n], judgement, wrong)
	# Some notes might be considered more than 1 at the same time? connected ones aren't

	var notes_hit = 1
	if not editing or previewing:
		# Rating graphic
		if judgement < judge.JUDGE_RATINGS.FINE or wrong:
			# Missed a note
			if UserSettings.user_settings.enable_voice_fade:
				audio_stream_player_voice.volume_db = -90
			set_current_combo(0)
		else:
			set_current_combo(current_combo + notes_hit)
			audio_stream_player_voice.volume_db = _song_volume
			result.notes_hit += notes_hit

		if not wrong:
			result.note_ratings[judgement] += notes_hit
		else:
			result.wrong_note_ratings[judgement] += notes_hit

		result.total_notes += notes_hit

		if current_combo > result.max_combo:
			result.max_combo = current_combo

		# We average the notes position so that multinote ratings are centered
		var avg_pos = Vector2()
		for n in notes:
			avg_pos += n.position
		avg_pos = avg_pos / float(notes.size())

		var judgement_info = {"judgement": judgement, "target_time": notes[0].time, "time": int(time * 1000), "wrong": wrong, "avg_pos": avg_pos}

		emit_signal("note_judged", judgement_info)