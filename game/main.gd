extends Control

var session: OEGameSession
var audio: OEAudioManager
var classic_view: TextureRect
var remastered_view: TextureRect
var view_frame: Panel
var heading: Label
var mode_row: HBoxContainer
var actions_row: HBoxContainer
var controls: Control
var softkeys: HBoxContainer
var keypad: GridContainer
var auxiliary: HBoxContainer
var left_key: Button
var right_key: Button
var status: Label
var hint: Label
var classic_button: Button
var remastered_button: Button
var shader: ShaderMaterial
var last_time: int
var selected_mode: int = 0
var fade: Tween
var held_key: int = 0
var next_repeat: int = 0
var touch_start := Vector2.ZERO
var paused: bool = false
var saved_path: String = "user://quick-save.oe2"
var toast_until: int = 0
var testing: bool = false
var presenter: OEPresentationState
var native_menu: PanelContainer
var native_rows: VBoxContainer
var menu_signature: String = ""
var menu_buttons: Dictionary = {}
var pending_menu: int = -1
var pending_row: int = -1
var menu_wait_selection: int = -1
var menu_next_time: int = 0

func _ready() -> void:
	audio = OEAudioManager.new()
	add_child(audio)
	session = OEGameSession.new(not testing,audio)
	presenter=OEPresentationState.new(session.vm)
	last_time = Time.get_ticks_msec()
	make_theme()
	heading = Label.new()
	heading.text = "ORCS & ELVES II"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",20)
	add_child(heading)
	mode_row = HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation",8)
	add_child(mode_row)
	classic_button = make_button(mode_row,"Classic",func(): set_render_mode(0))
	remastered_button = make_button(mode_row,"Remastered",func(): set_render_mode(1))
	classic_button.tooltip_text = "Исходная пиксельная графика · F2"
	remastered_button.tooltip_text = "Обработка контуров и освещения · F2"
	view_frame = Panel.new()
	add_child(view_frame)
	var atlas := AtlasTexture.new()
	atlas.atlas = session.texture
	atlas.region = Rect2(0,0,352,388)
	classic_view = TextureRect.new()
	classic_view.texture = atlas
	classic_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	classic_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	classic_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_frame.add_child(classic_view)
	classic_view.gui_input.connect(view_input)
	remastered_view = TextureRect.new()
	remastered_view.texture = atlas
	remastered_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	remastered_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	remastered_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	remastered_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	remastered_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader = ShaderMaterial.new()
	shader.shader = preload("res://rendering/remastered.gdshader")
	remastered_view.material = shader
	remastered_view.modulate.a = 0.0
	view_frame.add_child(remastered_view)
	native_menu=PanelContainer.new()
	native_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_frame.add_child(native_menu)
	var menu_margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]: menu_margin.add_theme_constant_override("margin_"+side,16)
	native_menu.add_child(menu_margin)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu_margin.add_child(scroll)
	native_rows=VBoxContainer.new()
	native_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	native_rows.add_theme_constant_override("separation",10)
	scroll.add_child(native_rows)
	controls = Control.new()
	add_child(controls)
	softkeys = HBoxContainer.new()
	softkeys.add_theme_constant_override("separation",8)
	controls.add_child(softkeys)
	left_key = key_button(softkeys,"Выбрать",-6)
	right_key = key_button(softkeys,"Назад",-7)
	keypad = GridContainer.new()
	keypad.columns = 3
	keypad.add_theme_constant_override("h_separation",6)
	keypad.add_theme_constant_override("v_separation",6)
	controls.add_child(keypad)
	for item in [["1",49],["Вперёд",50],["3",51],["Влево",52],["Действие",53],["Вправо",54],["7",55],["Назад",56],["9",57]]:
		key_button(keypad,item[0],item[1])
	auxiliary = HBoxContainer.new()
	auxiliary.add_theme_constant_override("separation",6)
	controls.add_child(auxiliary)
	for item in [["*",42],["0",48],["#",35]]: key_button(auxiliary,item[0],item[1])
	actions_row = HBoxContainer.new()
	actions_row.add_theme_constant_override("separation",6)
	add_child(actions_row)
	make_button(actions_row,"Сохранить",save_game).tooltip_text = "Быстро сохранить · F5"
	make_button(actions_row,"Загрузить",load_game).tooltip_text = "Быстро загрузить · F9"
	make_button(actions_row,"Звук",func(): audio.set_muted(not audio.muted)).tooltip_text = "Включить / выключить звук"
	make_button(actions_row,"Экран",toggle_fullscreen).tooltip_text = "Полный экран"
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",12)
	add_child(status)
	hint = Label.new()
	hint.text = "WASD / стрелки · Enter — действие · F2 — вид · F5 / F9 — сохранение"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",12)
	hint.add_theme_color_override("font_color",Color("a2a397"))
	add_child(hint)
	resized.connect(arrange)
	var settings := ConfigFile.new()
	var preferred: int = 0
	if not testing and settings.load("user://view.cfg")==OK: preferred=int(settings.get_value("view","mode",0))
	set_render_mode(clampi(preferred,0,1))
	arrange()

func make_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 15
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("222a2b") if state=="normal" else Color("3d4845")
		if state=="pressed": style.bg_color = Color("78633e")
		if state=="disabled": style.bg_color = Color("151b1c")
		style.border_color = Color("596150") if state!="focus" else Color("d8bd78")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		theme.set_stylebox(state,"Button",style)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color.BLACK
	panel.border_color = Color("6e6246")
	panel.set_border_width_all(1)
	theme.set_stylebox("panel","Panel",panel)

func make_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0,38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func key_button(parent: Control, text: String, key: int) -> Button:
	var button := make_button(parent,text,func(): pass)
	button.button_down.connect(func(): session.key(key); held_key=key; next_repeat=Time.get_ticks_msec()+350)
	button.button_up.connect(func(): if held_key==key: held_key=0)
	return button

func arrange() -> void:
	if not is_instance_valid(controls): return
	var wide: bool = size.x>size.y*1.15 and size.x>650
	var pad: float = 12.0
	var header: float = 82.0
	var footer: float = 72.0
	heading.position = Vector2(pad,8)
	heading.size = Vector2(size.x-pad*2,28)
	mode_row.position = Vector2(maxf(pad,(size.x-290)/2),40)
	mode_row.size = Vector2(minf(size.x-pad*2,290),34)
	classic_button.button_pressed = selected_mode==0
	remastered_button.button_pressed = selected_mode==1
	var content := Rect2(pad,header,size.x-pad*2,maxf(80,size.y-header-footer))
	if wide:
		var panel_width: float = clampf(size.x*0.24,240,340)
		var world := Rect2(content.position,Vector2(maxf(80,content.size.x-panel_width-pad),content.size.y))
		fit_frame(world)
		var side_height: float=44.0 if native_menu.visible else 258.0
		controls.position = Vector2(content.end.x-panel_width,content.position.y+maxf(0,(content.size.y-side_height)/2))
		controls.size = Vector2(panel_width,44 if native_menu.visible else 258)
	else:
		var panel_height: float = 44.0 if native_menu.visible else (220.0 if size.y>=700 else 208.0)
		fit_frame(Rect2(content.position,Vector2(content.size.x,maxf(80,content.size.y-panel_height-8))))
		controls.position = Vector2(content.position.x,content.end.y-panel_height)
		controls.size = Vector2(content.size.x,panel_height)
	keypad.visible=not native_menu.visible
	auxiliary.visible=not native_menu.visible
	var key_height: float = maxf(36,(controls.size.y-94)/3)
	softkeys.position = Vector2.ZERO
	softkeys.size = Vector2(controls.size.x,38)
	keypad.position = Vector2(0,44)
	keypad.size = Vector2(controls.size.x,key_height*3+12)
	for button in keypad.get_children(): button.custom_minimum_size.y = key_height
	auxiliary.position = Vector2(0,controls.size.y-32)
	auxiliary.size = Vector2(controls.size.x,32)
	for button in auxiliary.get_children(): button.custom_minimum_size.y=32
	actions_row.position = Vector2(pad,size.y-footer+2)
	actions_row.size = Vector2(size.x-pad*2,34)
	for button in actions_row.get_children(): button.custom_minimum_size.y=34
	status.position = Vector2(pad,size.y-34)
	status.size = Vector2(size.x-pad*2,20)
	hint.visible = size.x>650
	hint.position = Vector2(pad,size.y-19)
	hint.size = Vector2(size.x-pad*2,16)

func fit_frame(area: Rect2) -> void:
	if native_menu.visible:
		view_frame.size=Vector2(minf(area.size.x,520),area.size.y)
		view_frame.position=area.position+(area.size-view_frame.size)/2.0
		return
	var factor: float = minf(area.size.x/352.0,area.size.y/388.0)
	view_frame.size = Vector2(352,388)*factor
	view_frame.position = area.position+(area.size-view_frame.size)/2.0

func set_render_mode(mode: int) -> void:
	selected_mode = mode
	if fade!=null: fade.kill()
	fade = create_tween()
	fade.tween_property(remastered_view,"modulate:a",float(mode),0.25)
	classic_button.disabled = mode==0
	remastered_button.disabled = mode==1
	var settings := ConfigFile.new()
	settings.set_value("view","mode",mode)
	if not testing: settings.save("user://view.cfg")
	# This method only changes presentation. It never calls the VM or game input.

func save_game() -> void:
	toast("Игра сохранена" if OESnapshot.new().save_game(session,saved_path) else "Не удалось сохранить")

func load_game() -> void:
	audio.stop_music()
	toast("Сохранение загружено" if OESnapshot.new().load_game(session,saved_path) else "Нет сохранения")

func toast(text: String) -> void:
	status.text = text
	toast_until = Time.get_ticks_msec()+3000

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if not paused: session.tick(clampi(now-last_time,1,100))
	last_time = now
	if held_key!=0 and now>=next_repeat and not paused:
		session.key(held_key)
		next_repeat = now+180
	var state: int = session.vm.get_static("a","H","I")
	shader.set_shader_parameter("world_active",state in [3,4,7,17,19])
	update_native_menu(now)
	var rect: Variant = session.vm.get_static("a","c","[I")
	if rect is JObject and rect.data.size()>=4:
		shader.set_shader_parameter("world_rect",Vector4(rect.data[0]/352.0,rect.data[1]/416.0,(rect.data[0]+rect.data[2])/352.0,(rect.data[1]+rect.data[3])/416.0))
	for item in [[left_key,"d"],[right_key,"e"]]:
		var text: Variant = session.vm.get_static("a",item[1],"Ljava/lang/StringBuffer;")
		if text is JObject and text.data is String: item[0].text = clean_caption(text.data)
	if toast_until>0 and now>toast_until: status.text="";toast_until=0
	if session.vm.halted: status.text = session.vm.errors[-1] if not session.vm.errors.is_empty() else "Игра завершена"

func clean_caption(text: String) -> String:
	return presenter.chars(text)

func update_native_menu(now: int) -> void:
	var menu: Dictionary=presenter.menu()
	var active: bool=not menu.is_empty() and not menu.rows.is_empty()
	var show_menu: bool=int(session.vm.get_static("a","H","I"))==2
	var changed: bool=native_menu.visible!=show_menu
	native_menu.visible=show_menu
	classic_view.visible=not show_menu
	remastered_view.visible=not show_menu
	if changed: arrange()
	if not active:
		pending_menu=-1
		return
	var signature: String=JSON.stringify([menu.id,menu.rows,menu.description])
	if signature!=menu_signature:
		menu_signature=signature
		for child in native_rows.get_children(): child.free()
		menu_buttons.clear()
		var title:=Label.new()
		title.text="ORCS & ELVES II"
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size",20)
		title.add_theme_color_override("font_color",Color("d8bd78"))
		native_rows.add_child(title)
		for row: Dictionary in menu.rows:
			var index: int=row.index
			var label: String=row.text
			if not row.value.is_empty(): label+=" · "+row.value
			if row.get("readonly",false):
				var text_label:=Label.new()
				text_label.text=label
				text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				text_label.add_theme_font_size_override("font_size",18)
				native_rows.add_child(text_label)
				continue
			var button:=make_button(native_rows,label,func(): choose_menu_row(int(menu.id),index))
			button.disabled=row.disabled
			button.custom_minimum_size.y=44
			button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			menu_buttons[index]=button
		if not str(menu.description).is_empty():
			var description:=Label.new()
			description.text=menu.description
			description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			description.add_theme_font_size_override("font_size",14)
			native_rows.add_child(description)
	for index: Variant in menu_buttons:
		menu_buttons[index].modulate=Color("efd6a2") if int(index)==int(menu.selected) else Color.WHITE
	if pending_menu==int(menu.id) and now>=menu_next_time:
		var selected: int=menu.selected
		if selected==menu_wait_selection: return
		if selected==pending_row:
			session.key(53)
			pending_menu=-1
		else:
			session.key(56 if selected<pending_row else 50)
			menu_wait_selection=selected
			menu_next_time=now+160

func choose_menu_row(menu: int, index: int) -> void:
	pending_menu=menu
	pending_row=index
	menu_wait_selection=-1
	menu_next_time=0

func view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: touch_start=event.position
		else:
			var move: Vector2 = event.position-touch_start
			if move.length()<24: session.key(53)
			elif absf(move.x)>absf(move.y): session.key(54 if move.x>0 else 52)
			else: session.key(56 if move.y>0 else 50)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo: return
	if event.pressed:
		match event.keycode:
			KEY_F2: set_render_mode(1-selected_mode);get_viewport().set_input_as_handled();return
			KEY_F5: save_game();get_viewport().set_input_as_handled();return
			KEY_F9: load_game();get_viewport().set_input_as_handled();return
	var mapping := {KEY_W:50,KEY_UP:50,KEY_S:56,KEY_DOWN:56,KEY_A:52,KEY_LEFT:52,KEY_D:54,KEY_RIGHT:54,KEY_ENTER:53,KEY_SPACE:53,KEY_ESCAPE:-7,KEY_F1:-6,KEY_M:-7}
	var raw: int = mapping.get(event.keycode,0)
	if event.unicode>=48 and event.unicode<=57: raw=event.unicode
	if event.unicode==42 or event.unicode==35: raw=event.unicode
	if raw!=0:
		if event.pressed: session.key(raw);held_key=raw;next_repeat=Time.get_ticks_msec()+350
		elif held_key==raw: held_key=0
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: held_key=0

func _exit_tree() -> void:
	if session!=null: session.close()
