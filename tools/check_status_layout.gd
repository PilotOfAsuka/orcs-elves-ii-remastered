extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game: Control=load("res://main.tscn").instantiate()
	root.add_child(game);game.set_process(false)
	game.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	await process_frame
	var cases:=0
	for viewport: Vector2 in [Vector2(360,640),Vector2(390,844),Vector2(1280,720)]:
		game.size=viewport
		for remastered: bool in [false,true]:
			game.remastered=remastered;game.arrange()
			var world:=Rect2(game.picture.position,game.picture.size)
			for count: int in [1,5,12,0]:
				var data: Array=[]
				for id in count:data.append({"id":id,"amount":10 if id%2 else -5,"turns":30-id})
				game.effects.show_state(data);game.effects.visible=count>0;game.arrange_effects()
				assert(Rect2(game.picture.position,game.picture.size)==world,"Effect count must not change the world viewport")
				assert(game.effects.rows.size()==count)
				if count>0:
					assert(game.effects.position.x==world.position.x+8,"Effects belong at the left edge")
					assert(game.encounter.position.x>=game.effects.position.x+game.effects.size.x+8,"Enemy/events must not overlap effects")
					for row: Dictionary in game.effects.rows:
						assert(row.card.position.y>=0 and row.card.position.y+row.card.size.y<=game.effects.size.y+0.1)
						assert(row.icon.size.x==14)
				cases+=1
	print("Status layout passed: ",cases," cases, Classic/Remastered, compact left column, unchanged viewport")
	game.queue_free()
	await process_frame
	quit()
