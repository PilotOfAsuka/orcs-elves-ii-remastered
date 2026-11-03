extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game:=OEGameSession.new(false)
	var presenter:=OEPresentationState.new(game.vm)
	if not OESnapshot.new().load_game(game,"res://../build/fixtures/world.oe2"): quit(1);return
	var transitions: Array=[]
	var last: int=-1
	var last_key: int=-30
	var captures: Dictionary={}
	var walk: int=0
	for tick in 600:
		game.tick(25)
		if game.vm.halted: break
		var state: int=game.vm.get_static("a","H","I")
		if state!=last:
			transitions.append({"state":state,"tick":tick,"cinematic":presenter.cinematic()});last=state
		if state==17 and not captures.has("cinematic"):
			captures.cinematic=OESnapshot.new().save_game(game,"res://../build/fixtures/cinematic_012.oe2")
		if state==7 and tick>30 and not captures.has("scene_dialogue"):
			captures.scene_dialogue=OESnapshot.new().save_game(game,"res://../build/fixtures/scene_dialogue_012.oe2")
		if tick-last_key<28: continue
		if state==3 and walk<5:
			game.key(50);walk+=1;last_key=tick
		elif state==7:
			game.key(53);last_key=tick
	var report: Dictionary={"transitions":transitions,"captures":captures,"errors":game.vm.errors.duplicate()}
	FileAccess.open("res://../build/cinematic_journey.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));game.close();quit()
