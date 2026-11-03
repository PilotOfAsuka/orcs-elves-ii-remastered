extends SceneTree

func _initialize() -> void: call_deferred("run")

func original(session: OEGameSession, key: String, args: Array) -> Variant:
	var main: Array[Dictionary]=session.vm.fibers.duplicate()
	var next: int=session.vm.next_id
	session.vm.fibers.clear()
	var fiber: Dictionary=session.vm.launch("p",key,null,args)
	for tick in 1000:
		if fiber.frames.is_empty() or session.vm.halted: break
		session.vm.tick(0)
	session.vm.fibers.assign(main)
	session.vm.next_id=next
	return fiber.result

func run() -> void:
	var session:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	session.vm.fast_resources=false
	session.vm.max_slice=1000000
	var before: String="user://entity-before.oe2"
	OESnapshot.new().save_game(session,before)
	var cases: Dictionary={}
	for entry: JObject in session.vm.get_static("p","a","[Lg;").data:
		var a: int=entry.fields["g.a:B"]
		var b: int=entry.fields["g.b:B"]
		var c: int=entry.fields["g.c:B"]
		cases[str(["a(I)Lg;",entry.fields["g.a:S"]])]=["a(I)Lg;",[entry.fields["g.a:S"]]]
		cases[str(["a(II)Lg;",a,b])]=["a(II)Lg;",[a,b]]
		cases[str(["a(III)Lg;",a,b,c])]=["a(III)Lg;",[a,b,c]]
		cases[str(["a(III)Lg;",a,b,-1])]=["a(III)Lg;",[a,b,-1]]
	for id in [-32768,-1,0,32767,65535]: cases[str(id)]=["a(I)Lg;",[id]]
	for type in [-1,127,128]: cases["missing"+str(type)]=["a(III)Lg;",[type,255,255]]
	var failures: Array=[]
	for value: Array in cases.values():
		var expected: Variant=original(session,value[0],value[1])
		var actual: Variant=session.vm.resource_helpers.lookup(value[0],value[1])
		if expected!=actual: failures.append(value)
	var after: String="user://entity-after.oe2"
	OESnapshot.new().save_game(session,after)
	var unchanged: bool=FileAccess.open(before,FileAccess.READ).get_var(false).checksum==FileAccess.open(after,FileAccess.READ).get_var(false).checksum
	var passed: bool=failures.is_empty() and unchanged and session.vm.errors.is_empty()
	var report: Dictionary={"passed":passed,"comparisons":cases.size(),"unchanged":unchanged,"failures":failures,"errors":session.vm.errors.duplicate()}
	FileAccess.open("res://../build/entity_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	for path in [before,after]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	session.close()
	quit(0 if passed else 1)
