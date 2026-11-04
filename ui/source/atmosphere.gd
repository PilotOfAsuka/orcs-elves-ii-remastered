class_name OEAtmosphere
extends Control
## Static, inexpensive ornament. Redraw only when the layout changes.
var frame_only: bool=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var r:=Rect2(Vector2.ZERO,size)
	if not frame_only:
		draw_rect(r,Color("090f0c"))
		for n in 24:
			var t: float=float(n)/24
			draw_rect(Rect2(0,t*size.y,size.x,size.y/24+1),Color("1b2821").lerp(Color("080e0b"),t))
		for x in range(20,int(size.x),96):
			draw_line(Vector2(x,64),Vector2(x,size.y-48),Color(0.42,0.46,0.32,0.035),1)
		draw_line(Vector2(20,55),Vector2(size.x-20,55),Color("544a32"),1)
		draw_circle(Vector2(size.x/2,55),3,Color("ba9554"))
		return
	draw_rect(r.grow(-1),Color("72603e"),false,1)
	draw_rect(r.grow(-4),Color(0.12,0.15,0.11,0.75),false,3)
	for corner in [Vector2(1,1),Vector2(size.x-1,1),Vector2(1,size.y-1),size-Vector2.ONE]:
		var dir:=Vector2(1 if corner.x<2 else -1,1 if corner.y<2 else -1)
		draw_line(corner,corner+Vector2(22*dir.x,0),OESkin.GOLD,2)
		draw_line(corner,corner+Vector2(0,22*dir.y),OESkin.GOLD,2)
		draw_circle(corner+dir*6,1.6,OESkin.GOLD)
