class_name OERenderHelpers
extends RefCounted
## Exact fixed-point software-rendering routines from original class k.
## Every array and rendering counter belongs to the original game state.
var vm: OEVM
var raster: OEWebRaster

func _init(machine: OEVM) -> void:
	vm=machine
	raster=OEWebRaster.new(vm)

func accepts(owner: String, key: String) -> bool:
	return owner=="k" and key in ["a(IIIII)V","b(IIII)V","b(II)V","f()Z","h()Z","a(IIIIIIII)Z"]

func data(name: String, desc: String) -> Array:
	var object: Variant=vm.get_static("k",name,desc)
	if not object is JObject:
		vm.throw_exception("java/lang/NullPointerException")
		return []
	return object.data

func invoke(key: String, args: Array) -> Variant:
	match key:
		"a(IIIII)V": wall(args)
		"b(IIII)V": sprite(args)
		"b(II)V": colors(args[0],args[1])
		"f()Z": return int(wall_columns())
		"h()Z": return int(sprite_columns())
		"a(IIIIIIII)Z": return int(sprite_2d(args))
	return null

func number(name: String, desc: String="I") -> int:
	return int(vm.get_static("k",name,desc))

func colors(offset: int, mode: int) -> void:
	if number("c","Z")!=0 or mode==255:
		vm.set_static("k","ba","I",255);return
	if number("l","Z")!=0: mode=0
	var effects: int=number("aQ")
	var cache: int=OEVM.i32(offset+(mode<<16)+(effects<<24))
	if cache==number("aX"): return
	vm.set_static("k","aX","I",cache)
	var source: Array=data("f","[S")
	var palette: Array=data("q","[I")
	for index in 16:
		var rgb: int=int(source[offset+index])
		var color: int=OEVM.i32(0xff000000|(((rgb>>11)&63)<<19)|(((rgb>>5)&63)<<10)|((rgb&31)<<3))
		var blue: int=color&255
		var green: int=(color>>8)&255
		var red: int=(color>>16)&255
		if (effects&4)!=0:
			blue=(red+green+blue)/3;green=blue;red=blue
		if (effects&8)!=0:
			red=mini(red+64,255);green=mini(green+64,255);blue=mini(blue+64,255)
		if (effects&32)!=0: blue=mini(blue+64,255)
		if (effects&64)!=0: green=mini(green+64,255)
		if (effects&128)!=0:
			red=mini(red+64,255);green=maxi(green-16,0);blue=maxi(blue-16,0)
		if (effects&256)!=0: red=mini(red+128,255)
		if (effects&492)!=0: color=(red<<16)|(green<<8)|blue
		match mode:
			1: color=(color&0xfcfcfc)>>2
			3: color=((color&0xfefefe)>>1)+((color&0xfcfcfc)>>2)
			4: color=color&0xfefefe
			5: color=((color&0xfcfcfc)>>1)+((color&0xf8f8f8)>>2)
			6: color=(color&0xfcfcfc)>>1
			7: color=(color&0xf8f8f8)>>2
		palette[index]=color
	vm.set_static("k","ba","I",4 if mode in [5,6,7] else mode)

func wall_columns() -> bool:
	if raster.enabled:
		var result: Variant=raster.wall_columns()
		if result!=null: return bool(result)
	var vertices: Array=data("l","[I")
	var flags: int=number("ag")
	var extent: int=OEVM.i32(int(vertices[3])-int(vertices[0]))
	if extent<=0: return false
	vm.set_static("k","ab","I",OEVM.i32(number("ab")+1))
	extent=OEVM.i32((2147483647/extent)<<1)
	var step_y: int=OEVM.i32((OEVM.i32(int(vertices[4])-int(vertices[1]))*extent)>>16)
	var step_u: int=OEVM.i32((OEVM.i32(int(vertices[5])-int(vertices[2]))*extent)>>16)
	var lower: Array=data("n","[I")
	var upper: Array=data("o","[I")
	var left: int=maxi(OEVM.i32(int(vertices[0])+65535)>>16,int(lower[0]))
	var right: int=mini(OEVM.i32(int(vertices[3])+65535)>>16,int(upper[0]))
	var delta: int=OEVM.i32((left<<16)-int(vertices[0]))
	var u: int=OEVM.i32(int(vertices[2])+OEVM.i32((delta*step_u)>>16))
	var y: int=OEVM.i32(int(vertices[1])+OEVM.i32((delta*step_y)>>16))
	var material: Array=data("g","[S")
	var texture: int=int(material[number("aT")*2])
	colors(int(material[number("aT")*2+1]),0)
	var camera_offset: int=OEVM.i32(number("aR")-32)
	var depth: Array=data("p","[I")
	var floor_height: int=number("c","S")
	var ceiling: int=number("d","S")
	var clipped_height: int=number("b","S")
	var center: int=number("as")
	var camera: int=number("aG")
	var width: int=number("b")
	var empty: bool=true
	while left<right:
		var distance: int=OEVM.i32((0x40000000/y)<<2)
		var column: int=OEVM.i32((u*distance)>>32)&63
		if distance<=int(depth[left]):
			if (flags&0x10000)==0: depth[left]=distance
			distance>>=3
			var texel: int=OEVM.i32(texture+(column<<6))
			var height: int=64
			var screen_y: int=-1
			while height>floor_height:
				var length: int=64
				if (flags&0x80000)!=0 and OEVM.i32(height+camera_offset)>ceiling:
					length=OEVM.i32(64-OEVM.i32(height+camera_offset-clipped_height))
					texel=OEVM.i32(texel+(OEVM.i32(OEVM.i32(height+camera_offset-ceiling)*64)>>6))
					height=OEVM.i32(clipped_height-camera_offset)
				if OEVM.i32(height+camera_offset-length)<floor_height: length=OEVM.i32(height+camera_offset-floor_height)
				if length<=0: continue
				var pixels: int=OEVM.i32(length*y)>>17
				if screen_y==-1: screen_y=OEVM.i32(center-(OEVM.i32(OEVM.i32(height-camera+camera_offset)*y+32768)>>17))
				var position: int=OEVM.i32(texel<<12)
				if screen_y<int(lower[1]):
					position=OEVM.i32(position+distance*OEVM.i32(int(lower[1])-screen_y))
					pixels=OEVM.i32(pixels-OEVM.i32(int(lower[1])-screen_y));screen_y=int(lower[1])
				if OEVM.i32(screen_y+pixels)>int(upper[1]): pixels=OEVM.i32(int(upper[1])-screen_y)
				if pixels>0:
					empty=false;wall([OEVM.i32(left+screen_y*width),position,distance,width,pixels])
				screen_y=OEVM.i32(screen_y+pixels);height=OEVM.i32(height-64)
		y=OEVM.i32(y+step_y);u=OEVM.i32(u+step_u);left+=1
	return empty

func sprite_2d(args: Array) -> bool:
	if number("j","Z")!=0: return true
	var width: int=number("b")
	var unit: int=32768/width
	var inverse: int=65536/unit
	var vertical: int=inverse
	var texture_position: int=0
	var sprites: Array=data("j","[S")
	var materials: Array=data("i","[S")
	var edges: Array=data("e","[S")
	var material: int=OEVM.i32(int(sprites[int(args[0])])+int(args[1]))
	var texture: int=int(materials[material*2])
	var scale: int=args[7]
	var advance: int=OEVM.i32(unit<<8)/scale if scale!=0 else unit
	var start: int=int(edges[texture+2])-32
	var finish: int=int(edges[texture+3])-32
	var step: int=OEVM.i32((OEVM.i32(unit<<8)/scale)<<4) if scale!=0 else OEVM.i32(unit<<4)
	if scale!=0: vertical=OEVM.i32(inverse*scale)>>8
	var top: int=OEVM.i32(number("c")-(OEVM.i32(OEVM.i32(int(args[3])+64)*vertical)>>8))
	vm.set_static("k","aQ","I",args[5])
	colors(int(materials[material*2+1]),int(args[4]))
	var offset: int=OEVM.i32((int(edges[texture])&65535)|(int(edges[texture+1])<<16))
	var table: int=texture+4
	var left: int=OEVM.i32(int(args[2])+(OEVM.i32(start*inverse+128)>>8))
	var right: int=OEVM.i32(int(args[2])+(OEVM.i32(finish*inverse+128)>>8))
	var extent: int=OEVM.i32(finish-start+1)
	var lower: Array=data("n","[I")
	var upper: Array=data("o","[I")
	var flags: int=args[6]
	if left<int(lower[0]):
		texture_position=OEVM.i32(-advance*OEVM.i32(left-int(lower[0])));left=int(lower[0])
	if right>int(upper[0]): right=int(upper[0])
	if left<int(lower[0]):
		if (flags&0x20000)==0: texture_position=OEVM.i32(texture_position-advance*left)
		left=int(lower[0])
	if right>=int(upper[0]): right=int(upper[0])-1
	var direction: int=1
	if (flags&0x20000)!=0:
		var swap: int=left;left=right;right=swap;direction=-1
	var last_column: int=0
	var end: int=OEVM.i32(right+direction)
	var empty: bool=true
	while left!=end and (texture_position>>8)<extent:
		var column: int=texture_position>>8
		texture_position=OEVM.i32(texture_position+advance)
		while last_column!=column:
			var movement: int=1 if last_column<column else -1
			var edge: int=texture+int(edges[table+last_column if last_column<column else table+last_column-1])+2
			var length: int=0
			while (int(edges[edge])&255)!=127:
				length=OEVM.i32(length+(int(edges[edge])>>8));edge+=1
			offset=OEVM.i32(offset+length*movement);last_column+=movement
		var texel: int=offset
		var edge: int=texture+int(edges[table+column])+2
		while (int(edges[edge])&255)!=127:
			var run: int=int(edges[edge]);edge+=1
			var length: int=run>>8
			var height: int=64-(run&255)-length if (flags&0x40000)!=0 else run&255
			var pixels: int=OEVM.i32(vertical*length)>>8
			var screen_y: int=OEVM.i32(top+(OEVM.i32(vertical*height)>>8))
			var position: int=OEVM.i32(texel<<12)
			if screen_y<int(lower[1]):
				position=OEVM.i32(position+step*OEVM.i32(int(lower[1])-screen_y))
				pixels=OEVM.i32(pixels-OEVM.i32(int(lower[1])-screen_y));screen_y=int(lower[1])
			if OEVM.i32(screen_y+pixels)>int(upper[1]): pixels=OEVM.i32(int(upper[1])-screen_y)
			if (flags&0x40000)!=0:
				position=OEVM.i32(position+unit*OEVM.i32(pixels-1));step=OEVM.i32(-step)
			if pixels>0:
				sprite([OEVM.i32(left+screen_y*width),position,step,pixels]);empty=false
			texel=OEVM.i32(texel+length)
		left=OEVM.i32(left+direction)
	return empty

func sprite_columns() -> bool:
	if raster.enabled:
		var result: Variant=raster.sprite_columns()
		if result!=null: return bool(result)
	var vertices: Array=data("l","[I")
	var flags: int=number("ag")
	var extent: int=OEVM.i32(int(vertices[3])-int(vertices[0]))
	if extent<=0: return true
	vm.set_static("k","af","I",OEVM.i32(number("af")+1))
	var step_y: int=OEVM.i32((OEVM.i32(int(vertices[4])-int(vertices[1]))<<16)/extent)
	var step_u: int=OEVM.i32((OEVM.i32(int(vertices[5])-int(vertices[2]))<<16)/extent)
	var lower: Array=data("n","[I")
	var upper: Array=data("o","[I")
	var left: int=maxi(OEVM.i32(int(vertices[0])+65535)>>16,int(lower[0]))
	var right: int=mini(OEVM.i32(int(vertices[3])+65535)>>16,int(upper[0]))
	var delta: int=OEVM.i32((left<<16)-int(vertices[0]))
	var u: int=OEVM.i32(int(vertices[2])+OEVM.i32((delta*step_u)>>16))
	var y: int=OEVM.i32(int(vertices[1])+OEVM.i32((delta*step_y)>>16))
	var materials: Array=data("i","[S")
	var texture: int=int(materials[number("aT")*2])
	colors(int(materials[number("aT")*2+1]),number("aP"))
	var edges: Array=data("e","[S")
	var table: int=texture+4
	var offset: int=OEVM.i32((int(edges[texture])&65535)|(int(edges[texture+1])<<16))
	var last_column: int=0
	var scale: int=number("aS")
	var depth: Array=data("p","[I")
	var camera: int=number("aG")
	var shift: int=number("aR")
	var center: int=number("as")
	var floor_height: int=number("c","S")
	var ceiling: int=number("d","S")
	var effects: int=number("aQ")
	var width: int=number("b")
	var empty: bool=true
	while left<right:
		var distance: int=OEVM.i32((0x40000000/y)<<2)
		var step: int=OEVM.i32((scale<<16)/y) if scale!=0 else distance
		var column: int=OEVM.i32((u*step)>>32)
		if distance<=int(depth[left]):
			while last_column!=column:
				var direction: int=1 if last_column<column else -1
				var edge: int=texture+int(edges[table+last_column if last_column<column else table+last_column-1])+2
				var length: int=0
				while (int(edges[edge])&255)!=127:
					length=OEVM.i32(length+(int(edges[edge])>>8));edge+=1
				offset=OEVM.i32(offset+length*direction);last_column+=direction
			var texel: int=offset
			step>>=3
			var edge: int=texture+int(edges[table+column])+2
			var camera_offset: int=OEVM.i32(OEVM.i32(camera-OEVM.i32(shift-32))*y)>>17
			var bottom: int=OEVM.i32(center+(OEVM.i32(OEVM.i32(camera-floor_height)*y)>>17))
			var top: int=OEVM.i32(center+(OEVM.i32(OEVM.i32(camera-ceiling)*y)>>17))
			while (int(edges[edge])&255)!=127:
				var run: int=int(edges[edge]);edge+=1
				var length: int=run>>8
				var height: int=OEVM.i32((run&255)+length) if (flags&0x1000000)!=0 else 64-(run&255)
				var pixels: int=(OEVM.i32(y*length)/scale)>>1 if scale!=0 else OEVM.i32(y*length)>>17
				var screen_y: int=OEVM.i32(center-((OEVM.i32(y*height)/scale)>>1)+camera_offset) if scale!=0 else OEVM.i32(center-(OEVM.i32(y*height)>>17)+camera_offset)
				if (flags&0x80000)!=0 and screen_y<top:
					var clip: int=OEVM.i32(top-screen_y)
					pixels=OEVM.i32(pixels-clip);texel=OEVM.i32(texel+clip);screen_y=top
				if (effects&1)==0 and OEVM.i32(screen_y+pixels)>bottom: pixels=OEVM.i32(bottom-screen_y)
				var position: int=OEVM.i32(texel<<12)
				if (flags&0x1000000)!=0: position=OEVM.i32(position+step*OEVM.i32(pixels-1))
				if screen_y<int(lower[1]):
					position=OEVM.i32(position+step*OEVM.i32(int(lower[1])-screen_y))
					pixels=OEVM.i32(pixels-OEVM.i32(int(lower[1])-screen_y));screen_y=int(lower[1])
				if OEVM.i32(screen_y+pixels)>int(upper[1]): pixels=OEVM.i32(int(upper[1])-screen_y)
				if pixels>0:
					empty=false;sprite([OEVM.i32(left+screen_y*width),position,OEVM.i32(-step) if (flags&0x1000000)!=0 else step,pixels])
				texel=OEVM.i32(texel+length)
		y=OEVM.i32(y+step_y);u=OEVM.i32(u+step_u);left+=1
	return empty

func wall(args: Array) -> void:
	if int(vm.get_static("k","c","Z"))!=0: return
	var count: int=args[4]
	if count<=0: return
	if raster.enqueue(-1,args): return
	raster.before_access(vm.get_static("k","m","[I"),true)
	var destination: Array=data("m","[I")
	var texels: Array=data("c","[B")
	var palette: Array=data("q","[I")
	if vm.exception!=null: return
	var pixel: int=args[0]
	var position: int=args[1]
	var step: int=args[2]
	var stride: int=args[3]
	for n in count:
		var index: int=position>>12
		if pixel<0 or pixel>=destination.size() or index<0 or index>=texels.size():
			vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException");return
		var texel: int=int(texels[index])
		if texel<0 or texel>=palette.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException");return
		destination[pixel]=palette[texel]
		pixel=OEVM.i32(pixel+stride)
		position=OEVM.i32(position+step)

func sprite(args: Array) -> void:
	var mode: int=vm.get_static("k","ba","I")
	var count: int=args[3]
	if count<=0 or mode not in [0,1,3,4,8,9]: return
	if raster.enqueue(mode,args): return
	raster.before_access(vm.get_static("k","m","[I"),true)
	var destination: Array=data("m","[I")
	var texels: Array=[]
	var palette: Array=[]
	if mode!=8:
		texels=data("c","[B")
		palette=data("q","[I")
	if vm.exception!=null: return
	var pixel: int=args[0]
	var position: int=args[1]
	var step: int=args[2]
	var stride: int=vm.get_static("k","b","I")
	for n in count:
		if pixel<0 or pixel>=destination.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException");return
		var color: int=0
		if mode!=8:
			var index: int=position>>13
			if index<0 or index>=texels.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException");return
			var texel: int=(int(texels[index])>>((position>>10)&4))&15
			if texel>=palette.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException");return
			color=int(palette[texel])
		var old: int=int(destination[pixel])
		match mode:
			0: destination[pixel]=color
			1: destination[pixel]=OEVM.i32(0xff000000|(((old&0xfefefe)>>1)+((old&0xfcfcfc)>>2)+color))
			3: destination[pixel]=OEVM.i32(0xff000000|(color+((old&0xfcfcfc)>>2)))
			4:
				var sum: int=OEVM.i32((old&0xfefefe)+color)
				var carry: int=sum&0x1010100
				destination[pixel]=OEVM.i32((sum&0xfffefefe)|(carry>>1)|(carry>>2)|(carry>>3))
			8:
				var grey: int=(((old>>16)&255)*3+((old>>8)&255)*6+(old&255))/20
				destination[pixel]=OEVM.i32(0xff000000|(grey<<16)|(grey<<8)|grey)
			9:
				destination[pixel]=OEVM.i32(0xff000000|((((old>>16)&255)*((color>>16)&255)<<8)&0xff0000)|((((old>>8)&255)*((color>>8)&255))&0xff00)|(((old&255)*(color&255)>>8)&255))
		if mode!=8: position=OEVM.i32(position+step)
		pixel=OEVM.i32(pixel+stride)
