class_name OEAdventureHUD
extends Control
## A fixed-height bronze instrument panel; stats never resize the game view.
signal ring_requested
const RINGS=preload("res://generated/menu/rings.png")
var ring_button: Button
var ring_id: int=-1
var health_text: Label
var armor_text: Label
var weapon_text: Label
var ammo_text: Label
var health_caption: Label
var armor_caption: Label
var heart: TextureRect
var shield: TextureRect
var weapon_icon: TextureRect
var ammo_icon: TextureRect
var hp: float=1.0
var ap: float=1.0
var pulse: float=0.0
var panel_style: StyleBoxFlat

func symbol(kind: String, tint: Color, width: int) -> TextureRect:
	var node:=TextureRect.new();node.texture=OESkin.icon(kind);node.modulate=tint
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.size=Vector2(width,width);add_child(node);return node

func label(font_size: int, tint: Color=OESkin.PAPER) -> Label:
	var node:=Label.new();node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",tint);node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_shadow_color",Color.BLACK);node.add_theme_constant_override("shadow_outline_size",2)
	add_child(node);return node

func _ready() -> void:
	panel_style=OESkin.plate(Color("0d1512"),Color("7f6842"),0)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	heart=symbol("heart",Color("e49b84"),23);shield=symbol("shield",Color("bdd0cf"),23)
	weapon_icon=symbol("attack",OESkin.GOLD,18);ammo_icon=symbol("gem",Color("b5c9c5"),16)
	health_caption=label(9,OESkin.MUTED);armor_caption=label(9,OESkin.MUTED)
	health_text=label(16);armor_text=label(16)
	weapon_text=label(13);weapon_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	ammo_text=label(13);ammo_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	ring_button=Button.new();ring_button.focus_mode=Control.FOCUS_NONE;ring_button.expand_icon=true;ring_button.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;ring_button.add_theme_constant_override("icon_max_width",18)
	for part in ["normal","hover","pressed","disabled"]:ring_button.add_theme_stylebox_override(part,OESkin.plate(Color("17201c"),OESkin.GOLD if part=="hover" else OESkin.BRONZE,2))
	ring_button.add_theme_color_override("icon_normal_color",Color.WHITE);ring_button.add_theme_color_override("icon_hover_color",Color.WHITE);ring_button.add_theme_color_override("icon_pressed_color",Color.WHITE)
	ring_button.pressed.connect(func():ring_requested.emit());add_child(ring_button);ring_button.hide()
	resized.connect(arrange);arrange()

func arrange() -> void:
	if heart==null:return
	var half:=size.x/2.0
	heart.position=Vector2(15,10);shield.position=Vector2(half+14,10)
	health_caption.position=Vector2(50,3);armor_caption.position=Vector2(half+49,3)
	health_text.position=Vector2(50,13);armor_text.position=Vector2(half+49,13)
	weapon_icon.position=Vector2(13,50);weapon_text.position=Vector2(38,49);weapon_text.size=Vector2(maxf(20,size.x-(151 if ring_button.visible else 120)),22)
	ring_button.position=Vector2(size.x-103,49);ring_button.size=Vector2(24,22)
	ammo_icon.position=Vector2(size.x-63,51);ammo_text.position=Vector2(size.x-43,49);ammo_text.size=Vector2(28,22)
	queue_redraw()

func _draw() -> void:
	var bounds:=Rect2(Vector2.ZERO,size)
	draw_style_box(panel_style,bounds)
	draw_rect(Rect2(2,2,maxf(0,size.x-4),42),Color("18211a"))
	draw_line(Vector2(5,1),Vector2(size.x-5,1),Color("b39a60"),1)
	draw_line(Vector2(10,45),Vector2(size.x-10,45),Color("534832"),1)
	draw_line(Vector2(size.x/2,8),Vector2(size.x/2,37),Color("65563a"),1)
	for x in [26.0,size.x/2+25.0]:
		draw_circle(Vector2(x,22),16,Color("0a100e"));draw_arc(Vector2(x,22),16,0,TAU,32,Color("967a4b"),1,true)
		draw_arc(Vector2(x,22),13,0.2,PI+0.1,24,Color("3e4738"),1,true)
	var danger:=0.55+0.25*sin(pulse*5) if hp<0.25 else 0.15
	vital_bar(Rect2(50,34,maxf(10,size.x/2-65),6),hp,Color("a83229"),Color("e39166"),danger)
	vital_bar(Rect2(size.x/2+49,34,maxf(10,size.x/2-64),6),ap,Color("527a85"),Color("b9d4d1"),0.10)
	for x in [5.0,size.x-5]:
		draw_line(Vector2(x,5),Vector2(x,10),OESkin.GOLD,1)
		draw_line(Vector2(x,61),Vector2(x,66),OESkin.BRONZE,1)

func vital_bar(rect: Rect2, fraction: float, fill: Color, shine: Color, glow: float) -> void:
	draw_rect(rect.grow(1),Color("7d6b45"));draw_rect(rect,Color("070c0b"))
	var lit:=Rect2(rect.position,Vector2(rect.size.x*clampf(fraction,0,1),rect.size.y))
	if lit.size.x<=0:return
	draw_rect(lit.grow(2),Color(fill,glow));draw_rect(lit,fill)
	draw_rect(Rect2(lit.position,Vector2(lit.size.x,2)),shine)
	draw_line(lit.position+Vector2(0,lit.size.y-1),lit.end-Vector2(0,1),fill.darkened(0.45),1)

func _process(delta: float) -> void:
	if visible and hp>0 and hp<0.25:pulse+=delta;queue_redraw()

func show_state(data: Dictionary) -> void:
	visible=not data.is_empty()
	if not visible or health_text==null:return
	hp=float(data.health)/maxf(1,float(data.max_health));ap=float(data.armor)/maxf(1,float(data.max_armor))
	health_text.text="%d / %d" % [int(data.health),int(data.max_health)]
	armor_text.text="%d / %d" % [int(data.armor),int(data.max_armor)]
	health_caption.text=OEText.localize("Здоровье").to_upper();armor_caption.text=OEText.localize("Броня").to_upper()
	var next_ring: int=int(data.get("ring_id",0))
	ring_button.visible=(int(data.get("rings_owned",0))&0x1fe)!=0
	if next_ring!=ring_id:
		ring_id=next_ring
		if ring_id>0 and ring_id<=8:
			var texture:=AtlasTexture.new();texture.atlas=RINGS;texture.region=Rect2(0,(ring_id-1)*18,18,18);ring_button.icon=texture
		else:ring_button.icon=OESkin.icon("ring")
	var ring_name: String=OEText.localize(str(data.get("ring_name",""))) if ring_id>0 else OEText.localize("Кольцо не надето")
	ring_button.tooltip_text=ring_name+"\n"+OEText.localize(str(data.get("ring_description","")));ring_button.accessibility_name=ring_name
	arrange()
	weapon_text.text=OEText.localize(str(data.weapon_name)) if not str(data.weapon_name).is_empty() else OEText.localize("Оружие")
	ammo_text.text=str(int(data.ammo)) if int(data.ammo)>=0 else "—"
	queue_redraw()
