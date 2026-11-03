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
func paint(weapon: int,frame: int,enabled: bool,effects: int=0,flags: int=0) -> void:
	OESnapshot.new().load_game(ui.session,"res://../build/fixtures/user_world_015.oe2")
	ui.hd_weapons.enabled=enabled;ui.hd_weapons.pending={}
	var vm: OEVM=ui.session.vm
	vm.set_field(vm.get_static("v","b","Lq;"),"q","g","I",weapon)
	if frame==1:
		vm.set_static("a","H","I",4);vm.set_static("u","a","Ls;",null);vm.set_static("u","m","I",1)
	var args: Array=[]
	vm.span_observer=func(key: String,values: Array):
		if key=="a(IIIIIIII)Z" and int(values[0])==weapon+1: args.assign(values)
	original("u","a(II)V",[0,0]);vm.span_observer=Callable()
	check(not args.is_empty(),"original weapon placement "+str(weapon))
	if args.is_empty(): return
	check(int(args[1])==frame,"original animation frame")
	original("k","a(IIII)V",[vm.get_static("a","h","I"),vm.get_static("a","i","I"),vm.get_static("a","j","I"),vm.get_static("a","k","I")])
	args[5]=effects;args[6]=flags
	vm.render_helpers.sprite_2d(args)
	var width: int=vm.get_static("k","b","I");var height: int=vm.get_static("k","c","I")
	var rect: JObject=vm.get_static("a","c","[I")
	ui.session.platform.draw_rgb(ui.session.platform.screen.data,[vm.get_static("k","m","[I"),0,width,rect.data[0],rect.data[1],width,height,0])
	ui._process(0)
func run() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	ui=load("res://main.tscn").instantiate();ui.testing=true;ui.paused=true;viewport.add_child(ui);ui.set_process(false)
	for sprite in [1,2]:
		for texture: Texture2D in ui.hd_weapons.ART[sprite]:
			var image: Image=texture.get_image()
			check(image.get_width()==1254 and image.get_height()==1254,"high resolution original canvas")
			check(image.get_pixel(0,0).a==0 and image.detect_alpha()!=Image.ALPHA_NONE,"generated alpha retained")
	var cases: Array=[]
	for weapon in [0,1]:
		for frame in [0,1]:
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
				var name: String=("wand" if weapon==0 else "staff")+"_%d_%s"%[frame,"classic" if mode==0 else "hd"]
				viewport.get_texture().get_image().save_png("res://../build/preview_"+name+".png")
			cases.append({"weapon":weapon,"frame":frame,"same_graph":pair[0]==pair[1],"args":ui.hd_weapons.current.get("args",[])})
	paint(0,0,true,32)
	check(ui.hd_weapons.current.is_empty(),"special palette uses original renderer")
	paint(0,0,true,0,0x20000)
	check(not ui.hd_weapons.current.is_empty(),"mirrored pose supported")
	for dims in [Vector2i(390,844),Vector2i(844,390),Vector2i(1280,720)]:
		viewport.size=dims;ui.size=Vector2(dims);ui.arrange();ui._process(0);await process_frame
		check(ui.hd_weapons.size.x>0 and ui.hd_weapons.size.y>0,"responsive clip "+str(dims))
	var report: Dictionary={"checks":checks,"failures":failures,"cases":cases,"errors":ui.session.vm.errors.duplicate()}
	FileAccess.open("res://../build/hd_weapons.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	ui.queue_free();await process_frame;viewport.queue_free();await process_frame
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://hd-weapon-proof.oe2"+suffix): DirAccess.remove_absolute("user://hd-weapon-proof.oe2"+suffix)
	quit(0 if failures.is_empty() else 1)
