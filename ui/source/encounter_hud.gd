class_name OEEncounterHUD
extends VBoxContainer
## Enemy HP first, events below; this overlay never changes viewport geometry.
var enemy: ProgressBar
var target: Label
var message: Label
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",4)
	enemy=ProgressBar.new();enemy.show_percentage=false
	enemy.custom_minimum_size.y=5;enemy.mouse_filter=Control.MOUSE_FILTER_IGNORE
	enemy.add_theme_stylebox_override("background",OESkin.plate(Color(0.03,0.04,0.03,0.8),Color("61513b"),0))
	enemy.add_theme_stylebox_override("fill",OESkin.plate(Color("a9583c"),OESkin.GOLD,0))
	add_child(enemy)
	target=Label.new();target.mouse_filter=Control.MOUSE_FILTER_IGNORE;target.add_theme_font_size_override("font_size",15);target.add_theme_color_override("font_color",OESkin.GOLD);target.add_theme_color_override("font_shadow_color",Color.BLACK);target.add_theme_constant_override("shadow_outline_size",4);target.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;add_child(target)
	message=Label.new();message.mouse_filter=Control.MOUSE_FILTER_IGNORE
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.max_lines_visible=3
	message.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	message.add_theme_font_size_override("font_size",14)
	message.add_theme_color_override("font_color",OESkin.PAPER)
	message.add_theme_color_override("font_shadow_color",Color.BLACK)
	message.add_theme_constant_override("shadow_outline_size",4)
	add_child(message)
func show_state(data: Dictionary, cinematic: bool=false) -> void:
	if enemy==null: return
	enemy.visible=int(data.get("target_health",-1))>=0 and int(data.get("target_max",0))>0
	enemy.max_value=maxi(1,int(data.get("target_max",1)));enemy.value=int(data.get("target_health",0))
	target.text=str(data.get("target_name",""));target.visible=not cinematic and not target.text.is_empty()
	var lines: Array[String]=[]
	if not cinematic:
		for event in data.get("events",[]):
			var text: String=str(event).replace("-\n","").replace("\n"," ").strip_edges()
			if not text.is_empty() and text not in lines:lines.append(text)
	for key in (["cinematic","context","notices"] if cinematic else ["notices","context"]):
		var text: String=str(data.get(key,"")).replace("-\n","").replace("\n"," ").strip_edges()
		if not text.is_empty() and text not in lines and text!=target.text: lines.append(text)
	message.text="\n".join(lines.slice(0,2));message.visible=not message.text.is_empty()
	visible=enemy.visible or target.visible or message.visible
