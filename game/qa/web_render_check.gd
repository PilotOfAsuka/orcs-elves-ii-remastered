extends RefCounted
## Local opt-in browser equivalence check. Does not change the quick save.
func run(ui: Control) -> void:
	ui.paused=true
	var session: OEGameSession=ui.session
	var base: String="user://raster-qa-base.oe2"
	var result_path: String="user://raster-qa-result.oe2"
	var reports: Array=[]
	var passed: bool=OESnapshot.new().load_game(session,ui.saved_path)
	if passed: passed=OESnapshot.new().save_game(session,base)
	if passed:
		for angle in [0,64,128,192,32,96,160,224,0,64,128,192]:
			var probe: bool=reports.size()>=8
			var outputs: Array=[]
			for js in [false,true]:
				OESnapshot.new().load_game(session,base)
				session.vm.frame_budget_us=0
				session.vm.max_slice=256
				session.vm.fast_geometry=true
				session.vm.render_helpers.raster.enabled=js
				var main: Array[Dictionary]=session.vm.fibers.duplicate()
				session.vm.fibers.clear()
				session.vm.render_helpers.raster.wall_jobs=0
				session.vm.render_helpers.raster.span_jobs=0
				session.vm.render_helpers.raster.batch_jobs=0
				var before: int=session.vm.instructions
				var started: int=Time.get_ticks_usec()
				var args: Array=[session.vm.get_static("a","h","I"),session.vm.get_static("a","i","I"),session.vm.get_static("a","j","I"),angle]
				var fiber: Dictionary=session.vm.launch("k","a(IIII)V",null,args)
				for tick in 10000:
					if fiber.frames.is_empty() or session.vm.halted: break
					session.vm.tick(0)
				if probe:
					# A real JVM array store/read must publish buffered rendering first.
					var ref: Dictionary={"owner":"k","name":"m","desc":"[I"}
					var method: Dictionary={"flags":8,"name":"poke","desc":"()I","params":[],"max_locals":0,"exceptions":[],"code":[[178,ref],[3],[19,0x11223344],[79],[178,ref],[3],[46],[172]]}
					session.vm.classes.RenderProbe={"parent":"java/lang/Object","interfaces":[],"fields":[],"methods":{"poke()I":method}}
					session.vm.statics.RenderProbe={};session.vm.initialized.RenderProbe=true
					var poke: Dictionary=session.vm.launch("RenderProbe","poke()I")
					for n in 1000:
						if poke.frames.is_empty(): break
						session.vm.tick(0)
					if poke.result!=0x11223344: passed=false
				var width: int=session.vm.get_static("k","b","I")
				var height: int=session.vm.get_static("k","c","I")
				session.platform.draw_rgb(session.platform.screen.data,[session.vm.get_static("k","m","[I"),0,width,0,0,width,height,0])
				var elapsed: int=Time.get_ticks_usec()-started
				session.vm.fibers.assign(main)
				if not OESnapshot.new().save_game(session,result_path): passed=false;break
				outputs.append({"compiled":session.vm.geometry.accepts("k","a(S)V"),"instructions":session.vm.instructions-before,"wall_jobs":session.vm.render_helpers.raster.wall_jobs,"span_jobs":session.vm.render_helpers.raster.span_jobs,"batches":session.vm.render_helpers.raster.batch_jobs,"us":elapsed,"graph":FileAccess.open(result_path,FileAccess.READ).get_var(false).checksum})
			var equal: bool=outputs.size()==2 and outputs[0].graph==outputs[1].graph
			passed=passed and equal
			reports.append({"probe":probe,"angle":angle,"equal":equal,"runs":outputs})
	var report: Dictionary={"passed":passed,"scenes":reports,"errors":session.vm.errors.duplicate()}
	JavaScriptBridge.eval("(()=>{let p=document.createElement('pre');p.id='oe-render-check';p.style='position:fixed;inset:0;background:#101820;color:white;z-index:999;white-space:pre-wrap;overflow:auto';p.textContent="+JSON.stringify(JSON.stringify(report))+";document.body.appendChild(p)})()",true)
	if FileAccess.file_exists(base): OESnapshot.new().load_game(session,base)
	session.vm.render_helpers.raster.enabled=true
	session.vm.frame_budget_us=10000
	session.vm.max_slice=12000
	ui.paused=true
	ui.set_process(false)
	for path in [base,result_path]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
