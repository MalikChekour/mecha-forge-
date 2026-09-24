extends Node
func _ready() -> void:
	var ms := MetaScreen.new()
	get_tree().root.add_child(ms)
	ms.call("_build_garage")
	await get_tree().process_frame
	# compter les lignes reellement dans l'arbre + verifier le texte du titre
	var titres: Array = []
	_collecte_labels(ms, titres)
	print("labels trouves : ", titres.size())
	for t in titres:
		print("  -> ", t)
	get_tree().quit(0)

func _collecte_labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collecte_labels(c, out)
