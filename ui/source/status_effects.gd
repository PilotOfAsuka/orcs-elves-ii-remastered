class_name OEStatusEffects
extends Control
## Compact native modifier icons and turn counters, over the left of the view.
const ICONS=[preload("res://generated/effects/00.png"),preload("res://generated/effects/01.png"),preload("res://generated/effects/02.png"),preload("res://generated/effects/03.png"),preload("res://generated/effects/04.png"),preload("res://generated/effects/05.png"),preload("res://generated/effects/06.png"),preload("res://generated/effects/07.png"),preload("res://generated/effects/08.png"),preload("res://generated/effects/09.png"),preload("res://generated/effects/10.png"),preload("res://generated/effects/11.png")]
const NAMES=["Фамильяр","Уклонение","Очищение","Ускорение","Опьянение","Регенерация","Точность","Сила","Защита","Заморозка","Отравление","Уменьшение"]
var entries: Array=[]
var rows: Array[Dictionary]=[]
var elapsed: float=0
var signature: String=""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(arrange)

func show_state(data: Array) -> void:
	var next_signature: String=JSON.stringify([data,OEText.language])
	if signature==next_signature:return
	signature=next_signature
	entries=data
	visible=not entries.is_empty()
	while rows.size()>entries.size():
		var old: Dictionary=rows.pop_back();old.card.free()
	while rows.size()<entries.size():
		var card:=Panel.new();card.mouse_filter=Control.MOUSE_FILTER_PASS;add_child(card)
		var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(icon)
		var amount:=Label.new();amount.add_theme_font_size_override("font_size",9);amount.mouse_filter=Control.MOUSE_FILTER_IGNORE;amount.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.add_child(amount)
		var turns:=Label.new();turns.add_theme_font_size_override("font_size",11);turns.mouse_filter=Control.MOUSE_FILTER_IGNORE;turns.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;turns.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.add_child(turns)
		rows.append({"card":card,"icon":icon,"amount":amount,"turns":turns})
	for index in entries.size():
		var effect: Dictionary=entries[index];var row: Dictionary=rows[index];var id: int=int(effect.id)
		var negative: bool=int(effect.amount)<0 or id in [9,10,11]
		var tint:=Color("d79b86") if negative else Color("b7c994")
		row.card.add_theme_stylebox_override("panel",OESkin.plate(Color(0.035,0.055,0.04,0.92),Color("855948") if negative else OESkin.BRONZE,2))
		row.icon.texture=ICONS[clampi(id,0,11)]
		row.amount.text=("%+d" % int(effect.amount)) if id not in [0,2,3,9] else ""
		row.amount.modulate=tint;row.turns.text=str(int(effect.turns));row.turns.modulate=OESkin.PAPER
		row.card.tooltip_text=OEText.localize(NAMES[clampi(id,0,11)])+" · "+OEText.localize("Осталось ходов: %d") % int(effect.turns)
		row.card.accessibility_name=row.card.tooltip_text
	arrange()

func arrange() -> void:
	if rows.is_empty():return
	var step: float=minf(23,(size.y+3)/rows.size())
	for index in rows.size():
		var row: Dictionary=rows[index];var height: float=maxf(12,step-3)
		row.card.position=Vector2(0,index*step);row.card.size=Vector2(size.x,height)
		row.amount.position=Vector2(2,0);row.amount.size=Vector2(17,height)
		row.icon.position=Vector2(21,(height-minf(14,height-2))/2);row.icon.size=Vector2(14,minf(14,height-2))
		row.turns.position=Vector2(37,0);row.turns.size=Vector2(size.x-39,height)

func _process(delta: float) -> void:
	if not visible:return
	elapsed+=delta
	for index in rows.size():
		rows[index].icon.modulate.a=0.75+0.25*cos(elapsed*TAU*2) if int(entries[index].turns)<10 else 1.0
