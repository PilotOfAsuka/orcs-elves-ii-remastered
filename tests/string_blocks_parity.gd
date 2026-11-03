extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	session.vm.fast_resources=false
	var failures: Array=[]
	var count: int=0
	for length in [0,1,2,7,8,31,32770]:
		for zeros in [false,true]:
			for start: int in [0,mini(1,length),length]:
				for block in ["string_count","string_offsets"]:
					OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2")
					session.vm.fibers.clear()
					var bytes:=JObject.new("[B");bytes.data=[]
					for index in length: bytes.data.append(0 if zeros and (index%3==0 or index>=32767) else -1)
					var fiber: Dictionary=session.vm.launch("a","e(I)V",null,[0])
					session.vm.fibers.assign([fiber])
					var frame: Dictionary=fiber.frames.back();frame.entered=true
					frame.locals[6]=bytes
					if block=="string_count":
						frame.pc=94;frame.last=104;frame.locals[7]=123;frame.locals[8]=start
					else:
						var output:=JObject.new("[S");output.data=[]
						for index in length+1: output.data.append(-123)
						frame.pc=123;frame.last=140;frame.locals[7]=1;frame.locals[8]=output;frame.locals[9]=start
					OESnapshot.new().save_game(session,"user://string-block-base.oe2")
					var sums: Array=[]
					for fast in [false,true]:
						OESnapshot.new().load_game(session,"user://string-block-base.oe2")
						var f: Dictionary=session.vm.fibers[0]
						if fast: session.vm.resource_helpers.invoke(f.frames.back(),block)
						else:
							for instruction in 2000000:
								session.vm.step(f)
								if f.frames.back().pc==(105 if block=="string_count" else 141): break
						OESnapshot.new().save_game(session,"user://string-block-out.oe2")
						sums.append(FileAccess.open("user://string-block-out.oe2",FileAccess.READ).get_var(false).checksum)
					if sums[0]!=sums[1]: failures.append([length,zeros,start,block])
					count+=1
	var report: Dictionary={"comparisons":count,"failures":failures,"errors":session.vm.errors.duplicate()}
	FileAccess.open("res://../build/string_blocks_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report));print(JSON.stringify(report))
	for path in ["user://string-block-base.oe2","user://string-block-out.oe2"]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	session.close();quit(0 if failures.is_empty() else 1)
