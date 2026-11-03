extends SceneTree

var session: OEGameSession
var samples: Dictionary={}
var failures: Array[String]=[]
var comparisons: int=0

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

func observe(key: String, args: Array) -> void:
	if samples.has(key): return
	var path: String="res://../build/fixtures/span_"+key.sha256_text().substr(0,12)+".oe2"
	if not OESnapshot.new().save_game(session,path): failures.append("capture "+key)
	samples[key]={"args":args.duplicate(),"path":path}

func checksum(path: String) -> String:
	if not OESnapshot.new().save_game(session,path): failures.append("save");return ""
	return FileAccess.open(path,FileAccess.READ).get_var(false).checksum

func kernel(key: String, args: Array, mode: int, effects: int=-1) -> void:
	var sample: Dictionary=samples[key]
	var results: Array=[]
	for fast in [false,true]:
		OESnapshot.new().load_game(session,sample.path)
		session.vm.fast_render=false
		if key=="b(IIII)V": session.vm.set_static("k","ba","I",mode)
		if effects>=0: session.vm.set_static("k","aQ","I",effects)
		var value: Variant
		if fast: value=session.vm.render_helpers.invoke(key,args)
		else:
			# Direct helper calls do not allocate fibers; use the same wrapper for both.
			var next: int=session.vm.next_id
			value=original("k",key,args)
			session.vm.next_id=next
		results.append({"graph":checksum("user://render-kernel.oe2"),"value":value})
	comparisons+=1
	if results[0]!=results[1]: failures.append(str([key,args,mode,effects]))

func run() -> void:
	session=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	session.vm.max_slice=1000000
	session.vm.fast_render=false
	session.vm.span_observer=observe
	var position: Array=[session.vm.get_static("a","h","I"),session.vm.get_static("a","i","I"),session.vm.get_static("a","j","I"),session.vm.get_static("a","k","I")]
	original("k","a(IIII)V",position)
	session.vm.fast_render=true
	session.key(54)
	for tick in 30: session.tick(50)
	session.vm.span_observer=Callable()
	print("CAPTURED ",samples.keys())
	if not samples.has("a(IIIIIIII)Z"): failures.append("missing weapon sprite capture")
	for key: String in samples:
		var args: Array=samples[key].args
		if key=="b(II)V":
			for effects in [0,1,4,8,16,32,64,128,256,508,511]:
				for mode in [0,1,2,3,4,5,6,7,8,9,255]: kernel(key,[args[0],mode],mode,effects)
			continue
		if key=="a(IIIIIIII)Z":
			for flags in [0,0x20000,0x40000,0x60000]:
				var variant: Array=args.duplicate();variant[6]=flags
				kernel(key,variant,0)
			continue
		if key in ["f()Z","h()Z"]:
			kernel(key,args,0);continue
		var index: int=4 if key=="a(IIIII)V" else 3
		var counts: Dictionary={}
		for count in [0,1,7,8,9,int(args[index])]: counts[mini(count,int(args[index]))]=true
		for count: Variant in counts:
			var variant: Array=args.duplicate()
			variant[index]=count
			if key=="a(IIIII)V": kernel(key,variant,0)
			else:
				for mode in [0,1,3,4,8,9,2,255]: kernel(key,variant,mode)
	# Whole world painters at the real position, four directions and a nearby position.
	var scenes: Array=[]
	for angle in [0,64,128,192,32,96,160,224]:
		var results: Array=[]
		for fast in [false,true]:
			OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2")
			session.vm.fast_render=fast
			if angle%64!=0: session.vm.set_static("k","aQ","I",[4,128,1,8][angle/64])
			var began: int=Time.get_ticks_usec()
			var count: int=session.vm.instructions
			original("k","a(IIII)V",[position[0],position[1],position[2],angle])
			results.append({"us":Time.get_ticks_usec()-began,"instructions":session.vm.instructions-count,"graph":checksum("user://render-frame.oe2"),"pixels":var_to_bytes(session.vm.get_static("k","m","[I").data).hex_encode().sha256_text()})
		var equal: bool=results[0].pixels==results[1].pixels and results[0].graph==results[1].graph
		if not equal: failures.append("world angle "+str(angle))
		scenes.append({"angle":angle,"equal":equal,"bytecode":results[0],"accelerated":results[1]})
		print("SCENE ",angle," ",equal," ",results[0].us," -> ",results[1].us)
	var report: Dictionary={"samples":samples,"comparisons":comparisons,"scenes":scenes,"failures":failures,"errors":session.vm.errors.duplicate()}
	FileAccess.open("res://../build/render_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	for path in ["user://render-kernel.oe2","user://render-frame.oe2"]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	session.close()
	quit(0 if failures.is_empty() else 1)
