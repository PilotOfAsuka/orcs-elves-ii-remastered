extends SceneTree
var ui: Control
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func original(owner: String,key: String,args: Array) -> void:
	var vm: OEVM=ui.session.vm
	var main: Array[Dictionary]=vm.fibers.duplicate();vm.fibers.clear()
	var fiber: Dictionary=vm.launch(owner,key,null,args)
	for n in 20000:
		if fiber.frames.is_empty() or vm.halted: break
		vm.tick(0)
	vm.fibers.assign(main)
	check(fiber.frames.is_empty(),"completed "+key)
func signature() -> String:
	OESnapshot.new().save_game(ui.session,"user://hd-weapon-proof.oe2")
	return FileAccess.open("user://hd-weapon-proof.oe2",FileAccess.READ).get_var(false).checksum
func paint(weapon: int,frame: int,enabled: bool,effects: int=0,flags: int=0,ammo: bool=true) -> void:
	OESnapshot.new().load_game(ui.session,"res://../build/fixtures/user_world_015.oe2")
	ui.hd_weapons.enabled=enabled;ui.hd_weapons.pending={}
	var vm: OEVM=ui.session.vm
	vm.set_field(vm.get_static("v","b","Lq;"),"q","g","I",weapon)
	vm.set_static("a","H","I",3);vm.set_static("v","i","Z",int(weapon==4 and frame==2));vm.set_static("v","c","Z",int(frame!=2))
	vm.set_static("u","a","Ls;",null);vm.set_static("v","k","Z",0)
	var ammo_type: int=vm.get_static("u","a","[B").data[weapon*10+5]
	if ammo_type>0: vm.get_static("v","b","[B").data[ammo_type]=10 if ammo else 0
	if frame>0 and not (weapon==4 and frame==2):
		vm.set_static("a","H","I",4);vm.set_static("u","m","I",1)
	var draws: Array=[];var observer: Callable=vm.render_helpers.sprite_observer
	vm.render_helpers.sprite_observer=func(args: Array):
		if int(args[0])==weapon+1 or int(ui.hd_weapons.AUX.get(weapon,-1))==int(args[0]):
			args[5]=effects;args[6]=flags;draws.append(args.duplicate())
		observer.call(args)
	original("k","a(IIII)V",[vm.get_static("a","h","I"),vm.get_static("a","i","I"),vm.get_static("a","j","I"),vm.get_static("a","k","I")])
	original("u","a(II)V",[0,0]);vm.render_helpers.sprite_observer=observer
	var expected_frame: int=1 if not ammo and weapon in [5,6] and frame==0 else frame
	check(draws.any(func(args: Array): return int(args[0])==weapon+1 and int(args[1])==expected_frame),"original animation pose "+str([weapon,frame]))
	var width: int=vm.get_static("k","b","I");var height: int=vm.get_static("k","c","I");var rect: JObject=vm.get_static("a","c","[I")
	ui.session.platform.draw_rgb(ui.session.platform.screen.data,[vm.get_static("k","m","[I"),0,width,rect.data[0],rect.data[1],width,height,0])
	ui._process(0)
	if enabled and effects==0:
		check(not ui.hd_weapons.current.is_empty(),"HQ frame published")
		if not ui.hd_weapons.current.is_empty():
			check(ui.hd_weapons.current.layers.size()==draws.size(),"all source layers retained")
			for i in draws.size(): check(ui.hd_weapons.current.layers[i].args==draws[i],"original draw arguments retained")
func run() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	ui=load("res://main.tscn").instantiate();ui.testing=true;ui.paused=true;viewport.add_child(ui);ui.set_process(false)
	for sprite in ui.hd_weapons.ART:
		for path: String in ui.hd_weapons.ART[sprite]:
			var texture: Texture2D=load(path)
			var image: Image=texture.get_image()
			check(image.get_width()>=1024 and image.get_width()==image.get_height(),"high resolution original canvas")
			check(image.get_pixel(0,0).a==0 and image.detect_alpha()!=Image.ALPHA_NONE,"generated alpha retained")
	var cases: Array=[]
	for weapon in 11:
		for frame in ui.hd_weapons.ART[weapon+1].size():
			var pair: Array=[]
			for enabled in [false,true]:
				paint(weapon,frame,enabled)
				pair.append(signature())
				check(ui.hd_weapons.current.is_empty()!=enabled,"HQ layer validity")
			check(pair[0]==pair[1],"presentation preserves complete graph "+str([weapon,frame]))
			for mode in [0,1]:
				var before: String=signature()
				ui.set_render_mode(mode);ui.fade.kill();ui.remastered_view.modulate.a=float(mode)
				check(signature()==before,"render switching preserves game state")
				await process_frame;RenderingServer.force_draw(false)
				var name: String="weapon_%02d_%d_%s"%[weapon,frame,"classic" if mode==0 else "hd"]
				viewport.get_texture().get_image().save_png("res://../build/preview_"+name+".png")
			cases.append({"weapon":weapon,"frame":frame,"same_graph":pair[0]==pair[1],"args":ui.hd_weapons.current.get("args",[])})
	for weapon in 11:
		var pair: Array=[]
		for active in [false,true]:
			paint(weapon,0,active)
			var background: String=ui.hd_weapons.current.background.get_data().hex_encode().sha256_text() if active else ""
			# Original cold start paints u.a again AFTER its first drawRGB.
			original("u","a(II)V",[0,0])
			ui.hd_weapons.current={};ui.hd_weapons.current_revision=-1;ui._process(0)
			if active: check(not ui.hd_weapons.current.is_empty(),"copied frame survives later unpresented pose")
			# Dialogue/event exit republishes the existing framebuffer, no movement.
			for state in [7,3]:
				ui.session.vm.set_static("a","H","I",state);original("a","i()V",[]);ui._process(0)
				if active: check(not ui.hd_weapons.current.is_empty(),"HD survives event-only copy "+str([weapon,state]))
			original("u","a(II)V",[0,0]);original("a","i()V",[]);ui._process(0)
			if active and not ui.hd_weapons.current.is_empty():
				check(ui.hd_weapons.current.background.get_data().hex_encode().sha256_text()==background,"clean background excludes repeated original weapon")
				check(ui.remastered_view.texture==ui.hd_weapons.background_texture,"event exit uses HD presentation")
			pair.append(signature())
		check(pair[0]==pair[1],"event/repeated paint preserves complete graph "+str(weapon))
	paint(0,0,true,32)
	check(ui.hd_weapons.current.is_empty(),"special palette uses original renderer")
	paint(1,0,true,0,0x20000)
	check(not ui.hd_weapons.current.is_empty(),"mirrored pose supported")
	for weapon in [4,5,6,8,9,10]:
		paint(weapon,0,true,0,0,false)
		check(ui.hd_weapons.current.layers.size()==(2 if weapon==4 else 1),"empty ammo removes auxiliary layer")
	for flags in [0x20000,0x40000,0x60000]: paint(1,1,true,0,flags)
	check(ui.hd_weapons.textures.size()<=6,"bounded texture cache")
	for dims in [Vector2i(390,844),Vector2i(844,390),Vector2i(1280,720)]:
		viewport.size=dims;ui.size=Vector2(dims);ui.arrange();ui._process(0);await process_frame
		check(ui.hd_weapons.size.x>0 and ui.hd_weapons.size.y>0,"responsive clip "+str(dims))
	var report: Dictionary={"checks":checks,"failures":failures,"cases":cases,"errors":ui.session.vm.errors.duplicate()}
	FileAccess.open("res://../build/hd_weapons.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	ui.queue_free();await process_frame;viewport.queue_free();await process_frame
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://hd-weapon-proof.oe2"+suffix): DirAccess.remove_absolute("user://hd-weapon-proof.oe2"+suffix)
	quit(0 if failures.is_empty() else 1)
