extends ConfirmationDialog

onready var tree: Tree = get_node("VBoxContainer/VBoxContainer/Tree")
onready var create_icon_pack_dialog_text_edit = get_node("CreateIconPackDialog/TextEdit")

signal pack_opened(pack)

func populate_list(allow_builtin=false):
	tree.hide_root = true
	tree.clear()
	var root = tree.create_item()
	for pack_id in ResourcePackLoader.resource_packs:
		var pack: HBResourcePack = ResourcePackLoader.resource_packs[pack_id] as HBResourcePack
		if pack._path.begins_with("user://editor_resource_packs") or (allow_builtin and pack._path.begins_with("res://")):
			var item: TreeItem = tree.create_item(root)
			item.set_text(0, pack.pack_name)
			item.set_meta("pack", pack)
	if allow_builtin:
		var item: TreeItem = tree.create_item(root)
		item.set_text(0, ResourcePackLoader.fallback_pack.pack_name)
		item.set_meta("pack", ResourcePackLoader.fallback_pack)

func _ready():
	connect("about_to_show", self, "_on_about_to_show")
func _on_about_to_show():
	populate_list()

func _on_CreateIconPackDialog_confirmed():
	var file_name := HBUtils.get_valid_filename(create_icon_pack_dialog_text_edit.text) as String
	if file_name.strip_edges() != "":
		var dir := Directory.new()
		var meta_path = HBUtils.join_path("user://editor_resource_packs", file_name)
		if not dir.file_exists(meta_path):
			dir.make_dir_recursive(meta_path)
		var pack := HBResourcePack.new()
		pack.pack_name = create_icon_pack_dialog_text_edit.text
		pack._path = meta_path
		pack._id = file_name
		ResourcePackLoader.resource_packs[file_name] = pack
		pack.save_pack()
	populate_list()

func _on_OpenResourcePackDialog_confirmed():
	if tree.get_selected():
		emit_signal("pack_opened", tree.get_selected().get_meta("pack"))
		hide()

func _unhandled_input(event):
	if event.is_action_pressed("free_friends"):
		populate_list(true)