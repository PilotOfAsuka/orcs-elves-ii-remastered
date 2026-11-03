class_name OEHDWeapons
extends Control
## Presentation only. Keep the original framebuffer, palette and game state intact.
const ART={
	1:[preload("res://assets/remastered/wand/generated/wand_frame_00_v1.png"),preload("res://assets/remastered/wand/generated/wand_frame_01_v1.png")],
	2:[preload("res://assets/remastered/staff/generated/staff_frame_00_v1.png"),preload("res://assets/remastered/staff/generated/staff_frame_01_v1.png")]
}
var enabled: bool=true
var pending: Dictionary={}
var current: Dictionary={}
var background_texture: ImageTexture
var current_graphics_id: int=-1
var current_revision: int=-1
var display_scale: float=1.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents=true

func capture(vm: OEVM, screen: JObject, args: Array) -> void:
	if int(args[0]) not in ART: return
	var player: Variant=vm.get_static("v","b","Lq;")
	if not player is JObject or int(vm.get_field(player,"q","g","I"))+1!=int(args[0]): return
	pending={}
	if not enabled or int(args[1])<0 or int(args[1])>=ART[int(args[0])].size(): return
	if int(args[4])!=0 or int(args[5])!=0 or int(args[7])!=0: return
	if int(vm.get_static("a","H","I")) not in [3,4,7] or int(vm.get_static("k","Z","I"))!=0: return
	var effects: Variant=vm.get_static("v","a","[B")
	if effects is JObject and effects.data.size()>11 and int(effects.data[11])>0: return
	var width: int=vm.get_static("k","b","I");var height: int=vm.get_static("k","c","I")
	var pixels: Variant=vm.get_static("k","m","[I")
	if not pixels is JObject or width<=0 or height<=0 or width*height>pixels.data.size(): return
	var base: Image=vm.render_helpers.raster.preview(pixels,width,height)
	if base==null:
		vm.render_helpers.raster.before_access(pixels)
		var bytes:=PackedByteArray();bytes.resize(width*height*4)
		for n in width*height:
			var color: int=pixels.data[n]
			bytes.encode_u32(n*4,0xff000000|((color&255)<<16)|(color&0xff00)|((color>>16)&255))
		base=Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,bytes)
	elif base.get_height()!=height:
		base=base.get_region(Rect2i(0,0,width,height))
	var lower: JObject=vm.get_static("k","n","[I");var upper: JObject=vm.get_static("k","o","[I")
	pending={"args":args.duplicate(),"size":Vector2(width,height),"background":base,"clip":Rect2(Vector2(lower.data[0],lower.data[1]),Vector2(upper.data[0]-lower.data[0],upper.data[1]-lower.data[1])),"graphics":screen.get_instance_id(),"before":int(screen.extra.get("world_revision",-1))}

func publish(graphics: JObject, revision: int, world_size: Vector2) -> void:
	var id: int=graphics.get_instance_id()
	if id==current_graphics_id and revision==current_revision: return
	current_graphics_id=id;current_revision=revision
	current={}
	if enabled and not pending.is_empty() and int(pending.graphics)==id and int(pending.before)+1==revision and pending.size==world_size:
		current=pending
		var base: Image=current.background
		if background_texture==null or background_texture.get_size()!=world_size: background_texture=ImageTexture.create_from_image(base)
		else: background_texture.update(base)
	pending={}
	queue_redraw()

func present(area: Vector2, active: bool) -> void:
	visible=active and enabled and not current.is_empty()
	if not visible: return
	display_scale=minf(area.x/current.size.x,area.y/current.size.y)
	var fitted: Vector2=current.size*display_scale
	var clip: Rect2=current.clip
	position=(area-fitted)/2+clip.position*display_scale
	size=clip.size*display_scale
	queue_redraw()

func _draw() -> void:
	if current.is_empty() or not enabled: return
	var args: Array=current.args
	var width: int=int(current.size.x);var height: int=int(current.size.y)
	var unit: int=32768/width;var inverse: int=65536/unit
	var pixel_scale: float=float(inverse)/256.0
	var origin:=Vector2(float(args[2])-32*pixel_scale,float(height)-float(int(args[3])+64)*pixel_scale)
	origin-=current.clip.position
	var rectangle:=Rect2(origin*display_scale,Vector2.ONE*64*pixel_scale*display_scale)
	var flip:=Vector2(-1 if (int(args[6])&0x20000)!=0 else 1,-1 if (int(args[6])&0x40000)!=0 else 1)
	var offset: Vector2=rectangle.position+Vector2(rectangle.size.x if flip.x<0 else 0,rectangle.size.y if flip.y<0 else 0)
	draw_set_transform(offset,0,flip)
	draw_texture_rect(ART[int(args[0])][int(args[1])],Rect2(Vector2.ZERO,rectangle.size),false)
	draw_set_transform(Vector2.ZERO)
