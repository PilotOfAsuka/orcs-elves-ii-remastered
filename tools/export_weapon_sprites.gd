extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(game,"res://../build/fixtures/user_world_015.oe2"): quit(1);return
	var sprite: int=int(OS.get_cmdline_user_args()[0])
	var asset: String=OS.get_cmdline_user_args()[1]
	var vm: OEVM=game.vm
	var sprites: Array=vm.get_static("k","j","[S").data
	var materials: Array=vm.get_static("k","i","[S").data
	var edges: Array=vm.get_static("k","e","[S").data
	print("SPRITES ",str(sprites.slice(0,16)))
	var folder: String="res://assets/remastered/"+asset+"/reference"
	DirAccess.make_dir_recursive_absolute(folder)
	vm.set_static("k","b","I",128);vm.set_static("k","c","I",128)
	vm.set_static("k","n","[I",vm.new_array("[I",2));vm.get_static("k","n","[I").data.assign([0,0])
	vm.set_static("k","o","[I",vm.new_array("[I",2));vm.get_static("k","o","[I").data.assign([128,128])
	vm.set_static("k","m","[I",vm.new_array("[I",16384))
	vm.set_static("k","c","Z",0);vm.set_static("k","l","Z",0);vm.set_static("k","j","Z",0)
	var frames: Array=[]
	var end: int=materials.size()/2
	for start in sprites:
		if int(start)!=32767 and int(start)>int(sprites[sprite]): end=mini(end,int(start))
	for frame in end-int(sprites[sprite]):
		var pixels: Array=vm.get_static("k","m","[I").data;pixels.fill(0x12345678);vm.set_static("k","aX","I",-1)
		game.vm.render_helpers.sprite_2d([sprite,frame,32,64,0,0,0,0])
		var bytes:=PackedByteArray();bytes.resize(16384*4)
		for n in 16384:
			var packed: int=pixels[n]
			bytes.encode_u32(n*4,0 if packed==0x12345678 else ((packed&255)<<16)|(packed&0xff00)|((packed>>16)&255)|0xff000000)
		var image:=Image.create_from_data(128,128,false,Image.FORMAT_RGBA8,bytes)
		var source: Image=image.get_region(Rect2i(0,0,64,64))
		source.save_png(folder+"/source_frame_%02d.png"%frame)
		var source_zoom: Image=source.duplicate();source_zoom.resize(512,512,Image.INTERPOLATE_NEAREST)
		source_zoom.save_png(folder+"/source_frame_%02d_8x.png"%frame)
		var bounds: Rect2i=image.get_used_rect()
		var cropped: Image=image.get_region(bounds)
		var path: String=folder+"/original_frame_%02d.png"%frame
		cropped.save_png(path)
		var zoom: Image=cropped.duplicate();zoom.resize(cropped.get_width()*8,cropped.get_height()*8,Image.INTERPOLATE_NEAREST)
		zoom.save_png(folder+"/reference_frame_%02d_8x.png"%frame)
		var shape: int=materials[(int(sprites[sprite])+frame)*2]
		frames.append({"frame":frame,"source_sprite":sprite,"shape":shape,"shape_bounds":[edges[shape+2],edges[shape+3]],"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"path":path})
	FileAccess.open(folder+"/frames.json",FileAccess.WRITE).store_string(JSON.stringify({"jar_sha256":"759213ee5ce194f1ac92ff5937ffe562200e2c01dcfd76890c5148cf57787a33","frames":frames},"\t"))
	print(JSON.stringify(frames));game.close();quit()
