extends SceneTree
func _initialize() -> void: call_deferred("run")
func b64(values: Array) -> String: return Marshalls.raw_to_base64(PackedInt32Array(values).to_byte_array())
func run() -> void:
	var session:=OEGameSession.new(false)
	var cases: Array=[]
	for key in ["a(IIIII)V","b(IIII)V"]:
		var file: String="res://../build/fixtures/span_"+key.sha256_text().substr(0,12)+".oe2"
		if not OESnapshot.new().load_game(session,file): quit(1);return
		var args: Array=[48025,50593792,5585,352,46] if key=="a(IIIII)V" else [51179,362455040,5562,11]
		var initial: Array=session.vm.get_static("k","m","[I").data.duplicate()
		var pixels: Array=session.vm.get_static("k","m","[I").data
		var texture: Array=session.vm.get_static("k","c","[B").data
		var palette: Array=session.vm.get_static("k","q","[I").data
		for mode in ([-1] if key=="a(IIIII)V" else [0,1,3,4,8,9]):
			for count in [0,1,7,8,9,int(args[-1])]:
				for sign in [-1,1]:
					pixels.assign(initial)
					var input: Array=args.duplicate();input[-1]=count;input[2]*=sign
					session.vm.set_static("k","ba","I",mode)
					session.vm.render_helpers.invoke(key,input)
					var stride: int=input[3] if mode==-1 else session.vm.get_static("k","b","I")
					var command: Array=[mode,input[0],input[1],input[2],stride,count]+palette
					cases.append({"mode":mode,"count":count,"sign":sign,"base":b64(initial),"texture":b64(texture),"commands":b64(command),"expected":b64(pixels)})
	FileAccess.open("res://../build/web_raster_cases.json",FileAccess.WRITE).store_string(JSON.stringify(cases))
	print("CASES ",cases.size()," errors ",session.vm.errors)
	session.close();quit()
