extends SceneTree
var failures: Array[String]=[]
var game: OEGameSession
func _initialize() -> void: call_deferred("run")
func runnable() -> bool:
	for fiber: Dictionary in game.vm.fibers:
		if not fiber.frames.is_empty() and fiber.waiting==null and int(fiber.wake)<=game.vm.now_ms: return true
	return false
func graph() -> String:
	OESnapshot.new().save_game(game,"user://sprite-setup-parity.oe2")
	return FileAccess.open("user://sprite-setup-parity.oe2",FileAccess.READ).get_var(false).checksum
func original(key: String,args: Array) -> void:
	var main: Array[Dictionary]=game.vm.fibers.duplicate();game.vm.fibers.clear()
	var fiber: Dictionary=game.vm.launch("k",key,null,args)
	for n in 20000:
		if fiber.frames.is_empty() or game.vm.halted: break
		game.vm.tick(0)
	if not fiber.frames.is_empty(): failures.append("unfinished "+key)
	game.vm.fibers.assign(main)
func result() -> Dictionary:
	return {"graph":graph(),"pixels":var_to_bytes(game.vm.get_static("k","m","[I").data).hex_encode().sha256_text(),"errors":game.vm.errors.duplicate()}
func run() -> void:
	game=OEGameSession.new(false)
	var rows: Array=[]
	for fixture in ["world","user_f9_014"]:
		for angle in [0,32,64,96,128,160,192,224]:
			var results: Array=[]
			for fast in [false,true]:
				OESnapshot.new().load_game(game,"res://../build/fixtures/"+fixture+".oe2")
				game.vm.max_slice=1000000;game.vm.fast_sprite_setup=fast;game.vm.fast_tiled_paint=fast
				if angle%64!=0: game.vm.set_static("k","aQ","I",[4,128,1,8][angle/64])
				original("a(IIII)V",[game.vm.get_static("a","h","I"),game.vm.get_static("a","i","I"),game.vm.get_static("a","j","I"),angle])
				results.append(result())
			var equal: bool=results[0]==results[1]
			if not equal: failures.append(str([fixture,angle]))
			rows.append({"fixture":fixture,"angle":angle,"equal":equal,"results":results})
			print("SPRITE ",fixture," ",angle," ",equal)
	# Replay real player actions and all callbacks, with the identical game clock.
	for key in [54,52,50,56,53,57]:
		var results: Array=[]
		for fast in [false,true]:
			OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_014.oe2")
			game.vm.fast_sprite_setup=fast;game.vm.fast_tiled_paint=fast;game.key(key)
			for clock_step in 6:
				game.tick(50)
				for slice in 10000:
					if not runnable() or game.vm.halted: break
					game.tick(0)
			results.append(result())
		var equal: bool=results[0]==results[1]
		if not equal: failures.append("action "+str(key))
		rows.append({"key":key,"equal":equal,"results":results});print("ACTION ",key," ",equal)
	# Exceptions must unwind the same live JVM frame at the same instruction.
	var ref: Dictionary={"owner":"k","name":"g","desc":"(I)V","params":["I"],"return":"V"}
	game.vm.classes.k.methods["qaSprite()V"]={"name":"qaSprite","desc":"()V","params":[],"return":"V","max_locals":0,"flags":8,"exceptions":[{"start":0,"end":1,"handler":2,"type":null}],"code":[[184,ref],[177],[87],[177]]}
	for invalid in ["negative","bounds","null_flags","null_positions"]:
		var results: Array=[]
		for fast in [false,true]:
			OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_014.oe2")
			game.vm.fast_sprite_setup=fast
			if invalid=="null_flags": game.vm.set_static("k","b","[I",null)
			if invalid=="null_positions": game.vm.set_static("k","b","[S",null)
			var main: Array[Dictionary]=game.vm.fibers.duplicate();game.vm.fibers.clear()
			var fiber: Dictionary=game.vm.launch("k","qaSprite()V")
			fiber.frames.back().stack.append(-1 if invalid=="negative" else (65535 if invalid=="bounds" else 0))
			for n in 10000:
				if fiber.frames.is_empty() or game.vm.halted: break
				game.vm.tick(0)
			game.vm.fibers.assign(main);results.append(result())
		var equal: bool=results[0]==results[1]
		if not equal: failures.append("exception "+invalid)
		rows.append({"invalid":invalid,"equal":equal,"results":results});print("EXCEPTION ",invalid," ",equal)
	var report: Dictionary={"comparisons":rows.size(),"failures":failures,"results":rows}
	FileAccess.open("res://../build/sprite_setup_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify({"comparisons":rows.size(),"failures":failures}))
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://sprite-setup-parity.oe2"+suffix): DirAccess.remove_absolute("user://sprite-setup-parity.oe2"+suffix)
	game.close();quit(0 if failures.is_empty() else 1)
