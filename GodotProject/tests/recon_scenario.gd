extends SceneTree

func _initialize() -> void:
	call_deferred("scenario")

func scenario() -> void:
	var session = load("res://main.tscn").instantiate()
	root.add_child(session)
	await process_frame
	session.start("recon")
	for hazard in session.hazards:
		hazard.mark = true
	for i in 5000:
		if not session.active:
			break
		# Keep Hornet nearby while the AI convoy follows the route and clears the marked hazards.
		var distance: float = session.primary.distance
		session.drone.position = session.road.at(distance+15)+Vector3.UP*22
		session.time_run += .1
		session.step_traffic(.1)
		if i%12==0:
			await physics_frame
	var success: bool = not session.active and session.primary.distance >= session.road.plan.finish
	print("RECON_SCENARIO ",success," distance=",session.primary.distance," cabin=",session.primary.cabin_health)
	for h in session.hazards:
		print("HAZARD ",h.at," remaining=",h.hp)
	session.dispose()
	await create_timer(.2).timeout
	quit(0 if success else 1)
