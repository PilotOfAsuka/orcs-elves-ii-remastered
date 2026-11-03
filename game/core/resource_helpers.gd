class_name OEResourceHelpers
extends RefCounted
## Exact inner loops in k.d()Z (shape run tables) and k.b()Z (wall nibbles).
## File selection, reads, allocation, progress and all game decisions stay in
## bytecode. Locals and the exit PC are preserved for snapshots and fallback.
var vm: OEVM

func _init(machine: OEVM) -> void:
	vm=machine

func accepts(owner: String, key: String) -> bool:
	return owner=="p" and key in ["a(I)Lg;","a(II)Lg;","a(III)Lg;"]

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

func invoke(frame: Dictionary, key: String) -> void:
	if key=="wall_nibbles": wall_nibbles(frame)
	else: shape_runs(frame)

func wall_nibbles(frame: Dictionary) -> void:
	var locals: Array=frame.locals
	var source: Array=vm.get_static("n","a","[B").data
	var destination: Array=vm.get_static("k","c","[B").data
	var offset: int=locals[0]
	var index: int=locals[16]
	var count: int=locals[15]
	if index<0 or count>source.size() or offset<0 or offset+2*maxi(0,count-index)>destination.size(): return
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
