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
var header_tools: HBoxContainer
var frame_ornament: OEAtmosphere
var map_view: OEDungeonMap
var stage_caption: Label
var subtitle: Label
var is_cinematic: bool=false
var sound_button: Button
var modal_layer: Control
var map_tools: HBoxContainer
var map_scale: Label
var interaction_meter: HBoxContainer
var dialogue_base_kind: String="world"
var language_ready: bool=false
var language_picker: OEStartupLanguage

func _ready() -> void:
	var locale_settings:=ConfigFile.new()
	var preferred_language: String="ru"
	if not testing and locale_settings.load("user://language.cfg")==OK: preferred_language=str(locale_settings.get_value("ui","language","ru"))
	OEText.choose(preferred_language)
	audio = OEAudioManager.new()
	add_child(audio)
	session = OEGameSession.new(not testing,audio)
	presenter=OEPresentationState.new(session.vm)
	last_time = Time.get_ticks_msec()
	make_theme()
	var backdrop:=OEAtmosphere.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	heading = Label.new()
	heading.text = "ORCS & ELVES II"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",16)
	heading.add_theme_color_override("font_color",OESkin.GOLD)
	add_child(heading)
	mode_row = HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation",8)
	add_child(mode_row)
	classic_button = make_button(mode_row,"CLASSIC",func(): set_render_mode(0))
	remastered_button = make_button(mode_row,"REMASTERED",func(): set_render_mode(1))
	classic_button.tooltip_text = "Исходная пиксельная графика · F2"
	remastered_button.tooltip_text = "Увеличенный игровой вид · F2"
	for button in [classic_button,remastered_button]: button.add_theme_font_size_override("font_size",12)
	header_tools=HBoxContainer.new()
	header_tools.add_theme_constant_override("separation",6)
	add_child(header_tools)
	for item in [["menu",48,"Меню","I"],["map",35,"Карта","M"]]:
		var button:=key_button(header_tools,"",item[1])
		OESkin.decorate(button,item[0],item[2],item[3])
	view_frame = Panel.new()
	add_child(view_frame)
	original_atlas = AtlasTexture.new()
	original_atlas.atlas = session.texture
	original_atlas.region = Rect2(0,0,352,416)
	classic_view = TextureRect.new()
	classic_view.texture = null
	classic_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	classic_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	classic_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	classic_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_frame.add_child(classic_view)
	classic_view.gui_input.connect(view_input)
	remastered_view = TextureRect.new()
	remastered_view.texture = null
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
	modal_layer=Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.z_index=50
	modal_layer.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(modal_layer)
	var shade:=ColorRect.new()
	shade.color=Color(0.015,0.025,0.02,0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(shade)
	modal_layer.visible=false
	reader_panel.key_requested.connect(func(key: int): session.key(key))
	reader_panel.choice_requested.connect(choose_dialogue)
	reader_panel.continue_requested.connect(func(): session.key(53))
	map_view=OEDungeonMap.new()
	view_frame.add_child(map_view)
	map_view.visible=false
	map_tools=HBoxContainer.new()
	map_tools.add_theme_constant_override("separation",6)
	view_frame.add_child(map_tools)
	for item in [["minus","Уменьшить карту",func(): map_view.zoom_by(0.8)],["plus","Увеличить карту",func(): map_view.zoom_by(1.25)],["center","Сбросить вид карты",func(): map_view.reset_view()]]:
		var button:=make_button(map_tools,"",item[2])
		OESkin.decorate(button,item[0],item[1])
		button.custom_minimum_size=Vector2(40,38)
	map_scale=Label.new();map_scale.text="100%";map_scale.custom_minimum_size.x=48
	map_scale.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	map_scale.add_theme_font_size_override("font_size",12)
	map_scale.add_theme_color_override("font_color",OESkin.GOLD)
	map_tools.add_child(map_scale)
	map_view.view_changed.connect(func(): map_scale.text="%d%%" % roundi(map_view.zoom*100))
	map_tools.visible=false
	stage_caption=Label.new()
	stage_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stage_caption.add_theme_font_size_override("font_size",12)
	stage_caption.add_theme_color_override("font_color",OESkin.GOLD)
	stage_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view_frame.add_child(stage_caption)
	interaction_meter=HBoxContainer.new()
	interaction_meter.add_theme_constant_override("separation",5)
	view_frame.add_child(interaction_meter)
	interaction_meter.visible=false
	subtitle=Label.new()
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",18)
	subtitle.add_theme_color_override("font_color",OESkin.PAPER)
	subtitle.add_theme_color_override("font_shadow_color",Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_x",2)
	subtitle.add_theme_constant_override("shadow_offset_y",2)
	subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view_frame.add_child(subtitle)
	frame_ornament=OEAtmosphere.new()
	frame_ornament.frame_only=true
	frame_ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_frame.add_child(frame_ornament)
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
	for item in [["strafe_left",49,"Шаг влево","Z"],["forward",50,"Вперёд","W"],["strafe_right",51,"Шаг вправо","C"],["turn_left",52,"Повернуть влево","A"],["attack",53,"Действие / удар","Enter"],["turn_right",54,"Повернуть вправо","D"],["weapon",55,"Следующее оружие","E"],["back",56,"Назад","S"],["wait",57,"Пропустить ход","R"]]:
		var button:=key_button(keypad,"",item[1])
		OESkin.decorate(button,item[0],item[2],item[3])
		if int(item[1])==53:
			button.add_theme_stylebox_override("normal",OESkin.plate(Color("463b24"),OESkin.GOLD,8))
	auxiliary = HBoxContainer.new()
	auxiliary.add_theme_constant_override("separation",6)
	controls.add_child(auxiliary)
	for item in [["< Оружие",42],["Меню",48],["Карта",35]]: key_button(auxiliary,item[0],item[1])
	actions_row = HBoxContainer.new()
	actions_row.add_theme_constant_override("separation",6)
	add_child(actions_row)
	for item in [["save","Сохранить","F5",save_game],["load","Загрузить","F9",load_game],["sound","Звук","",func(): audio.set_muted(not audio.muted)],["fullscreen","Полный экран","",toggle_fullscreen]]:
		var button:=make_button(actions_row,"",item[3])
		OESkin.decorate(button,item[0],item[1],item[2])
		if item[0]=="sound": sound_button=button
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
	var preferred: int = 1
	if not testing and settings.load("user://view.cfg")==OK: preferred=int(settings.get_value("view","mode",0))
	set_render_mode(clampi(preferred,0,1))
	arrange()
	language_ready=testing
	if not testing:
		language_picker=OEStartupLanguage.new()
		add_child(language_picker)
		language_picker.selected.connect(select_language)

	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.search.includes('rastercheck=1')")):
		qa_check=preload("res://qa/web_render_check.gd").new()
		qa_check.call_deferred("run",self)
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.search.includes('spritecheck=1')")):
		qa_check=preload("res://qa/web_sprite_check.gd").new()
		qa_check.call_deferred("run",self)

	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.search.includes('weaponcheck=1')")):
		qa_check=preload("res://qa/web_weapon_check.gd").new()
		qa_check.call_deferred("run",self)

func select_language(language: String) -> void:
	OEText.choose(language)
	var config:=ConfigFile.new();config.set_value("ui","language",OEText.language)
	if not testing: config.save("user://language.cfg")
	language_ready=true;last_time=Time.get_ticks_msec()
	if is_instance_valid(language_picker): language_picker.queue_free()
	localize_controls(self)
	menu_signature=""
	arrange()

func localize_controls(node: Node) -> void:
	if node==language_picker: return
	if node is Label or node is Button:
		if not node.has_meta("locale_source_text"): node.set_meta("locale_source_text",node.text)
		node.text=OEText.localize(str(node.get_meta("locale_source_text")))
	if node is Control:
		if not node.has_meta("locale_source_tooltip"): node.set_meta("locale_source_tooltip",node.tooltip_text)
		if not node.has_meta("locale_source_name"): node.set_meta("locale_source_name",node.accessibility_name)
		node.tooltip_text=OEText.localize(str(node.get_meta("locale_source_tooltip")))
		node.accessibility_name=OEText.localize(str(node.get_meta("locale_source_name")))
	for child in node.get_children(): localize_controls(child)

func make_theme() -> void:
	theme=OESkin.make_theme()

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
	var wide: bool=size.x>size.y*1.2 and size.x>=600
	var pad: float=12 if size.x<650 else 22
	var layout_kind: String=dialogue_base_kind if presentation_kind=="dialogue" else presentation_kind
	var play: bool=layout_kind in ["world","cinematic","death","interaction"]
	var text_screen: bool=layout_kind in ["menu","story","loading","credits","map","cinematic","death"]
	var expanded: bool=selected_mode==1 and play
	var header: float=62
	var footer: float=44
	heading.visible=size.x>850 or presentation_kind in ["menu","story","loading","credits"]
	heading.position=Vector2(pad,17)
	heading.size=Vector2(220,26)
	if size.x<=850:
		heading.visible=not play and size.y>550
		heading.position=Vector2(pad,8);heading.size=Vector2(size.x-pad*2,22)
		if heading.visible: header=92
	mode_row.position=Vector2((size.x-248)/2,14 if header==62 else 42)
	mode_row.size=Vector2(248,32)
	for button in [classic_button,remastered_button]: button.custom_minimum_size.y=32
	header_tools.visible=play or presentation_kind=="map"
	header_tools.position=Vector2(size.x-pad-94,10)
	header_tools.size=Vector2(94,38)
	if size.x<600:
		mode_row.position.x=pad;mode_row.size.x=minf(226,size.x-124)
		for button in [classic_button,remastered_button]: button.add_theme_font_size_override("font_size",11)
	var content:=Rect2(pad,header,size.x-pad*2,maxf(100,size.y-header-footer-8))
	var world: Rect2=content
	# Reserve context and target rows: item captions never resize the scene.
	var hud_height: float=114
	if hud.visible:
		hud.position=Vector2(content.position.x,content.end.y-hud_height)
		hud.size=Vector2(content.size.x,hud_height)
		world.size.y-=hud_height+8
	keypad.visible=not text_screen
	softkeys.visible=not play
	auxiliary.visible=false
	if wide:
		if keypad.visible:
			var side: float=164 if size.y>=500 else 140
			controls.size=Vector2(side,158 if size.y>=500 else 132)
			if expanded:
				# Dock in a side gutter: the entire original view remains visible.
				var image_width: float=world.size.y*scene_aspect
				var gutter: float=(world.size.x-image_width)/2
				if gutter<side+20: world.size.x-=side+16;world.position.x+=side+16
				controls.position=Vector2(content.position.x,world.end.y-controls.size.y)
			else:
				world.size.x-=side+18
				controls.position=Vector2(content.end.x-side,world.position.y+(world.size.y-controls.size.y)/2)
		else:
			controls.position=Vector2(content.position.x,content.end.y-40)
			controls.size=Vector2(content.size.x,40)
			if softkeys.visible: world.size.y-=48
	else:
		var control_height: float=148 if size.y>=700 else 132
		if keypad.visible:
			controls.position=Vector2(content.position.x,content.end.y-control_height)
			controls.size=Vector2(content.size.x,control_height)
			world.size.y-=control_height+8
			if hud.visible:
				hud.position.y-=control_height+8
		else:
			controls.position=Vector2(content.position.x,content.end.y-40)
			controls.size=Vector2(content.size.x,40)
			if softkeys.visible:
				world.size.y-=48
				if hud.visible: hud.position.y-=48
	fit_frame(world)
	if presentation_kind=="dialogue":
		reader_panel.size=Vector2(minf(size.x-pad*2,620),minf(size.y-24,280))
		reader_panel.position=(size-reader_panel.size)/2
	else:
		reader_panel.position=Vector2.ZERO;reader_panel.size=view_frame.size
	map_view.position=Vector2(10,34);map_view.size=view_frame.size-Vector2(20,94)
	map_tools.position=Vector2((view_frame.size.x-196)/2,view_frame.size.y-48)
	map_tools.size=Vector2(196,38)
	stage_caption.position=Vector2(12,10);stage_caption.size=Vector2(view_frame.size.x-24,24)
	interaction_meter.position=Vector2((view_frame.size.x-interaction_meter.get_combined_minimum_size().x)/2,40)
	subtitle.position=Vector2(24,maxf(40,view_frame.size.y-108))
	subtitle.size=Vector2(maxf(20,view_frame.size.x-48),88)
	softkeys.position=Vector2.ZERO;softkeys.size=Vector2(controls.size.x,40)
	var grid_height: float=controls.size.y
	keypad.position=Vector2.ZERO;keypad.size=Vector2(controls.size.x,grid_height)
	for button in keypad.get_children(): button.custom_minimum_size.y=(grid_height-12)/3
	actions_row.position=Vector2(size.x/2-100,size.y-footer)
	actions_row.size=Vector2(200,34)
	for button in actions_row.get_children(): button.custom_minimum_size=Vector2(42,32);button.add_theme_constant_override("icon_max_width",19)
	status.position=Vector2(pad,size.y-footer-24);status.size=Vector2(size.x-pad*2,22)
	hint.visible=wide and size.x>1000
	hint.position=Vector2(pad,size.y-30);hint.size=Vector2(maxf(50,size.x/2-130),20)
	hint.add_theme_font_size_override("font_size",10)
	version_badge.position=Vector2(size.x-76,size.y-26);version_badge.size=Vector2(54,14)

func fit_frame(area: Rect2) -> void:
	if presentation_kind in ["menu","story","loading","credits"]:
		view_frame.size=Vector2(minf(area.size.x,620),area.size.y)
		view_frame.position=area.position+(area.size-view_frame.size)/2
		return
	if presentation_kind=="map" or (selected_mode==1 and presentation_kind in ["world","dialogue","cinematic","death","interaction"]):
		view_frame.position=area.position;view_frame.size=area.size
		return
	var target:=Vector2(352,352/scene_aspect)
	var factor: float=minf(area.size.x/target.x,area.size.y/target.y)*0.88
	view_frame.size=target*factor
	view_frame.position=area.position+(area.size-view_frame.size)/2

func set_render_mode(mode: int) -> void:
	selected_mode = mode
	if fade!=null: fade.kill()
	fade = create_tween()
	fade.tween_property(remastered_view,"modulate:a",float(mode),0.25)
	for button in [classic_button,remastered_button]: button.toggle_mode=true
	classic_button.set_pressed_no_signal(mode==0)
	remastered_button.set_pressed_no_signal(mode==1)
	var settings := ConfigFile.new()
	settings.set_value("view","mode",mode)
	if not testing: settings.save("user://view.cfg")
	arrange()
	# This method only changes presentation. It never calls the VM or game input.

func save_game() -> void:
	toast("Игра сохранена" if OESnapshot.new().save_game(session,saved_path) else "Не удалось сохранить")

func load_game() -> void:
	audio.stop_music()
	toast("Сохранение загружено" if OESnapshot.new().load_game(session,saved_path) else "Нет сохранения")

func toast(text: String) -> void:
	status.text = OEText.localize(text)
	toast_until = Time.get_ticks_msec()+3000

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(_delta: float) -> void:
	if not language_ready: last_time=Time.get_ticks_msec();return
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
	shader.set_shader_parameter("world_active",state in [3,4,7,9,12,17,19])
	update_native_menu(now)
	update_adventure(now)
	sound_button.icon=OESkin.icon("muted" if audio.muted else "sound")
	var rect: Variant = session.vm.get_static("a","c","[I")
	if classic_view.texture==world_texture and world_texture!=null:
		shader.set_shader_parameter("world_rect",Vector4(0,0,1,1))
	elif rect is JObject and rect.data.size()>=4:
		shader.set_shader_parameter("world_rect",Vector4(rect.data[0]/352.0,rect.data[1]/416.0,(rect.data[0]+rect.data[2])/352.0,(rect.data[1]+rect.data[3])/416.0))
	for item in [[left_key,"d"],[right_key,"e"]]:
		var text: Variant = session.vm.get_static("a",item[1],"Ljava/lang/StringBuffer;")
		if text is JObject and text.data is String: item[0].text = clean_caption(text.data)
	if not reader_data.is_empty():
		left_key.text=OEText.localize(str(reader_data.left))
		right_key.text=OEText.localize(str(reader_data.right))
	left_key.disabled=left_key.text.is_empty()
	right_key.disabled=right_key.text.is_empty()
	if toast_until>0 and now>toast_until: status.text="";toast_until=0
	if session.vm.halted: status.text = session.vm.errors[-1] if not session.vm.errors.is_empty() else "Игра завершена"

	session.metrics.publish(Time.get_ticks_usec()-ui_began)

func clean_caption(text: String) -> String:
	return OEText.localize(presenter.chars(text))

func update_native_menu(now: int) -> void:
	var menu: Dictionary=presenter.menu()
	var active: bool=not menu.is_empty() and not menu.rows.is_empty()
	var show_menu: bool=int(session.vm.get_static("a","H","I"))==2 and active
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
		title.text="ORCS & ELVES II" if int(menu.id)<100 else OEText.localize("ПУТЕШЕСТВИЕ")
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
	var previous_cinematic: bool=is_cinematic
	is_cinematic=presenter.cinematic() or state in [9,17]
	if state in [0,1,6,15] or (state==2 and not native_menu.visible):
		reader_data={"kind":"loading","text":presenter.buffer("a","c") if not presenter.buffer("a","c").is_empty() else "Подготовка игры…","left":"","right":""}
	var graphics: JObject=session.platform.screen
	var world: Variant=graphics.extra.get("world_surface")
	var revision: int=int(graphics.extra.get("world_revision",-1))
	var aspect: float=scene_aspect
	if world is Image and (revision!=world_revision or world_graphics_id!=graphics.get_instance_id()):
		if world_texture==null or world_texture.get_size()!=Vector2(world.get_size()): world_texture=ImageTexture.create_from_image(world)
		else: world_texture.update(world)
		world_revision=revision;world_graphics_id=graphics.get_instance_id()
		aspect=float(world.get_width())/float(world.get_height())
	var kind: String="loading"
	if state==2 and native_menu.visible: kind="menu"
	elif not reader_data.is_empty(): kind=str(reader_data.kind)
	elif state==5: kind="map"
	elif state==12: kind="death"
	elif state==19: kind="interaction"
	elif is_cinematic: kind="cinematic"
	elif not hud_data.is_empty() and world is Image: kind="world"
	else: reader_data={"kind":"loading","text":"Подготовка игры…","left":"","right":""}
	var using_world: bool=kind in ["world","dialogue","cinematic","death","interaction"] and world is Image
	# The phone framebuffer stays a research reference. Never present its UI.
	classic_view.texture=world_texture if using_world else null
	remastered_view.texture=classic_view.texture
	classic_view.visible=using_world;remastered_view.visible=using_world
	var old_hud_visible: bool=hud.visible
	if kind=="dialogue" and presentation_kind!="dialogue":
		dialogue_base_kind=presentation_kind if presentation_kind in ["world","cinematic","death","interaction"] else "world"
	var hud_kind: String=dialogue_base_kind if kind=="dialogue" else kind
	hud.show_state(hud_data if using_world and hud_kind not in ["cinematic","death"] else {})
	var modal: bool=kind=="dialogue"
	if modal and reader_panel.get_parent()!=modal_layer:
		reader_panel.reparent(modal_layer,false)
		held_key=0
	elif not modal and reader_panel.get_parent()!=view_frame:
		reader_panel.reparent(view_frame,false)
		view_frame.move_child(reader_panel,view_frame.get_child_count()-2)
	modal_layer.visible=modal
	reader_panel.show_state(reader_data)
	map_view.show_state(presenter.map_state())
	map_tools.visible=kind=="map"
	stage_caption.text="КАРТА ПОДЗЕМЕЛЬЯ" if kind=="map" else ("СЮЖЕТНАЯ СЦЕНА" if is_cinematic else ("ПУТЬ ОКОНЧЕН" if kind=="death" else ""))
	stage_caption.text=OEText.localize(stage_caption.text)
	interaction_meter.visible=kind=="interaction"
	if kind=="interaction":
		var code: Variant=session.vm.get_static("l","a","[C")
		var length: int=0
		if code is JObject:
			for letter: Variant in code.data:
				if int(letter)==0: break
				length+=1
		if interaction_meter.get_child_count()!=length:
			for child in interaction_meter.get_children(): child.free()
			for index in length:
				var pip:=ColorRect.new();pip.custom_minimum_size=Vector2(18,8)
				interaction_meter.add_child(pip)
			interaction_meter.position.x=(view_frame.size.x-length*23+5)/2
		for index in interaction_meter.get_child_count():
			var completed: int=session.vm.get_static("a","ax","I")
			interaction_meter.get_child(index).color=Color("7e9a57") if index<completed else (OESkin.GOLD if index==completed and int(session.vm.get_static("a","aw","I"))==1 else Color("454f3d"))
		stage_caption.text="%s   %d / %d" % [presenter.text_id(55),int(session.vm.get_static("a","ax","I")),length]
	subtitle.text=""
	if is_cinematic:
		var lines: PackedStringArray=[]
		for name in ["a","b"]:
			var line: String=presenter.buffer("e",name)
			if not line.is_empty(): lines.append(line)
		subtitle.text="\n".join(lines)
	if kind=="death": subtitle.text=OEText.localize("Вы пали в бою…")
	subtitle.visible=not subtitle.text.is_empty()
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
	if kind!=presentation_kind or aspect!=scene_aspect or old_hud_visible!=hud.visible or previous_cinematic!=is_cinematic:
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
	if not language_ready: return
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
	held_key=raw if raw in [49,50,51,52,54,56] and presentation_kind!="dialogue" else 0
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
