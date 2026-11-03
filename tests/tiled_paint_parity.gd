extends SceneTree
var game: OEGameSession
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func checksum() -> String:
	OESnapshot.new().save_game(game,"user://tiled-paint-parity.oe2")
	return FileAccess.open("user://tiled-paint-parity.oe2",FileAccess.READ).get_var(false).checksum
func run() -> void:
	game=OEGameSession.new(false)
	var key: String="a(Ljavax/microedition/lcdui/Image;IIIIIII)V"
	var source: Dictionary=game.vm.classes.a.methods[key]
	var ref: Dictionary={"owner":"a","name":"a","desc":source.desc,"params":source.params,"return":"V"}
	var wrapper: Dictionary={"name":"qaTiles","desc":"()V","params":[],"return":"V","max_locals":0,"flags":8,"exceptions":[],"code":[[184,ref],[177]]}
	game.vm.classes.a.methods["qaTiles()V"]=wrapper
	var comparisons: int=0
	for dims in [[0,0],[31,19],[4,3]]:
		for anchor in [0,8,16,2,32,20,40,10]:
			var results: Array=[]
			for fast in [false,true]:
				OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_014.oe2");game.vm.fast_geometry=fast
				var image:=Image.create(9,7,false,Image.FORMAT_RGBA8)
				for y in 7:
					for x in 9: image.set_pixel(x,y,Color8(x*25,y*30,160,100 if (x+y)%2 else 255))
				var asset:=JObject.new("javax/microedition/lcdui/Image");asset.data=image
				var main: Array[Dictionary]=game.vm.fibers.duplicate();game.vm.fibers.clear()
				var fiber: Dictionary=game.vm.launch("a","qaTiles()V")
				fiber.frames.back().stack.assign([asset,0,0,dims[0],dims[1],5,3,anchor])
				for n in 1000:
					if fiber.frames.is_empty() or game.vm.halted: break
					game.vm.tick(0)
				game.vm.fibers.assign(main)
				results.append({"graph":checksum(),"pixels":game.platform.screen.data.surface.get_data().hex_encode().sha256_text(),"errors":game.vm.errors.duplicate()})
			comparisons+=1
			if results[0]!=results[1]: failures.append(str([dims,anchor]))
	var report: Dictionary={"comparisons":comparisons,"failures":failures}
	FileAccess.open("res://../build/tiled_paint_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://tiled-paint-parity.oe2"+suffix): DirAccess.remove_absolute("user://tiled-paint-parity.oe2"+suffix)
	game.close();quit(0 if failures.is_empty() else 1)
