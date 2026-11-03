class_name OEHDWeapons
extends Control
## Presentation only: original framebuffer and game state remain the reference.
const ART={
	1:["res://assets/remastered/wand/generated/wand_frame_00_v1.png","res://assets/remastered/wand/generated/wand_frame_01_v1.png"],
	2:["res://assets/remastered/staff/generated/staff_frame_00_v1.png","res://assets/remastered/staff/generated/staff_frame_01_v1.png"],
	3:["res://assets/remastered/dagger/generated/dagger_frame_00_v1.png","res://assets/remastered/dagger/generated/dagger_frame_01_v1.png","res://assets/remastered/dagger/generated/dagger_frame_02_v1.png"],
	4:["res://assets/remastered/poison_dagger/generated/poison_dagger_frame_00_v1.png","res://assets/remastered/poison_dagger/generated/poison_dagger_frame_01_v1.png","res://assets/remastered/dagger/generated/dagger_frame_02_v1.png"],
	5:["res://assets/remastered/bob/generated/bob_frame_00_v1.png","res://assets/remastered/bob/generated/bob_frame_01_v1.png","res://assets/remastered/bob/generated/bob_frame_02_v1.png"],
	6:["res://assets/remastered/fire_crossbow/generated/fire_crossbow_frame_00_v1.png","res://assets/remastered/fire_crossbow/generated/fire_crossbow_frame_00_v1.png"],
	7:["res://assets/remastered/kinetic_crossbow/generated/kinetic_crossbow_frame_00_v1.png","res://assets/remastered/kinetic_crossbow/generated/kinetic_crossbow_frame_00_v1.png"],
	8:["res://assets/remastered/flame_sword/generated/flame_sword_frame_00_v1.png","res://assets/remastered/flame_sword/generated/flame_sword_frame_01_v1.png"],
	9:["res://assets/remastered/shrink_orbs/generated/shrink_orbs_frame_00_v1.png","res://assets/remastered/shrink_orbs/generated/shrink_orbs_frame_01_v1.png"],
	10:["res://assets/remastered/shrink_orbs/generated/shrink_orbs_frame_00_v1.png","res://assets/remastered/shrink_orbs/generated/shrink_orbs_frame_01_v1.png"],
	11:["res://assets/remastered/shrink_orbs/generated/shrink_orbs_frame_00_v1.png","res://assets/remastered/shrink_orbs/generated/shrink_orbs_frame_01_v1.png"],
	14:["res://assets/remastered/freeze_orb/generated/freeze_orb_frame_00_v1.png"],
	15:["res://assets/remastered/mold_orb/generated/mold_orb_frame_00_v1.png"],
	16:["res://assets/remastered/shrink_orb/generated/shrink_orb_frame_00_v1.png"],
	130:["res://assets/remastered/crossbow_bolt/generated/crossbow_bolt_frame_00_v1.png"],
}
const AUX={5:130,6:130,8:16,9:15,10:14}
var enabled: bool=true
var pending: Dictionary={}
var current: Dictionary={}
var background_texture: ImageTexture
var current_graphics_id: int=-1
var current_revision: int=-1
var display_scale: float=1.0
var layer_views: Array[Control]=[]
var additive: ShaderMaterial
var textures: Dictionary={}

func art(sprite: int, frame: int) -> Texture2D:
	var path: String=ART[sprite][frame]
	if not textures.has(path):
		textures[path]=load(path)
		if textures.size()>6: textures.erase(textures.keys()[0])
	return textures[path]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents=true
	additive=ShaderMaterial.new();additive.shader=preload("res://rendering/weapon_additive.gdshader")

func capture(vm: OEVM, screen: JObject, args: Array) -> void:
	var player: Variant=vm.get_static("v","b","Lq;")
	if not player is JObject: return
	var weapon: int=vm.get_field(player,"q","g","I")
	var sprite: int=int(args[0]);var frame: int=int(args[1]);var primary: bool=weapon+1==sprite
	if not primary and int(AUX.get(weapon,-1))!=sprite: return
	var revision: int=int(screen.extra.get("world_revision",-1))
	var same_frame: bool=not pending.is_empty() and int(pending.graphics)==screen.get_instance_id() and int(pending.before)==revision
	# Bob's hands (frame 0) and familiar (frame 1) are two original draw calls.
	var bob_head: bool=primary and sprite==5 and frame==1 and same_frame and pending.layers.size()==1 and int(pending.layers[0].args[1])==0
	if primary and not bob_head: pending={}
	if not enabled or sprite not in ART or frame<0 or frame>=ART[sprite].size(): pending={};return
	if int(args[5])!=0 or (primary and (int(args[4])!=0 or int(args[7])!=0)) or (not primary and int(args[4]) not in [3,4]): pending={};return
	if not primary and (int(args[7])!=(64 if sprite==130 else 112) or int(args[4])!=(4 if sprite==130 else 3)): pending={};return
	if int(vm.get_static("a","H","I")) not in [3,4,7] or int(vm.get_static("k","Z","I"))!=0: pending={};return
	var effects: Variant=vm.get_static("v","a","[B")
	if effects is JObject and effects.data.size()>11 and int(effects.data[11])>0: pending={};return
	var width: int=vm.get_static("k","b","I");var height: int=vm.get_static("k","c","I")
	var pixels: Variant=vm.get_static("k","m","[I")
	if not pixels is JObject or width<=0 or height<=0 or width*height>pixels.data.size(): pending={};return
	if pending.is_empty():
		if not primary: return
		var base: Image=vm.render_helpers.raster.preview(pixels,width,height)
		if base==null:
			vm.render_helpers.raster.before_access(pixels)
			var bytes:=PackedByteArray();bytes.resize(width*height*4)
			for n in width*height:
				var color: int=pixels.data[n]
				bytes.encode_u32(n*4,0xff000000|((color&255)<<16)|(color&0xff00)|((color>>16)&255))
			base=Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,bytes)
		elif base.get_height()!=height: base=base.get_region(Rect2i(0,0,width,height))
		var lower: JObject=vm.get_static("k","n","[I");var upper: JObject=vm.get_static("k","o","[I")
		pending={"args":args.duplicate(),"layers":[],"size":Vector2(width,height),"background":base,"clip":Rect2(Vector2(lower.data[0],lower.data[1]),Vector2(upper.data[0]-lower.data[0],upper.data[1]-lower.data[1])),"graphics":screen.get_instance_id(),"before":revision}
	var sprites: Array=vm.get_static("k","j","[S").data;var materials: Array=vm.get_static("k","i","[S").data;var edges: Array=vm.get_static("k","e","[S").data
	var shape: int=materials[(int(sprites[sprite])+frame)*2]
	pending.layers.append({"args":args.duplicate(),"bounds":Vector2i(edges[shape+2],edges[shape+3])})

func publish(graphics: JObject, revision: int, world_size: Vector2) -> void:
	var id: int=graphics.get_instance_id()
	if id==current_graphics_id and revision==current_revision: return
	current_graphics_id=id;current_revision=revision;current={}
	if enabled and not pending.is_empty() and int(pending.graphics)==id and int(pending.before)+1==revision and pending.size==world_size:
		current=pending
		var base: Image=current.background
		if background_texture==null or background_texture.get_size()!=world_size: background_texture=ImageTexture.create_from_image(base)
		else: background_texture.update(base)
	pending={}
	for layer in layer_views:
		layer.hide();layer.get_child(0).texture=null

func present(area: Vector2, active: bool) -> void:
	visible=active and enabled and not current.is_empty()
	if not visible: return
	display_scale=minf(area.x/current.size.x,area.y/current.size.y)
	var fitted: Vector2=current.size*display_scale;var clip: Rect2=current.clip
	position=(area-fitted)/2+clip.position*display_scale;size=clip.size*display_scale
	var width: int=int(current.size.x);var height: int=int(current.size.y)
	var unit: int=32768/width;var inverse: int=65536/unit
	for index in current.layers.size():
		if index>=layer_views.size():
			var layer:=Control.new();layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.clip_contents=true
			var view:=Sprite2D.new();view.centered=false;layer.add_child(view);add_child(layer);layer_views.append(layer)
		var layer: Control=layer_views[index];var view: Sprite2D=layer.get_child(0)
		var job: Dictionary=current.layers[index];var args: Array=job.args;var bounds: Vector2i=job.bounds
		var scale_arg: int=int(args[7]);var advance: int=(unit<<8)/scale_arg if scale_arg!=0 else unit
		var vertical: int=(inverse*scale_arg)>>8 if scale_arg!=0 else inverse
		var texel_scale:=Vector2(256.0/advance,float(vertical)/256.0)
		var raw_left: int=int(args[2])+(((bounds.x-32)*inverse+128)>>8)
		var raw_right: int=int(args[2])+(((bounds.y-32)*inverse+128)>>8)
		var left: int=maxi(raw_left,int(clip.position.x));var right: int=mini(raw_right,int(clip.end.x)-1)
		var top: int=height-(((int(args[3])+64)*vertical)>>8)
		var source_x: float=float(bounds.x)+float(advance*(left-raw_left))/256.0
		var mirror: bool=(int(args[6])&0x20000)!=0
		var origin_x: float=float(right+1)+(source_x-64)*texel_scale.x if mirror else float(left)-source_x*texel_scale.x
		layer.position=Vector2(left-clip.position.x,0)*display_scale;layer.size=Vector2(maxi(0,right-left+1),clip.size.y)*display_scale;layer.visible=right>=left
		view.texture=art(int(args[0]),int(args[1]))
		view.position=Vector2(origin_x-left,top-clip.position.y)*display_scale
		view.scale=Vector2.ONE*64*texel_scale*display_scale/view.texture.get_size()
		view.flip_h=mirror;view.flip_v=(int(args[6])&0x40000)!=0
		view.material=additive if int(args[4])==4 else null
		view.modulate.a=0.75 if int(args[4])==3 else 1.0
