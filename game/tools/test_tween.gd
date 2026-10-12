extends SceneTree
func _init():
    var n = Node.new()
    var t = n.create_tween()
    print("Has set_pause_mode: ", t.has_method("set_pause_mode"))
    quit()
