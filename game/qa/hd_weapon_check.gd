extends RefCounted
## Explicit diagnostic route: read F9, work only in separate temporary files.
func original(ui: Control, owner: String, key: String, args: Array) -> bool:
	var vm: OEVM=ui.session.vm
	var main: Array[Dictionary]=vm.fibers.duplicate();vm.fibers.clear()
	var fiber: Dictionary=vm.launch(owner,key,null,args)
	for n in 20000:
		if fiber.frames.is_empty() or vm.halted: break
		vm.tick(0)
	vm.fibers.assign(main)
	return fiber.frames.is_empty() and not vm.halted
func paint(ui: Control, base: String, weapon: int, frame: int, active: bool) -> bool:
	if not OESnapshot.new().load_game(ui.session,base): return false
	var vm: OEVM=ui.session.vm
	ui.hd_weapons.enabled=active;ui.hd_weapons.pending={}
	vm.set_field(vm.get_static("v","b","Lq;"),"q","g","I",weapon)
	vm.set_static("a","H","I",3);vm.set_static("v","i","Z",int(weapon==4 and frame==2));vm.set_static("v","c","Z",int(frame!=2))
	vm.set_static("u","a","Ls;",null);vm.set_static("v","k","Z",0)
	var ammo_type: int=vm.get_static("u","a","[B").data[weapon*10+5]
	if ammo_type>0: vm.get_static("v","b","[B").data[ammo_type]=10
	if frame>0 and not (weapon==4 and frame==2): vm.set_static("a","H","I",4);vm.set_static("u","m","I",1)
	if not original(ui,"k","a(IIII)V",[vm.get_static("a","h","I"),vm.get_static("a","i","I"),vm.get_static("a","j","I"),vm.get_static("a","k","I")]): return false
	if not original(ui,"u","a(II)V",[0,0]): return false
	var width: int=vm.get_static("k","b","I");var height: int=vm.get_static("k","c","I");var rect: JObject=vm.get_static("a","c","[I")
	ui.session.platform.draw_rgb(ui.session.platform.screen.data,[vm.get_static("k","m","[I"),0,width,rect.data[0],rect.data[1],width,height,0])
	ui._process(0)
	return (not ui.hd_weapons.current.is_empty())==active
func run(ui: Control) -> void:
	ui.paused=true;ui.language_ready=true;ui.set_process(false)
	var base: String="user://hd-qa-base.oe2";var proof: String="user://hd-qa-proof.oe2"
	var passed: bool=OESnapshot.new().load_game(ui.session,ui.saved_path)
	ui.saved_path="user://hd-qa-copy.oe2"
	if passed:
		ui.session.vm.frame_budget_us=0;ui.session.vm.paint_budget_us=0
		if int(ui.session.vm.get_static("a","H","I"))==2 and int(ui.session.vm.get_static("w","g","I"))==100: passed=original(ui,"w","b(I)V",[0])
		passed=passed and int(ui.session.vm.get_static("a","H","I"))==3 and OESnapshot.new().save_game(ui.session,base)
	var cases: Array=[]
	if passed:
		for weapon in 11:
			for frame in ui.hd_weapons.ART[weapon+1].size():
				var pair: Array=[]
				for active in [false,true]:
					passed=paint(ui,base,weapon,frame,active) and passed
					OESnapshot.new().save_game(ui.session,proof)
					pair.append(FileAccess.open(proof,FileAccess.READ).get_var(false).checksum)
				cases.append({"weapon":weapon,"frame":frame,"equal":pair[0]==pair[1],"graph":pair[1],"layers":ui.hd_weapons.current.get("layers",[]).size()})
				passed=passed and pair[0]==pair[1]
		for weapon in 11:
			var pair: Array=[];var retained: bool=true;var clean: bool=true
			for active in [false,true]:
				passed=paint(ui,base,weapon,0,active) and passed
				var background: String=ui.hd_weapons.current.background.get_data().hex_encode().sha256_text() if active else ""
				passed=original(ui,"u","a(II)V",[0,0]) and passed
				ui.hd_weapons.current={};ui.hd_weapons.current_revision=-1;ui._process(0)
				if active: retained=retained and not ui.hd_weapons.current.is_empty()
				for state in [7,3]:
					ui.session.vm.set_static("a","H","I",state);passed=original(ui,"a","i()V",[]) and passed;ui._process(0)
					if active: retained=retained and not ui.hd_weapons.current.is_empty()
				passed=original(ui,"u","a(II)V",[0,0]) and passed;passed=original(ui,"a","i()V",[]) and passed;ui._process(0)
				if active: clean=not ui.hd_weapons.current.is_empty() and ui.hd_weapons.current.background.get_data().hex_encode().sha256_text()==background
				OESnapshot.new().save_game(ui.session,proof);pair.append(FileAccess.open(proof,FileAccess.READ).get_var(false).checksum)
			cases.append({"event_return":true,"weapon":weapon,"equal":pair[0]==pair[1],"retained":retained,"clean":clean})
			passed=passed and pair[0]==pair[1] and retained and clean
		passed=paint(ui,base,7,0,true) and passed
	ui.set_render_mode(1);ui.fade.kill();ui.remastered_view.modulate.a=1
	var report: Dictionary={"passed":passed,"cases":cases,"texture_cache":ui.hd_weapons.textures.size(),"errors":ui.session.vm.errors.duplicate()}
	JavaScriptBridge.eval("(()=>{const p=document.createElement('pre');p.id='oe-hd-check';p.style='position:fixed;top:8px;left:8px;max-width:45vw;max-height:35vh;overflow:auto;z-index:999;background:#122019;color:#eddfb8;font:12px monospace';p.textContent="+JSON.stringify(JSON.stringify(report))+";p.onclick=()=>p.remove();document.body.appendChild(p)})()",true)
	for path in [base,proof]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
