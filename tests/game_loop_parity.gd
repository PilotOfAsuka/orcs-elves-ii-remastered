extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session:=OEGameSession.new(false)
	var failures: Array=[]
	var count: int=0
	for live in [0,1]:
		for slot in [1,7,19]:
			for mask in [0,268435456]:
				OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2")
				session.vm.fast_resources=false;session.vm.fast_geometry=false
				var pool: Array=session.vm.get_static("l","a","[Lc;").data
				for entry: JObject in pool: session.vm.set_field(entry,"c","a","Z",0)
				session.vm.set_static("l","v","I",1)
				session.vm.set_field(pool[slot],"c","a","Z",live)
				session.vm.get_field(pool[slot],"c","a","[I").data[8]=mask
				var main: Array[Dictionary]=session.vm.fibers.duplicate()
				session.vm.fibers.clear()
				var check: Dictionary=session.vm.launch("l","e()Z")
				for n in 10000:
					if check.frames.is_empty(): break
					session.vm.step(check)
				var value: Variant=session.vm.geometry.invoke("l.e()Z",[])
				if value!=check.result: failures.append([live,slot,mask,"return"])
				count+=1
				# Stop at the loop entry before executing a live script callback.
				session.vm.fibers.clear()
				var fiber: Dictionary=session.vm.launch("l","b(I)V",null,[123])
				for n in 10000:
					session.vm.step(fiber)
					if fiber.frames.back().pc==5 and fiber.frames.back().last==55: break
				OESnapshot.new().save_game(session,"user://loop-base.oe2")
				var sums: Array=[]
				for fast in [false,true]:
					OESnapshot.new().load_game(session,"user://loop-base.oe2")
					var current: Dictionary=session.vm.fibers[0]
					if fast: session.vm.resource_helpers.inactive_threads(current.frames.back())
					else:
						for n in 10000:
							session.vm.step(current)
							if current.frames.back().pc in [16,56]: break
					OESnapshot.new().save_game(session,"user://loop-result.oe2")
					sums.append(FileAccess.open("user://loop-result.oe2",FileAccess.READ).get_var(false).checksum)
				if sums[0]!=sums[1]: failures.append([live,slot,mask,"frame"])
				count+=1
	print(JSON.stringify({"comparisons":count,"failures":failures}))
	for path in ["user://loop-base.oe2","user://loop-result.oe2"]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	session.close();quit(0 if failures.is_empty() else 1)
