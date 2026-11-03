class_name OEReaderPanel
extends PanelContainer

signal choice_requested(index: int)
signal continue_requested
var title: Label
var body: Label
var scroll: ScrollContainer
var choices: HBoxContainer
var choice_buttons: Array[Button]=[]
var page: int=-1
var primary: Button

func _ready() -> void:
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	margin.add_child(box)
	title=Label.new()
	title.add_theme_font_size_override("font_size",19)
	title.add_theme_color_override("font_color",Color("dfc48b"))
	box.add_child(title)
	scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	body=Label.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size",20)
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
	title.text="История · %d / %d" % [int(data.page)+1,int(data.pages)] if data.kind=="story" else ("Загрузка" if data.kind=="loading" else "Сообщение")
	if body.text!=str(data.text): body.text=str(data.text)
	var next_page: int=int(data.get("page",-1))
	if next_page!=page: scroll.scroll_vertical=0;page=next_page
	choices.visible=data.get("choice",false)
	primary.visible=data.kind=="dialogue" and not choices.visible
	primary.text=str(data.get("primary","Продолжить"))
	if choices.visible:
		for index in 2:
			choice_buttons[index].text=str(data.choices[index]) if data.choices.size()>index else str(index+1)
			choice_buttons[index].modulate=Color("efd6a2") if int(data.selected_choice)==index else Color.WHITE
