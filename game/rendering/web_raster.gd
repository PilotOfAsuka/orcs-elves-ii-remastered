class_name OEWebRaster
extends RefCounted
## Batches only pixel operations. CPU-visible Java arrays are synchronized before
## Java read/write and snapshot. drawRGB publishes an image without copying Java pixels.
var vm: OEVM
var enabled: bool=false
var defer_present: bool=true
var image_dirty: bool=true
var wall_jobs: int=0
var span_jobs: int=0
var batch_jobs: int=0
var sync_jobs: int=0
var texture_switches: int=0
var profile_enabled: bool=false
var profile_us: Dictionary={}

var commands:=PackedInt32Array()
var destination: JObject
var texture: JObject
var ready: bool=false
var js_active: bool=false
var last_edges: JObject
var last_texture: JObject
var image_destination: JObject
var image: Image

func _init(machine: OEVM) -> void:
	vm=machine
	enabled=OS.has_feature("web")

func record(name: String, began: int) -> void:
	if profile_enabled: profile_us[name]=int(profile_us.get(name,0))+Time.get_ticks_usec()-began

func enqueue(mode: int, args: Array) -> bool:
	if not enabled: return false
	var output: Variant=vm.get_static("k","m","[I")
	var texels: Variant=vm.get_static("k","c","[B")
	var palette: Variant=vm.get_static("k","q","[I")
	var stride: int=int(args[3]) if mode==-1 else int(vm.get_static("k","b","I"))
	var count: int=int(args[4]) if mode==-1 else int(args[3])
	if count<=0: return true
	if not output is JObject: return false
	var end: int=int(args[0])+(count-1)*stride
	if mini(int(args[0]),end)<0 or maxi(int(args[0]),end)>=output.data.size(): return false
	if mode!=8:
		if not texels is JObject or not palette is JObject or palette.data.size()!=16: return false
		var last: int=int(args[1])+(count-1)*int(args[2])
		var lower: int=mini(last,int(args[1]))
		var upper: int=maxi(last,int(args[1]))
		if lower<0 or upper>2147483647 or (upper>>(12 if mode==-1 else 13))>=texels.data.size(): return false
	if destination!=null and mode!=8 and texture!=null and texture!=texels: texture_switches+=1
	if destination!=null and (destination!=output or (mode!=8 and texture!=null and texture!=texels)): sync()
	destination=output
	image_dirty=true
	if mode!=8: texture=texels
	span_jobs+=1
	commands.append_array(PackedInt32Array([mode,args[0],args[1],args[2],stride,count]))
	commands.append_array(PackedInt32Array(palette.data) if mode!=8 else PackedInt32Array([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]))
	return true

func rows(args: Array) -> bool:
	if not enabled or int(args[1])<=0: return false
	var source: Variant=args[2]
	var output: Variant=args[3]
	var width: int=vm.get_static("k","b","I")
	var start: int=args[0]
	var count: int=args[1]
	if not source is JObject or not output is JObject or source==output or output!=vm.get_static("k","m","[I"): return false
	if width<=0 or source.data.size()<width or start<0 or start+count*width>output.data.size(): return false
	if destination!=null and destination!=output: sync()
	destination=output
	image_dirty=true
	commands.append_array(PackedInt32Array([10,start,count,width]))
	commands.append_array(PackedInt32Array(source.data.slice(0,width)))
	return true

func discard() -> void:
	commands.clear();js_active=false;destination=null;texture=null
	image=null;image_destination=null;last_texture=null;last_edges=null;image_dirty=true

func before_access(array: Variant, writing: bool=false) -> void:
	# Pending spans must consume the old texels before a Java write changes them.
	if writing and array==texture and not commands.is_empty(): prepare()
	if destination!=null and array==destination: sync()
	if writing and array==image_destination: image=null;image_destination=null;image_dirty=true
	if writing and array==last_texture: last_texture=null
	if writing and array==last_edges: last_edges=null

func prepare() -> void:
	var began: int=Time.get_ticks_usec() if profile_enabled else 0
	batch_jobs+=1
	if not ready:
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://rendering/raster.js"),true)
		ready=true
	if texture!=null and texture!=last_texture:
		var texels: String=Marshalls.raw_to_base64(PackedByteArray(texture.data))
		JavaScriptBridge.eval("OERaster.texels=OERaster.decodeTexels("+JSON.stringify(texels)+")",true)
		last_texture=texture
	if not js_active:
		var base: String=Marshalls.raw_to_base64(PackedInt32Array(destination.data).to_byte_array())
		JavaScriptBridge.eval("OERaster.start("+JSON.stringify(base)+")",true)
		js_active=true
	if not commands.is_empty():
		var batch: String=Marshalls.raw_to_base64(commands.to_byte_array())
		JavaScriptBridge.eval("OERaster.feed("+JSON.stringify(batch)+")",true)
		commands.clear()
	record("prepare",began)

func wall_columns(multi: bool=false) -> Variant:
	if not enabled: return null
	var began: int=Time.get_ticks_usec() if profile_enabled else 0
	wall_jobs+=1
	var vertices: Variant=vm.get_static("k","l","[I")
	if not vertices is JObject: return null
	var extent: int=OEVM.i32(int(vertices.data[3])-int(vertices.data[0]))
	if extent<=0: return false
	var output: Variant=vm.get_static("k","m","[I")
	var texels: Variant=vm.get_static("k","c","[B")
	if not output is JObject or not texels is JObject: return null
	if destination!=null and texture!=null and texture!=texels: texture_switches+=1
	if destination!=null and (destination!=output or (texture!=null and texture!=texels)): sync()
	destination=output;texture=texels
	image_dirty=true
	vm.set_static("k","ab","I",OEVM.i32(int(vm.get_static("k","ab","I"))+1))
	var materials: Array=vm.get_static("k","g","[S").data
	var material: int=vm.get_static("k","aT","I")
	var second_texture: int=int(materials[material*2])
	if multi:
		var other: int=vm.get_static("k","aU","I")
		var mode: int=vm.get_static("k","aP","I")
		if material!=other:
			vm.render_helpers.colors(int(materials[other*2+1]),mode)
			second_texture=int(materials[other*2])
			vm.get_static("k","r","[I").data.assign(vm.get_static("k","q","[I").data)
			if int(vm.get_static("k","d","S"))>64: vm.render_helpers.colors(int(materials[material*2+1]),mode)
			else: material=other
		else:
			vm.render_helpers.colors(int(materials[material*2+1]),mode)
			vm.get_static("k","r","[I").data.assign(vm.get_static("k","q","[I").data)
	else: vm.render_helpers.colors(int(materials[material*2+1]),0)
	var depth: JObject=vm.get_static("k","p","[I")
	var input: Dictionary={"vertices":vertices.data,"depth":depth.data,"lower":vm.get_static("k","n","[I").data,"upper":vm.get_static("k","o","[I").data,"flags":vm.get_static("k","ag","I"),"texture":materials[material*2],"palette":vm.get_static("k","q","[I").data}
	input.multi=multi
	input.texture2=second_texture
	if multi: input.palette2=vm.get_static("k","r","[I").data
	for pair in [["offset","aR","I"],["floor","c","S"],["ceiling","d","S"],["clipped","b","S"],["center","as","I"],["camera","aG","I"],["width","b","I"],["suppressed","c","Z"]]: input[pair[0]]=vm.get_static("k",pair[1],pair[2])
	input.offset=OEVM.i32(int(input.offset)-32)
	prepare()
	var result: Variant=JavaScriptBridge.eval("OERaster.columns("+JSON.stringify(JSON.stringify(input))+")",true)
	if not result is String: vm.fail("Browser wall columns failed");return false
	var report: Dictionary=JSON.parse_string(result)
	depth.data.assign(Array(PackedInt32Array(report.depth)))
	if multi and int(report.flipped)!=0:
		var previous: JObject=vm.get_static("k","q","[I")
		vm.set_static("k","q","[I",vm.get_static("k","r","[I"))
		vm.set_static("k","r","[I",previous)
	record("walls",began)
	return bool(report.empty)

func sprite_columns() -> Variant:
	if not enabled: return null
	var began: int=Time.get_ticks_usec() if profile_enabled else 0
	var vertices: Variant=vm.get_static("k","l","[I")
	if not vertices is JObject: return null
	var extent: int=OEVM.i32(int(vertices.data[3])-int(vertices.data[0]))
	if extent<=0: return true
	var output: Variant=vm.get_static("k","m","[I")
	var texels: Variant=vm.get_static("k","c","[B")
	if not output is JObject or not texels is JObject: return null
	if destination!=null and texture!=null and texture!=texels: texture_switches+=1
	if destination!=null and (destination!=output or (texture!=null and texture!=texels)): sync()
	destination=output;texture=texels
	image_dirty=true
	vm.set_static("k","af","I",OEVM.i32(int(vm.get_static("k","af","I"))+1))
	var materials: Array=vm.get_static("k","i","[S").data
	var material: int=vm.get_static("k","aT","I")
	vm.render_helpers.colors(int(materials[material*2+1]),int(vm.get_static("k","aP","I")))
	var input: Dictionary={"vertices":vertices.data,"depth":vm.get_static("k","p","[I").data,"lower":vm.get_static("k","n","[I").data,"upper":vm.get_static("k","o","[I").data,"flags":vm.get_static("k","ag","I"),"shape":materials[material*2],"palette":vm.get_static("k","q","[I").data}
	for pair in [["shift","aR","I"],["floor","c","S"],["ceiling","d","S"],["center","as","I"],["camera","aG","I"],["width","b","I"],["scale","aS","I"],["effects","aQ","I"],["mode","ba","I"]]: input[pair[0]]=vm.get_static("k",pair[1],pair[2])
	prepare()
	var edges: JObject=vm.get_static("k","e","[S")
	if edges!=last_edges:
		JavaScriptBridge.eval("OERaster.edges=OERaster.decode("+JSON.stringify(Marshalls.raw_to_base64(PackedInt32Array(edges.data).to_byte_array()))+")",true)
		last_edges=edges
	var result: Variant=JavaScriptBridge.eval("OERaster.sprites("+JSON.stringify(JSON.stringify(input))+")",true)
	if not result is String: vm.fail("Browser sprite columns failed");return false
	record("sprites",began)
	return bool(JSON.parse_string(result).empty)

func preview(array: Variant, width: int, height: int) -> Image:
	# drawRGB only needs the displayed image. Keep Java pixels buffered until a
	# real CPU read/write or snapshot; the next world frame can reuse this buffer.
	if not enabled or not defer_present or array!=destination: return null
	if width<=0 or width!=int(vm.get_static("k","b","I")) or height<=0 or width*height>array.data.size() or array.data.size()%width!=0: return null
	if not image_dirty and image_destination==array and image!=null: return image
	var began: int=Time.get_ticks_usec() if profile_enabled else 0
	prepare()
	var result: Variant=JavaScriptBridge.eval("OERaster.rgba()",true)
	if not result is PackedByteArray: vm.fail("Browser image preview failed");return null
	image=Image.create_from_data(width,array.data.size()/width,false,Image.FORMAT_RGBA8,result)
	image_destination=array;image_dirty=false
	record("preview",began)
	return image

func sync() -> void:
	if commands.is_empty() and not js_active: return
	sync_jobs+=1
	var began: int=Time.get_ticks_usec() if profile_enabled else 0
	prepare()
	var image_ready: bool=not image_dirty and image_destination==destination and image!=null
	# Godot's bundled _godot_js_eval transfers Uint8Array directly into a
	# PackedByteArray. Avoid base64 strings and repeated UTF-8 conversions.
	var result: Variant=JavaScriptBridge.eval("OERaster.readbackBytes()" if image_ready else "OERaster.finishBytes()",true)
	if result is PackedByteArray:
		var size: int=destination.data.size()*4
		if result.size()!=(size if image_ready else size*2): vm.fail("Browser pixel buffer size mismatch");return
		destination.data.assign(Array(result.slice(0,size).to_int32_array()))
		var width: int=vm.get_static("k","b","I")
		if not image_ready and width>0 and destination.data.size()%width==0:
			image=Image.create_from_data(width,destination.data.size()/width,false,Image.FORMAT_RGBA8,result.slice(size))
			image_destination=destination;image_dirty=false
	else: vm.fail("Browser pixel kernel failed")
	commands.clear();js_active=false;destination=null;texture=null
	record("sync",began)
