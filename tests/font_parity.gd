extends SceneTree

var failures: Array[String]=[]
var comparisons: int=0

func _initialize() -> void:
	call_deferred("run")

func original(session: OEGameSession, owner: String, key: String, args: Array=[]) -> Variant:
	var main: Array[Dictionary]=session.vm.fibers.duplicate()
	session.vm.fibers.clear()
	var fiber: Dictionary=session.vm.launch(owner,key,null,args)
	for tick in 10000:
		if fiber.frames.is_empty() or session.vm.halted: break
		session.vm.tick(20 if int(fiber.wake)>session.vm.now_ms else 0)
	session.vm.fibers.assign(main)
	if not fiber.frames.is_empty(): failures.append("unfinished "+key)
	return fiber.result

func compare(session: OEGameSession, key: String, args: Array) -> void:
	var a: Variant=original(session,"b",key,args)
	var b: int=session.vm.font_helpers.invoke(key,args)
	comparisons+=1
	if a!=b: failures.append(str([key,args,a,b]))

func run() -> void:
	var session:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	session.vm.max_slice=1000000
	session.vm.fast_font=false
	var high: int=int(session.vm.get_static("b","b","I"))-2
	for language in [4]:
		session.vm.set_static("a","a","B",language)
		for code in range(-2,513): compare(session,"a(S)S",[code])
		for code in range(1024,1110): compare(session,"a(S)S",[code])
	for code in range(-2,1300):
		compare(session,"a(III)I",[code,0,high])
	compare(session,"a(III)I",[65,3,2])
	# Real menu painters: compare the complete framebuffer and the whole saved Java graph.
	var scenes: Array=[]
	for menu in [3,16,100,500,102]:
		original(session,"w","b(I)V",[menu])
		var baseline: String="user://font-baseline.oe2"
		OESnapshot.new().save_game(session,baseline)
		var states: Array=[]
		for accelerated in [false,true]:
			OESnapshot.new().load_game(session,baseline)
			session.vm.fast_font=accelerated
			var count: int=session.vm.instructions
			var began: int=Time.get_ticks_usec()
			original(session,"w","g()V")
			var elapsed: int=Time.get_ticks_usec()-began
			var output: String="user://font-render.oe2"
			OESnapshot.new().save_game(session,output)
			var doc: Dictionary=FileAccess.open(output,FileAccess.READ).get_var(false)
			states.append({"pixels":session.platform.screen.data.surface.get_data().hex_encode().sha256_text(),"graph":doc.checksum,"instructions":session.vm.instructions-count,"us":elapsed})
		var equal: bool=states[0].pixels==states[1].pixels and states[0].graph==states[1].graph
		if not equal: failures.append("menu parity "+str(menu))
		scenes.append({"menu":menu,"equal":equal,"bytecode":states[0],"accelerated":states[1]})
		print("MENU ",menu," ",equal)
	for path in ["user://font-baseline.oe2","user://font-render.oe2"]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	var report: Dictionary={"comparisons":comparisons,"scenes":scenes,"errors":session.vm.errors.duplicate(),"failures":failures}
	FileAccess.open("res://../build/font_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	session.close()
	quit(0 if failures.is_empty() else 1)
