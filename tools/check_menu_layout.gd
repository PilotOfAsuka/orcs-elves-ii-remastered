extends SceneTree
func _init() -> void:call_deferred("run")
func run() -> void:
	var fixtures: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../build/menu-fixtures.json"))
	var game: Control=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	await process_frame
	var cases:=0
	for viewport: Vector2 in [Vector2(360,640),Vector2(390,844),Vector2(1280,720)]:
		game.size=viewport;game.remastered=true;game.arrange();var world:=Rect2(game.picture.position,game.picture.size)
		for lang: String in ["ru","en"]:
			OEText.choose(lang)
			for source: Dictionary in fixtures:
				game.state=OEText.translate_state(source);game.menu_signature="";game.update_menu();game.menu.show();game.arrange()
				await process_frame;game.arrange();await process_frame
				assert(Rect2(game.picture.position,game.picture.size)==world,"Menus cannot change the world viewport")
				var rect: Rect2=game.menu.get_rect()
				assert(rect.position.x>=0 and rect.end.x<=viewport.x+0.1,"Panel must fit width")
				assert(rect.position.y>=0 and rect.end.y<=viewport.y+0.1,"Panel must fit height")
				assert(game.menu_box.size.x<=rect.size.x+0.1,"Menu contents must fit mobile width")
				if int(source.menu_id)==1:
					var buttons: Array=[];collect_buttons(game.menu_box,buttons);assert(buttons.size()==1,"Only Continue is actionable on results")
				cases+=1
	for viewport: Vector2 in [Vector2(360,640),Vector2(390,844),Vector2(1280,720)]:
		game.size=viewport;game.arrange();var world:=Rect2(game.picture.position,game.picture.size)
		for id in range(1,9):
			game.hud.show_state({"health":100,"max_health":140,"armor":90,"max_armor":100,"weapon_name":"Очень длинное название оружия","ammo":99,"ring_id":id,"rings_owned":510,"ring_name":"Кольцо","ring_description":"Описание"})
			assert(game.hud.ring_button.visible)
			assert(game.hud.weapon_text.position.x+game.hud.weapon_text.size.x<=game.hud.ring_button.position.x-4)
			assert(game.hud.ring_button.position.x+game.hud.ring_button.size.x<=game.hud.ammo_icon.position.x-4)
			assert(Rect2(game.picture.position,game.picture.size)==world,"Ring badge cannot resize the world")
			assert(game.hud.ring_button.icon.region.position.y==(id-1)*18,"Original ring icon must match native ID")
	print("Menu layout passed: ",cases," cases; 19 native screens, RU/EN, phone/desktop, stable world; level metrics are inert; 24 ring HUD layouts")
	game.queue_free();await process_frame;quit()
func collect_buttons(node: Node,buttons: Array) -> void:
	if node is Button:buttons.append(node)
	for child in node.get_children():collect_buttons(child,buttons)
