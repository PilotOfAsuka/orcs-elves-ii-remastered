class_name OEDungeonMap
extends Control
## Read-only map of the original discovered cells / visible wall flags.
signal view_changed
var data: Dictionary={}
var zoom: float=1.0
var pan:=Vector2.ZERO
var dragging: bool=false
var touches: Dictionary={}
var level_id: int=0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_DRAG
	resized.connect(queue_redraw)

func show_state(value: Dictionary) -> void:
	visible=not value.is_empty()
	if visible:
		if level_id!=int(value.get("level_id",0)):
			level_id=int(value.get("level_id",0));reset_view()
		data=value;queue_redraw()

func _draw() -> void:
	if data.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("111912"))
	var cell: float=minf((size.x-24)/32,(size.y-24)/32)*zoom
	var origin: Vector2=(size-Vector2.ONE*cell*32)/2+pan
	for axis in range(33):
		draw_line(origin+Vector2(axis*cell,0),origin+Vector2(axis*cell,32*cell),Color("293226"),1,true)
		draw_line(origin+Vector2(0,axis*cell),origin+Vector2(32*cell,axis*cell),Color("293226"),1,true)
	for index in mini(1024,data.tiles.size()):
		var flags: int=int(data.tiles[index])
		var rect:=Rect2(origin+Vector2(index%32,index/32)*cell,Vector2.ONE*cell)
		if data.hidden: continue
		if (flags&4)!=0: draw_rect(rect,Color("5d7850"))
		elif (flags&0x20)!=0:
			if (flags&8)!=0: draw_rect(rect,Color("87503b"))
			elif (flags&1)==0: draw_rect(rect.grow(-0.6),Color("a49c70"))
	if not data.hidden:
		for wall: Array in data.walls:
			var color: Color=Color("e0c58a")
			if wall.size()>4: color={277:Color("b95446"),278:Color("6699ae"),279:Color("80a25c")}.get(int(wall[4]),Color("878776"))
			draw_line(origin+Vector2(wall[0],wall[1])*cell,origin+Vector2(wall[2],wall[3])*cell,color,maxf(1,cell*0.1),true)
		for marker: Array in data.get("markers",[]):
			var point: Vector2=origin+Vector2(marker[0],marker[1])*cell
			draw_circle(point,maxf(1.5,cell*0.2),Color("749856") if marker[2]=="door" else Color("d0c6a1"))
	var center: Vector2=origin+Vector2(data.x,data.y)*cell
	var forward:=Vector2.RIGHT.rotated(-int(data.angle)*TAU/256)
	var side:=forward.orthogonal()
	var marker: float=maxf(5,cell*0.7)
	draw_circle(center,marker+3,Color(0,0,0,0.6))
	draw_colored_polygon(PackedVector2Array([center+forward*marker,center-forward*marker*0.65+side*marker*0.65,center-forward*marker*0.3,center-forward*marker*0.65-side*marker*0.65]),OESkin.GOLD)

func zoom_to(value: float, anchor: Vector2) -> void:
	var next: float=clampf(value,0.75,6.0)
	pan=anchor-size/2-(anchor-size/2-pan)*(next/zoom)
	zoom=next;limit_pan();queue_redraw();view_changed.emit()

func zoom_by(factor: float) -> void: zoom_to(zoom*factor,size/2)

func reset_view() -> void:
	zoom=1.0;pan=Vector2.ZERO;dragging=false;touches.clear()
	queue_redraw();view_changed.emit()

func limit_pan() -> void:
	var limit: Vector2=size*zoom*0.65
	pan=pan.clamp(-limit,limit)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: touches[event.index]=event.position
		else: touches.erase(event.index)
		dragging=false;accept_event()
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches.size()==1: pan+=event.relative
		else:
			var previous: Array=touches.values()
			touches[event.index]=event.position
			var current: Array=touches.values()
			var distance: float=Vector2(previous[0]).distance_to(previous[1])
			var center: Vector2=(Vector2(previous[0])+Vector2(previous[1]))/2
			if distance>4: zoom_to(zoom*Vector2(current[0]).distance_to(current[1])/distance,center)
			pan+=(Vector2(current[0])+Vector2(current[1]))/2-center
		touches[event.index]=event.position;limit_pan();queue_redraw();accept_event()
	elif event is InputEventMouseButton and touches.is_empty():
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_to(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8),event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging and touches.is_empty():
		pan+=event.relative;limit_pan();queue_redraw();accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_to(zoom*event.factor,event.position);accept_event()
	elif event is InputEventPanGesture:
		pan-=event.delta*12;limit_pan();queue_redraw();accept_event()

func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not visible:
		dragging=false;touches.clear()
