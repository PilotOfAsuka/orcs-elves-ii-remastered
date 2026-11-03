extends SceneTree

var session: OEGameSession
var failures: Array[String]=[]

func _initialize() -> void: call_deferred("run")

func original(owner: String, key: String, args: Array=[]) -> Variant:
	var main: Array[Dictionary]=session.vm.fibers.duplicate()
	session.vm.fibers.clear()
	var fiber: Dictionary=session.vm.launch(owner,key,null,args)
	for n in 20000:
		if fiber.frames.is_empty() or session.vm.halted: break
		session.vm.tick(20 if fiber.wake>session.vm.now_ms else 0)
	session.vm.fibers.assign(main)
	if not fiber.frames.is_empty(): failures.append("unfinished "+key)
	return fiber.result

func checksum(path: String) -> String:
	if not OESnapshot.new().save_game(session,path): failures.append("save");return ""
	return FileAccess.open(path,FileAccess.READ).get_var(false).checksum

func run() -> void:
	session=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	session.vm.max_slice=1000000
	var position: Array=[session.vm.get_static("a","h","I"),session.vm.get_static("a","i","I"),session.vm.get_static("a","j","I"),session.vm.get_static("a","k","I")]
	# Eight camera angles with selected palette effects at the captured position.
	var scenes: Array=[]
	for angle in [0,64,128,192,32,96,160,224]:
		var results: Array=[]
		for fast in [false,true]:
			OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2")
			session.vm.fast_render=true
			session.vm.fast_geometry=fast
			if angle%64!=0: session.vm.set_static("k","aQ","I",[4,128,1,8][angle/64])
			var began: int=Time.get_ticks_usec()
			var count: int=session.vm.instructions
			original("k","a(IIII)V",[position[0],position[1],position[2],angle])
			results.append({"us":Time.get_ticks_usec()-began,"instructions":session.vm.instructions-count,"graph":checksum("user://render-frame.oe2"),"pixels":var_to_bytes(session.vm.get_static("k","m","[I").data).hex_encode().sha256_text()})
		var equal: bool=results[0].pixels==results[1].pixels and results[0].graph==results[1].graph
		if not equal: failures.append("world angle "+str(angle))
		scenes.append({"angle":angle,"equal":equal,"bytecode":results[0],"accelerated":results[1]})
		print("SCENE ",angle," ",equal," ",results[0].us," -> ",results[1].us)
	var report: Dictionary={"comparisons":scenes.size(),"scenes":scenes,"failures":failures,"errors":session.vm.errors.duplicate()}
	FileAccess.open("res://../build/geometry_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	for path in ["user://render-frame.oe2"]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	session.close()
	quit(0 if failures.is_empty() else 1)
