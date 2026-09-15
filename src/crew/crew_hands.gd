class_name CrewHands
extends Node

## The crew's hands (D82, D83, D86): one package at a time, following the
## HandAnchor (child of the eye camera, so the hold pitches with the look).
##
## E is a DURATION detector measured in ticks (D86): tap = grab / unstrap /
## seat; hold (strap_hold_seconds, with a package in hand and a free anchor
## in reach) = strap. strap_progress(fraction) is emitted while holding, for
## the future HUD (D29). PRIORITY with a package in hand: an E tap targets
## anchors or nothing — the seat is REJECTED with a print and no effect
## (nobody drives while carrying). An E tap on a STRAPPED package with an
## empty hand unstraps it back to the hand.
## throw (left click) / drop (right click) only act with the pointer
## captured; a click with a FREE pointer only re-captures (crew_input owns
## capture) and NEVER throws.

signal strap_progress(fraction: float)

var held: Package = null


## Grabs the nearest FREE package within interaction_reach_m of the eye ray.
## Precondition: held == null.
func try_grab() -> bool:
	return false


## Releases the held package with care: at the hand point if the box fits
## there (overlap test), else at the feet on the floor; velocity = the
## bus-point velocity (v + w x r) so it is not slammed. Package.release()
## owns the place-then-enable order.
func drop() -> void:
	pass


## Throws: velocity = camera forward * package_throw_speed_mps + the
## bus-point velocity. The composition is a PURE function, tested without
## physics.
func throw() -> void:
	pass


## Starts the strap hold (E held with a package in hand and a free anchor in
## reach). Emits strap_progress as the hold accumulates in physics ticks.
func begin_strap() -> void:
	pass


## Cancels the hold (E released before strap_hold_seconds) — nothing changes.
func cancel_strap() -> void:
	pass
