extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ui = load("res://main.tscn").instantiate()
	ui.testing = true
	ui.paused = true
	root.add_child(ui)
	for n in 150: ui.session.tick(50)
	var paths := ["user://presentation-before.oe2","user://presentation-after.oe2"]
	var failures: Array[String] = []
	if not OESnapshot.new().save_game(ui.session,paths[0]): failures.append("before save")
	var instructions: int = ui.session.vm.instructions
	ui.set_render_mode(1)
	await create_timer(0.3).timeout
	if ui.selected_mode!=1 or ui.remastered_view.modulate.a<0.99: failures.append("Remastered transition")
	ui.set_render_mode(0)
	await create_timer(0.3).timeout
	if ui.remastered_view.modulate.a>0.01: failures.append("Classic transition")
	if ui.session.vm.instructions!=instructions: failures.append("render switch advanced VM")
	if not OESnapshot.new().save_game(ui.session,paths[1]): failures.append("after save")
	var a: Dictionary = FileAccess.open(paths[0],FileAccess.READ).get_var(false)
	var b: Dictionary = FileAccess.open(paths[1],FileAccess.READ).get_var(false)
	if a.checksum!=b.checksum: failures.append("render switch changed original state")
	for dims in [Vector2(360,640),Vector2(390,844),Vector2(1280,720),Vector2(1920,1080)]:
		ui.size=dims
		ui.arrange()
		if ui.view_frame.position.x<0 or ui.view_frame.position.y<0: failures.append("world outside viewport")
		if ui.controls.position.y+ui.controls.size.y>dims.y: failures.append("controls outside viewport")
		if ui.keypad.visible and ui.auxiliary.visible and ui.keypad.position.y+ui.keypad.size.y>ui.auxiliary.position.y: failures.append("overlapping controls")
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	ui.queue_free()
	await process_frame
	print(JSON.stringify({"failures":failures,"render_switch_state_unchanged":a.checksum==b.checksum}))
	quit(0 if failures.is_empty() else 1)
