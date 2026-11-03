extends RefCounted
## Explicit local diagnostic route. Original F9 and RMS are never overwritten.
func runnable(vm: OEVM) -> bool:
	for fiber: Dictionary in vm.fibers:
		if not fiber.frames.is_empty() and fiber.waiting==null and int(fiber.wake)<=vm.now_ms: return true
	return false
func show_report(report: Dictionary, bytes: PackedByteArray=PackedByteArray()) -> void:
	var script: String="(()=>{let p=document.getElementById('oe-checkpoint-check');if(p)p.remove();p=document.createElement('section');p.id='oe-checkpoint-check';p.style='position:fixed;inset:0;background:#101b14;color:#e8dfc7;z-index:200;padding:24px;font:16px system-ui;overflow:auto';const pre=document.createElement('pre');pre.style='white-space:pre-wrap';pre.textContent="+JSON.stringify(JSON.stringify(report))+";p.appendChild(pre);"
	if not bytes.is_empty(): script+="const a=document.createElement('a');a.textContent='Скачать диагностическую копию F9';a.download='orcs-elves-user-f9.oe2';a.href='data:application/octet-stream;base64,"+Marshalls.raw_to_base64(bytes)+"';a.style='display:block;color:#dfc48b;padding:16px';p.appendChild(a);"
	script+="const b=document.createElement('button');b.textContent='Закрыть отчёт';b.onclick=()=>p.remove();p.appendChild(b);document.body.appendChild(p);})()"
	JavaScriptBridge.eval(script,true)
func run(ui: Control) -> void:
	ui.paused=true;ui.language_ready=true
	var settings:=ConfigFile.new()
	if settings.load("user://language.cfg")==OK: ui.select_language(str(settings.get_value("ui","language","ru")))
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(ui.saved_path)
	var loaded: bool=not bytes.is_empty() and OESnapshot.new().load_game(ui.session,ui.saved_path)
	# All later shortcuts in this diagnostic tab target a separate copy too.
	ui.saved_path="user://diagnostic-copy.oe2"
	if loaded: FileAccess.open(ui.saved_path,FileAccess.WRITE).store_buffer(bytes)
	var report: Dictionary={"loaded":loaded,"bytes":bytes.size(),"report":ui.session.report(),"hud":ui.presenter.hud(),"pose":ui.session.metrics.pose(ui.session.vm)}
	show_report(report,bytes)
	ui._process(0)
	if loaded and bool(JavaScriptBridge.eval("location.search.includes('checkpointuibench=1')")):
		var ui_rows: Array=[]
		OESnapshot.new().save_game(ui.session,"user://diagnostic-proof.oe2")
		var before: String=FileAccess.open("user://diagnostic-proof.oe2",FileAccess.READ).get_var(false).checksum
		for fast in [false,true]:
			ui.presenter.menu_cache_enabled=fast;ui._process(0)
			var samples: Array=[]
			for n in 35:
				var began: int=Time.get_ticks_usec();ui._process(0);samples.append(Time.get_ticks_usec()-began)
				await ui.get_tree().process_frame
			samples.sort();ui_rows.append({"fast":fast,"median_us":samples[17],"max_us":samples.back()})
		ui.presenter.menu_cache_enabled=true
		OESnapshot.new().save_game(ui.session,"user://diagnostic-proof.oe2")
		show_report({"done":true,"ui":ui_rows,"unchanged":before==FileAccess.open("user://diagnostic-proof.oe2",FileAccess.READ).get_var(false).checksum},bytes)
		return
	if not loaded or not bool(JavaScriptBridge.eval("location.search.includes('checkpointprofile=1')")): return
	if bool(JavaScriptBridge.eval("location.search.includes('checkpointworld=1')")) and int(ui.session.vm.get_static("a","H","I"))==2 and int(ui.session.vm.get_static("w","g","I"))==100:
		var closing: Dictionary=ui.session.vm.launch("w","b(I)V",null,[0])
		for n in 1000:
			ui.session.tick(20)
			if closing.frames.is_empty(): break
			await ui.get_tree().process_frame
		OESnapshot.new().save_game(ui.session,ui.saved_path)
	ui.session.vm.frame_budget_us=0;ui.session.vm.paint_budget_us=0
	var rows: Array=[]
	var detail: bool=bool(JavaScriptBridge.eval("location.search.includes('checkpointdetail=1')"))
	for fast in ([true] if detail else [false,true]):
		for key in [54,52,50,56,53,57]:
			OESnapshot.new().load_game(ui.session,ui.saved_path)
			var stage15: bool=bool(JavaScriptBridge.eval("location.search.includes('checkpointstage15=1')"))
			ui.session.vm.fast_sprite_setup=true if stage15 else fast;ui.session.vm.fast_tiled_paint=true if stage15 else fast
			ui.session.vm.render_helpers.fast_visibility=fast if stage15 else true
			ui.session.vm.resource_helpers.fast_text=fast if stage15 else true
			if bool(JavaScriptBridge.eval("location.search.includes('checkpointscheduled=1')")):
				ui.session.vm.native_budget_checks=fast
				ui.session.vm.frame_budget_us=10000;ui.session.vm.paint_budget_us=24000 if fast else 60000
			if detail:
				ui.session.vm.profile_enabled=true
				ui.session.vm.profile_native_us.clear();ui.session.vm.profile_native_max_us.clear();ui.session.vm.profile_native_calls.clear()
				ui.session.vm.render_helpers.raster.profile_enabled=true;ui.session.vm.render_helpers.raster.profile_us.clear()
			ui.session.key(key)
			var total: int=0;var worst: int=0
			for clock_step in 6:
				var began: int=Time.get_ticks_usec();ui.session.tick(50)
				var elapsed: int=Time.get_ticks_usec()-began;total+=elapsed;worst=maxi(worst,elapsed)
				for slice in 10000:
					if not runnable(ui.session.vm) or ui.session.vm.halted: break
					began=Time.get_ticks_usec();ui.session.tick(0)
					elapsed=Time.get_ticks_usec()-began;total+=elapsed;worst=maxi(worst,elapsed)
				await ui.get_tree().process_frame
			OESnapshot.new().save_game(ui.session,"user://diagnostic-proof.oe2")
			var graph: String=FileAccess.open("user://diagnostic-proof.oe2",FileAccess.READ).get_var(false).checksum
			rows.append({"fast":fast,"key":key,"cpu_us":total,"worst_slice_us":worst,"graph":graph,"pose":ui.session.metrics.pose(ui.session.vm),"errors":ui.session.vm.errors.duplicate(),"state":int(ui.session.vm.get_static("a","H","I")),"menu":int(ui.session.vm.get_static("w","g","I"))})
			if detail:
				rows[-1].native_us=ui.session.vm.profile_native_us.duplicate()
				rows[-1].native_max_us=ui.session.vm.profile_native_max_us.duplicate()
				rows[-1].raster_us=ui.session.vm.render_helpers.raster.profile_us.duplicate()
				rows[-1].texture_switches=ui.session.vm.render_helpers.raster.texture_switches
			show_report({"completed":rows.size(),"total":12,"rows":rows})
	ui.session.vm.fast_sprite_setup=true;ui.session.vm.fast_tiled_paint=true;ui.session.vm.render_helpers.fast_visibility=true;ui.session.vm.resource_helpers.fast_text=true
	OESnapshot.new().load_game(ui.session,ui.saved_path)
	ui._process(0)
	show_report({"done":true,"rows":rows},bytes)
