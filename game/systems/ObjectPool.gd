extends RefCounted
class_name ObjectPool
## Pool generique (Phase 2). Le chemin chaud fait acquire / release + reset().
## queue_free n'est jamais appele ici : l'excedent reste parque, invisible.

var _free: Array[Node] = []
var _overflow: Array[Node] = []
var _make: Callable = Callable()
var _parent: Node = null
var _cap: int = 32

func setup(make: Callable, cap: int) -> void:
	_make = make
	_cap = maxi(1, cap)

## Cree `n` noeuds (bornes par le cap), enfants de `parent`, deja en reserve.
func prewarm(n: int, parent: Node) -> void:
	_parent = parent
	var count: int = mini(maxi(0, n), _cap)
	for _i in count:
		var node: Node = _make.call()
		if node.get_parent() == null:
			parent.add_child(node)
		_reset_node(node)
		_free.append(node)

func acquire() -> Node:
	var node: Node
	if not _free.is_empty():
		node = _free.pop_back()
	elif not _overflow.is_empty():
		node = _overflow.pop_back()
	else:
		node = _make.call()
		if _parent != null and node.get_parent() == null:
			_parent.add_child(node)
	return node

func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_reset_node(node)
	if _free.size() < _cap:
		_free.append(node)
	else:
		# Hors quota : on parque quand meme. Pas de queue_free sur le chemin chaud.
		_overflow.append(node)

func parked() -> int:
	return _free.size() + _overflow.size()

func _reset_node(node: Node) -> void:
	if node.has_method("reset"):
		node.reset()
	elif node.has_method("deactivate"):
		node.deactivate()
	else:
		node.visible = false
		node.set_process(false)
		node.set_physics_process(false)
