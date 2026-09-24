class_name BusInteriorVisual
extends Node3D

@export var material: Material


func _ready() -> void:
	var model: Node = get_node_or_null("Model")
	var changed: int = VisualMaterialApplier.apply(model, material)
	if changed == 0:
		push_error("BusInteriorVisual: no MeshInstance3D received the interior material")
	if VisualMaterialApplier.carries_collision(self):
		push_error("BusInteriorVisual: visual GLB must not carry collision")
