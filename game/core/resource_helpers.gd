class_name OEResourceHelpers
extends RefCounted
## Exact binary readers, identity lookups and loader loops (shapes, texels, strings).
## File selection, reads, allocation, progress and all game decisions stay in
## bytecode. Locals and the exit PC are preserved for snapshots and fallback.
var fast_text: bool=true
var prepared_text: Variant=null
var vm: OEVM

func _init(machine: OEVM) -> void:
	vm=machine

func accepts(owner: String, key: String, args: Array=[]) -> bool:
	if owner=="a" and key=="a(SSLjava/lang/StringBuffer;)V" and fast_text:
		var began: int=Time.get_ticks_usec() if vm.profile_enabled else 0
		prepared_text=plan_text(args)
		if vm.profile_enabled: vm.record_native_profile("text:decode",began)
		return prepared_text!=null
	if owner=="p": return key in ["a(I)Lg;","a(II)Lg;","a(III)Lg;"]
	if owner=="n": return key in ["a()B","a()S","a(I)S","b(I)S","b()S","a()I","b()I","c()S"]
	if owner=="s" and key=="a()S": return vm.initialized.has("l") and int(vm.get_static("l","e","I"))<=32767
	return false

func invoke_method(owner: String, key: String, object: Variant, args: Array) -> Variant:
	if owner=="a":
		args[2].data=prepared_text;prepared_text=null;return null
	if owner=="p": return lookup(key,args)
	if owner=="s": return entity_index(object)
	return read_number(key,args)

func byte_at(array: Variant, index: int) -> Variant:
	if array==null: vm.throw_exception("java/lang/NullPointerException");return null
	if index<0 or index>=array.data.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(index));return null
	vm.render_helpers.raster.before_access(array)
	return int(array.data[index])

func read_number(key: String, args: Array) -> Variant:
	var array: Variant=vm.get_static("n","a","[B")
	var index: int=int(args[0]) if not args.is_empty() else int(vm.get_static("n","b","I"))
	# The one-byte a() overloads increment BEFORE baload, even on exceptions.
	if key in ["a()B","a()S"]: vm.set_static("n","b","I",OEVM.i32(index+1))
	var value: int=0
	if key=="b()I":
		# Preserve reverse access order and fault index from the original bytecode.
		for offset in [3,2,1,0]:
			var byte: Variant=byte_at(array,OEVM.i32(index+offset))
			if vm.exception!=null: return null
			value=OEVM.i32(value|((int(byte)&255)<<(offset*8)))
	else:
		var first: Variant=byte_at(array,index)
		if vm.exception!=null: return null
		value=int(first) if key=="a()B" else int(first)&255
		if key in ["b(I)S","b()S","a()I"]:
			var second: Variant=byte_at(array,OEVM.i32(index+1))
			if vm.exception!=null: return null
			value+=((int(second)<<8)&65280)
			if key!="a()I": value=OEVM.signed(value,16)
		elif key=="c()S": value=OEVM.signed(value<<3,16)
	if args.is_empty() and key not in ["a()B","a()S"]:
		var count: int=4 if key=="b()I" else (2 if key in ["b()S","a()I"] else 1)
		vm.set_static("n","b","I",OEVM.i32(index+count))
	return value

func entity_index(object: Variant) -> Variant:
	var count: int=vm.get_static("l","e","I")
	if count<=0: return -1
	var table: Variant=vm.get_static("l","b","[Ls;")
	if table==null: vm.throw_exception("java/lang/NullPointerException");return null
	for index in count:
		if index>=table.data.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(index));return null
		if object==table.data[index]: return index
	return -1

func lookup(key: String, args: Array) -> Variant:
	var count: int=vm.get_static("p","b","I")
	if count<=0: return null
	var table: Variant=vm.get_static("p","a","[Lg;")
	if not table is JObject: vm.throw_exception("java/lang/NullPointerException");return null
	var exact: bool=key=="a(I)Lg;"
	var variant: int=int(args[2]) if args.size()==3 else -1
	for index in count:
		if index>=table.data.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(index));return null
		var entry: Variant=table.data[index]
		if not entry is JObject: vm.throw_exception("java/lang/NullPointerException");return null
		if exact:
			if int(entry.fields["g.a:S"])==int(args[0]): return entry
		elif int(entry.fields["g.a:B"])==int(args[0]) and int(entry.fields["g.b:B"])==int(args[1]) and (variant==-1 or int(entry.fields["g.c:B"])==variant): return entry
	return null

func install() -> void:
	var shapes: Dictionary=vm.classes.k.methods["d()Z"]
	var texels: Dictionary=vm.classes.k.methods["b()Z"]
	assert(shapes.code[477]==[167,369] and shapes.code[371]==[162,478])
	assert(texels.code[254]==[167,226] and texels.code[228]==[162,255])
	shapes.resource_blocks={369:"shape_runs"}
	texels.resource_blocks={226:"wall_nibbles"}
	assert(vm.classes.k.methods["a(IIII)V"].code[149]==[167,142])
	assert(vm.classes.l.methods["b(I)V"].code[55]==[167,5])
	vm.classes.k.methods["a(IIII)V"].resource_blocks={142:"depth_reset"}
	vm.classes.l.methods["b(I)V"].resource_blocks={5:"inactive_threads"}
	var strings: Dictionary=vm.classes.a.methods["e(I)V"]
	assert(strings.code[104]==[167,94] and strings.code[140]==[167,123])
	strings.resource_blocks={94:"string_count",123:"string_offsets"}

func invoke(frame: Dictionary, key: String) -> void:
	if key=="string_count": string_count(frame)
	elif key=="string_offsets": string_offsets(frame)
	elif key=="inactive_threads": inactive_threads(frame)
	elif key=="depth_reset": depth_reset(frame)
	elif key=="wall_nibbles": wall_nibbles(frame)
	else: shape_runs(frame)

func wall_nibbles(frame: Dictionary) -> void:
	var locals: Array=frame.locals
	var source: Array=vm.get_static("n","a","[B").data
	var destination: Array=vm.get_static("k","c","[B").data
	var offset: int=locals[0]
	var index: int=locals[16]
	var count: int=locals[15]
	if index<0 or count>source.size() or offset<0 or offset+2*maxi(0,count-index)>destination.size(): return
	vm.render_helpers.raster.before_access(vm.get_static("k","c","[B"),true)
	while index<count:
		var value: int=int(source[index])&255
		destination[offset]=value&15
		destination[offset+1]=(value>>4)&15
		offset=OEVM.i32(offset+2)
		locals[17]=value
		index+=1
	locals[0]=offset
	locals[16]=index
	frame.pc=255
	frame.last=228

func shape_runs(frame: Dictionary) -> void:
	var locals: Array=frame.locals
	var source: Array=locals[6].data
	var destination: Array=vm.get_static("k","e","[S").data
	var cursor: int=locals[7]
	var base: int=locals[8]
	var width: int=locals[12]
	var height: int=locals[13]
	var stride: int=locals[14]
	var column: int=locals[17]
	# Keep malformed/boundary cases in bytecode, including its exception order.
	if cursor<0 or base<0 or column<0 or width<0 or height<0 or stride<0 or base+width+4>destination.size() or 12+width*stride>source.size(): return
	var required: int=cursor
	for x in range(column,width):
		var previous: bool=false
		for row in height:
			var present: bool=(int(source[12+x*stride+row/8])&(1<<(row&7)))!=0
			if present and not previous: required+=1
			previous=present
		required+=1
	if required>mini(destination.size(),32767): return
	vm.render_helpers.raster.before_access(vm.get_static("k","e","[S"),true)
	while column<width:
		destination[base+column+4]=OEVM.signed(cursor-base-2,16)
		var bitmap: int=OEVM.i32(12+column*stride)
		var y: int=0
		while y<height:
			while y<height and (int(source[bitmap+y/8])&(1<<(y&7)))==0: y+=1
			if y==height: break
			var start: int=y
			while y<height and (int(source[bitmap+y/8])&(1<<(y&7)))!=0: y+=1
			var length: int=y-start
			destination[cursor]=OEVM.signed(((start+int(source[10]))&255)|(length<<8),16)
			cursor=OEVM.signed(cursor+1,16)
			locals[20]=start
			locals[21]=length
		destination[cursor]=127
		cursor=OEVM.signed(cursor+1,16)
		column+=1
		locals[18]=bitmap
		locals[19]=y
	locals[7]=cursor
	locals[17]=column
	frame.pc=478
	frame.last=371

func depth_reset(frame: Dictionary) -> void:
	var object: Variant=vm.get_static("k","p","[I")
	var count: int=frame.locals[4]
	if not object is JObject or count<0 or count>object.data.size(): return
	for index in count: object.data[index]=2147483647
	frame.locals[4]=-1
	frame.pc=150;frame.last=144

func inactive_threads(frame: Dictionary) -> void:
	var pool: Variant=vm.get_static("l","a","[Lc;")
	var index: int=frame.locals[1]
	if not pool is JObject or pool.data.size()<20 or index<0 or index>20: return
	var previous: Variant=frame.locals[2]
	while index<20:
		var record: Variant=pool.data[index]
		if not record is JObject: return
		previous=record
		if int(record.fields.get("c.a:Z",0))!=0:
			frame.locals[1]=index;frame.locals[2]=record
			frame.pc=16;frame.last=14;return
		index+=1
	frame.locals[1]=20;frame.locals[2]=previous
	frame.pc=56;frame.last=7

func string_count(frame: Dictionary) -> void:
	var bytes: Variant=frame.locals[6]
	var index: int=frame.locals[8]
	if not bytes is JObject or index<0 or index>bytes.data.size(): return
	var count: int=frame.locals[7]
	for offset in range(index,bytes.data.size()):
		if int(bytes.data[offset])==0: count=OEVM.i32(count+1)
	frame.locals[7]=count;frame.locals[8]=bytes.data.size()
	frame.pc=105;frame.last=97

func string_offsets(frame: Dictionary) -> void:
	var bytes: Variant=frame.locals[6]
	var output: Variant=frame.locals[8]
	var index: int=frame.locals[9]
	var cursor: int=frame.locals[7]
	if not bytes is JObject or not output is JObject or index<0 or index>bytes.data.size() or cursor<0 or cursor>output.data.size(): return
	var required: int=0
	for offset in range(index,bytes.data.size()):
		if int(bytes.data[offset])==0: required+=1
	if required>output.data.size()-cursor: return
	vm.render_helpers.raster.before_access(output,true)
	for offset in range(index,bytes.data.size()):
		if int(bytes.data[offset])==0:
			output.data[cursor]=OEVM.signed(OEVM.i32(offset+1),16);cursor+=1
	frame.locals[7]=cursor;frame.locals[9]=bytes.data.size()
	frame.pc=141;frame.last=126

func plan_text(args: Array) -> Variant:
	# Original a.a(short,short,StringBuffer). Plan without side effects; every
	# exceptional or unsupported input runs the original bytecode, including
	# partially appended output and signed-short cursor wrap.
	if args.size()!=3 or not args[2] is JObject or args[2].type!="java/lang/StringBuffer" or not args[2].data is String: return null
	var group: int=args[0];var index: int=args[1]
	var texts: Variant=vm.get_static("a","a","[[B")
	var positions: Variant=vm.get_static("a","a","[[S")
	if not texts is JObject or not positions is JObject or group<0 or group>=texts.data.size() or group>=positions.data.size(): return null
	var bytes: Variant=texts.data[group];var offsets: Variant=positions.data[group]
	if not bytes is JObject or not offsets is JObject or index<0 or index>=offsets.data.size() or index>bytes.data.size(): return null
	var objects: Variant=vm.get_static("a","a","[Ljava/lang/Object;")
	var integers: Variant=vm.get_static("a","g","[I")
	var pixel_array: Variant=vm.render_helpers.raster.destination
	if pixel_array!=null and pixel_array in [texts,positions,bytes,offsets,objects,integers]: return null
	var cursor: int=int(offsets.data[index]);var pieces: PackedStringArray=[]
	var budget: int=bytes.data.size()+1
	while budget>0:
		budget-=1
		if cursor<0 or cursor>=bytes.data.size(): return null
		var letter: int=int(bytes.data[cursor])&255
		if letter==0: return str(args[2].data)+"".join(pieces)
		if letter==92 or letter==37:
			cursor=OEVM.signed(cursor+1,16)
			if cursor<0 or cursor>=bytes.data.size(): return null
			var escaped: int=int(bytes.data[cursor])
			if letter==92:
				if escaped==37: pieces.append("%")
				elif escaped==110: pieces.append("\n")
				else: pieces.append("\\"+String.chr(escaped&65535))
			else:
				var argument: int=escaped-49
				if argument>=0 and argument<int(vm.get_static("a","ab","I")):
					if not objects is JObject or argument>=objects.data.size(): return null
					var value: Variant=objects.data[argument]
					if value is JObject and value==args[2]: return null
					if value!=null:
						if value is JObject:
							if value.type not in ["java/lang/StringBuffer","java/lang/Integer"]: return null
							value=value.data
						pieces.append("null" if value==null else str(value))
					else:
						if not integers is JObject or argument>=integers.data.size(): return null
						pieces.append(str(integers.data[argument]))
		else: pieces.append(String.chr(letter))
		cursor=OEVM.signed(cursor+1,16)
	return null
