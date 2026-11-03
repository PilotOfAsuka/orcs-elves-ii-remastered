extends RefCounted
## Compare original portable, old browser spans and whole browser 2D sprites.
## The user's quick save is read only; all output goes to temporary QA files.
func run(ui: Control) -> void:
	ui.paused=true
	var session: OEGameSession=ui.session
	var captured: Dictionary={}
	var base: String="user://weapon-qa-base.oe2"
	var output: String="user://weapon-qa-output.oe2"
	var passed: bool=OESnapshot.new().load_game(session,ui.saved_path)
	if passed:
		session.vm.frame_budget_us=0;session.vm.max_slice=1000000
		session.vm.render_helpers.raster.enabled=false
		session.vm.span_observer=func(key: String,args: Array):
			if key=="a(IIIIIIII)Z" and captured.is_empty():
				captured.args=args.duplicate()
				captured.saved=OESnapshot.new().save_game(session,base)
		var main: Array[Dictionary]=session.vm.fibers.duplicate()
		session.vm.fibers.clear()
		# Request the original world + weapon paint, without advancing movement.
		session.vm.set_static("a","l","Z",1)
		var fiber: Dictionary=session.vm.launch("a","c(III)V",null,[session.vm.get_static("a","h","I"),session.vm.get_static("a","i","I"),session.vm.get_static("a","k","I")])
		for tick in 10000:
			if fiber.frames.is_empty() or session.vm.halted: break
			session.vm.tick(0)
		session.vm.fibers.assign(main)
		session.vm.span_observer=Callable()
		passed=captured.get("saved",false) and fiber.frames.is_empty() and not session.vm.halted
	var scenes: Array=[]
	if passed:
		for flags in [0,0x20000,0x40000,0x60000]:
			for scale in [0,192,384]:
				for mode in [0,1,4,8,9,255]:
					var runs: Array=[]
					for variant in [0,1,2]:
						if not OESnapshot.new().load_game(session,base): passed=false;break
						var raster: OEWebRaster=session.vm.render_helpers.raster
						raster.enabled=variant!=0;raster.fast_2d=variant==2
						raster.weapon_jobs=0;raster.weapon_fallbacks=0;raster.span_jobs=0
						raster.profile_enabled=true;raster.profile_us.clear()
						var args: Array=captured.args.duplicate()
						args[4]=mode;args[6]=flags;args[7]=scale
						var began: int=Time.get_ticks_usec()
						var value: bool=session.vm.render_helpers.sprite_2d(args)
						var width: int=session.vm.get_static("k","b","I")
						var height: int=session.vm.get_static("k","c","I")
						session.platform.draw_rgb(session.platform.screen.data,[session.vm.get_static("k","m","[I"),0,width,0,0,width,height,0])
						var elapsed: int=Time.get_ticks_usec()-began
						if session.vm.halted or session.vm.exception!=null: passed=false
						if not OESnapshot.new().save_game(session,output): passed=false;break
						runs.append({"value":value,"graph":FileAccess.open(output,FileAccess.READ).get_var(false).checksum,"us":elapsed,"whole_jobs":raster.weapon_jobs,"fallbacks":raster.weapon_fallbacks,"spans":raster.span_jobs})
					var equal: bool=runs.size()==3 and runs[0].value==runs[1].value and runs[1].value==runs[2].value and runs[0].graph==runs[1].graph and runs[1].graph==runs[2].graph
					passed=passed and equal
					scenes.append({"flags":flags,"scale":scale,"mode":mode,"equal":equal,"runs":runs})
	# Compare warm repeated draws with exactly the same input and virtual clock.
	var repeated: Array=[]
	if passed:
		for fast in [false,true]:
			OESnapshot.new().load_game(session,base)
			var raster: OEWebRaster=session.vm.render_helpers.raster
			raster.enabled=true;raster.fast_2d=fast
			var width: int=session.vm.get_static("k","b","I")
			var height: int=session.vm.get_static("k","c","I")
			var timings: Array=[]
			for repeat in 12:
				var began: int=Time.get_ticks_usec()
				session.vm.render_helpers.sprite_2d(captured.args)
				session.platform.draw_rgb(session.platform.screen.data,[session.vm.get_static("k","m","[I"),0,width,0,0,width,height,0])
				if repeat>0: timings.append(Time.get_ticks_usec()-began)
			timings.sort()
			OESnapshot.new().save_game(session,output)
			repeated.append({"fast":fast,"median_us":timings[timings.size()/2],"max_us":timings[-1],"graph":FileAccess.open(output,FileAccess.READ).get_var(false).checksum})
		passed=passed and repeated[0].graph==repeated[1].graph
	var report: Dictionary={"passed":passed,"captured":captured.get("args",[]),"scenes":scenes,"repeated":repeated,"errors":session.vm.errors.duplicate()}
	JavaScriptBridge.eval("(()=>{let p=document.createElement('pre');p.id='oe-render-check';p.style='position:fixed;inset:0;background:#101820;color:white;z-index:999;white-space:pre-wrap;overflow:auto';p.textContent="+JSON.stringify(JSON.stringify(report))+";document.body.appendChild(p)})()",true)
	ui.set_process(false)
	for path in [base,output]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
