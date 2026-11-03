extends Control

var qa_check: RefCounted
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
var version_badge: Label
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
var backgrounded: bool = false
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
var world_texture: ImageTexture
var world_revision: int = -1
var world_graphics_id: int = 0
var hud: OEAdventureHUD
var reader_panel: OEReaderPanel
var presentation_kind: String = ""
var original_atlas: AtlasTexture
var scene_aspect: float = 352.0/416.0
var reader_data: Dictionary = {}
var pending_choice: int = -1
var choice_wait: int = -1

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
	original_atlas = AtlasTexture.new()
	var atlas: AtlasTexture = original_atlas
	atlas.atlas = session.texture
	atlas.region = Rect2(0,0,352,416)
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
	reader_panel=OEReaderPanel.new()
	view_frame.add_child(reader_panel)
	reader_panel.visible=false
	reader_panel.choice_requested.connect(choose_dialogue)
	reader_panel.continue_requested.connect(func(): session.key(53))
	hud=OEAdventureHUD.new()
	add_child(hud)
	hud.visible=false
	hud.key_requested.connect(func(key: int): session.key(key))
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
	for item in [["Шаг влево",49],["Вперёд",50],["Шаг вправо",51],["< Поворот",52],["Действие",53],["Поворот >",54],["Оружие >",55],["Назад",56],["Ждать",57]]:
		key_button(keypad,item[0],item[1])
	auxiliary = HBoxContainer.new()
	auxiliary.add_theme_constant_override("separation",6)
	controls.add_child(auxiliary)
	for item in [["< Оружие",42],["Меню",48],["Карта",35]]: key_button(auxiliary,item[0],item[1])
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
	version_badge=Label.new()
	version_badge.text="v"+str(ProjectSettings.get_setting("application/config/version"))
	version_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	version_badge.add_theme_font_size_override("font_size",10)
	version_badge.add_theme_color_override("font_color",Color("a2a397"))
	add_child(version_badge)
	hint.text = "WASD — ход · Z/C — шаг вбок · Q/E — оружие · Enter — действие · M — карта"
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

	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.search.includes('rastercheck=1')")):
		qa_check=preload("res://qa/web_render_check.gd").new()
		qa_check.call_deferred("run",self)
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.search.includes('spritecheck=1')")):
		qa_check=preload("res://qa/web_sprite_check.gd").new()
		qa_check.call_deferred("run",self)

	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.search.includes('weaponcheck=1')")):
		qa_check=preload("res://qa/web_weapon_check.gd").new()
		qa_check.call_deferred("run",self)

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
	button.button_down.connect(func(): begin_key(key))
	button.button_up.connect(func(): end_key(key))
	return button

func arrange() -> void:
	if not is_instance_valid(controls): return
	var wide: bool = size.x>size.y*1.15 and size.x>650
	var pad: float = 12.0
	var compact_game: bool = presentation_kind in ["world","dialogue"]
	var text_screen: bool = presentation_kind in ["menu","story","dialogue","loading"]
	var header: float = 58.0 if compact_game else 82.0
	var footer: float = 72.0
	heading.visible=not compact_game
	heading.position = Vector2(pad,8)
	heading.size = Vector2(size.x-pad*2,28)
	mode_row.position = Vector2(maxf(pad,(size.x-290)/2),10 if compact_game else 40)
	mode_row.size = Vector2(minf(size.x-pad*2,290),34)
	classic_button.button_pressed = selected_mode==0
	remastered_button.button_pressed = selected_mode==1
	var content := Rect2(pad,header,size.x-pad*2,maxf(80,size.y-header-footer))
	if wide:
		var panel_width: float = clampf(size.x*0.24,240,340)
		var world := Rect2(content.position,Vector2(maxf(80,content.size.x-panel_width-pad),content.size.y))
		if hud.visible:
			hud.position=Vector2(world.position.x,world.end.y-94)
			hud.size=Vector2(world.size.x,94)
			world.size.y-=100
		fit_frame(world)
		var side_height: float=44.0 if text_screen else 208.0
		controls.position = Vector2(content.end.x-panel_width,content.position.y+maxf(0,(content.size.y-side_height)/2))
		controls.size = Vector2(panel_width,44 if text_screen else 208)
	else:
		var panel_height: float = 44.0 if text_screen else ((188.0 if size.y>=700 else 170.0) if compact_game else 208.0)
		var world := Rect2(content.position,Vector2(content.size.x,maxf(80,content.size.y-panel_height-8)))
		if hud.visible:
			hud.position=Vector2(world.position.x,world.end.y-94)
			hud.size=Vector2(world.size.x,94)
			world.size.y=maxf(40,world.size.y-100)
		fit_frame(world)
		controls.position = Vector2(content.position.x,content.end.y-panel_height)
		controls.size = Vector2(content.size.x,panel_height)
	keypad.visible=not text_screen
	auxiliary.visible=presentation_kind=="fallback"
	reader_panel.position=Vector2.ZERO
	reader_panel.size=view_frame.size
	if presentation_kind=="dialogue":
		reader_panel.position.y=view_frame.size.y*0.12
		reader_panel.size.y=view_frame.size.y-reader_panel.position.y
	var key_height: float = maxf(36,(controls.size.y-(94 if auxiliary.visible else 56))/3)
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
	version_badge.position=Vector2(size.x-66,size.y-16)
	version_badge.size=Vector2(54,14)

func fit_frame(area: Rect2) -> void:
	if presentation_kind in ["menu","story","loading"]:
		view_frame.size=Vector2(minf(area.size.x,520),area.size.y)
		view_frame.position=area.position+(area.size-view_frame.size)/2.0
		return
	var target_size := Vector2(352,352/scene_aspect)
	var factor: float = minf(area.size.x/target_size.x,area.size.y/target_size.y)
	view_frame.size = target_size*factor
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
	if backgrounded:
		last_time=Time.get_ticks_msec()
		return
	var now := Time.get_ticks_msec()
	if not paused: session.tick(clampi(now-last_time,1,100))
	last_time = now
	var ui_began: int=Time.get_ticks_usec()
	if held_key!=0 and now>=next_repeat and not paused:
		if int(session.vm.get_static("a","aJ","I"))==0: session.key(held_key)
		next_repeat = now+180
	var state: int = session.vm.get_static("a","H","I")
	shader.set_shader_parameter("world_active",state in [3,4,7])
	update_native_menu(now)
	update_adventure(now)
	var rect: Variant = session.vm.get_static("a","c","[I")
	if classic_view.texture==world_texture and world_texture!=null:
		shader.set_shader_parameter("world_rect",Vector4(0,0,1,1))
	elif rect is JObject and rect.data.size()>=4:
		shader.set_shader_parameter("world_rect",Vector4(rect.data[0]/352.0,rect.data[1]/416.0,(rect.data[0]+rect.data[2])/352.0,(rect.data[1]+rect.data[3])/416.0))
	for item in [[left_key,"d"],[right_key,"e"]]:
		var text: Variant = session.vm.get_static("a",item[1],"Ljava/lang/StringBuffer;")
		if text is JObject and text.data is String: item[0].text = clean_caption(text.data)
	if not reader_data.is_empty():
		left_key.text=str(reader_data.left)
		right_key.text=str(reader_data.right)
	left_key.disabled=left_key.text.is_empty()
	right_key.disabled=right_key.text.is_empty()
	if toast_until>0 and now>toast_until: status.text="";toast_until=0
	if session.vm.halted: status.text = session.vm.errors[-1] if not session.vm.errors.is_empty() else "Игра завершена"

	session.metrics.publish(Time.get_ticks_usec()-ui_began)

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
	if changed: menu_signature=""
	if not active:
		pending_menu=-1
		return
	var signature: String=JSON.stringify([menu.id,menu.rows,menu.description])
	if signature!=menu_signature:
		menu_signature=signature
		for child in native_rows.get_children(): child.free()
		menu_buttons.clear()
		var title:=Label.new()
		title.text="Меню"
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
		if selected==menu_wait_selection and now<menu_next_time+800: return
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

func update_adventure(now: int) -> void:
	reader_data=presenter.reader()
	var hud_data: Dictionary=presenter.hud()
	var state: int=session.vm.get_static("a","H","I")
	if state in [0,6] and reader_data.is_empty():
		var level_name: String=presenter.buffer("k","a")
		reader_data={"kind":"loading","text":level_name if not level_name.is_empty() else "Подготовка игры…","left":"","right":""}
	var graphics: JObject=session.platform.screen
	var world: Variant=graphics.extra.get("world_surface")
	var revision: int=int(graphics.extra.get("world_revision",-1))
	var aspect: float=scene_aspect
	if world is Image and (revision!=world_revision or world_graphics_id!=graphics.get_instance_id()):
		if world_texture==null or world_texture.get_size()!=Vector2(world.get_size()): world_texture=ImageTexture.create_from_image(world)
		else: world_texture.update(world)
		world_revision=revision
		world_graphics_id=graphics.get_instance_id()
		aspect=float(world.get_width())/float(world.get_height())
	var kind: String="fallback"
	if state==2: kind="menu"
	elif not reader_data.is_empty(): kind=str(reader_data.kind)
	elif not hud_data.is_empty() and world is Image: kind="world"
	var using_world: bool=kind in ["world","dialogue"] and world is Image
	classic_view.texture=world_texture if using_world else original_atlas
	remastered_view.texture=classic_view.texture
	classic_view.visible=kind not in ["menu","story","loading"]
	remastered_view.visible=classic_view.visible
	var old_hud_visible: bool=hud.visible
	hud.show_state(hud_data if using_world else {})
	reader_panel.show_state(reader_data)
	if not reader_data.is_empty() and reader_data.kind=="dialogue" and pending_choice>=0 and now>=menu_next_time:
		if reader_data.get("choice",false):
			var selected: int=reader_data.selected_choice
			if selected==pending_choice:
				session.key(53)
				pending_choice=-1
			elif selected!=choice_wait or now>=menu_next_time+800:
				session.key(52 if pending_choice==0 else 54)
				choice_wait=selected
				menu_next_time=now+160
	elif reader_data.is_empty(): pending_choice=-1
	if kind!=presentation_kind or aspect!=scene_aspect or old_hud_visible!=hud.visible:
		presentation_kind=kind
		scene_aspect=aspect if using_world else 352.0/416.0
		arrange()

func choose_dialogue(index: int) -> void:
	pending_choice=index
	choice_wait=-1
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
	var mapping := {KEY_W:50,KEY_UP:50,KEY_S:56,KEY_DOWN:56,KEY_A:52,KEY_LEFT:52,KEY_D:54,KEY_RIGHT:54,KEY_ENTER:53,KEY_SPACE:53,KEY_ESCAPE:-7,KEY_F1:-6,KEY_M:35,KEY_Q:42,KEY_E:55,KEY_Z:49,KEY_C:51,KEY_R:57,KEY_I:48}
	var raw: int = mapping.get(event.physical_keycode,mapping.get(event.keycode,0))
	if event.keycode>=KEY_0 and event.keycode<=KEY_9: raw=int(event.keycode)
	elif event.unicode>=48 and event.unicode<=57: raw=event.unicode
	if event.unicode==42 or event.unicode==35: raw=event.unicode
	if raw!=0:
		if event.pressed: begin_key(raw)
		else: end_key(raw)
		get_viewport().set_input_as_handled()

func begin_key(raw: int) -> void:
	session.key(raw)
	held_key=raw if raw in [49,50,51,52,54,56] else 0
	next_repeat=Time.get_ticks_msec()+350

func end_key(raw: int) -> void:
	if held_key==raw: held_key=0

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		held_key=0
		if not testing:
			backgrounded=true
			Engine.max_fps=10
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN and not testing:
		backgrounded=false
		Engine.max_fps=60
		last_time=Time.get_ticks_msec()

func _exit_tree() -> void:
	if session!=null: session.close()
