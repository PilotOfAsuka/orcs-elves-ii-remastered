class_name OEMenuDesign
extends RefCounted
## Presentation only: every consequential action goes through the native menu.
const ITEMS=preload("res://generated/menu/items.png")

static func words(text: String) -> String:
	return OEText.localize(text).replace("\u0087","").replace("✓","").replace("\u0080","·").strip_edges()

static func heading(box: VBoxContainer, title: String, subtitle: String="", close_action: Callable=Callable()) -> void:
	var header:=HBoxContainer.new();box.add_child(header)
	var label:=Label.new();label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.text=words(title);label.add_theme_font_size_override("font_size",25);label.add_theme_color_override("font_color",OESkin.GOLD);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;header.add_child(label)
	if close_action.is_valid():
		var close:=button(header,"",close_action,false,"close");close.custom_minimum_size=Vector2(36,36);close.size_flags_horizontal=0;close.tooltip_text=OEText.localize("Вернуться в игру")
	if not subtitle.is_empty():
		var detail:=Label.new();detail.text=words(subtitle);detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_color_override("font_color",OESkin.MUTED);detail.add_theme_font_size_override("font_size",13);box.add_child(detail)
	var rule:=HSeparator.new();box.add_child(rule)

static func button(box: Node, caption: String, action: Callable, primary: bool=false, icon: String="") -> Button:
	var b:=Button.new();b.text=words(caption);b.custom_minimum_size.y=54 if primary else 44;b.focus_mode=Control.FOCUS_NONE;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not icon.is_empty():b.icon=OESkin.icon(icon);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",23);b.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
	if primary:b.add_theme_stylebox_override("normal",OESkin.plate(Color("3a3625"),OESkin.GOLD,10));b.add_theme_color_override("font_color",OESkin.GOLD)
	b.pressed.connect(action);box.add_child(b);return b

static func native_button(owner: Control, box: Node, st: Dictionary, index: int, caption: String="", primary: bool=false, icon: String="") -> void:
	if index<0 or index>=st.items.size():return
	var row: Dictionary=st.items[index]
	if str(row.text).strip_edges().is_empty():return
	var b:=button(box,caption if not caption.is_empty() else str(row.text),func():owner.brew.menu(int(st.menu_id),int(row.index)),primary,icon)
	b.disabled=(int(row.flags)&4)!=0;b.tooltip_text=words(OEText.expand_native_help(str(row.help)))

static func columns(box: VBoxContainer, count: int=2) -> GridContainer:
	var grid:=GridContainer.new();grid.columns=count;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);box.add_child(grid);return grid

static func info(box: Node, text: String) -> void:
	var label:=Label.new();label.text=words(text);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_color_override("font_color",OESkin.MUTED);label.add_theme_font_size_override("font_size",13);box.add_child(label)

static func balance(box: VBoxContainer, st: Dictionary) -> void:
	info(box,OEText.localize("Золото: %d") % int(st.menu_context.gold))

static func item_icon(id: int) -> Texture2D:
	if id<0 or id>=48:return OESkin.icon("gem")
	var texture:=AtlasTexture.new();texture.atlas=ITEMS;texture.region=Rect2((id%16)*24,(id/16)*24,24,24);return texture

static func item_card(owner: Control, box: VBoxContainer, st: Dictionary, row: Dictionary, shop: bool) -> void:
	var line:=HBoxContainer.new();line.add_theme_constant_override("separation",6);box.add_child(line)
	var b:=button(line,"",func():owner.brew.menu(int(st.menu_id),int(row.index)))
	b.custom_minimum_size.y=110 if shop else 76;b.disabled=(int(row.flags)&4)!=0
	var content:=HBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=10;content.offset_right=-10;content.offset_top=8;content.offset_bottom=-8
	var image:=TextureRect.new();image.texture=OESkin.icon("ring") if int(st.menu_id)==502 and int(row.action)==0 else item_icon(int(row.get("icon",127)));image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(38,38);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(image)
	var body:=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(body)
	var name:=Label.new();name.text=words(str(row.text));
	if int(st.menu_id)==502 and int(row.action)==0:name.text=OEText.localize("Кольцо не надето" if str(row.text).strip_edges().begins_with("✓") else "Снять кольцо")
	if str(row.text).strip_edges().begins_with("✓"):b.add_theme_stylebox_override("normal",OESkin.plate(Color("302e21"),OESkin.GOLD,8));name.add_theme_color_override("font_color",OESkin.GOLD)
	name.add_theme_font_size_override("font_size",16);name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(name)
	var value:=Label.new();value.text=(OEText.localize("Цена: %s") % words(str(row.value))) if shop else words(str(row.value)).replace("··","—");value.add_theme_font_size_override("font_size",13);value.add_theme_color_override("font_color",OESkin.GOLD);value.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(value)
	if shop:
		var description:=Label.new();description.text=words(OEText.expand_native_help(str(row.help)));description.add_theme_font_size_override("font_size",11);description.add_theme_color_override("font_color",OESkin.MUTED);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.max_lines_visible=2;description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;description.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(description)
	if str(row.text).strip_edges().begins_with("✓"):
		var check:=TextureRect.new();check.texture=OESkin.icon("check");check.modulate=OESkin.GOLD;check.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;check.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;check.custom_minimum_size=Vector2(18,18);check.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(check)
	b.tooltip_text=words(OEText.expand_native_help(str(row.help)))
	if (int(row.flags)&0x20)!=0:
		var details:=button(line,"i",func():owner.brew.itemDetails(int(st.menu_id),int(row.index)));details.custom_minimum_size=Vector2(34,44);details.size_flags_horizontal=0;details.tooltip_text=OEText.localize("Подробнее")

static func statistics(owner: Control, box: VBoxContainer, st: Dictionary) -> void:
	var completed: bool=int(st.menu_id)==1
	heading(box,"ОБЛАСТЬ ПРОЙДЕНА" if completed else "Персонаж",str(st.menu_context.level_name))
	var grid: GridContainer
	var last_value: Label
	for row: Dictionary in st.items:
		if (int(row.flags)&0x400)!=0:
			if (int(row.flags)&1)!=0 and last_value!=null:
				last_value.text=words(str(row.text));continue
			if grid==null:grid=columns(box)
			var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",OESkin.plate(Color("111c16"),OESkin.BRONZE,10));card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card)
			var body:=VBoxContainer.new();card.add_child(body)
			var label:=Label.new();label.text=words(str(row.text));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",12);label.add_theme_color_override("font_color",OESkin.MUTED);body.add_child(label)
			var value:=Label.new();value.text=words(str(row.value));value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;value.add_theme_font_size_override("font_size",23);value.add_theme_color_override("font_color",OESkin.GOLD);body.add_child(value);last_value=value
		elif (int(row.flags)&1)!=0 and not str(row.text).strip_edges().is_empty():
			if completed:continue
			info(box,str(row.text));grid=null
	if completed:native_button(owner,box,st,st.items.size()-1,"Продолжить",true,"forward")
	else:native_button(owner,box,st,0,"Назад",false,"back")

static func build(owner: Control, box: VBoxContainer, st: Dictionary) -> bool:
	var id: int=int(st.menu_id)
	if id==3:
		heading(box,"ORCS & ELVES II")
		var resume_available: bool=not str(st.items[0].text).strip_edges().is_empty() and (int(st.items[0].flags)&4)==0
		if resume_available:native_button(owner,box,st,0,"Продолжить",true,"forward")
		native_button(owner,box,st,1,"Новая игра",not resume_available,"attack")
		native_button(owner,box,st,2,"Настройки",false,"menu")
		native_button(owner,box,st,3,"Помощь / Об игре",false,"eye")
		return true
	if id==100:
		heading(box,"ПАУЗА",str(st.menu_context.level_name))
		native_button(owner,box,st,0,"Продолжить игру",true,"forward")
		var grid:=columns(box)
		for pair in [[1,"pack"],[6,"eye"],[2,"map"],[5,"map"]]:native_button(owner,grid,st,int(pair[0]),"",false,str(pair[1]))
		var saves:=columns(box);native_button(owner,saves,st,3,"Сохранить",false,"save");native_button(owner,saves,st,4,"Загрузить",false,"load")
		native_button(owner,box,st,8,"Настройки",false,"menu")
		button(box,"Свернуть" if owner.menu_more else "Ещё",func():owner.menu_more=not owner.menu_more;owner.menu_signature="")
		if owner.menu_more:
			for index in [7,9,10,11]:native_button(owner,box,st,index)
		return true
	if id in [1,101]:statistics(owner,box,st);return true
	if id>=500 and id<=504:
		heading(box,"РЮКЗАК","",func():owner.brew.closeInventory());balance(box,st)
		var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",4);box.add_child(tabs)
		var names: Array=["Оружие","Зелья","Кольца","Прочее"]
		# Native category order is weapons, rings, potions, other.
		for pair in [[0,0],[2,1],[1,2],[3,3]]:
			var tab: int=pair[0];var b:=button(tabs,names[int(pair[1])],func():owner.brew.inventoryTab(tab),id==501+tab);b.add_theme_font_size_override("font_size",12);b.custom_minimum_size.y=38
		if id==500:owner.brew.inventoryTab(0)
		for row: Dictionary in st.items:
			if int(row.index)<2 or str(row.text).strip_edges().is_empty():continue
			if (int(row.flags)&1)!=0:info(box,str(row.text))
			else:item_card(owner,box,st,row,false)
		button(box,"Вернуться в игру",func():owner.brew.closeInventory(),false,"back")
		return true
	if id>=303 and id<=308:
		heading(box,"ТОРГОВЛЯ");balance(box,st)
		native_button(owner,box,st,0,"Уйти" if id==307 else "Назад",false,"back")
		if id==307:
			var grid:=columns(box)
			for index in range(2,st.items.size()):native_button(owner,grid,st,index)
		else:
			for row: Dictionary in st.items:
				if int(row.index)==0 or str(row.text).strip_edges().is_empty():continue
				if (int(row.flags)&1)!=0:info(box,str(row.text))
				else:item_card(owner,box,st,row,true)
		return true
	if id==309:
		heading(box,str(st.items[0].text));balance(box,st)
		info(box,str(st.items[2].help))
		var price:=Label.new();price.text=words(str(st.items[1].text))+"  "+words(str(st.items[1].value));price.add_theme_color_override("font_color",OESkin.GOLD);box.add_child(price)
		info(box,"Ваше предложение")
		var offer:=SpinBox.new();offer.min_value=0;offer.max_value=99999;offer.step=1;offer.value=int(str(st.items[2].value).strip_edges());offer.custom_minimum_size.y=48;box.add_child(offer)
		offer.get_line_edit().text_submitted.connect(func(_text: String):offer.apply();owner.brew.tradeOffer(int(offer.value)))
		button(box,"Предложить",func():offer.apply();owner.brew.tradeOffer(int(offer.value)),true,"gem")
		button(box,"Отмена",func():owner.brew.tradeCancel(),false,"back")
		return true
	if id>=310 and id<=313:
		heading(box,"ТОРГОВЛЯ");balance(box,st)
		for row: Dictionary in st.items:
			if (int(row.flags)&1)!=0 and not str(row.text).strip_edges().is_empty():info(box,str(row.text))
		native_button(owner,box,st,st.items.size()-1,"Продолжить",true)
		return true
	return false
