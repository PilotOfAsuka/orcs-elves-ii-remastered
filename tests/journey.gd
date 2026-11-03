extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../build/fixtures"))
	var session:=OEGameSession.new(false)
	var phase: int=0
	var last_key: int=-100
	var story_saved: bool=false
	var dialogue_saved: bool=false
	var world_saved: bool=false
	for tick in 1600:
		session.tick(50)
		if session.vm.halted: break
		var state: int=session.vm.get_static("a","H","I")
		var menu: int=session.vm.get_static("w","g","I")
		var settled: bool=session.vm.fibers.size()==1 and session.vm.fibers[0].frames.size()==1
		if state in [8,13] and settled and not story_saved:
			story_saved=OESnapshot.new().save_game(session,"res://../build/fixtures/story.oe2")
		if state==7 and settled and session.platform.screen.extra.has("world_surface") and not dialogue_saved:
			dialogue_saved=OESnapshot.new().save_game(session,"res://../build/fixtures/dialogue.oe2")
		if state==3 and settled and session.platform.screen.extra.has("world_surface"):
			world_saved=OESnapshot.new().save_game(session,"res://../build/fixtures/world.oe2")
			session.platform.screen.extra.world_surface.save_png("res://../build/world-only.png")
			print("HUD ",JSON.stringify(OEPresentationState.new(session.vm).hud()))
			break
		if tick-last_key<15: continue
		if state==2 and menu==20:
			if phase==0: session.key(56);phase=1;last_key=tick
			elif phase==1: session.key(53);phase=2;last_key=tick
		elif state==2 and menu==3 and phase==2: session.key(53);phase=3;last_key=tick
		elif state==2 and menu==16 and phase==3: session.key(53);phase=4;last_key=tick
		elif state in [8,13] and story_saved: session.key(-7);last_key=tick
		elif state==7 and dialogue_saved: session.key(53);last_key=tick
		if tick%100==0: print("TICK ",tick," ",JSON.stringify(session.report()))
	var report: Dictionary=session.report()
	report.fixtures={"story":story_saved,"dialogue":dialogue_saved,"world":world_saved}
	FileAccess.open("res://../build/journey.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	session.close()
	quit(0 if world_saved else 1)
