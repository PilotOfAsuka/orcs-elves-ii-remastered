extends RefCounted
## Local opt-in browser equivalence check. Does not change the quick save.
func run(ui: Control) -> void:
	ui.paused=true
	var session: OEGameSession=ui.session
	var base: String="user://raster-qa-base.oe2"
	var result_path: String="user://raster-qa-result.oe2"
	var reports: Array=[]
	assert(session.vm.render_helpers.raster!=null)
	var passed: bool=OESnapshot.new().load_game(session,ui.saved_path)
	if passed: passed=OESnapshot.new().save_game(session,base)
	if passed:
		for angle in [0,64,128,192,32,96,160,224,0,64,128,192,0,64,0,64]:
			var probe: bool=reports.size()>=8 and reports.size()<12
			var repeat: bool=reports.size()>=12 and reports.size()<14
			var texture_probe: bool=reports.size()>=14
			var outputs: Array=[]
			for js in [false,true]:
				OESnapshot.new().load_game(session,base)
				session.vm.frame_budget_us=0
				session.vm.max_slice=256
				session.vm.fast_geometry=true
				session.vm.render_helpers.raster.enabled=js
				session.vm.render_helpers.raster.defer_present=not bool(JavaScriptBridge.eval("location.search.includes('eager=1')"))
				var main: Array[Dictionary]=session.vm.fibers.duplicate()
				session.vm.fibers.clear()
				session.vm.render_helpers.raster.wall_jobs=0
				session.vm.render_helpers.raster.span_jobs=0
				session.vm.render_helpers.raster.batch_jobs=0
				session.vm.render_helpers.raster.sync_jobs=0
				session.vm.render_helpers.raster.texture_switches=0
				session.vm.render_helpers.raster.profile_enabled=true
				session.vm.render_helpers.raster.profile_us.clear()
				var before: int=session.vm.instructions
				var started: int=Time.get_ticks_usec()
				var args: Array=[session.vm.get_static("a","h","I"),session.vm.get_static("a","i","I"),session.vm.get_static("a","j","I"),angle]
				var fiber: Dictionary=session.vm.launch("k","a(IIII)V",null,args)
				for tick in 10000:
					if fiber.frames.is_empty() or session.vm.halted: break
					session.vm.tick(0)
				if not fiber.frames.is_empty() or session.vm.halted: passed=false
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
				if texture_probe:
					# Real bytecode writes between queued spans must preserve ordering.
					var texels: JObject=session.vm.get_static("k","c","[B")
					var index: int=0
					while index<texels.data.size() and (int(texels.data[index])<0 or int(texels.data[index])>=16): index+=1
					if index==texels.data.size(): passed=false;break
					var value: int=(int(texels.data[index])+1)%16
					session.vm.set_static("k","c","Z",0)
					session.vm.render_helpers.wall([0,index<<12,0,1,1])
					if angle==0:
						var ref: Dictionary={"owner":"k","name":"c","desc":"[B"}
						var method: Dictionary={"flags":8,"name":"poke","desc":"()V","params":[],"max_locals":0,"exceptions":[],"code":[[178,ref],[19,index],[19,value],[84],[177]]}
						session.vm.classes.TextureProbe={"parent":"java/lang/Object","interfaces":[],"fields":[],"methods":{"poke()V":method}}
						session.vm.statics.TextureProbe={};session.vm.initialized.TextureProbe=true
						var poke: Dictionary=session.vm.launch("TextureProbe","poke()V")
						for n in 1000:
							if poke.frames.is_empty(): break
							session.vm.tick(0)
						if not poke.frames.is_empty() or session.vm.halted: passed=false
					else:
						var stream:=JObject.new("java/io/ByteArrayInputStream")
						stream.data=PackedByteArray([value]);stream.extra={"pos":0}
						var result: Variant=session.platform.invoke({"owner":"java/io/InputStream","name":"read","desc":"([BII)I"},stream,[texels,index,1],session.vm.active)
						if result!=1: passed=false
					session.vm.render_helpers.wall([1,index<<12,0,1,1])
				var width: int=session.vm.get_static("k","b","I")
				var height: int=session.vm.get_static("k","c","I")
				session.platform.draw_rgb(session.platform.screen.data,[session.vm.get_static("k","m","[I"),0,width,0,0,width,height,0])
				var elapsed: int=Time.get_ticks_usec()-started
				if repeat:
					for next_angle in [(angle+64)%256,(angle+192)%256]:
						args[3]=next_angle
						var next_frame: Dictionary=session.vm.launch("k","a(IIII)V",null,args)
						for tick in 10000:
							if next_frame.frames.is_empty() or session.vm.halted: break
							session.vm.tick(0)
						if not next_frame.frames.is_empty() or session.vm.halted: passed=false
						session.platform.draw_rgb(session.platform.screen.data,[session.vm.get_static("k","m","[I"),0,width,0,0,width,height,0])
					elapsed=Time.get_ticks_usec()-started
				var present_us: Dictionary=session.vm.render_helpers.raster.profile_us.duplicate()
				var present_syncs: int=session.vm.render_helpers.raster.sync_jobs
				session.vm.fibers.assign(main)
				if not OESnapshot.new().save_game(session,result_path): passed=false;break
				outputs.append({"compiled":session.vm.geometry.accepts("k","a(S)V"),"instructions":session.vm.instructions-before,"wall_jobs":session.vm.render_helpers.raster.wall_jobs,"span_jobs":session.vm.render_helpers.raster.span_jobs,"raster_us":present_us,"present_syncs":present_syncs,"batches":session.vm.render_helpers.raster.batch_jobs,"syncs":session.vm.render_helpers.raster.sync_jobs,"texture_switches":session.vm.render_helpers.raster.texture_switches,"us":elapsed,"graph":FileAccess.open(result_path,FileAccess.READ).get_var(false).checksum})
			var equal: bool=outputs.size()==2 and outputs[0].graph==outputs[1].graph
			passed=passed and equal and session.vm.errors.is_empty()
			reports.append({"probe":probe,"repeat":repeat,"texture_probe":texture_probe,"angle":angle,"equal":equal,"runs":outputs})
	var report: Dictionary={"passed":passed,"scenes":reports,"errors":session.vm.errors.duplicate()}
	JavaScriptBridge.eval("(()=>{let p=document.createElement('pre');p.id='oe-render-check';p.style='position:fixed;inset:0;background:#101820;color:white;z-index:999;white-space:pre-wrap;overflow:auto';p.textContent="+JSON.stringify(JSON.stringify(report))+";document.body.appendChild(p)})()",true)
	if FileAccess.file_exists(base): OESnapshot.new().load_game(session,base)
	session.vm.render_helpers.raster.enabled=true
	session.vm.render_helpers.raster.defer_present=true
	session.vm.render_helpers.raster.profile_enabled=false
	session.vm.frame_budget_us=10000
	session.vm.max_slice=12000
	ui.paused=true
	ui.set_process(false)
	for path in [base,result_path]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
