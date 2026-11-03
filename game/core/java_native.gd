class_name OEJavaNative
extends RefCounted
## Only platform APIs are implemented here. No creature/combat/quest decisions.
var vm: OEVM
var screen: JObject
var display: JObject = JObject.new("javax/microedition/lcdui/Display")
var saves: OESaveManager
var audio: Node
var image_cache: Dictionary = {}
var random_serial: int = 0
var flush_count: int = 0
var deterministic: bool = false
var unsupported: Dictionary = {}
var exit_requested: bool = false
var requested_url: String = ""
var alert_text: String = ""
var native_statics: Dictionary = {}

func get_static(owner: String, name: String, desc: String) -> Variant:
	var key: String = owner+"."+name+":"+desc
	if native_statics.has(key): return native_statics[key]
	if key in ["java/lang/System.out:Ljava/io/PrintStream;","javax/microedition/lcdui/AlertType.ERROR:Ljavax/microedition/lcdui/AlertType;"]:
		var value := JObject.new(desc.trim_prefix("L").trim_suffix(";"))
		native_statics[key] = value
		return value
	vm.fail("Missing Java static field: "+key)
	return null

func draw_rgb(g: OEMidpGraphics, args: Array) -> void:
	var source: Array = args[0].data
	var start: int = int(args[1])
	var scan: int = int(args[2])
	var x: int = int(args[3])+g.offset.x
	var y: int = int(args[4])+g.offset.y
	var width: int = int(args[5])
	var height: int = int(args[6])
	var alpha: bool = int(args[7])!=0
	var rect := Rect2i(x,y,maxi(0,width),maxi(0,height)).intersection(g.clip)
	for yy in range(rect.position.y,rect.end.y):
		for xx in range(rect.position.x,rect.end.x):
			var packed: int = int(source[start+(yy-y)*scan+xx-x])
			var color := Color8((packed>>16)&255,(packed>>8)&255,packed&255,(packed>>24)&255 if alpha else 255)
			if color.a8==255: g.surface.set_pixel(xx,yy,color)
			elif color.a8>0: g.surface.set_pixel(xx,yy,g.surface.get_pixel(xx,yy).blend(color))
	g.dirty = true
	# Preserve the actual world paint before the original HUD/dialogue overlays.
	# Store it in the Java graphics object's extra data so graph snapshots retain it.
	if g==screen.data and args[0]==vm.get_static("k","m","[I"):
		var world_rect := Rect2i(x,y,width,height)
		if Rect2i(Vector2i.ZERO,g.surface.get_size()).encloses(world_rect) and g.clip.encloses(world_rect):
			screen.extra.world_surface=g.surface.get_region(world_rect)
			screen.extra.world_revision=int(screen.extra.get("world_revision",0))+1

func draw_region(g: OEMidpGraphics, args: Array) -> void:
	var image: Image = args[0].data
	var region := image.get_region(Rect2i(args[1],args[2],args[3],args[4]))
	var transform: int = int(args[5])
	match transform:
		1: region.flip_y()
		2: region.flip_x()
		3: region.flip_x(); region.flip_y()
		4: region.flip_x(); region.rotate_90(COUNTERCLOCKWISE)
		5: region.rotate_90(CLOCKWISE)
		6: region.rotate_90(COUNTERCLOCKWISE)
		7: region.flip_x(); region.rotate_90(CLOCKWISE)
	g.blit(region,int(args[6]),int(args[7]),int(args[8]))

func _init(machine: OEVM, storage: OESaveManager, sound: Node = null) -> void:
	vm = machine; saves = storage; audio = sound
	screen = JObject.new("javax/microedition/lcdui/Graphics")
	screen.data = OEMidpGraphics.new()

func byte_array(bytes: PackedByteArray) -> JObject:
	var o: JObject = vm.new_array("[B",bytes.size())
	for n: int in bytes.size(): o.data[n] = OEVM.signed(bytes[n],8)
	return o

func bytes_of(array: JObject) -> PackedByteArray:
	var bytes: PackedByteArray = []
	for b: Variant in array.data: bytes.append(int(b)&255)
	return bytes

func stream(bytes: PackedByteArray, path: String = "") -> JObject:
	var s: JObject = JObject.new("java/io/InputStream")
	s.data = bytes
	s.extra = {"pos":0,"path":path}
	return s

func take(s: JObject, count: int) -> PackedByteArray:
	var result: PackedByteArray = s.data.slice(int(s.extra.pos),int(s.extra.pos)+count)
	s.extra.pos += result.size()
	if result.size()<count: vm.throw_exception("java/io/EOFException")
	return result

func utf(s: JObject) -> String:
	var len_bytes: PackedByteArray = take(s,2)
	if vm.exception!=null: return ""
	var bytes: PackedByteArray = take(s,(int(len_bytes[0])<<8)|int(len_bytes[1]))
	var units: PackedByteArray = []; var p: int = 0
	while p<bytes.size():
		var c: int = bytes[p]; p+=1
		var u: int = c
		if c & 224 == 192:
			u = ((c&31)<<6)|(int(bytes[p])&63); p+=1
		elif c & 240 == 224:
			u = ((c&15)<<12)|((int(bytes[p])&63)<<6)|(int(bytes[p+1])&63); p+=2
		units.append(u&255); units.append(u>>8)
	return units.get_string_from_utf16()

func random_next(o: JObject, bits: int) -> int:
	# java.util.Random's 48-bit LCG; split multiplication avoids overflowing int64.
	var seed: int = int(o.data)
	var low: int = seed & 16777215
	var high: int = seed >> 24
	var product: int = low * 25214903917 + 11
	seed = (product + (((high*25214903917)&16777215)<<24)) & 281474976710655
	o.data = seed
	return seed >> (48-bits)

func invoke(ref: Dictionary, o: Variant, args: Array, fiber: Dictionary) -> Variant:
	var owner: String = ref.owner
	var name: String = ref.name
	var desc: String = ref.desc
	if name=="<init>" and owner.begins_with("java/") and (owner.ends_with("Exception") or owner.ends_with("Error")):
		o.data = "" if args.is_empty() else args[0]
		return null
	if owner=="java/lang/Class" and name=="forName":
		var klass := JObject.new("java/lang/Class")
		klass.data = args[0]
		return klass
	if owner=="java/lang/Runtime":
		if name=="getRuntime": return JObject.new(owner)
		if name=="freeMemory": return JLong.new(8388608)
		if name=="totalMemory": return JLong.new(16777216)
	if owner=="javax/microedition/midlet/MIDlet" and name=="getAppProperty": return null
	if owner=="javax/microedition/midlet/MIDlet" and name=="platformRequest":
		# The original contains external promotional links; record the request locally.
		requested_url = str(args[0])
		return 0
	if name=="hashCode": return OEVM.i32(o.get_instance_id())
	if owner=="java/lang/Object" and name=="equals": return 1 if o==args[0] else 0
	if owner=="java/lang/Throwable": return str(o.data)
	if owner=="java/lang/Thread" and name=="setPriority": return null
	if owner=="java/lang/Integer" and name=="parseInt":
		if not str(args[0]).is_valid_int(): vm.throw_exception("java/lang/NumberFormatException"); return 0
		return int(args[0])
	if owner in ["java/lang/Integer","java/lang/Long"] and name=="toString": return str(OEVM.number(args[0]))
	if owner=="java/lang/String":
		match name:
			"compareTo":
				var left: String = str(o)
				var right: String = str(args[0])
				for n in mini(left.length(),right.length()):
					if left.unicode_at(n)!=right.unicode_at(n): return left.unicode_at(n)-right.unicode_at(n)
				return left.length()-right.length()
			"toLowerCase": return str(o).to_lower()
			"trim": return str(o).strip_edges()
			"valueOf": return String.chr(int(args[0])) if desc=="(C)Ljava/lang/String;" else str(args[0])
	if owner=="java/lang/StringBuffer":
		match name:
			"length": return o.data.length()
			"charAt": return o.data.unicode_at(int(args[0]))
			"setLength":
				var size: int = int(args[0])
				o.data = o.data.substr(0,size) if size<=o.data.length() else o.data+String.chr(0).repeat(size-o.data.length())
				return null
			"setCharAt": o.data = o.data.substr(0,int(args[0]))+String.chr(int(args[1]))+o.data.substr(int(args[0])+1); return null
			"insert": o.data = o.data.insert(int(args[0]),String.chr(int(args[1])) if desc.begins_with("(IC)") else str(args[1])); return o
	if name=="<init>" and owner=="java/io/ByteArrayOutputStream": o.data = []; return null
	if name=="<init>" and owner=="java/io/DataOutputStream": o.data = args[0].data; return null
	if owner=="java/io/ByteArrayOutputStream" and name=="toByteArray":
		var result := vm.new_array("[B",o.data.size())
		result.data = o.data.duplicate()
		return result
	if owner=="java/io/DataOutputStream" and name.begins_with("write"):
		var count: int = {"writeBoolean":1,"writeByte":1,"writeShort":2,"writeInt":4}.get(name,0)
		if count==0: vm.fail("Unsupported output API: "+name); return null
		var value: int = int(args[0])
		for n in range(count-1,-1,-1): o.data.append(OEVM.signed((value>>(8*n))&255,8))
		return null
	if owner.begins_with("java/io/") and name in ["readUnsignedByte","readBoolean"]:
		var bytes := take(o,1)
		if vm.exception!=null: return 0
		return (1 if bytes[0]!=0 else 0) if name=="readBoolean" else int(bytes[0])
	if owner=="java/io/PrintStream" and name=="println": print(str(args[0])); return null
	if owner=="javax/microedition/lcdui/Display" and name=="getCurrent": return display.data
	if owner=="javax/microedition/lcdui/Display" and name=="vibrate": return 0
	if owner=="javax/microedition/lcdui/Image" and name=="getWidth": return o.data.get_width()
	if owner=="javax/microedition/lcdui/Image" and name=="getHeight": return o.data.get_height()
	if owner=="javax/microedition/lcdui/Alert" and name in ["<init>","setString","setTimeout","setType"]:
		if name=="setString": alert_text = str(args[0]); vm.fail("Original game alert: "+alert_text)
		return null
	if owner=="javax/microedition/rms/RecordStore" and name=="listRecordStores":
		if saves.records.is_empty(): return null
		var stores := vm.new_array("[Ljava/lang/String;",saves.records.size())
		stores.data = saves.records.keys()
		return stores
	if owner=="javax/microedition/rms/RecordStore" and name=="enumerateRecords":
		var enumeration := JObject.new("javax/microedition/rms/RecordEnumeration")
		enumeration.data = o.data
		return enumeration
	if owner=="javax/microedition/rms/RecordEnumeration" and name=="nextRecordId": return 1
	if owner=="javax/microedition/rms/RecordStore" and name=="addRecord":
		if not saves.commit(o.data,args[0].data.slice(int(args[1]),int(args[1])+int(args[2]))): vm.throw_exception("javax/microedition/rms/RecordStoreException",saves.last_error)
		return 1
	if owner=="javax/microedition/media/Player":
		if name=="getState": return int(o.extra.get("state",100))
		if name in ["close","deallocate"]:
			if audio!=null: audio.stop_midi(o.data)
			o.extra.state = 0 if name=="close" else 100
			return null
		if name=="prefetch": o.extra.state = 300; return null
		if name=="start": o.extra.state = 400
		if name=="stop": o.extra.state = 300
	if name=="<init>":
		match owner:
			"java/lang/StringBuffer": o.data = str(args[0]) if desc == "(Ljava/lang/String;)V" else ""
			"java/util/Vector": o.data = []
			"java/lang/Integer": o.data = args[0]
			"java/lang/Thread": o.data = args[0]
			"java/util/Random":
				random_serial += 1
				var seed: int = OEVM.number(args[0]) if not args.is_empty() else (vm.epoch_ms+vm.now_ms+random_serial*997)
				o.data = (seed ^ 25214903917) & 281474976710655
			"java/io/DataInputStream": o.data = args[0].data; o.extra = args[0].extra
			"java/io/ByteArrayInputStream": o.data = bytes_of(args[0]); o.extra = {"pos":0,"path":""}
		return null
	if owner=="java/lang/System":
		match name:
			"currentTimeMillis": return JLong.new(vm.epoch_ms+vm.now_ms)
			"getProperty": return "ru" if args[0]=="microedition.locale" else ""
			"gc": return null
			"arraycopy":
				var segment: Array = args[0].data.slice(int(args[1]),int(args[1])+int(args[4]))
				for n: int in segment.size(): args[2].data[int(args[3])+n] = segment[n]
				return null
	if owner=="java/lang/Thread":
		match name:
			"start": vm.launch(o.data.type,"run()V",o.data); return null
			"yield": fiber.yielded = true; return null
			"sleep": fiber.wake = vm.now_ms+maxi(1,OEVM.number(args[0])); fiber.yielded = true; return null
	if owner=="java/lang/Math":
		if name=="max": return maxi(args[0],args[1])
		if name=="abs": return OEVM.i32(absi(int(args[0])))
	if owner=="java/util/Random":
		if name=="setSeed": o.data = (OEVM.number(args[0])^25214903917)&281474976710655; return null
		if name=="nextInt": return OEVM.i32(random_next(o,32))
	if owner=="java/lang/Integer" and name=="intValue": return o.data
	if owner=="java/lang/String" or o is String:
		match name:
			"valueOf": return str(args[0])
			"equals": return 1 if args[0] is String and o==args[0] else 0
			"length": return o.length()
			"charAt": return o.unicode_at(int(args[0]))
			"substring": return o.substr(int(args[0]),int(args[1])-int(args[0])) if args.size()>1 else o.substr(int(args[0]))
			"indexOf": return o.find(String.chr(int(args[0])),int(args[1]) if args.size()>1 else 0)
			"startsWith": return 1 if o.begins_with(args[0]) else 0
			"toString": return o
	if owner=="java/lang/StringBuffer":
		match name:
			"append":
				var value: Variant = args[0]
				if value is JObject and value.type in ["java/lang/StringBuffer","java/lang/Integer"]: value = value.data
				o.data += String.chr(int(value)) if desc.begins_with("(C)") else ("null" if value==null else str(value))
				return o
			"deleteCharAt": o.data = o.data.substr(0,int(args[0]))+o.data.substr(int(args[0])+1); return o
			"toString": return o.data
	if owner=="java/util/Vector":
		match name:
			"addElement": o.data.append(args[0]); return null
			"elementAt": return o.data[int(args[0])]
			"firstElement": return o.data[0]
			"removeElementAt": o.data.remove_at(int(args[0])); return null
			"size": return o.data.size()
			"isEmpty": return 1 if o.data.is_empty() else 0
	if name=="getClass": return JObject.new("java/lang/Class")
	if owner=="java/lang/Class" and name=="getResourceAsStream":
		var path: String = "res://assets/original/"+str(args[0]).trim_prefix("/")
		return stream(FileAccess.get_file_as_bytes(path),args[0]) if FileAccess.file_exists(path) else null
	if name=="wait":
		fiber.monitor_depth = int(o.extra.get("monitor_depth",1))
		o.extra.monitor_owner = 0
		o.extra.monitor_depth = 0
		fiber.waiting = o
		fiber.yielded = true
		return null
	if name in ["notify","notifyAll"]:
		for f: Dictionary in vm.fibers:
			if f.waiting==o:
				f.waiting = null
				f.reacquire = o
				if name=="notify": break
		return null
	if owner.begins_with("java/io/"):
		match name:
			"close": return null
			"readUTF": return utf(o)
			"skipBytes":
				var count: int = mini(maxi(0,int(args[0])),o.data.size()-int(o.extra.pos))
				o.extra.pos += count; return count
			"readByte","readShort","readInt":
				var count: int = 1 if name=="readByte" else (2 if name=="readShort" else 4)
				var bytes: PackedByteArray = take(o,count)
				if vm.exception!=null: return 0
				var result: int = 0
				for b: int in bytes: result = (result<<8)|b
				return OEVM.signed(result,count*8)
			"read":
				var start: int = int(args[1]) if args.size()>1 else 0
				var wanted: int = int(args[2]) if args.size()>1 else args[0].data.size()
				if wanted==0: return 0
				var count: int = mini(wanted,o.data.size()-int(o.extra.pos))
				for n: int in count: args[0].data[start+n] = OEVM.signed(int(o.data[int(o.extra.pos)+n]),8)
				o.extra.pos += count
				return count if count>0 else -1
	if owner=="javax/microedition/rms/RecordStore":
		match name:
			"openRecordStore":
				if not saves.records.has(args[0]) and int(args[1])==0:
					vm.throw_exception("javax/microedition/rms/RecordStoreNotFoundException",str(args[0])); return null
				var record: JObject = JObject.new(owner); record.data = str(args[0]); return record
			"closeRecordStore": return null
			"getNumRecords": return 1 if saves.records.has(o.data) else 0
			"getRecord":
				var arr: JObject = vm.new_array("[B",saves.records[o.data].size()); arr.data = saves.records[o.data].duplicate(); return arr
			"addRecord": saves.commit(o.data,[]); return 1
			"setRecord":
				if not saves.commit(o.data,args[1].data.slice(int(args[2]),int(args[2])+int(args[3]))): vm.throw_exception("javax/microedition/rms/RecordStoreException",saves.last_error)
				return null
			"deleteRecordStore": saves.delete(args[0]); return null
	if owner=="javax/microedition/lcdui/Font":
		match name:
			"getFont":
				var font: JObject = JObject.new(owner); font.data = {"bold":int(args[1])&1 != 0}; return font
			"getHeight": return int(screen.data.font_data(o.data.bold).height)
			"stringWidth": return screen.data.width(args[0],o.data.bold)
	if owner=="javax/microedition/lcdui/Image":
		match name:
			"createImage":
				var im: Image
				var path: String = ""
				if args.size()==1:
					path = "res://assets/original/"+str(args[0]).trim_prefix("/")
					if image_cache.has(path): return image_cache[path]
					im = load(path).get_image()
				elif args.size()==2: im = Image.create(int(args[0]),int(args[1]),false,Image.FORMAT_RGBA8); im.fill(Color.WHITE)
				else:
					im = Image.new(); im.load_png_from_buffer(bytes_of(args[0]).slice(int(args[1]),int(args[1])+int(args[2])))
				im.convert(Image.FORMAT_RGBA8)
				var obj: JObject = JObject.new(owner); obj.data = im; obj.extra.path = path
				if not path.is_empty(): image_cache[path] = obj
				return obj
			"getGraphics":
				var graphics: JObject = JObject.new("javax/microedition/lcdui/Graphics"); graphics.data = OEMidpGraphics.new(o.data); return graphics
	if owner=="javax/microedition/lcdui/Graphics":
		var g: OEMidpGraphics = o.data
		match name:
			"setColor": g.set_color(int(args[0]) if args.size()==1 else ((int(args[0])<<16)|(int(args[1])<<8)|int(args[2])))
			"getColor": return (g.color.r8<<16)|(g.color.g8<<8)|g.color.b8
			"clipRect":
				var rect := g.clip.intersection(Rect2i(Vector2i(args[0],args[1])+g.offset,Vector2i(maxi(0,args[2]),maxi(0,args[3]))))
				g.clip = rect
			"drawRGB": draw_rgb(g,args)
			"drawRegion": draw_region(g,args)
			"setClip": g.set_clip(args[0],args[1],args[2],args[3])
			"fillRect": g.fill_rect(args[0],args[1],args[2],args[3])
			"drawRect": g.draw_rect(args[0],args[1],args[2],args[3])
			"drawLine": g.line(args[0],args[1],args[2],args[3])
			"drawArc": g.arc(args,false)
			"fillArc": g.arc(args,true)
			"drawImage": g.blit(args[0].data,args[1],args[2],args[3])
			"drawString": g.string(args[0],args[1],args[2],args[3])
			"setFont": g.font_bold = args[0].data.bold
			"getClipX": return g.clip.position.x-g.offset.x
			"getClipY": return g.clip.position.y-g.offset.y
			"getClipWidth": return g.clip.size.x
			"getClipHeight": return g.clip.size.y
			"translate": g.offset += Vector2i(args[0],args[1])
			_: vm.fail("Missing graphics API "+name)
		return null
	if name=="getGraphics": return screen
	if name=="flushGraphics": flush_count += 1; return null
	if name=="getWidth": return 352
	if name=="getHeight": return 416
	if name=="getGameAction": return {-1:1,-2:6,-3:2,-4:5,-5:8}.get(int(args[0]),0)
	if name=="setFullScreenMode": return null
	if name=="getDisplay": return display
	if name=="setCurrent": display.data = args[0]; return null
	if name=="notifyDestroyed": vm.halted = true; exit_requested = true; return null
	if name=="notifyPaused": return null
	if owner=="javax/microedition/media/Manager":
		var player: JObject = JObject.new("javax/microedition/media/Player"); player.data = args[0].data; player.extra.loop = 1; return player
	if owner.begins_with("javax/microedition/media/"):
		match name:
			"prefetch": return null
			"getControl": return JObject.new("javax/microedition/media/control/VolumeControl")
			"setLevel": return args[0]
			"setLoopCount": o.extra.loop = args[0]; return null
			"start":
				if audio!=null: audio.play_midi(o.data,int(o.extra.loop))
				return null
			"stop":
				if audio!=null: audio.stop_midi(o.data)
				return null
	var api: String = owner+"."+name+desc
	unsupported[api] = true
	vm.fail("Missing Java ME API: "+api)
	return null
