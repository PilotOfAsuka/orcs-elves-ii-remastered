extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func ranked(values: Dictionary, count: int=25) -> Array:
	var rows: Array=[]
	for key: Variant in values: rows.append({"method":key,"value":values[key]})
	rows.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.value)>int(b.value))
	return rows.slice(0,count)

func run() -> void:
	var session:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	var args:=OS.get_cmdline_user_args()
	session.vm.profile_enabled=not args.has("plain")
	session.vm.fast_render=args.has("fast")
	session.vm.fast_geometry=args.has("fast")
	session.platform.fast_rgb=args.has("fast")
	session.vm.fast_font=args.has("fast")
	session.vm.fast_resources=args.has("fast")
	var results: Array=[]
	var frames: Array=[]
	for key in [54,50,52,50,53,57]:
		var began: int=Time.get_ticks_usec()
		var before: int=session.vm.instructions
		var worst: int=0
		session.key(key)
		for tick in 90:
			var started: int=Time.get_ticks_usec()
			session.tick(50)
			var elapsed: int=Time.get_ticks_usec()-started
			worst=maxi(worst,elapsed)
			frames.append(elapsed)
			if session.vm.halted: break
		results.append({"key":key,"us":Time.get_ticks_usec()-began,"worst_tick_us":worst,"instructions":session.vm.instructions-before,"state":session.report().state,"player":[session.vm.get_static("a","h","I"),session.vm.get_static("a","i","I"),session.vm.get_static("a","q","I")]})
		print(JSON.stringify(results[-1]))
		if session.vm.halted: break
	frames.sort()
	var report: Dictionary={"actions":results,"instructions":ranked(session.vm.profile_instructions),"native_us":ranked(session.vm.profile_native_us),"native_calls":ranked(session.vm.profile_native_calls),"median_tick_us":frames[frames.size()/2],"p95_tick_us":frames[int(frames.size()*0.95)],"errors":session.vm.errors.duplicate()}
	FileAccess.open("res://../build/performance_"+("accelerated_" if session.vm.fast_render else "baseline_")+("profile" if session.vm.profile_enabled else "plain")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	var failed: bool=session.vm.halted
	session.close()
	quit(1 if failed else 0)
