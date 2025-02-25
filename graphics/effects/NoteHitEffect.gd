extends Node2D

@onready var note_icon = get_node("NoteIcon")
@onready var note_loop = get_node("Loop")
@onready var note_flare = get_node("Flare")

@onready var tween = Threen.new()

# 1-12: yellow thing
# 7-28 note with 4 frame fade
# 7-28 shockwave


func _ready():
	$NoteIcon.texture = ResourcePackLoader.get_graphic("bubble.png")
	$Flare.texture = ResourcePackLoader.get_graphic("flare.png")
	$Loop.texture = ResourcePackLoader.get_graphic("loop.png")
	tween.connect("tween_all_completed", Callable(self, "queue_free"))
	add_child(tween)
	play_effect()
	scale = Vector2.ONE * 0.40
	
func play_effect():
	$AnimationPlayer.play("play")
	return
	note_icon.scale = Vector2.ZERO
	note_icon.modulate.a = 0.0
	note_loop.scale = Vector2.ZERO
	note_loop.modulate.a = 0.0
	note_flare.scale = Vector2.ZERO
	note_flare.modulate.a = 0.0
	tween.playback_speed = 1.5
	tween.remove_all()
	var note_icon_t = Color.WHITE
	note_icon_t.a = 0.75
	
	var transparent_trans = Threen.TRANS_QUINT
	var transparent_ease = Threen.EASE_IN
	
	tween.interpolate_property(note_icon, "scale", Vector2(0.25, 0.25), Vector2(0.65, 0.65), 0.25, Threen.TRANS_EXPO, Threen.EASE_OUT, 0.20)
	tween.interpolate_property(note_icon, "modulate:a", 1.0, 0.0, 0.05, 0, 2, 0.20)
	
	tween.interpolate_property(note_loop, "scale", Vector2(0.15, 0.15), Vector2(0.75, 0.75), 0.15, Threen.TRANS_BOUNCE, Threen.EASE_IN)
	tween.interpolate_property(note_loop, "scale", Vector2(0.75, 0.75), Vector2(4.0, 4.0), 0.60, Threen.TRANS_QUAD, Threen.EASE_OUT, 0.15)
	tween.interpolate_property(note_loop, "modulate:a", 0.2, 0.0, 0.7, transparent_trans, transparent_ease)
	
	tween.interpolate_property(note_flare, "scale", Vector2(0.15, 0.15), Vector2(0.75, 0.75), 0.15, Threen.TRANS_BOUNCE, Threen.EASE_IN)
	tween.interpolate_property(note_flare, "scale", Vector2(0.75, 0.75), Vector2(1.0, 1.0), 0.25, Threen.TRANS_QUAD, Threen.EASE_OUT, 0.15)
	tween.interpolate_property(note_flare, "modulate:a", 0.4, 0.0, 0.4, transparent_trans, transparent_ease)
	
	tween.start()
	
#	$AnimationPlayer.play("COOL")

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		queue_free()


func _on_animation_player_animation_finished(_anim_name: StringName):
	queue_free()
