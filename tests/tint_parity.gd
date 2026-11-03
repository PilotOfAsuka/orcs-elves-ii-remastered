extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	var counts: Array=[0,1,7,8,9,16,97,session.vm.get_static("k","m","[I").data.size()]
	var failures: Array=[]
	var cases: Array=[]
	var full_timing: Array=[]
	for size: int in counts:
		var initial: Array=[]
		for index in size: initial.append([0,-1,2147483647,-2147483648,0xffffff,0x12345678][index%6])
		var results: Array=[]
		for fast in [false,true]:
			OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2")
			session.vm.get_static("k","m","[I").data.assign(initial)
			var began: int=Time.get_ticks_usec()
			if fast: session.vm.render_helpers.tint()
			else:
				var main: Array[Dictionary]=session.vm.fibers.duplicate()
				var next: int=session.vm.next_id
				session.vm.fibers.clear()
				var fiber: Dictionary=session.vm.launch("k","g()V")
				for tick in 10000:
					if fiber.frames.is_empty() or session.vm.halted: break
					session.vm.tick(0)
				if not fiber.frames.is_empty() or session.vm.halted: failures.append("unfinished")
				session.vm.fibers.assign(main);session.vm.next_id=next
			if size==counts[-1]: full_timing.append({"fast":fast,"us":Time.get_ticks_usec()-began})
			var path: String="user://tint-check.oe2"
			OESnapshot.new().save_game(session,path)
			results.append(FileAccess.open(path,FileAccess.READ).get_var(false).checksum)
		if results[0]!=results[1]: failures.append(size)
		cases.append({"base":initial,"expected":session.vm.get_static("k","m","[I").data.duplicate()})
	FileAccess.open("res://../build/tint_cases.json",FileAccess.WRITE).store_string(JSON.stringify(cases))
	print(JSON.stringify({"comparisons":counts.size(),"failures":failures,"errors":session.vm.errors.duplicate(),"full_frame_timing":full_timing}))
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://tint-check.oe2"+suffix): DirAccess.remove_absolute("user://tint-check.oe2"+suffix)
	session.close();quit(0 if failures.is_empty() else 1)
