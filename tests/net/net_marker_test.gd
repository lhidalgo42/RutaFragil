extends GdUnitTestSuite

## NetMarker (D55, plan M0-T0.4 step 2): the replicated spawn marker exposes
## the peer id it was spawned for.


func test_owner_peer_id_is_stored() -> void:
	var marker: NetMarker = auto_free(NetMarker.new())
	marker.owner_peer_id = 12345
	assert_int(marker.owner_peer_id).is_equal(12345)
