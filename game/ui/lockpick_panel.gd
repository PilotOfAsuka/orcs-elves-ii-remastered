class_name OELockpickPanel
extends PanelContainer
## Only original progress is visible; the secret combination never enters this UI.
signal key_requested(raw: int)
var title: Label
var instructions: Label
var progress: HBoxContainer
var attempts: Label
var cancel: Button
var buttons: Dictionary={}
func _ready() -> void:
	add_theme_stylebox_override("panel",OESkin.plate(Color("182119"),OESkin.GOLD,12))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6);add_child(box)
	title=Label.new();title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",OESkin.GOLD);title.add_theme_font_size_override("font_size",18);box.add_child(title)
	var instructions_area:=Control.new();instructions_area.custom_minimum_size.y=52;instructions_area.clip_contents=true;box.add_child(instructions_area)
	instructions=Label.new();instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_font_size_override("font_size",13);instructions.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;instructions_area.add_child(instructions);instructions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress=HBoxContainer.new();progress.alignment=BoxContainer.ALIGNMENT_CENTER;progress.add_theme_constant_override("separation",6);box.add_child(progress)
	attempts=Label.new();attempts.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;attempts.add_theme_font_size_override("font_size",13);box.add_child(attempts)
	var center:=CenterContainer.new();center.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(center)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);center.add_child(grid)
	for item in [["",0],["forward",50],["",0],["left",52],["",0],["right",54],["",0],["back",56],["",0]]:
		if int(item[1])==0:
			var empty:=Control.new();empty.custom_minimum_size=Vector2(44,44);empty.mouse_filter=Control.MOUSE_FILTER_IGNORE;grid.add_child(empty)
		else:
			var button:=Button.new();button.custom_minimum_size=Vector2(44,44);button.focus_mode=Control.FOCUS_NONE
			var raw: int=item[1]
			var hints: Dictionary={50:["Вверх","W"],56:["Вниз","S"],52:["Влево","A"],54:["Вправо","D"]}
			OESkin.decorate(button,item[0],hints[raw][0],hints[raw][1])
			button.pressed.connect(func(): key_requested.emit(raw));grid.add_child(button);buttons[raw]=button
	cancel=Button.new();cancel.custom_minimum_size.y=36;cancel.focus_mode=Control.FOCUS_NONE
	cancel.pressed.connect(func(): key_requested.emit(53));box.add_child(cancel)
func show_state(data: Dictionary) -> void:
	visible=not data.is_empty()
	if not visible: return
	title.text=OEText.localize("ВЗЛОМ ЗАМКА")
	instructions.text=OEText.localize("Выберите направление. Верное направление подтвердите повторным нажатием.")
	cancel.text=OEText.localize("Отменить взлом")+" · Esc"
	attempts.text=OEText.localize("Попытки")+": %d" % int(data.attempts)
	if progress.get_child_count()!=int(data.length):
		for child in progress.get_children(): child.free()
		for n in int(data.length):
			var pip:=ColorRect.new();pip.custom_minimum_size=Vector2(20,8);progress.add_child(pip)
	for n in progress.get_child_count(): progress.get_child(n).color=Color("7e9a57") if n<int(data.completed) else (OESkin.GOLD if n==int(data.completed) and data.partial else Color("454f3d"))
	cancel.disabled=bool(data.finished)
	for button: Button in buttons.values(): button.disabled=bool(data.finished)
