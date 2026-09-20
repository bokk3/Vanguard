extends SceneTree

func _init() -> void:
	var drone_script = load("res://target_drone.gd")
	var d = Node3D.new()
	d.set_script(drone_script)
	root.add_child(d)
	# In SceneTree headless scripts, _ready is not called immediately in _init unless forced or during process
	d._ready()
	print("drone children count after _ready():", d.get_child_count())
	for c in d.get_children():
		print(" - child:", c.name, " type:", c.get_class())
	quit(0)
