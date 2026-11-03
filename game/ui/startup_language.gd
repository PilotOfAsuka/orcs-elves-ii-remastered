class_name OEStartupLanguage
extends Control
signal selected(language: String)
var panel: PanelContainer
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=100
	var shade:=ColorRect.new();shade.color=Color("0b130e")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",OESkin.plate(Color("1a241b"),OESkin.BRONZE,22));add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",16);panel.add_child(box)
	for caption in ["ORCS & ELVES II","Язык / Language"]:
		var label:=Label.new();label.text=caption;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",20 if caption.begins_with("ORCS") else 17)
		label.add_theme_color_override("font_color",OESkin.GOLD);box.add_child(label)
	for item in [["ru","Русский"],["en","English"]]:
		var button:=Button.new();button.text=item[1];button.custom_minimum_size.y=52
		button.toggle_mode=true;button.set_pressed_no_signal(OEText.language==item[0])
		button.pressed.connect(func(): selected.emit(item[0]))
		box.add_child(button)
	var note:=Label.new();note.text="Выберите язык\nChoose your language";note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size",13);note.add_theme_color_override("font_color",OESkin.MUTED);box.add_child(note)
	resized.connect(arrange);arrange()
func arrange() -> void:
	if panel==null: return
	panel.size=Vector2(minf(size.x-24,370),310)
	panel.position=(size-panel.size)/2
