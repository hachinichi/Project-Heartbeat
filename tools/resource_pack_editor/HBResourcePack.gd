extends HBSerializable

class_name HBResourcePack

enum NOTE_SUBGRAPHICS {
	note,
	target,
	multi_note,
	multi_note_target,
	double_target
	double_note,
	sustain_note,
	sustain_target,
	target_blue
}

var pack_name: String = ""
var pack_description: String = ""
var pack_author_name: String = ""
var notes_atlas_data: Dictionary = {}
var _path: String = ""
var _id: String = ""

var up_trail_margin: float = 0.0
var down_trail_margin: float = 0.0
var left_trail_margin: float = 0.0
var right_trail_margin: float = 0.0
var slide_left_trail_margin: float = 0.0
var slide_right_trail_margin: float = 0.0
var slide_chain_piece_left_trail_margin: float = 0.0
var slide_chain_piece_right_trail_margin: float = 0.0
var heart_trail_margin: float = 0.0

var up_trail_color = Color("#24E438")
var down_trail_color: Color = Color("#2996f8")
var left_trail_color: Color = Color("#f971d3")
var right_trail_color: Color = Color("#ff0c5c")
var slide_left_trail_color: Color = Color("#ed8a2e")
var slide_right_trail_color: Color = Color("#ed8a2e")
var slide_chain_piece_left_trail_color: Color = Color("#ed8a2e")
var slide_chain_piece_right_trail_color: Color = Color("#ed8a2e")
var heart_trail_color: Color = Color("#4a2ac9")

var property_overrides = []

func _init():
	serializable_fields += [
	# Meta
	"pack_name", "pack_author_name", "pack_description",
	# Atlases
	"notes_atlas_data", 
	# Trail margins
	"up_trail_margin", "down_trail_margin", "left_trail_margin", "right_trail_margin",
	"slide_left_trail_margin", "slide_right_trail_margin", "slide_chain_piece_left_trail_margin",
	"slide_chain_piece_right_trail_margin", "heart_trail_margin",
	# Trail colors
	"up_trail_color", "down_trail_color", "left_trail_color", "right_trail_color",
	"slide_left_trail_color", "slide_right_trail_color", "slide_chain_piece_left_trail_color",
	"slide_chain_piece_right_trail_color", "heart_trail_color",
	
	#misc
	"property_overrides"
	]

func get_note_graphic_file_name(note_i: int, subgraphic_i: int) -> String:
	var note_name = HBUtils.find_key(HBBaseNote.NOTE_TYPE, note_i)
	var subgraphic_name = HBUtils.find_key(NOTE_SUBGRAPHICS, subgraphic_i)
	return "%s_%s.png" % [note_name, subgraphic_name]
	
# Creates the atlas textures
# optional margin for having multiple atlases in one texture (batching optimization)
# atlas_name should be the atlas name, aka icon for icon_atlas_data
func create_atlas_textures(texture: Texture, atlas_name: String, offset=Vector2(0, 0)) -> Dictionary:
	var _atlas_textures = {}
	var atlas_data = get(atlas_name + "_atlas_data")
	for file_name in atlas_data:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.filter_clip = false
		atlas_texture.atlas = texture
		atlas_texture.region = atlas_data[file_name].region
		atlas_texture.region.position += offset
		atlas_texture.margin = atlas_data[file_name].margin
		_atlas_textures[file_name] = atlas_texture
	return _atlas_textures

func get_serialized_type():
	return "HBResourcePack"

static func load_from_directory(path: String):
	var meta_path = HBUtils.join_path(path, "resource_pack.json")
	var out = HBSerializable.from_file(meta_path)
	if out:
		out._path = path
	return out

func save_pack():
	return save_to_file(HBUtils.join_path(_path, "resource_pack.json"))

func get_atlas_path(atlas_name: String) -> String:
	var atlases_dir = HBUtils.join_path(_path, "atlases")
	return HBUtils.join_path(atlases_dir, atlas_name + "_atlas.png")

func get_atlas_image(atlas_name: String) -> Image:
	var path := get_atlas_path(atlas_name)
	var file := File.new()
	if file.file_exists(path):
		var img = Image.new()
		img.load(path)
		return img
	return null

func get_graphic_image(graphic_name: String) -> Image:
	var file := File.new()
	var file_path = HBUtils.join_path(_path, HBUtils.join_path("graphics", graphic_name))
	if file.file_exists(file_path):
		var img = Image.new()
		img.load(file_path)
		return img
	return null

func get_pack_icon_path() -> String:
	return HBUtils.join_path(_path, "icon.png")

func get_pack_icon() -> Image:
	var f := File.new()
	var pack_icon_path := get_pack_icon_path()
	if f.file_exists(pack_icon_path):
		var img = Image.new()
		if img.load(pack_icon_path) == OK:
			return img
	return null