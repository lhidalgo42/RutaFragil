"""Right sliding-door frame/leaf and both cab side windows for blender_van.py.

Blender frame: +Y front, +Z up. The physical doorway is Blender y[1.30,2.20]
from the floor (z 0.20) to the header (z 2.10); the front wheel arch skirt
starts at y 2.05, so the leaf steps over it like a real van slider.
Window openings stay empty: the Godot wrapper adds the transparent panes.
"""

LEAF_BOTTOM = 0.24
ARCH_REAR_Y = 2.05
LEAF_FACE_X = 1.330


def author_side(box, flank, side_prism):
    """Fixed frame around the full-height doorway; returns the leaf part names."""
    flank("RightDoorHeader", 1, 1.27, 2.21, 2.05, 2.10, 0.008)
    flank("RightDoorRearJamb", 1, 1.25, 1.30, 0.10, 2.05, 0.006)
    flank("RightDoorFrontJamb", 1, 2.20, 2.25, 1.10, 2.05, 0.006)
    # Dark floor edge and the outside tread over the physical Step1/Step2 plates.
    box("RightDoorThreshold", 1.28, ARCH_REAR_Y, 0.10, 0.20, 1.12, 1.25, 0.006)
    box("RightDoorLowerSillTrim", 1.30, ARCH_REAR_Y, 0.00, 0.10, 1.14, 1.28, 0.006)
    # Jamb trims stay inboard of the popped leaf (x>=1.287) so it can slide past.
    box("RightDoorRearJambTrim", 1.245, 1.285, LEAF_BOTTOM, 2.04, 1.252, 1.282, 0.004)
    box("RightDoorFrontJambTrim", 2.215, 2.255, 1.10, 2.04, 1.282, 1.312, 0.004)
    box("RightDoorHeaderTrim", 1.27, 2.23, 2.052, 2.09, 1.282, 1.312, 0.004)
    # Top rail plus the classic waist track behind the door, both above the stripe.
    box("SlidingDoorRail", 0.30, 1.27, 2.055, 2.095, 1.26, 1.29, 0.006)
    box("SlidingDoorCenterRail", 0.30, 1.25, 1.19, 1.23, 1.25, 1.278, 0.004)

    # Stepped leaf, exported closed: full height behind the arch, notched above it.
    side_prism("SideDoorPanel", 1, ((1.30, LEAF_BOTTOM), (ARCH_REAR_Y, LEAF_BOTTOM),
                                    (ARCH_REAR_Y, 1.04), (2.20, 1.04), (2.20, 2.05),
                                    (1.30, 2.05)), LEAF_FACE_X - 1.252, LEAF_FACE_X - 1.25)
    # Shut-line strips sink 2 mm into the panel and overlap each other by a few mm:
    # no merged strip may share a vertex with the panel or a neighbour (glb_check winding).
    face = (LEAF_FACE_X - 0.002, LEAF_FACE_X + 0.004)
    shut_lines = (("Rear", 1.30, 1.315, LEAF_BOTTOM + 0.008, 2.042),
                  ("Top", 1.30, 2.20, 2.035, 2.05),
                  ("Bottom", 1.30, ARCH_REAR_Y, LEAF_BOTTOM, LEAF_BOTTOM + 0.015),
                  ("FrontLow", ARCH_REAR_Y - 0.015, ARCH_REAR_Y, LEAF_BOTTOM + 0.008, 1.048),
                  ("Step", ARCH_REAR_Y, 2.20, 1.04, 1.055),
                  ("FrontHigh", 2.185, 2.20, 1.048, 2.042))
    names = []
    for suffix, y0, y1, z0, z1 in shut_lines:
        names.append(box("SideDoorGasket" + suffix, y0, y1, z0, z1, *face, 0.0).name)
    # Body-colour pressed panels give the leaf depth without a fake black window.
    for suffix, z0, z1 in (("Upper", 1.37, 1.93), ("Lower", 0.34, 0.96)):
        names.append(box("SideDoorRib" + suffix, 1.40, 1.95, z0, z1,
                         LEAF_FACE_X, LEAF_FACE_X + 0.008, 0.004).name)
    names.append(box("SideDoorHandlePlate", 1.36, 1.56, 1.21, 1.33,
                     LEAF_FACE_X, LEAF_FACE_X + 0.006, 0.0).name)
    names.append(box("SideDoorHandle", 1.39, 1.53, 1.25, 1.29,
                     LEAF_FACE_X + 0.006, 1.356, 0.006).name)
    return ["SideDoorPanel"] + names


def author_cab_windows(box, flank):
    """Symmetric open driver/copilot windows framed by dark gaskets."""
    for side, prefix in ((-1, "Left"), (1, "Right")):
        flank(prefix + "CabRearPillar", side, 2.21 if side < 0 else 2.25, 2.34, 1.24, 2.06, 0.010)
        flank(prefix + "CabAPillar", side, 3.60, 3.82, 1.24, 2.06, 0.010)
        xs = (1.19, 1.262) if side > 0 else (-1.262, -1.19)
        # Uprights overlap the sill/header by 1 cm so no two strips share a vertex.
        for suffix, y0, y1, z0, z1 in (("Lower", 2.34, 3.60, 1.24, 1.28),
                                       ("Upper", 2.34, 3.60, 2.00, 2.05),
                                       ("Rear", 2.34, 2.38, 1.27, 2.01),
                                       ("Front", 3.56, 3.60, 1.27, 2.01)):
            box("%sCabWindowGasket%s" % (prefix, suffix), y0, y1, z0, z1, *xs, 0.0)
