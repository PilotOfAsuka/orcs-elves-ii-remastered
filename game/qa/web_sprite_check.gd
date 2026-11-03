extends RefCounted
## Compare the portable oracle and browser columns at an actual sprite call.
func run(ui: Control) -> void:
	ui.paused=true
	var session: OEGameSession=ui.session
	var captured: Dictionary={}
	var base: String="user://sprite-qa-base.oe2"
	var output: String="user://sprite-qa-output.oe2"
	var passed: bool=OESnapshot.new().load_game(session,ui.saved_path)
	if passed:
		session.vm.frame_budget_us=0;session.vm.max_slice=1000000
		session.vm.fast_geometry=false
		session.vm.render_helpers.raster.enabled=false
		session.vm.span_observer=func(key: String,_args: Array):
			if key=="h()Z" and captured.is_empty(): captured.saved=OESnapshot.new().save_game(session,base)
		var main: Array[Dictionary]=session.vm.fibers.duplicate()
		session.vm.fibers.clear()
		var fiber: Dictionary=session.vm.launch("k","a(IIII)V",null,[session.vm.get_static("a","h","I"),session.vm.get_static("a","i","I"),session.vm.get_static("a","j","I"),0])
		for tick in 10000:
			if fiber.frames.is_empty() or session.vm.halted: break
			session.vm.tick(0)
		session.vm.fibers.assign(main)
		session.vm.span_observer=Callable()
		passed=captured.get("saved",false)
	var scenes: Array=[]
	if passed:
		for flip in [false,true]:
			for mode in [0,1,3,4,5,6,7,8,9,255]:
				var runs: Array=[]
				for js in [false,true]:
					OESnapshot.new().load_game(session,base)
					session.vm.render_helpers.raster.enabled=js
					session.vm.set_static("k","aP","I",mode)
					if flip: session.vm.set_static("k","ag","I",int(session.vm.get_static("k","ag","I"))^0x1000000)
					var result: bool=session.vm.render_helpers.sprite_columns()
					session.vm.render_helpers.raster.sync()
					if not OESnapshot.new().save_game(session,output): passed=false;break
					runs.append({"value":result,"graph":FileAccess.open(output,FileAccess.READ).get_var(false).checksum})
				var equal: bool=runs.size()==2 and runs[0]==runs[1]
				passed=passed and equal
				scenes.append({"flip":flip,"mode":mode,"equal":equal})
	var report: Dictionary={"passed":passed,"scenes":scenes,"errors":session.vm.errors.duplicate()}
	JavaScriptBridge.eval("(()=>{let p=document.createElement('pre');p.id='oe-render-check';p.style='position:fixed;inset:0;background:#101820;color:white;z-index:999;white-space:pre-wrap;overflow:auto';p.textContent="+JSON.stringify(JSON.stringify(report))+";document.body.appendChild(p)})()",true)
	ui.set_process(false)
	for path in [base,output]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
