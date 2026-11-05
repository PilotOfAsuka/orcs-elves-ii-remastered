class_name OELockpickPanel
extends PanelContainer
## Original padlock art and original puzzle progress; never exposes the code.
signal key_requested(raw: int)
const IDLE=preload("res://generated/lock/idle.png")
const READY=preload("res://generated/lock/ready.png")
var title: Label
var instructions: Label
var progress: HBoxContainer
var mechanism: PanelContainer
var padlock: TextureRect
var cancel: Button
var buttons: Array[Button]=[]
var last_attempts: int=-1
var last_completed: int=0
var reaction: Tween

func _ready() -> void:
	add_theme_stylebox_override("panel",OESkin.plate(Color("182119"),OESkin.GOLD,12))
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8);scroll.add_child(box)
	title=Label.new();title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.text=OEText.localize("ВЗЛОМ ЗАМКА")
	title.add_theme_color_override("font_color",OESkin.GOLD);title.add_theme_font_size_override("font_size",18);box.add_child(title)
	var mount:=CenterContainer.new();box.add_child(mount)
	mechanism=PanelContainer.new();mechanism.custom_minimum_size=Vector2(112,112)
	mechanism.add_theme_stylebox_override("panel",OESkin.plate(Color("0c140f"),OESkin.BRONZE,8));mount.add_child(mechanism)
	padlock=TextureRect.new();padlock.custom_minimum_size=Vector2(96,96);padlock.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	padlock.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;padlock.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;mechanism.add_child(padlock)
	progress=HBoxContainer.new();progress.alignment=BoxContainer.ALIGNMENT_CENTER;progress.add_theme_constant_override("separation",6);box.add_child(progress)
	instructions=Label.new();instructions.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;instructions.add_theme_font_size_override("font_size",13);instructions.add_theme_color_override("font_color",OESkin.MUTED);box.add_child(instructions)
	var center:=CenterContainer.new();center.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(center)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);center.add_child(grid)
	for item in [["",0],["forward",0xe031],["",0],["left",0xe033],["",0],["right",0xe034],["",0],["back",0xe032],["",0]]:
		if int(item[1])==0:
			var empty:=Control.new();empty.custom_minimum_size=Vector2(48,44);empty.mouse_filter=Control.MOUSE_FILTER_IGNORE;grid.add_child(empty)
		else:
			var button:=Button.new();button.custom_minimum_size=Vector2(48,44);button.focus_mode=Control.FOCUS_NONE
			var raw: int=item[1]
			var hints: Dictionary={0xe031:"Вверх",0xe032:"Вниз",0xe033:"Влево",0xe034:"Вправо"}
			OESkin.decorate(button,item[0],hints[raw],"")
			button.pressed.connect(func(): key_requested.emit(raw));grid.add_child(button);buttons.append(button)
	cancel=Button.new();cancel.custom_minimum_size.y=36;cancel.focus_mode=Control.FOCUS_NONE
	cancel.pressed.connect(func(): key_requested.emit(0xe030));box.add_child(cancel)

func show_state(data: Dictionary) -> void:
	var opening:=not visible
	visible=not data.is_empty()
	if not visible:
		last_attempts=-1
		return
	var count:=int(data.attempts)
	var completed:=int(data.completed)
	title.text=OEText.localize("ВЗЛОМ ЗАМКА")
	instructions.text=OEText.localize("Подберите направление. Следите за замком.")
	cancel.text=OEText.localize("Отменить взлом")
	padlock.texture=READY if data.partial else IDLE
	if opening or last_attempts<0 or count<last_attempts:
		if reaction:reaction.kill()
		mechanism.modulate=Color.WHITE
	elif count!=last_attempts:
		if reaction:reaction.kill()
		mechanism.modulate=Color("a2d477") if completed>last_completed else (Color("ffdf8b") if data.partial else Color("dc8970"))
		reaction=create_tween();reaction.tween_property(mechanism,"modulate",Color.WHITE,0.28)
	last_attempts=count;last_completed=completed
	if progress.get_child_count()!=int(data.length):
		for child in progress.get_children():child.free()
		for n in int(data.length):
			var pip:=ColorRect.new();pip.custom_minimum_size=Vector2(24,10);progress.add_child(pip)
	for n in progress.get_child_count():
		progress.get_child(n).custom_minimum_size.x=minf(24,maxf(8,(size.x-36-6*(int(data.length)-1))/maxi(1,int(data.length))))
		progress.get_child(n).color=Color("7eac58") if n<completed else (OESkin.GOLD if n==completed and data.partial else Color("454f3d"))
	cancel.disabled=bool(data.finished)
	for button: Button in buttons:button.disabled=bool(data.finished)
