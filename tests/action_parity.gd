extends SceneTree

func _initialize() -> void: call_deferred("run")

func ready(vm: OEVM) -> bool:
	for fiber: Dictionary in vm.fibers:
		if not fiber.frames.is_empty() and fiber.waiting==null and int(fiber.wake)<=vm.now_ms: return true
	return false

func run() -> void:
	var session:=OEGameSession.new(false)
	var results: Array=[]
	var fixture: String="res://../build/fixtures/action_base.oe2"
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://../build/fixtures/world.oe2"),ProjectSettings.globalize_path(fixture))
	for fast in [false,true]:
		if not OESnapshot.new().load_game(session,fixture): quit(1);return
		session.vm.fast_render=fast
		session.vm.fast_font=fast
		session.vm.fast_resources=fast
		session.platform.fast_rgb=fast
		var started: int=Time.get_ticks_usec()
		var steps: Array=[]
		for key in [54,53,50]:
			var began: int=Time.get_ticks_usec()
			session.key(key)
			# Freeze the virtual clock while CPU work is unfinished. Both implementations
			# receive exactly the same input and clock, independent of interpreter slices.
			for clock_step in 4:
				session.tick(50)
				for slice in 10000:
					if not ready(session.vm) or session.vm.halted: break
					session.tick(0)
			steps.append({"key":key,"us":Time.get_ticks_usec()-began,"state":session.report().state})
			print("ACTION ",fast," ",JSON.stringify(steps[-1]))
			if session.vm.halted: break
		var path: String="user://action-parity.oe2"
		OESnapshot.new().save_game(session,path)
		results.append({"us":Time.get_ticks_usec()-started,"actions":steps,"graph":FileAccess.open(path,FileAccess.READ).get_var(false).checksum,"errors":session.vm.errors.duplicate()})
	var equal: bool=results[0].graph==results[1].graph and results[0].errors.is_empty() and results[1].errors.is_empty()
	var report: Dictionary={"equal":equal,"bytecode":results[0],"accelerated":results[1]}
	FileAccess.open("res://../build/action_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	for suffix in ["",".bak"]:
		var path: String="user://action-parity.oe2"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	session.close()
	quit(0 if equal else 1)
