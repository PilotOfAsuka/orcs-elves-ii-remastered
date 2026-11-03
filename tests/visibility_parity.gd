extends SceneTree
var game: OEGameSession
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func original(owner: String,key: String,args: Array=[]) -> void:
	var main: Array[Dictionary]=game.vm.fibers.duplicate();game.vm.fibers.clear()
	var fiber: Dictionary=game.vm.launch(owner,key,null,args)
	for n in 20000:
		if fiber.frames.is_empty() or game.vm.halted: break
		game.vm.tick(20 if int(fiber.wake)>game.vm.now_ms else 0)
	game.vm.fibers.assign(main)
	if not fiber.frames.is_empty(): failures.append("unfinished "+key)
func signature() -> Dictionary:
	OESnapshot.new().save_game(game,"user://visibility-proof.oe2")
	return {"graph":FileAccess.open("user://visibility-proof.oe2",FileAccess.READ).get_var(false).checksum,"pixels":var_to_bytes(game.vm.get_static("k","m","[I").data).hex_encode().sha256_text(),"errors":game.vm.errors.duplicate()}
func run() -> void:
	game=OEGameSession.new(false)
	var results: Array=[]
	# Derive a world checkpoint through the original Return to game path.
	OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_015.oe2")
	var closing: Dictionary=game.vm.launch("w","b(I)V",null,[0])
	for n in 1000:
		game.tick(20)
		if closing.frames.is_empty(): break
	if int(game.vm.get_static("a","H","I"))!=3: failures.append("resume user world")
	OESnapshot.new().save_game(game,"res://../build/fixtures/user_world_015.oe2")
	# Exact full images and full state, with the previous renderer as reference.
	for fixture in ["world","user_f9_014","user_world_015"]:
		for angle in [0,32,64,96,128,160,192,224]:
			var pair: Array=[]
			for fast in [false,true]:
				OESnapshot.new().load_game(game,"res://../build/fixtures/"+fixture+".oe2")
				game.vm.render_helpers.fast_visibility=fast
				var began: int=Time.get_ticks_usec()
				original("k","a(IIII)V",[game.vm.get_static("a","h","I"),game.vm.get_static("a","i","I"),game.vm.get_static("a","j","I"),angle])
				var elapsed: int=Time.get_ticks_usec()-began
				pair.append(signature());pair[-1].us=elapsed
			var equal: bool=pair[0].graph==pair[1].graph and pair[0].pixels==pair[1].pixels and pair[0].errors==pair[1].errors
			if not equal: failures.append(str([fixture,angle]))
			results.append({"fixture":fixture,"angle":angle,"equal":equal,"results":pair});print("VISIBILITY ",fixture," ",angle," ",equal," ",pair[0].us," -> ",pair[1].us)
	# Exhaustive small depth ranges, including sentinels before/inside/after.
	var depth: JObject=game.vm.new_array("[I",32);game.vm.set_static("k","p","[I",depth)
	var cases: int=0
	for sentinel in range(-1,32):
		depth.data.fill(7)
		if sentinel>=0: depth.data[sentinel]=2147483647
		for start in 33:
			for end in 33:
				var expected: int=1
				for n in range(start,end):
					if int(depth.data[n])==2147483647: expected=0;break
				if game.vm.render_helpers.visibility_scan(start,end)!=expected: failures.append("range "+str([sentinel,start,end]))
				cases+=1
	for span in [[-1,1],[0,33],[33,34]]:
		if game.vm.render_helpers.visibility_scan(span[0],span[1])!=null: failures.append("fallback "+str(span))
	game.vm.set_static("k","p","[I",null)
	if game.vm.render_helpers.visibility_scan(0,1)!=null: failures.append("null fallback")
	if game.vm.render_helpers.visibility_scan(0,0)!=1: failures.append("empty does not read null")
	var report: Dictionary={"comparisons":results.size(),"ranges":cases,"failures":failures,"results":results}
	FileAccess.open("res://../build/visibility_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify({"comparisons":results.size(),"ranges":cases,"failures":failures}))
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://visibility-proof.oe2"+suffix): DirAccess.remove_absolute("user://visibility-proof.oe2"+suffix)
	game.close();quit(0 if failures.is_empty() else 1)
