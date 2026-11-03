extends SceneTree
func _initialize() -> void: call_deferred("run")
func runnable(vm: OEVM) -> bool:
	for fiber: Dictionary in vm.fibers:
		if not fiber.frames.is_empty() and fiber.waiting==null and int(fiber.wake)<=vm.now_ms: return true
	return false
func ranked(source: Dictionary) -> Array:
	var rows: Array=[]
	for key in source: rows.append({"method":key,"value":source[key]})
	rows.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.value)>int(b.value))
	return rows.slice(0,25)
func run() -> void:
	var label: String=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "current"
	var game:=OEGameSession.new(false)
	var rows: Array=[]
	for key in [54,52,50,56,53,57]:
		if not OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_014.oe2"): quit(1);return
		game.vm.fast_sprite_setup=label!="baseline";game.vm.fast_tiled_paint=label!="baseline"
		game.vm.profile_enabled=true
		game.vm.profile_instructions.clear();game.vm.profile_native_us.clear();game.vm.profile_native_calls.clear()
		var started: int=Time.get_ticks_usec();var count: int=game.vm.instructions
		game.key(key)
		var worst: int=0
		for clock_step in 6:
			var began: int=Time.get_ticks_usec();game.tick(50);worst=maxi(worst,Time.get_ticks_usec()-began)
			for slice in 10000:
				if not runnable(game.vm) or game.vm.halted: break
				began=Time.get_ticks_usec();game.tick(0);worst=maxi(worst,Time.get_ticks_usec()-began)
		rows.append({"key":key,"us":Time.get_ticks_usec()-started,"worst_tick_us":worst,"instructions":game.vm.instructions-count,"state":game.report().state,"pose":game.metrics.pose(game.vm),"methods":ranked(game.vm.profile_instructions),"native_us":ranked(game.vm.profile_native_us),"errors":game.vm.errors.duplicate()})
		print(JSON.stringify(rows[-1]))
	var ui=load("res://main.tscn").instantiate();ui.testing=true;ui.paused=true;root.add_child(ui);ui.set_process(false)
	OESnapshot.new().load_game(ui.session,"res://../build/fixtures/user_f9_014.oe2")
	var ui_rows: Array=[]
	for locale in ["ru","en"]:
		ui.select_language(locale);ui._process(0)
		var times: Array=[]
		for index in 40:
			var began: int=Time.get_ticks_usec();ui._process(0);times.append(Time.get_ticks_usec()-began)
		times.sort();ui_rows.append({"locale":locale,"median_us":times[20],"max_us":times.back()})
	print("UI ",JSON.stringify(ui_rows))
	FileAccess.open("res://../build/user_checkpoint_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"actions":rows,"ui":ui_rows},"\t"))
	ui.queue_free();game.close();await process_frame;quit()
