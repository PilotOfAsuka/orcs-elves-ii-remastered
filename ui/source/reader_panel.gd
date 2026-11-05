class_name OEReaderPanel
extends PanelContainer

signal choice_requested(index: int)
signal continue_requested
signal key_requested(key: int)
const PORTRAITS=preload("res://generated/dialogue/portraits.png")
var portrait_frame: PanelContainer
var portrait: TextureRect
var crest: TextureRect
var close_button: Button
var title: Label
var body: Label
var scroll: ScrollContainer
var choices: HBoxContainer
var choice_buttons: Array[Button]=[]
var page: int=-1
var primary: Button
var margin: MarginContainer
var current_face: int=-2

func _ready() -> void:
	add_theme_stylebox_override("panel",OESkin.plate(Color("192018"),OESkin.BRONZE,0))
	margin=MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	crest=TextureRect.new()
	crest.texture=OESkin.icon("book");crest.custom_minimum_size=Vector2(28,28)
	crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.modulate=OESkin.GOLD
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	margin.add_child(box)
	var header:=HBoxContainer.new()
	box.add_child(header)
	portrait_frame=PanelContainer.new();portrait_frame.add_theme_stylebox_override("panel",OESkin.plate(Color("101713"),OESkin.GOLD,5));portrait_frame.custom_minimum_size=Vector2(64,64);header.add_child(portrait_frame);portrait_frame.hide()
	portrait=TextureRect.new();portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait_frame.add_child(portrait)
	header.add_child(crest)
	title=Label.new()
	title.add_theme_font_size_override("font_size",17)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("dfc48b"))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button=Button.new()
	close_button.custom_minimum_size=Vector2(32,32)
	close_button.focus_mode=Control.FOCUS_NONE
	OESkin.decorate(close_button,"close","Закрыть сообщение")
	close_button.add_theme_constant_override("icon_max_width",16)
	close_button.pressed.connect(func(): key_requested.emit(-7))
	header.add_child(close_button)
	scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	body=Label.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",18)
	body.add_theme_constant_override("line_spacing",5)
	scroll.add_child(body)
	choices=HBoxContainer.new()
	choices.add_theme_constant_override("separation",10)
	box.add_child(choices)
	for index in 2:
		var button:=Button.new()
		button.custom_minimum_size.y=44
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.focus_mode=Control.FOCUS_NONE
		button.pressed.connect(func(): choice_requested.emit(index))
		choices.add_child(button)
		choice_buttons.append(button)
	primary=Button.new()
	primary.custom_minimum_size.y=40
	primary.focus_mode=Control.FOCUS_NONE
	primary.pressed.connect(func(): continue_requested.emit())
	box.add_child(primary)

func show_state(data: Dictionary) -> void:
	visible=not data.is_empty()
	if not visible: return
	title.text=(OEText.localize("ЛЕТОПИСЬ")+"   ·   %d / %d") % [int(data.page)+1,int(data.pages)] if data.kind=="story" else str(data.get("title","СОБЫТИЯ"))
	if data.kind=="loading": title.text="В ПУТИ"
	if data.kind=="credits": title.text="СОЗДАТЕЛИ"
	var speaker: String=str(data.get("speaker",""))
	if not speaker.is_empty():title.text=speaker
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.text=OEText.localize(title.text)
	var face: int=int(data.get("portrait",-1))
	portrait_frame.visible=face>=0 and face<266;crest.visible=not portrait_frame.visible
	if portrait_frame.visible and face!=current_face:
		current_face=face
		var texture:=AtlasTexture.new();texture.atlas=PORTRAITS;texture.region=Rect2((face%16)*48,(face/16)*48,48,48);portrait.texture=texture
	close_button.tooltip_text=OEText.localize("Закрыть сообщение")
	close_button.visible=data.kind=="dialogue" and not str(data.get("right","")).is_empty()
	if body.text!=str(data.text): body.text=str(data.text);scroll.scroll_vertical=0
	var next_page: int=int(data.get("page",-1))
	if next_page!=page: scroll.scroll_vertical=0;page=next_page
	choices.visible=data.get("choice",false)
	primary.visible=data.kind in ["dialogue","credits"] and not choices.visible
	primary.text=OEText.localize(str(data.get("primary","Продолжить")))
	if choices.visible:
		for index in 2:
			choice_buttons[index].text=str(data.choices[index]) if data.choices.size()>index else str(index+1)
			choice_buttons[index].modulate=Color("efd6a2") if int(data.selected_choice)==index else Color.WHITE
