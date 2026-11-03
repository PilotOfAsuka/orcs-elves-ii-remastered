extends SceneTree
## Numeric oracle plus selected full-graph checks against original 2D bytecode.
var session: OEGameSession
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func b64(values: Array) -> String: return Marshalls.raw_to_base64(PackedInt32Array(values).to_byte_array())
func digest(values: Array) -> String: return PackedInt32Array(values).to_byte_array().hex_encode().sha256_text()
func graph() -> String:
	var path: String="user://weapon-parity.oe2"
	if not OESnapshot.new().save_game(session,path): failures.append("save");return ""
	return FileAccess.open(path,FileAccess.READ).get_var(false).checksum
func original(args: Array) -> Variant:
	var main: Array[Dictionary]=session.vm.fibers.duplicate()
	var next: int=session.vm.next_id
	session.vm.fibers.clear()
	var f: Dictionary=session.vm.launch("k","a(IIIIIIII)Z",null,args)
	for tick in 10000:
		if f.frames.is_empty() or session.vm.halted: break
		session.vm.tick(0)
	if not f.frames.is_empty() or session.vm.halted: failures.append("unfinished original")
	session.vm.fibers.assign(main);session.vm.next_id=next
	return f.result
func run() -> void:
	session=OEGameSession.new(false)
	var fixture: String="res://../build/fixtures/span_"+"a(IIIIIIII)Z".sha256_text().substr(0,12)+".oe2"
	if not OESnapshot.new().load_game(session,fixture): quit(1);return
	session.vm.max_slice=1000000
	var vm: OEVM=session.vm
	var pixels: Array=vm.get_static("k","m","[I").data
	var palette: Array=vm.get_static("k","q","[I").data
	var lower: Array=vm.get_static("k","n","[I").data
	var upper: Array=vm.get_static("k","o","[I").data
	var initial: Array=pixels.duplicate()
	var initial_palette: Array=palette.duplicate()
	var initial_lower: Array=lower.duplicate()
	var initial_upper: Array=upper.duplicate()
	var fields: Dictionary={}
	for key in ["aX","aQ","ba"]: fields[key]=vm.get_static("k",key,"I")
	var variants: Array=[]
	var base: Array=[1,0,231,-11,0,0,0,0]
	for flags in [0,0x20000,0x40000,0x60000]:
		for scale in [0,64,112,192,256,384]:
			for mode in [0,1,3,4,5,6,7,8,9,255]:
				var args: Array=base.duplicate();args[4]=mode;args[6]=flags;args[7]=scale
				variants.append({"args":args,"clip":[initial_lower,initial_upper]})
	for offset in [[0,-11],[351,-11],[176,40],[176,-70]]:
		for flags in [0,0x20000,0x40000,0x60000]:
			var args: Array=base.duplicate();args[2]=offset[0];args[3]=offset[1];args[6]=flags
			variants.append({"args":args,"clip":[initial_lower,initial_upper],"oracle":true})
	for effects in [4,8,128,256]:
		for mode in [0,1,4,8,9]:
			var args: Array=base.duplicate();args[4]=mode;args[5]=effects
			variants.append({"args":args,"clip":[[20,24],[330,int(initial_upper[1])-16]],"oracle":true})
	var sprite_table: Array=vm.get_static("k","j","[S").data
	for frame in range(1,mini(4,int(sprite_table[2])-int(sprite_table[1]))):
		for flags in [0,0x20000,0x40000,0x60000]:
			var args: Array=base.duplicate();args[1]=frame;args[6]=flags
			variants.append({"args":args,"clip":[initial_lower,initial_upper],"oracle":true})
	var cases: Array=[]
	var full_checks: int=0
	for v: Dictionary in variants:
		pixels.assign(initial);palette.assign(initial_palette);lower.assign(v.clip[0]);upper.assign(v.clip[1])
		for key: String in fields: vm.set_static("k",key,"I",fields[key])
		var value: bool=vm.render_helpers.sprite_2d(v.args)
		if vm.exception!=null or vm.halted: failures.append(str(v.args));break
		var sprites: Array=vm.get_static("k","j","[S").data
		var materials: Array=vm.get_static("k","i","[S").data
		var material: int=int(sprites[int(v.args[0])])+int(v.args[1])
		var input: Dictionary={"shape":materials[material*2],"width":vm.get_static("k","b","I"),"height":vm.get_static("k","c","I"),"x":v.args[2],"y":v.args[3],"scale":v.args[7],"flags":v.args[6],"mode":vm.get_static("k","ba","I"),"palette":palette.duplicate(),"lower":lower.duplicate(),"upper":upper.duplicate()}
		cases.append({"input":input,"expected":digest(pixels),"value":int(value)})
		# Check original geometry for every scale/flip, clipping and selected modes.
		if int(v.args[4])==0 or v.get("oracle",false):
			var expected: String=graph()
			pixels.assign(initial);palette.assign(initial_palette)
			for key: String in fields: vm.set_static("k",key,"I",fields[key])
			var result: Variant=original(v.args)
			if int(result)!=int(value) or graph()!=expected: failures.append("original "+str(v.args))
			full_checks+=1
	var fixture_data: Dictionary={"base":b64(initial),"texture":b64(vm.get_static("k","c","[B").data),"edges":b64(vm.get_static("k","e","[S").data),"cases":cases}
	FileAccess.open("res://../build/web_weapon_cases.json",FileAccess.WRITE).store_string(JSON.stringify(fixture_data))
	var report: Dictionary={"cases":cases.size(),"bytecode_graph_comparisons":full_checks,"failures":failures,"errors":vm.errors.duplicate()}
	FileAccess.open("res://../build/weapon_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://weapon-parity.oe2"+suffix): DirAccess.remove_absolute("user://weapon-parity.oe2"+suffix)
	session.close();quit(0 if failures.is_empty() else 1)
