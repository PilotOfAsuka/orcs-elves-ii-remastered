extends SceneTree
var ui: Control
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func call_original(owner: String,key: String,args: Array=[],receiver: Variant=null) -> Variant:
	var vm: OEVM=ui.session.vm
	var main: Array[Dictionary]=vm.fibers.duplicate();vm.fibers.clear()
	var fiber: Dictionary=vm.launch(owner,key,receiver,args)
	for n in 20000:
		if fiber.frames.is_empty() or vm.halted: break
		vm.tick(20 if int(fiber.wake)>vm.now_ms else 0)
	vm.fibers.assign(main)
	check(fiber.frames.is_empty(),"completed "+key)
	return fiber.result
func keys() -> Array:
	var result: Array=[]
	for fiber: Dictionary in ui.session.vm.fibers:
		for frame: Dictionary in fiber.frames:
			if frame.method.name=="keyPressed": result.append(frame.locals[1])
	return result
func tick() -> void:
	for n in 12: ui.session.tick(50)
	ui._process(0)
func load_fixture(name: String) -> void:
	check(OESnapshot.new().load_game(ui.session,"res://../build/fixtures/"+name+".oe2"),"load "+name)
	ui._process(0)
func run() -> void:
	var viewport:=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.size=Vector2i(390,844);root.add_child(viewport)
	ui=load("res://main.tscn").instantiate();ui.testing=true;ui.paused=true;ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);viewport.add_child(ui);ui.set_process(false)
	load_fixture("world");ui.size=Vector2(390,844);ui.arrange();await process_frame
	check(not ui.actions_row.visible,"service buttons hidden during play")
	check(ui.hud.find_children("*","Button",true,false).is_empty(),"no HUD weapon arrows")
	load_fixture("dialogue");await process_frame
	check(ui.game_input_blocked and ui.modal_layer.get_index()==ui.get_child_count()-1,"modal receives input above all controls")
	for button: Button in ui.keypad.get_children(): check(button.disabled,"disabled underlying "+button.tooltip_text)
	var before: Array=keys()
	ui.begin_key(50)
	var attack:=InputEventMouseButton.new();attack.button_index=MOUSE_BUTTON_LEFT;attack.pressed=false;ui.view_input(attack)
	var key:=InputEventKey.new();key.keycode=KEY_W;key.physical_keycode=KEY_W;key.pressed=true;ui._unhandled_key_input(key)
	check(keys()==before,"movement and view taps ignored during dialogue")
	# Real GUI hit testing: place Forward directly beneath Continue, then click.
	var forward: Button=ui.keypad.get_child(1)
	var point: Vector2=ui.reader_panel.primary.get_global_rect().get_center()
	ui.controls.position+=point-forward.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;viewport.push_input(motion,true)
	for pressed in [true,false]:
		var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=point;mouse.global_position=point;mouse.pressed=pressed
		viewport.push_input(mouse,true);await process_frame
	check(keys().slice(before.size())==[53],"Continue click sends only 53, never Forward")
	load_fixture("world")
	for button: Button in ui.keypad.get_children(): check(not button.disabled,"world buttons restored")
	# Exercise both genuine original settings menus, then original Back routing.
	for id in [24,119]:
		load_fixture("user_f9_014")
		call_original("w","b(I)V",[id]);call_original("a","a(I)V",[2]);ui._process(0)
		check(ui.is_language_menu(),"language screen "+str(id))
		check(ui.menu_buttons.size()==3,"only RU, EN and Back")
		var backend: int=ui.session.vm.get_static("a","a","B")
		ui.choose_menu_row(id,1);ui._process(0)
		check(OEText.language=="en" and (ui.menu_buttons.has(1) and ui.menu_buttons[1].text.contains("✓")),"English changes inside settings")
		check(int(ui.session.vm.get_static("a","a","B"))==backend,"original backend stays compatible")
		ui.begin_key(50);check(keys().is_empty(),"language navigation is UI only")
		ui.begin_key(53);tick()
		check(OEText.language=="ru","keyboard chooses Russian")
		check(int(ui.session.vm.get_static("w","g","I"))==(17 if id==24 else 102),"Back returns to correct settings")
		check(ui.presenter.menu().rows[2].value=="Русский","parent settings show selected language")
		check(ui.native_rows.get_child_count()>ui.menu_buttons.size(),"service actions available in settings")
	# Invoke the real entry handler on an unopened chest from the user's map.
	load_fixture("user_f9_014")
	var chest: JObject=ui.session.vm.get_static("l","b","[Ls;").data[52]
	check((int(ui.session.vm.get_field(chest,"s","b","I"))&0x400000)==0,"unopened original chest")
	call_original("a","a(Ls;)V",[chest]);ui._process(0)
	for n in 12:
		if int(ui.session.vm.get_static("a","H","I"))!=7: break
		ui.dialogue_key(53);tick()
	check(int(ui.session.vm.get_static("a","H","I"))==19,"original chest event entered")
	check(ui.lockpick_panel.visible and ui.game_input_blocked,"dedicated lock panel blocks movement")
	check(ui.lockpick_panel.buttons.size()==4,"four lock directions")
	check(not ui.presenter.lockpick().has("code"),"secret not projected to UI")
	for language in ["ru","en"]:
		ui.select_language(language);ui._process(0)
		for dims in [Vector2(360,640),Vector2(390,844),Vector2(640,360),Vector2(844,390),Vector2(1280,720)]:
			viewport.size=Vector2i(dims);ui.size=dims;ui.arrange();await process_frame
			check(Rect2(Vector2.ZERO,dims).encloses(ui.lockpick_panel.get_global_rect()),"lock panel bounds "+str([language,dims]))
			if dims==Vector2(390,844):
				RenderingServer.force_draw(false)
				viewport.get_texture().get_image().save_png("res://../build/preview_lock_"+language+"_014.png")
	ui.select_language("ru");ui._process(0)
	var raw: Dictionary={1:50,2:56,3:52,4:54}
	var secret: Array=ui.session.vm.get_static("l","a","[C").data.duplicate()
	var right: int=secret[0];var wrong: int=right%4+1
	call_original("a","i(I)V",[raw[wrong]]);ui._process(0)
	check(ui.presenter.lockpick().completed==0 and not ui.presenter.lockpick().partial,"wrong direction leaves stage incomplete")
	call_original("a","i(I)V",[raw[right]]);ui._process(0)
	check(ui.presenter.lockpick().partial,"first correct direction highlights stage")
	call_original("a","i(I)V",[raw[wrong]]);ui._process(0)
	check(not ui.presenter.lockpick().partial,"mistake resets partial confirmation")
	call_original("a","i(I)V",[raw[right]]);call_original("a","i(I)V",[raw[right]]);ui._process(0)
	check(ui.presenter.lockpick().completed==1,"two correct presses complete original stage")
	check(ui.presenter.lockpick().attempts==5,"original attempt counter")
	for stage in range(1,int(ui.presenter.lockpick().length)):
		call_original("a","i(I)V",[raw[int(secret[stage])]]);call_original("a","i(I)V",[raw[int(secret[stage])]])
	check(int(ui.session.vm.get_static("a","w","Z"))==1,"original combination completed")
	call_original("a","G()V");ui._process(0)
	check(int(ui.session.vm.get_static("a","H","I"))==3 and not ui.lockpick_panel.visible,"success returns to world")
	check((int(ui.session.vm.get_field(chest,"s","b","I"))&0x400000)!=0,"original chest opened")
	load_fixture("user_f9_014");chest=ui.session.vm.get_static("l","b","[Ls;").data[52]
	call_original("a","a(Ls;)V",[chest]);ui._process(0)
	for n in 12:
		if int(ui.session.vm.get_static("a","H","I"))!=7: break
		ui.dialogue_key(53);tick()
	key.keycode=KEY_ESCAPE;key.physical_keycode=KEY_ESCAPE;ui._unhandled_key_input(key);tick()
	check(int(ui.session.vm.get_static("a","H","I"))==3,"Escape cancels original lock event")
	check(not ui.game_input_blocked and ui.held_key==0,"cancel restores controls without held movement")
	check((int(ui.session.vm.get_field(chest,"s","b","I"))&0x400000)==0,"cancel does not open chest")
	var report: Dictionary={"checks":checks,"failures":failures,"errors":ui.session.vm.errors.duplicate()}
	FileAccess.open("res://../build/interaction_ui.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	ui.queue_free();await process_frame;viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
