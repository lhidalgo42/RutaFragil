class_name RestraintAnchor
extends Marker3D

## A restraint anchor (D69/D84): one package per anchor. The twelve anchors
## live as Marker3D under BusInterior/Restraints (restraint_left_0..5,
## restraint_right_0..5); agent C gives them this script and the
## "restraint_anchor" group via a TEXT edit of bus_interior.tscn (never the
## editor — the round-3 incident).

var occupant: Package = null


func is_free() -> bool:
	return occupant == null
