extends SceneTree

var failures: Array[String]=[]
var ui: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func settle(ticks: int=80) -> void:
	for n in ticks:
		ui.session.tick(50)
		ui._process(0.0)
		ui.update_native_menu(ui.session.vm.now_ms)
		ui.update_adventure(ui.session.vm.now_ms)
		if ui.session.vm.halted: break

func run() -> void:
	ui=load("res://main.tscn").instantiate()
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.testing=true
	ui.paused=true
	root.add_child(ui)
	var saved: Dictionary={}
	for fixture in ["story","dialogue","world"]:
		check(OESnapshot.new().load_game(ui.session,"res://../build/fixtures/"+fixture+".oe2"),"load "+fixture)
		ui._process(0.0)
		var state: Dictionary=ui.session.report()
		var reader: Dictionary=ui.presenter.reader()
		var hud: Dictionary=ui.presenter.hud()
		saved[fixture]={"reader":reader,"hud":hud,"report":state}
		check(ui.reader_panel.visible==(fixture!="world"),fixture+" reader visibility")
		if fixture=="world":
			check(ui.hud.visible,"native HUD visible")
			check(ui.classic_view.texture==ui.world_texture,"world separated from original HUD")
			check(int(hud.health)==100 and int(hud.armor)==100 and int(hud.ammo)==10,"initial original stats")
		else: check(not str(reader.text).is_empty() or not reader.get("complete",true),"reader contents "+fixture)
		var path: String="user://adventure-before.oe2"
		var after: String="user://adventure-after.oe2"
		check(OESnapshot.new().save_game(ui.session,path),"save before "+fixture)
		for dims in [Vector2(360,640),Vector2(390,844),Vector2(844,390),Vector2(1280,720),Vector2(1920,1080)]:
			ui.size=dims
			ui.arrange()
			var screen:=Rect2(Vector2.ZERO,dims)
			check(screen.encloses(Rect2(ui.view_frame.position,ui.view_frame.size)),"world inside "+str(dims)+fixture)
			if ui.hud.visible:
				check(screen.encloses(Rect2(ui.hud.position,ui.hud.size)),"HUD inside "+str(dims)+fixture)
				check(ui.hud.position.y>=ui.view_frame.position.y+ui.view_frame.size.y-0.1,"HUD covers world "+fixture)
			if ui.keypad.visible and ui.auxiliary.visible:
				check(ui.keypad.position.y+ui.keypad.size.y<=ui.auxiliary.position.y,"keypad overlap "+fixture)
		ui.set_render_mode(1)
		await create_timer(0.3).timeout
		ui.set_render_mode(0)
		await create_timer(0.3).timeout
		check(OESnapshot.new().save_game(ui.session,after),"save after "+fixture)
		var a: Dictionary=FileAccess.open(path,FileAccess.READ).get_var(false)
		var b: Dictionary=FileAccess.open(after,FileAccess.READ).get_var(false)
		check(a.checksum==b.checksum,"presentation changed original state "+fixture)
		for file in [path,path+".bak",after,after+".bak"]:
			if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	# Fast-forward rewinds the original story timer below zero; only -1 is the sentinel.
	check(OESnapshot.new().load_game(ui.session,"res://../build/fixtures/story.oe2"),"story fast-forward fixture")
	settle(8)
	ui.session.key(-7)
	settle(20)
	var fast_story: Dictionary=ui.presenter.reader()
	check(fast_story.get("kind","")=="story" and fast_story.get("complete",false),"story fast-forward completed")
	check(not str(fast_story.get("text","")).is_empty() and fast_story.get("text")==fast_story.get("full_text"),"story text after negative timer")
	# Digital keys release with unicode=0 in browsers. Never keep walking after key-up.
	var event:=InputEventKey.new()
	event.keycode=KEY_2
	event.unicode=50
	event.pressed=true
	ui._unhandled_key_input(event)
	check(ui.held_key==50,"numeric direction begins hold")
	event.unicode=0
	event.pressed=false
	ui._unhandled_key_input(event)
	check(ui.held_key==0,"numeric direction release stops hold")
	event.keycode=0x0426 # Cyrillic Ц on the physical W key.
	event.physical_keycode=KEY_W
	event.unicode=0x0446
	event.pressed=true
	ui._unhandled_key_input(event)
	check(ui.held_key==50,"physical WASD with Russian keyboard layout")
	event.pressed=false
	event.unicode=0
	ui._unhandled_key_input(event)
	check(ui.held_key==0,"physical WASD release")
	# Weapon arrows use the original next/previous actions and reflect the resulting state.
	check(OESnapshot.new().load_game(ui.session,"res://../build/fixtures/world.oe2"),"weapon fixture")
	ui.session.key(55)
	settle(80)
	var next_weapon: Dictionary=ui.presenter.hud()
	check(not next_weapon.is_empty() and next_weapon.weapon!=0,"original next weapon")
	check(ui.hud.weapon_text.text==next_weapon.weapon_name,"native weapon name updated")
	ui.session.key(42)
	settle(80)
	check(ui.presenter.hud().weapon==0,"original previous weapon")
	# The real game menu and inventory entries still come from the original table.
	check(OESnapshot.new().load_game(ui.session,"res://../build/fixtures/world.oe2"),"reload world")
	ui.session.key(48)
	settle(100)
	var menu: Dictionary=ui.presenter.menu()
	print("GAME MENU ",JSON.stringify(menu))
	check(not menu.is_empty() and int(menu.id)==100,"original game menu opens")
	check(ui.native_menu.visible,"own game menu visible")
	check(not ui.classic_view.visible,"old game menu hidden")
	var entries: JObject=ui.session.vm.get_static("w","a","[Lt;")
	var destination: int=ui.session.vm.get_field(entries.data[1],"t","f","I")
	ui.choose_menu_row(100,1)
	settle(160)
	var inventory: Dictionary=ui.presenter.menu()
	print("INVENTORY ",JSON.stringify(inventory))
	check(not inventory.is_empty() and int(inventory.id)==destination,"original rucksack destination")
	check(ui.native_menu.visible and not ui.classic_view.visible,"native inventory visible")
	check(ui.session.vm.errors.is_empty(),"runtime errors")
	FileAccess.open("res://../build/adventure.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"fixtures":saved,"menu":menu,"inventory":inventory},"\t"))
	ui.queue_free()
	await process_frame
	print(JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
