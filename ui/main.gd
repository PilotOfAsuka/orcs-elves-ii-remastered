extends Control
## Existing UI widgets, now driven exclusively by the BREW C engine.
const SELECT=0xe035
const SOFT1=0xe036
const SOFT2=0xe037
const CLEAR=0xe030
var brew: JavaScriptObject
var state: Dictionary={}
var picture: TextureRect
var story_ru: TextureRect
var travel_title: Label
var texture: ImageTexture
var image_size:=Vector2i.ZERO
var last_image_key: String=""
var hud: OEAdventureHUD
var frame: Panel
var effects: OEStatusEffects
var debug_overlay: Label
var debug_enabled: bool=false
var debug_elapsed: float=0
var debug_frames: int=0
var encounter: OEEncounterHUD
var status: Label
var mode: Button
var nav: HBoxContainer
var movement: GridContainer
var actions: Array[Button]=[]
var shade: ColorRect
var menu: PanelContainer
var menu_box: VBoxContainer
var menu_signature: String=""
var menu_more: bool=false
var backup_notice: Label
var reader: OEReaderPanel
var map_view: OEDungeonMap
var map_tools: HBoxContainer
var lock: OELockpickPanel
var story_next: Button
var story_back: Button
var language_picker: OEStartupLanguage
const LIGHT_DISTANCES: Array[int]=[5,15,20]
var light_distance: int=5
var quality_index: int=0
var remastered: bool=false
var choosing_language: bool=false
const RU_INTRO=[preload("res://localized/ru/intro_0.svg"),preload("res://localized/ru/intro_1.svg"),preload("res://localized/ru/intro_2.svg"),preload("res://localized/ru/intro_3.svg")]
const RU_ENDING=[preload("res://localized/ru/ending_0.svg"),preload("res://localized/ru/ending_1.svg")]
var held_action: int=0
var repeat_in: float=0

func _ready() -> void:
	theme=OESkin.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var atmosphere:=OEAtmosphere.new();add_child(atmosphere);atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame=Panel.new();frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel",OESkin.plate(Color("080e0b"),OESkin.BRONZE,0));add_child(frame)
	picture=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(picture)
	story_ru=TextureRect.new();story_ru.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;story_ru.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;story_ru.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;story_ru.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.add_child(story_ru);story_ru.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);story_ru.hide()
	travel_title=Label.new();travel_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;travel_title.add_theme_font_size_override("font_size",22);travel_title.add_theme_color_override("font_color",OESkin.PAPER);travel_title.add_theme_color_override("font_shadow_color",Color.BLACK);travel_title.add_theme_constant_override("shadow_outline_size",5);travel_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(travel_title);travel_title.hide()
	encounter=OEEncounterHUD.new();add_child(encounter)
	hud=OEAdventureHUD.new();add_child(hud)
	hud.ring_requested.connect(func():
		if brew!=null and int(state.get("state",0)) in [3,5]:held_action=0;brew.inventory();brew.inventoryTab(1))
	nav=HBoxContainer.new();nav.add_theme_constant_override("separation",6);add_child(nav)
	for item in [["menu",5,"Меню","Esc"],["map",7,"Карта","M"],["pack",16,"РЮКЗАК","I"]]:
		var button:=make_nav_button(str(item[0]),str(item[2]))
		nav.add_child(button)
		var action: int=item[1];button.pressed.connect(func(): send_action(action));actions.append(button)
	mode=make_nav_button("classic","Classic / Remastered");mode.custom_minimum_size=Vector2(124,30);mode.add_theme_font_size_override("font_size",12);mode.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT;mode.toggle_mode=true;mode.pressed.connect(toggle_mode);nav.add_child(mode)
	update_mode_button()
	movement=GridContainer.new();movement.columns=3;movement.add_theme_constant_override("h_separation",8);movement.add_theme_constant_override("v_separation",6);add_child(movement)
	for item in [["strafe_left",9,"Шаг влево","Z"],["forward",1,"Вперёд","W"],["strafe_right",10,"Шаг вправо","C"],["left",3,"Повернуть влево","A"],["attack",6,"Действие / удар","Enter"],["right",4,"Повернуть вправо","D"],["weapon",12,"Следующее оружие","E"],["back",2,"Назад","S"],["wait",14,"Пропустить ход","Space"]]:
		var button:=make_button(str(item[0]),str(item[2]),str(item[3]));button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.size_flags_vertical=Control.SIZE_EXPAND_FILL;button.add_theme_constant_override("icon_max_width",34);movement.add_child(button);actions.append(button)
		var action: int=item[1]
		button.button_down.connect(func(): held_action=action;repeat_in=0.3;send_action(action))
		button.button_up.connect(func(): held_action=0)
	status=Label.new();status.text="";status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_color_override("font_color",OESkin.MUTED);status.add_theme_font_size_override("font_size",12);add_child(status)
	map_view=OEDungeonMap.new();add_child(map_view);map_view.hide()
	map_tools=HBoxContainer.new();map_tools.add_theme_constant_override("separation",8);add_child(map_tools);map_tools.hide()
	for item in [["−",-1],["+",1],["↺",0]]:
		var button:=Button.new();button.text=item[0];button.custom_minimum_size=Vector2(48,34);button.focus_mode=Control.FOCUS_NONE;map_tools.add_child(button)
		if int(item[1])==0: OESkin.decorate(button,"map",OEText.localize("Сбросить вид карты"));button.add_theme_constant_override("icon_max_width",20)
		var direction: int=item[1];button.pressed.connect(func():
			if direction==0: map_view.reset_view()
			else: map_view.zoom_by(1.25 if direction>0 else 0.8))
	story_back=Button.new();story_back.text="‹";story_back.pressed.connect(func(): brew.key(SOFT1));add_child(story_back);story_back.hide()
	story_next=Button.new();story_next.text="Продолжить ›";story_next.pressed.connect(func(): brew.key(SOFT2));add_child(story_next);story_next.hide()
	shade=ColorRect.new();shade.color=Color(0.02,0.04,0.025,0.82);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade);shade.hide()
	menu=PanelContainer.new();menu.add_theme_stylebox_override("panel",OESkin.plate(Color("161e19"),OESkin.BRONZE,12));add_child(menu);menu.hide()
	var menu_scroll:=ScrollContainer.new();menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;menu.add_child(menu_scroll)
	menu_box=VBoxContainer.new();menu_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;menu_box.add_theme_constant_override("separation",7);menu_scroll.add_child(menu_box)
	reader=OEReaderPanel.new();add_child(reader);reader.hide()
	reader.continue_requested.connect(func():
		if int(state.get("state",0))==14:brew.key(CLEAR)
		else:brew.continueText())
	reader.choice_requested.connect(func(index: int): brew.choice(index))
	reader.key_requested.connect(func(_key: int): brew.key(SOFT1))
	effects=OEStatusEffects.new();add_child(effects);effects.hide()
	move_child(effects,shade.get_index())
	lock=OELockpickPanel.new();add_child(lock);lock.hide()
	lock.key_requested.connect(func(key: int): brew.key(key))
	debug_overlay=Label.new();debug_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	debug_overlay.add_theme_font_size_override("font_size",12)
	debug_overlay.add_theme_color_override("font_color",Color("cce5c6"))
	debug_overlay.add_theme_stylebox_override("normal",OESkin.plate(Color(0.01,0.025,0.015,0.85),Color("53664d"),5))
	add_child(debug_overlay);debug_overlay.hide()
	resized.connect(arrange);arrange()
	if OS.has_feature("web"):
		brew=JavaScriptBridge.get_interface("Brew")
		quality_index=int(brew.savedQuality());light_distance=int(brew.savedLightDistance())
		debug_enabled=bool(brew.savedDebug())
		remastered=str(brew.savedGraphics())=="remastered";update_mode_button();arrange()
		var saved: String=str(brew.savedLanguage())
		if saved in ["ru","en"]: OEText.choose(saved);update_mode_button()
		else: show_language()
	else: status.text="Откройте браузерную сборку BREW"

func make_button(icon: String, caption: String, key: String) -> Button:
	var button:=Button.new();button.custom_minimum_size=Vector2(44,40);button.focus_mode=Control.FOCUS_NONE;button.mouse_filter=Control.MOUSE_FILTER_IGNORE;OESkin.decorate(button,icon,caption,key);return button

func make_nav_button(icon: String, hint: String) -> Button:
	var button:=make_button(icon,hint,"")
	button.custom_minimum_size=Vector2(32,30);button.add_theme_constant_override("icon_max_width",19)
	for skin_state in ["normal","hover","pressed","disabled","focus"]:
		var fill:=Color("51422c") if skin_state=="pressed" else (Color("233025") if skin_state=="hover" else Color("141e18"))
		button.add_theme_stylebox_override(skin_state,OESkin.plate(fill,OESkin.GOLD if skin_state in ["hover","pressed"] else OESkin.BRONZE,4))
	return button

func update_mode_button() -> void:
	mode.text=OEText.localize("Remastered" if remastered else "Classic")
	mode.icon=OESkin.icon("lighting" if remastered else "classic")
	mode.button_pressed=remastered
	mode.tooltip_text=("Графика: " if OEText.language=="ru" else "Graphics: ")+("Remastered" if remastered else "Classic")+" · F2"
	mode.accessibility_name=mode.tooltip_text

func arrange() -> void:
	if hud==null: return
	var width: float=minf(size.x-16,640 if remastered else 480)
	var left: float=(size.x-width)/2
	nav.position=Vector2(left,8);nav.size=Vector2(238,30)
	var world_h: float=minf(width*164.0/176.0,maxf(120,size.y-272))
	picture.position=Vector2(left,46);picture.size=Vector2(width,world_h)
	hud.position=Vector2(left,52+world_h);hud.size=Vector2(width,72)
	movement.position=Vector2(left,132+world_h);movement.size=Vector2(width,maxf(132,size.y-movement.position.y-8))
	if size.x>=850:
		var main_width: float=minf(minf(800 if remastered else 510,size.x-290),maxf(120,size.y-136)*176.0/164.0)
		left=(size.x-main_width-240-20)/2
		world_h=minf(main_width*164.0/176.0,size.y-136)
		picture.position=Vector2(left,46);picture.size=Vector2(main_width,world_h)
		hud.position=Vector2(left,52+world_h);hud.size=Vector2(main_width,72)
		nav.position=Vector2(left,8)
		movement.position=Vector2(left+main_width+20,46);movement.size=Vector2(240,180)
	frame.position=picture.position-Vector2(2,2);frame.size=picture.size+Vector2(4,4)
	debug_overlay.position=picture.position+Vector2(8,picture.size.y-54);debug_overlay.size=Vector2(minf(300,picture.size.x-16),46)
	encounter.position=picture.position+Vector2(10,10);encounter.size=Vector2(picture.size.x-20,76)
	arrange_effects()
	travel_title.position=picture.position+Vector2(8,8);travel_title.size=Vector2(picture.size.x-16,32)
	status.position=picture.position+Vector2(12,picture.size.y/2-12);status.size=Vector2(picture.size.x-24,32)
	var popup_width: float=minf(size.x-24,580)
	var menu_id: int=int(state.get("menu_id",0))
	var menu_height: float=minf(size.y-72,maxf(180,menu_box.get_combined_minimum_size().y+24)) if menu_id in [1,3,100,309,310,311,312,313] else size.y-72
	menu.position=Vector2((size.x-popup_width)/2,maxf(40,(size.y-menu_height)/2));menu.size=Vector2(popup_width,menu_height)
	reader.position=Vector2((size.x-popup_width)/2,maxf(40,(size.y-400)/2));reader.size=Vector2(popup_width,minf(size.y-90,400))
	lock.position=Vector2((size.x-popup_width)/2,maxf(40,(size.y-440)/2));lock.size=Vector2(popup_width,minf(size.y-85,440))
	map_view.position=picture.position;map_view.size=picture.size
	map_tools.position=picture.position+Vector2(8,8)
	story_back.position=picture.position+Vector2(0,picture.size.y-36);story_back.size=Vector2(48,32)
	story_next.position=picture.position+Vector2(picture.size.x-170,picture.size.y-36);story_next.size=Vector2(170,32)

func _process(delta: float) -> void:
	if brew==null: return
	if not bool(brew.ready):
		status.text=str(brew.error) if not str(brew.error).is_empty() else OEText.localize("Подготовка игры…");return
	brew.paused=choosing_language
	brew.advance(delta*1000)
	var native_state: Dictionary=JSON.parse_string(str(brew.json()))
	if int(native_state.get("state",0))==2 and int(native_state.get("menu_type",0))==6:native_state.items=OEText.merge_menu_text(native_state.items)
	state=OEText.translate_state(native_state)
	if state.is_empty(): return
	var game_state: int=int(state.state)
	picture.visible=(game_state!=2 or int(state.world_width)>0) and game_state!=14
	frame.visible=picture.visible
	var modal: bool=game_state in [2,7,12,17,19] or choosing_language
	for button in actions:
		button.disabled=modal or game_state not in [3,4,5,20,21]
		button.mouse_filter=Control.MOUSE_FILTER_IGNORE if button.disabled else Control.MOUSE_FILTER_STOP
	mode.mouse_filter=Control.MOUSE_FILTER_IGNORE if modal else Control.MOUSE_FILTER_STOP
	hud.ring_button.disabled=modal or game_state not in [3,5]
	hud.ring_button.mouse_filter=Control.MOUSE_FILTER_IGNORE if hud.ring_button.disabled else Control.MOUSE_FILTER_STOP
	if modal: held_action=0
	elif held_action!=0:
		repeat_in-=delta
		if repeat_in<=0: send_action(held_action);repeat_in=0.12
	shade.visible=game_state in [2,7,14,19]
	menu.visible=game_state==2
	if menu.visible:
		update_menu()
		arrange()
	var dialogue_body: String=str(state.dialogue)
	if game_state==7 and int(state.get("dialog_style",0)) in [2,9]:
		var header_end:=dialogue_body.find("\n")
		if header_end>=0:dialogue_body=dialogue_body.substr(header_end+1).strip_edges()
	reader.show_state({"kind":"dialogue","text":dialogue_body,"title":str(state.get("dialog_title","")) if not str(state.get("dialog_title","")).is_empty() else "СОБЫТИЯ","speaker":str(state.get("dialog_speaker","")),"portrait":int(state.get("dialog_portrait",-1)),"page":int(state.dialog_top),"pages":1,"choice":(int(state.dialog_flags)&4)!=0,"choices":[OEText.localize("Да"),OEText.localize("Нет")],"selected_choice":int(state.dialog_choice),"right":"" if (int(state.dialog_flags)&1)!=0 else str(state.right),"primary":"Продолжить"} if game_state==7 else {})
	if game_state==14:
		reader.show_state({"kind":"credits","text":OEText.entry("2:0"),"title":"СОЗДАТЕЛИ","page":0,"pages":1})
	if game_state==12:
		reader.show_state({"kind":"dialogue","text":OEText.localize("Вы пали в бою…"),"title":"ПУТЬ ОКОНЧЕН","page":0,"pages":1,"choice":false,"right":"","primary":"Продолжить"})
		shade.show()
	encounter.show_state(state.hud,bool(state.get("cinematic_active",false)))
	effects.show_state(state.hud.get("effects",[]))
	effects.visible=not state.hud.get("effects",[]).is_empty() and game_state in [3,4,7,19,20,21]
	arrange_effects()
	if game_state in [0,2,5,6,8,11,13,14,15]: encounter.hide()
	lock.show_state({"length":int(state.lock.length),"completed":int(state.lock.slot),"partial":int(state.lock.hits)==1,"attempts":int(state.lock.attempts),"last_direction":int(state.lock.last_direction),"finished":int(state.lock.done)!=0} if game_state==19 else {})
	map_view.show_state(state.get("map",{}));map_tools.visible=game_state==5
	story_back.visible=game_state in [8,13] and int(state.story_page)>0;story_next.visible=game_state in [8,11,13,17]
	story_next.text=OEText.localize("Продолжить")+" ›"
	hud.show_state(state.hud if int(state.map_id)>0 and game_state not in [8,11,13,14] else {})
	var kind: String="world" if int(state.world_width)>0 else "frame"
	var revision: int=int(state.world_revision) if kind=="world" else int(state.ticks)
	var dimensions:=Vector2i(int(state.world_width),int(state.world_height)) if kind=="world" else Vector2i(176,220)
	story_ru.visible=game_state in [8,13] and OEText.language=="ru"
	if story_ru.visible:
		var pages: Array=RU_INTRO if game_state==8 else RU_ENDING
		story_ru.texture=pages[clampi(int(state.story_page),0,pages.size()-1)]
	if game_state in [8,13]: kind="story_base" if story_ru.visible else "story";revision=int(state.story_page);dimensions=Vector2i(176,176)
	travel_title.visible=game_state==11;travel_title.text=str(state.travel_name)
	if game_state==11:kind="travel";revision=int(state.ticks);dimensions=Vector2i(176,203)
	if remastered and kind=="world": dimensions*=1<<quality_index
	var image_key: String=kind+":"+str(revision)+":"+str(remastered)+":"+str(quality_index)+":"+OEText.language
	if remastered and kind=="world" and game_state!=2: image_key+=":"+str(state.ticks)
	if image_key!=last_image_key:
		var raw: Variant=brew.image(("lit" if remastered else "classic") if kind=="world" else kind)
		var pixels: PackedByteArray=raw if raw is PackedByteArray else JavaScriptBridge.js_buffer_to_packed_byte_array(raw)
		if pixels.size()!=dimensions.x*dimensions.y*4:
			push_error("BREW image transport: type %s, bytes %d" % [type_string(typeof(raw)),pixels.size()]);return
		var next:=Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8,pixels)
		if texture==null or dimensions!=image_size:
			texture=ImageTexture.create_from_image(next);picture.texture=texture;image_size=dimensions
		else: texture.update(next)
		last_image_key=image_key
	debug_overlay.visible=debug_enabled and game_state in [3,4,5,17]
	debug_elapsed+=delta;debug_frames+=1
	if debug_elapsed>=0.5:
		var fps: float=debug_frames/maxf(0.001,debug_elapsed)
		debug_frames=0;debug_elapsed=0
		if debug_overlay.visible:
			var timing: String="Шаг %.1f мс · Ремастер %.1f мс" if OEText.language=="ru" else "Core %.1f ms · Remaster %.1f ms"
			debug_overlay.text=("FPS %.0f · %d×%d\n" % [fps,image_size.x,image_size.y])+(timing % [float(brew.tickMs),float(brew.lightMs) if remastered else 0.0])
	if is_instance_valid(backup_notice): backup_notice.text=OEText.localize(str(brew.backupStatus))
	status.text=""
	if not str(brew.saveError).is_empty(): status.text=OEText.localize("Не удалось сохранить")
	status.visible=not status.text.is_empty()

func arrange_effects() -> void:
	if effects==null:return
	effects.position=picture.position+Vector2(8,10)
	effects.size=Vector2(58,maxf(16,picture.size.y-20))
	encounter.position=picture.position+Vector2(10+(66 if effects.visible else 0),10)
	encounter.size.x=maxf(40,picture.size.x-20-(66 if effects.visible else 0))

func update_menu() -> void:
	var signature: String=JSON.stringify([state.menu_id,state.selected,state.items,state.get("notes",[]),state.get("details",{}),OEText.language,quality_index,debug_enabled,menu_more])
	if signature==menu_signature: return
	menu_signature=signature
	for child in menu_box.get_children(): child.free()
	if OEMenuDesign.build(self,menu_box,state):return
	var title:=Label.new();title.text=OEText.localize("ORCS & ELVES II");title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_color_override("font_color",OESkin.GOLD);title.add_theme_font_size_override("font_size",21);menu_box.add_child(title)
	var help_pages: Dictionary={5:4,6:5,7:6,8:8,9:1,10:2,11:3,12:7,0x68:1,0x69:2,0x6a:3,0x6b:7,0x6d:4,0x6e:5,0x6f:6}
	if int(state.menu_id) in [0x70,400]:
		var back:=Button.new();back.text=OEText.localize("Назад");back.custom_minimum_size.y=42;back.pressed.connect(func():brew.key(SOFT1));menu_box.add_child(back)
		if int(state.menu_id)==400:
			for field in ["name","text","stats"]:
				var content:=Label.new();content.text=str(state.details.get(field,""));content.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_theme_font_size_override("font_size",18 if field=="name" else 17);menu_box.add_child(content)
		else:
			var heading:=Label.new();heading.text=OEText.localize("Quest Log");heading.add_theme_color_override("font_color",OESkin.GOLD);menu_box.add_child(heading)
			for note: Dictionary in state.get("notes",[]):
				var content:=Label.new();content.text=("✕ " if note.failed else "✓ " if note.done else "• ")+OEText.entry(str(note.id));content.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_theme_font_size_override("font_size",17);content.add_theme_color_override("font_color",Color("bc7772") if note.failed else Color("8fbc91") if note.done else OESkin.PAPER);menu_box.add_child(content)
		return
	if help_pages.has(int(state.menu_id)):
		var back:=Button.new();back.text=OEText.localize("Назад");back.custom_minimum_size.y=42;back.pressed.connect(func():brew.key(SOFT1));menu_box.add_child(back)
		var content:=Label.new();content.text=OEText.entry("2:"+str(help_pages[int(state.menu_id)]));content.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_theme_font_size_override("font_size",17);menu_box.add_child(content)
		return
	for item: Dictionary in state.items:
		var text: String=OEText.localize(str(item.text)).strip_edges()
		if not str(item.value).is_empty(): text+="   "+OEText.localize(str(item.value))
		if text.is_empty() or str(item.text).strip_edges() in ["More Games","Другие игры","Message a Friend","Отправить другу"]: continue
		if (int(item.flags)&1)!=0:
			var label:=Label.new();label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_color_override("font_color",OESkin.GOLD);menu_box.add_child(label)
		else:
			var button:=Button.new();button.text=text;button.custom_minimum_size.y=42;button.focus_mode=Control.FOCUS_NONE;button.disabled=(int(item.flags)&4)!=0;button.tooltip_text=OEText.localize(str(item.help));menu_box.add_child(button)
			if int(item.index)==int(state.selected): button.add_theme_color_override("font_color",OESkin.GOLD)
			var id: int=state.menu_id;var index: int=item.index;button.pressed.connect(func(): brew.menu(id,index))
	if int(state.menu_id) in [0x11,0x66]:
		var debug_check:=CheckBox.new();debug_check.text=OEText.localize("Отладка");debug_check.button_pressed=debug_enabled;debug_check.custom_minimum_size.y=42;debug_check.focus_mode=Control.FOCUS_NONE;menu_box.add_child(debug_check)
		debug_check.toggled.connect(func(enabled: bool): debug_enabled=enabled;brew.debug(enabled);menu_signature="")
		var quality_label:=Label.new();quality_label.text="Качество ремастера" if OEText.language=="ru" else "Remastered quality";menu_box.add_child(quality_label)
		var quality:=OptionButton.new();quality.custom_minimum_size.y=42;quality.focus_mode=Control.FOCUS_NONE
		for caption in ["Low · 176×164","Medium · 352×328","High · 704×656"]: quality.add_item(caption)
		quality.select(quality_index);menu_box.add_child(quality)
		quality.item_selected.connect(func(index: int): quality_index=index;brew.quality(index);last_image_key="";menu_signature="")
		var distance_label:=Label.new();distance_label.text=OEText.localize("Дальность обработки света");menu_box.add_child(distance_label)
		var distance_row:=HBoxContainer.new();distance_row.add_theme_constant_override("separation",6);menu_box.add_child(distance_row)
		var distance_group:=ButtonGroup.new()
		for index in range(LIGHT_DISTANCES.size()):
			var steps: int=LIGHT_DISTANCES[index]
			var distance:=Button.new();distance.text=["Low","Medium","High"][index];distance.toggle_mode=true;distance.button_group=distance_group;distance.button_pressed=light_distance==steps
			distance.custom_minimum_size.y=42;distance.size_flags_horizontal=Control.SIZE_EXPAND_FILL;distance.focus_mode=Control.FOCUS_NONE;distance_row.add_child(distance)
			distance.pressed.connect(func():light_distance=steps;brew.lightDistance(steps);last_image_key="")
		for item in [["Скачать сохранение",0],["Загрузить копию сохранения",1]]:
			var backup:=Button.new();backup.text=OEText.localize(item[0]);backup.custom_minimum_size.y=42;backup.focus_mode=Control.FOCUS_NONE;menu_box.add_child(backup)
			var action: int=item[1];backup.pressed.connect(func():
				if action==0:brew.exportSave()
				else:brew.importSave())
		backup_notice=Label.new();backup_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;backup_notice.add_theme_color_override("font_color",OESkin.GOLD);menu_box.add_child(backup_notice)
		for item in [["Язык",0],["Полный экран",1]]:
			var button:=Button.new();button.text=OEText.localize(item[0]);button.custom_minimum_size.y=40;button.focus_mode=Control.FOCUS_NONE;menu_box.add_child(button)
			var action: int=item[1]
			button.pressed.connect(func():
				if action==0: show_language()
				else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED))

func send_action(action: int) -> void:
	if brew==null or choosing_language or int(state.get("state",0)) in [2,7,19]: return
	if action==16: brew.inventory()
	else: brew.action(action)

func toggle_mode() -> void:
	remastered=not remastered;update_mode_button()
	if brew!=null: brew.graphics("remastered" if remastered else "classic")
	# Original BREW textures remain crisp in both lighting modes.
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	arrange()

func show_language() -> void:
	if choosing_language: return
	choosing_language=true;held_action=0
	language_picker=OEStartupLanguage.new();add_child(language_picker)
	language_picker.selected.connect(func(value: String):
		OEText.choose(value);OESkin.refresh_locale(self);update_mode_button()
		if brew!=null: brew.language(value)
		choosing_language=false;language_picker.queue_free();menu_signature="")

func _unhandled_key_input(event: InputEvent) -> void:
	if brew==null or choosing_language or not event is InputEventKey: return
	var key:=event as InputEventKey
	if not key.pressed: held_action=0;return
	if key.echo: return
	if key.keycode==KEY_F2: toggle_mode();get_viewport().set_input_as_handled();return
	if key.keycode==KEY_F5: brew.save();get_viewport().set_input_as_handled();return
	if key.keycode==KEY_F9: brew.load();get_viewport().set_input_as_handled();return
	var game_state: int=int(state.get("state",0))
	if game_state==7:
		if key.keycode in [KEY_ENTER,KEY_SPACE]: brew.continueText()
		elif key.keycode==KEY_ESCAPE: brew.key(SOFT1)
		elif (int(state.get("dialog_flags",0))&4)!=0 and key.keycode in [KEY_LEFT,KEY_RIGHT]: brew.key(0xe033 if key.keycode==KEY_LEFT else 0xe034)
	elif game_state==2:
		var keys: Dictionary={KEY_UP:0xe031,KEY_DOWN:0xe032,KEY_LEFT:0xe033,KEY_RIGHT:0xe034,KEY_ENTER:SELECT,KEY_ESCAPE:SOFT1}
		if keys.has(key.keycode): brew.key(keys[key.keycode])
	elif game_state in [8,11,13]: brew.key(SOFT1 if key.keycode in [KEY_LEFT,KEY_ESCAPE] else SOFT2)
	elif game_state==14 and key.keycode in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE]:brew.key(CLEAR)
	elif game_state==19:
		var keys: Dictionary={KEY_W:0xe031,KEY_UP:0xe031,KEY_S:0xe032,KEY_DOWN:0xe032,KEY_A:0xe033,KEY_LEFT:0xe033,KEY_D:0xe034,KEY_RIGHT:0xe034,KEY_ESCAPE:CLEAR}
		if keys.has(key.keycode): brew.key(keys[key.keycode])
	else:
		var keys: Dictionary={KEY_W:1,KEY_UP:1,KEY_S:2,KEY_DOWN:2,KEY_A:3,KEY_LEFT:3,KEY_D:4,KEY_RIGHT:4,KEY_Z:9,KEY_C:10,KEY_Q:11,KEY_E:12,KEY_ENTER:6,KEY_SPACE:14,KEY_M:7,KEY_ESCAPE:5,KEY_I:16}
		if keys.has(key.keycode):
			var action: int=keys[key.keycode];send_action(action)
			if action in [1,2,3,4,9,10]: held_action=action;repeat_in=0.3
	get_viewport().set_input_as_handled()
