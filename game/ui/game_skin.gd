class_name OESkin
extends RefCounted
## Shared stone / bronze skin. Icons are vector art, independent of the Java HUD.
const INK=Color("101512")
const BRONZE=Color("806845")
const GOLD=Color("d7b77a")
const PAPER=Color("e9dfc8")
const MUTED=Color("9b9d86")
static var icons: Dictionary={}
static var button_frames: Dictionary={}

static func plate(fill: Color=Color("17201c"), edge: Color=BRONZE, padding: float=10) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=fill;box.border_color=edge
	box.set_border_width_all(1);box.set_corner_radius_all(2)
	box.content_margin_left=padding;box.content_margin_right=padding
	box.content_margin_top=padding;box.content_margin_bottom=padding
	box.shadow_color=Color(0,0,0,0.3);box.shadow_size=3
	return box

static func make_theme() -> Theme:
	var result:=Theme.new()
	result.default_font_size=16
	result.set_color("font_color","Label",PAPER)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var fill: Color=Color("1b251f")
		var edge: Color=BRONZE
		if state=="hover": fill=Color("2d392d");edge=GOLD
		if state=="pressed": fill=Color("52452c");edge=GOLD
		if state=="disabled": fill=Color("101813");edge=Color("414937")
		if state=="focus": fill=Color.TRANSPARENT;edge=GOLD
		result.set_stylebox(state,"Button",button_frame(fill,edge) if state!="focus" else plate(fill,edge,8))
		result.set_color("font_"+state+"_color" if state!="normal" else "font_color","Button",MUTED if state=="disabled" else PAPER)
	result.set_color("font_hover_color","Button",Color("fff0cb"))
	result.set_color("icon_normal_color","Button",GOLD)
	result.set_color("icon_hover_color","Button",Color("fff0cb"))
	result.set_color("icon_pressed_color","Button",Color("fff0cb"))
	result.set_stylebox("panel","Panel",plate(Color("0c120f"),Color("62563b"),0))
	result.set_stylebox("panel","PanelContainer",plate(Color("161e19"),BRONZE,0))
	result.set_stylebox("panel","TooltipPanel",plate(Color("141c17"),GOLD,10))
	result.set_color("font_color","TooltipLabel",PAPER)
	result.set_stylebox("background","ProgressBar",plate(Color("080d0b"),Color("4a4935"),0))
	result.set_stylebox("fill","ProgressBar",plate(Color("8b3b35"),Color("bc6d50"),0))
	return result

static func button_frame(fill: Color, edge: Color) -> StyleBoxTexture:
	var key: String=fill.to_html()+edge.to_html()
	if button_frames.has(key): return button_frames[key]
	var svg: String="<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'><defs><linearGradient id='m' x1='0' y1='0' x2='0' y2='1'><stop stop-color='#%s'/><stop offset='1' stop-color='#%s'/></linearGradient></defs><path d='M4 1h56l3 3v56l-3 3H4l-3-3V4z' fill='url(#m)' stroke='#%s'/><path d='M6 4h52M4 6v52' fill='none' stroke='#%s' opacity='.4'/><path d='M6 60h52M60 6v52' fill='none' stroke='#070c09' opacity='.9'/></svg>" % [fill.lightened(0.08).to_html(false),fill.darkened(0.15).to_html(false),edge.to_html(false),edge.lightened(0.25).to_html(false)]
	var image:=Image.new();image.load_svg_from_string(svg)
	var style:=StyleBoxTexture.new();style.texture=ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,6)
		style.set_content_margin(side,8)
	button_frames[key]=style
	return style

static func icon(kind: String) -> Texture2D:
	if icons.has(kind): return icons[kind]
	var paths: Dictionary={
		"plus":"<path d='M6 16h20M16 6v20'/>",
		"minus":"<path d='M6 16h20'/>",
		"center":"<circle cx='16' cy='16' r='9'/><path d='M16 2v9m0 10v9M2 16h9m10 0h9'/>",
		"forward":"<path d='M16 27V6M7 15l9-9 9 9'/>",
		"back":"<path d='M16 5v21M7 18l9 9 9-9'/>",
		"strafe_left":"<path d='M27 16H5m8-8-8 8 8 8M27 7v18'/>",
		"strafe_right":"<path d='M5 16h22m-8-8 8 8-8 8M5 7v18'/>",
		"turn_left":"<path d='M25 26V16a8 8 0 0 0-8-8H6m7-5L6 8l7 6'/>",
		"turn_right":"<path d='M7 26V16a8 8 0 0 1 8-8h11m-7-5 7 5-7 6'/>",
		"attack":"<path d='m8 25 16-17 2-5-5 2L5 21m1-6 11 11M3 29l5-5m-6 3 3 3'/>",
		"weapon":"<path d='m9 25 15-18 3-4-6 2L6 21m-2-3 10 9m-9-3-3 4M3 8h10m-4-4 4 4-4 4'/>",
		"wait":"<path d='M8 3h16M8 29h16M10 3c0 8 2 8 6 13-4 5-6 5-6 13M22 3c0 8-2 8-6 13 4 5 6 5 6 13M12 25h8'/>",
		"menu":"<path d='M6 7h20M6 16h20M6 25h20'/><path d='m3 7 1-1 1 1-1 1zm0 9 1-1 1 1-1 1zm0 9 1-1 1 1-1 1z'/>",
		"map":"<path d='m3 7 8-4 10 4 8-4v22l-8 4-10-4-8 4zm8-4v22M21 7v22'/>",
		"save":"<path d='M5 3h19l4 5v21H4V3zm4 0v9h14V3M9 29V18h14v11M18 4v5'/>",
		"load":"<path d='M4 12V5h12l4 5h9v18H3V12h26M9 19h13m-5-4 5 4-5 4'/>",
		"sound":"<path d='m4 12 7 0 8-7v22l-8-7H4zm19-2c4 4 4 8 0 12m4-16c7 7 7 13 0 20'/>",
		"muted":"<path d='m4 12 7 0 8-7v22l-8-7H4zm19 0 7 9m0-9-7 9'/>",
		"fullscreen":"<path d='M12 4H4v8m16-8h8v8M4 20v8h8m8 0h8v-8'/>",
		"heart":"<path d='M16 28C5 20 2 15 3 10c2-8 10-6 13 0 3-6 11-8 13 0 1 5-2 10-13 18z'/>",
		"shield":"<path d='m16 3 12 5-2 13-10 9L6 21 4 8zm0 0v27M5 10h22'/>",
		"gem":"<path d='m16 2 10 9-2 13-8 6-8-6-2-13zm0 0-4 10 4 18 4-18zm-10 9 6 1h8l6-1'/>",
		"book":"<path d='M16 7c-5-4-9-4-13-3v23c5-1 9 0 13 3 4-3 8-4 13-3V4c-4-1-8-1-13 3v23M7 10l5 1m-5 5 5 1m8-6 5-1m-5 7 5-1'/>",
		"left":"<path d='m21 5-11 11 11 11'/>",
		"right":"<path d='m11 5 11 11-11 11'/>",
		"eye":"<path d='M2 16s6-10 14-10 14 10 14 10-6 10-14 10S2 16 2 16z'/><circle cx='16' cy='16' r='4'/>",
		"check":"<path d='m5 16 8 8L28 7'/>",
		"close":"<path d='m7 7 18 18M25 7 7 25'/>",
		"pack":"<path d='M10 8V5h12v3M7 9h18l3 20H4zm2 0 2 7h10l2-7M9 21h14M12 21v4m8-4v4'/>",
	}
	var svg: String="<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 32 32'><g fill='none' stroke='white' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>"+str(paths.get(kind,paths.eye))+"</g></svg>"
	var image:=Image.new()
	image.load_svg_from_string(svg,2.0)
	var texture:=ImageTexture.create_from_image(image)
	icons[kind]=texture
	return texture

static func decorate(button: Button, kind: String, hint: String, shortcut: String="") -> void:
	button.text="";button.icon=icon(kind);button.expand_icon=true
	button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width",26)
	button.tooltip_text=hint+(" · "+shortcut if not shortcut.is_empty() else "")
	button.accessibility_name=hint
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if not shortcut.is_empty():
		var caption:=Label.new()
		caption.text=shortcut;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size",9)
		caption.add_theme_color_override("font_color",MUTED)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		caption.offset_left=-31 if shortcut.length()>2 else -19;caption.offset_top=-14;caption.offset_right=-4;caption.offset_bottom=-2
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(caption)
