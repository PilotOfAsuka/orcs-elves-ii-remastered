extends SceneTree

func _initialize() -> void: call_deferred("run")

func original(session: OEGameSession, key: String) -> Variant:
	var main: Array[Dictionary]=session.vm.fibers.duplicate()
	session.vm.fibers.clear()
	var fiber: Dictionary=session.vm.launch("k",key)
	for tick in 10000:
		if fiber.frames.is_empty() or session.vm.halted: break
		session.vm.tick(20 if fiber.wake>session.vm.now_ms else 0)
	session.vm.fibers.assign(main)
	return fiber.result

func run() -> void:
	var session:=OEGameSession.new(false)
	session.vm.max_slice=1000000
	var scenes: Array=[]
	var passed: bool=true
	for kind in ["shapes","texels"]:
		var states: Array=[]
		for fast in [false,true]:
			if not OESnapshot.new().load_game(session,"res://../build/fixtures/resource_"+kind+".oe2"): quit(1);return
			session.vm.fast_resources=fast
			var began: int=Time.get_ticks_usec()
			var instructions: int=session.vm.instructions
			var result: Variant=original(session,"d()Z" if kind=="shapes" else "b()Z")
			var elapsed: int=Time.get_ticks_usec()-began
			var path: String="user://resource-parity.oe2"
			if not OESnapshot.new().save_game(session,path): quit(1);return
			states.append({"us":elapsed,"instructions":session.vm.instructions-instructions,"result":result,"graph":FileAccess.open(path,FileAccess.READ).get_var(false).checksum,"errors":session.vm.errors.duplicate()})
		var equal: bool=states[0].graph==states[1].graph and states[0].result==states[1].result and states[0].errors.is_empty() and states[1].errors.is_empty()
		passed=passed and equal
		scenes.append({"resource":kind,"equal":equal,"bytecode":states[0],"accelerated":states[1]})
		print(JSON.stringify(scenes[-1]))
	FileAccess.open("res://../build/resource_parity.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"scenes":scenes},"\t"))
	for suffix in ["",".bak"]:
		var path: String="user://resource-parity.oe2"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	session.close()
	quit(0 if passed else 1)
