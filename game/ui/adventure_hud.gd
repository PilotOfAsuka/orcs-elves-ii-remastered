class_name OEAdventureHUD
extends PanelContainer

signal key_requested(key: int)
var context: Label
var health: ProgressBar
var health_text: Label
var armor_text: Label
var weapon_text: Label
var ammo_text: Label
var target_health: ProgressBar

func _ready() -> void:
	var margin:=MarginContainer.new()
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,10)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,6)
	add_child(margin)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	margin.add_child(box)
	context=Label.new()
	context.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	context.add_theme_font_size_override("font_size",14)
	context.add_theme_color_override("font_color",Color("dfc48b"))
	box.add_child(context)
	target_health=ProgressBar.new()
	target_health.show_percentage=false
	target_health.custom_minimum_size.y=4
	box.add_child(target_health)
	var stats:=HBoxContainer.new()
	stats.add_theme_constant_override("separation",10)
	box.add_child(stats)
	health_text=Label.new()
	health_text.add_theme_font_size_override("font_size",14)
	stats.add_child(health_text)
	health=ProgressBar.new()
	health.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	health.show_percentage=false
	health.custom_minimum_size=Vector2(20,8)
	health.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var fill:=StyleBoxFlat.new()
	fill.bg_color=Color("b24c49")
	fill.set_corner_radius_all(3)
	health.add_theme_stylebox_override("fill",fill)
	stats.add_child(health)
	armor_text=Label.new()
	armor_text.add_theme_font_size_override("font_size",14)
	stats.add_child(armor_text)
	var weapon:=HBoxContainer.new()
	weapon.add_theme_constant_override("separation",6)
	box.add_child(weapon)
	weapon_button(weapon,"<",42,"Предыдущее оружие · Q")
	weapon_text=Label.new()
	weapon_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	weapon_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	weapon_text.add_theme_font_size_override("font_size",15)
	weapon.add_child(weapon_text)
	ammo_text=Label.new()
	ammo_text.add_theme_font_size_override("font_size",14)
	weapon.add_child(ammo_text)
	weapon_button(weapon,">",55,"Следующее оружие · E")

func weapon_button(parent: Control, text: String, key: int, hint: String) -> void:
	var button:=Button.new()
	button.text=text
	button.tooltip_text=hint
	button.custom_minimum_size=Vector2(34,30)
	button.focus_mode=Control.FOCUS_NONE
	button.pressed.connect(func(): key_requested.emit(key))
	parent.add_child(button)

func show_state(data: Dictionary) -> void:
	visible=not data.is_empty()
	if not visible: return
	health.max_value=maxi(1,int(data.max_health))
	health.value=int(data.health)
	health_text.text="Жизнь %d/%d" % [int(data.health),int(data.max_health)]
	armor_text.text="Броня %d" % int(data.armor)
	armor_text.tooltip_text="%d / %d" % [int(data.armor),int(data.max_armor)]
	weapon_text.text=data.weapon_name if not str(data.weapon_name).is_empty() else "Оружие"
	ammo_text.text="Заряды %d" % int(data.ammo) if int(data.ammo)>=0 else ""
	context.text=str(data.notices) if not str(data.notices).is_empty() else str(data.context)
	context.tooltip_text=context.text
	context.text=context.text.replace("\n"," · ")
	target_health.visible=int(data.target_health)>=0 and int(data.target_max)>0
	target_health.max_value=maxi(1,int(data.target_max))
	target_health.value=int(data.target_health)
