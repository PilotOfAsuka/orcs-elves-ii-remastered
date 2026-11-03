extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(390,844)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ui=load("res://main.tscn").instantiate()
	ui.testing=true
	ui.paused=true
	viewport.add_child(ui)
	var shots: Array=[]
	for sample in [["world",390,844,0],["world",390,844,1],["world",1280,720,1],["dialogue",390,844,0],["story",390,844,0]]:
		if not OESnapshot.new().load_game(ui.session,"res://../build/fixtures/"+str(sample[0])+".oe2"): quit(1);return
		if sample[0]!="world":
			ui.session.key(-7 if sample[0]=="story" else 53)
			for n in 12: ui.session.tick(50)
		viewport.size=Vector2i(sample[1],sample[2])
		ui._process(0.0)
		ui.set_render_mode(sample[3])
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var path: String="res://../build/preview_%s_%dx%d_%d.png" % [sample[0],sample[1],sample[2],sample[3]]
		var result: Error=viewport.get_texture().get_image().save_png(path)
		shots.append({"path":path,"error":result,"state":ui.session.report().state})
	ui.queue_free()
	await process_frame
	viewport.queue_free()
	print(JSON.stringify(shots))
	quit()
