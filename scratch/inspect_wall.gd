extends SceneTree

func _init() -> void:
	var path = "res://assets/meshes/environment/Modular_SciFi_Wall_01_game_ready.fbx"
	print("Loading: ", path)
	var scene = load(path)
	if scene == null:
		print("ERROR: Could not load scene!")
		quit(1)
		return
	var inst = scene.instantiate()
	print("Root node: ", inst.name, " (", inst.get_class(), ")")
	_print_tree(inst, 1)
	quit(0)

func _print_tree(node: Node, depth: int) -> void:
	var prefix = "  ".repeat(depth)
	var aabb_str = ""
	if node is VisualInstance3D:
		aabb_str = " AABB: " + str(node.get_aabb())
	print(prefix, "- ", node.name, " [", node.get_class(), "]", aabb_str)
	for c in node.get_children():
		_print_tree(c, depth + 1)
