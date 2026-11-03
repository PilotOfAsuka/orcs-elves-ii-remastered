class_name OEAdventureHUD
extends PanelContainer

signal key_requested(key: int)
var context: Label
var health: ProgressBar
var armor: ProgressBar
var health_text: Label
var armor_text: Label
var weapon_text: Label
var ammo_text: Label
var target_health: ProgressBar
var weapon_icon: TextureRect

func symbol(parent: Node, kind: String, tint: Color, width: int=24) -> TextureRect:
	var image:=TextureRect.new()
	image.texture=OESkin.icon(kind);image.modulate=tint
	image.custom_minimum_size=Vector2(width,width)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _ready() -> void:
	add_theme_stylebox_override("panel",OESkin.plate(Color("141e18"),OESkin.BRONZE,0))
	var margin:=MarginContainer.new()
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,12)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	add_child(margin)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",5)
	margin.add_child(box)
	context=Label.new()
	context.custom_minimum_size.y=18
	context.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	context.add_theme_font_size_override("font_size",13)
	context.add_theme_color_override("font_color",OESkin.GOLD)
	box.add_child(context)
	target_health=ProgressBar.new()
	target_health.show_percentage=false
	target_health.custom_minimum_size.y=3
	box.add_child(target_health)
	var stats:=HBoxContainer.new()
	stats.add_theme_constant_override("separation",18)
	box.add_child(stats)
	for kind in ["heart","shield"]:
		var row:=HBoxContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation",8);stats.add_child(row)
		symbol(row,kind,Color("cf7563") if kind=="heart" else Color("9da998"))
		var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",3);row.add_child(column)
		var text:=Label.new();text.add_theme_font_size_override("font_size",16);column.add_child(text)
		var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size=Vector2(20,5)
		column.add_child(bar)
		if kind=="heart": health=bar;health_text=text
		else:
			armor=bar;armor_text=text
			bar.add_theme_stylebox_override("fill",OESkin.plate(Color("667d72"),Color("a0ad8e"),0))
	var weapon:=HBoxContainer.new()
	weapon.add_theme_constant_override("separation",8)
	box.add_child(weapon)
	weapon_button(weapon,"left",42,"Предыдущее оружие","Q")
	weapon_icon=symbol(weapon,"attack",OESkin.GOLD,20)
	weapon_text=Label.new()
	weapon_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	weapon_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	weapon_text.add_theme_font_size_override("font_size",14)
	weapon.add_child(weapon_text)
	symbol(weapon,"gem",Color("a3b3a2"),17)
	ammo_text=Label.new();ammo_text.add_theme_font_size_override("font_size",14)
	ammo_text.custom_minimum_size.x=22;weapon.add_child(ammo_text)
	weapon_button(weapon,"right",55,"Следующее оружие","E")

func weapon_button(parent: Control, icon: String, key: int, caption: String, shortcut: String) -> void:
	var button:=Button.new()
	button.custom_minimum_size=Vector2(32,30)
	button.focus_mode=Control.FOCUS_NONE
	OESkin.decorate(button,icon,caption,shortcut)
	button.add_theme_constant_override("icon_max_width",16)
	button.pressed.connect(func(): key_requested.emit(key))
	parent.add_child(button)

func show_state(data: Dictionary) -> void:
	visible=not data.is_empty()
	if not visible: return
	health.max_value=maxi(1,int(data.max_health));health.value=int(data.health)
	health_text.text="%d / %d" % [int(data.health),int(data.max_health)]
	health_text.tooltip_text=OEText.localize("Здоровье")
	armor.max_value=maxi(1,int(data.max_armor));armor.value=int(data.armor)
	armor_text.text="%d / %d" % [int(data.armor),int(data.max_armor)]
	armor_text.tooltip_text=OEText.localize("Броня")
	weapon_text.text=data.weapon_name if not str(data.weapon_name).is_empty() else OEText.localize("Оружие")
	ammo_text.text=str(int(data.ammo)) if int(data.ammo)>=0 else "—"
	ammo_text.tooltip_text=OEText.localize("Заряды")
	context.text=str(data.notices) if not str(data.notices).is_empty() else str(data.context)
	context.tooltip_text=context.text
	context.text=context.text.replace("\n"," · ")
	context.visible=true
	target_health.modulate.a=1.0 if int(data.target_health)>=0 and int(data.target_max)>0 else 0.0
	target_health.max_value=maxi(1,int(data.target_max));target_health.value=int(data.target_health)
