extends SceneTree
## UI projections must never reveal the phone framebuffer or mutate the game.
var failures: Array[String]=[]
var checks: int=0
var ui: Control

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func run() -> void:
	ui=load("res://main.tscn").instantiate()
	ui.testing=true;ui.paused=true
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.add_child(ui)
	ui.set_process(false)
	for fixture in ["world","dialogue","story"]:
		check(OESnapshot.new().load_game(ui.session,"res://../build/fixtures/"+fixture+".oe2"),"load "+fixture)
		ui._process(0)
		var before: String="user://own-ui-before.oe2"
		var after: String="user://own-ui-after.oe2"
		OESnapshot.new().save_game(ui.session,before)
		var areas: Array=[]
		for mode in [0,1]:
			ui.set_render_mode(mode)
			for dims in [Vector2(360,640),Vector2(390,844),Vector2(640,360),Vector2(844,390),Vector2(1280,720),Vector2(1920,1080)]:
				ui.size=dims;ui.arrange()
				await process_frame
				var screen:=Rect2(Vector2.ZERO,dims)
				check(screen.encloses(ui.view_frame.get_rect()),"frame bounds "+str([fixture,mode,dims]))
				check(not ui.classic_view.visible or ui.classic_view.texture==ui.world_texture,"phone texture hidden "+fixture)
				if ui.hud.visible:
					check(screen.encloses(ui.hud.get_rect()),"HUD bounds "+str([mode,dims]))
					check(not ui.hud.get_rect().intersects(ui.view_frame.get_rect()),"HUD/world overlap "+str([mode,dims]))
				if ui.keypad.visible:
					for button: Button in ui.keypad.get_children():
						check(button.text.is_empty() and button.icon!=null and not button.accessibility_name.is_empty(),"icon has accessible name")
						check(screen.encloses(button.get_global_rect()),"button bounds "+str([mode,dims,button.tooltip_text]))
				if ui.reader_panel.visible:
					check(screen.encloses(ui.reader_panel.get_global_rect()),"reader bounds "+str([fixture,mode,dims]))
				if dims==Vector2(1280,720): areas.append(ui.view_frame.size.x*ui.view_frame.size.y)
		if fixture=="world": check(areas[1]>areas[0],"Remastered stage is larger")
		OESnapshot.new().save_game(ui.session,after)
		check(FileAccess.open(before,FileAccess.READ).get_var(false).checksum==FileAccess.open(after,FileAccess.READ).get_var(false).checksum,"layout changed VM "+fixture)
		for file in [before,after,before+".bak",after+".bak"]:
			if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	# Item captions and target HP may change content, never scene geometry.
	OESnapshot.new().load_game(ui.session,"res://../build/fixtures/world.oe2")
	ui._process(0)
	var stats: Dictionary=ui.presenter.hud()
	stats.notices="";stats.context="";stats.target_health=-1;stats.target_max=0
	for mode in [0,1]:
		ui.set_render_mode(mode)
		for dims in [Vector2(360,640),Vector2(390,844),Vector2(844,390),Vector2(1280,720)]:
			ui.size=dims;ui.hud.show_state(stats);ui.arrange();await process_frame
			var scene: Rect2=ui.view_frame.get_rect()
			var hp: Rect2=ui.hud.health_text.get_global_rect()
			for caption in ["","Пустой ларец","Очень длинная подпись предмета, которая должна обрезаться внутри своей строки"]:
				for target_hp in [-1,10]:
					var display: Dictionary=stats.duplicate()
					display.context=caption;display.target_health=target_hp;display.target_max=20 if target_hp>=0 else 0
					ui.hud.show_state(display);ui.arrange();await process_frame
					check(ui.view_frame.get_rect().is_equal_approx(scene),"caption resized scene "+str([mode,dims,caption,target_hp]))
					check(ui.hud.health_text.get_global_rect().is_equal_approx(hp),"caption moved health "+str([mode,dims,caption,target_hp]))
	# A real dialogue fixture overlays exactly the same game layout.
	for mode in [0,1]:
		for dims in [Vector2(360,640),Vector2(844,390),Vector2(1280,720)]:
			OESnapshot.new().load_game(ui.session,"res://../build/fixtures/world.oe2")
			ui._process(0);ui.size=dims;ui.set_render_mode(mode);ui.arrange();await process_frame
			var scene: Rect2=ui.view_frame.get_rect()
			var control: Rect2=ui.controls.get_rect()
			var hud_rect: Rect2=ui.hud.get_rect()
			OESnapshot.new().load_game(ui.session,"res://../build/fixtures/dialogue.oe2")
			ui._process(0);await process_frame
			check(ui.modal_layer.visible and ui.reader_panel.get_parent()==ui.modal_layer,"dialogue is modal")
			check(ui.keypad.visible and ui.hud.visible,"dialogue keeps HUD and controls")
			check(ui.view_frame.get_rect().is_equal_approx(scene),"dialogue moved scene "+str([mode,dims]))
			check(ui.controls.get_rect().is_equal_approx(control),"dialogue moved buttons")
			check(ui.hud.get_rect().is_equal_approx(hud_rect),"dialogue moved HUD")
	# Map zoom and drag are view-only, including touch and the reset action.
	ui.session.vm.set_static("a","H","I",5);ui._process(0)
	OESnapshot.new().save_game(ui.session,"user://map-before.oe2")
	var map:=ui.map_view as OEDungeonMap
	map.zoom_by(1.25);check(is_equal_approx(map.zoom,1.25),"map zoom button")
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
	map._gui_input(down)
	var move:=InputEventMouseMotion.new();move.relative=Vector2(25,12);map._gui_input(move)
	check(map.pan.length()>0,"map drag")
	down.pressed=false;map._gui_input(down)
	map.zoom_by(0.8);check(is_equal_approx(map.zoom,1.0),"map zoom out")
	map.reset_view();check(map.pan==Vector2.ZERO and map.zoom==1.0,"map reset")
	var first_touch:=InputEventScreenTouch.new();first_touch.index=0;first_touch.pressed=true;first_touch.position=Vector2(100,100)
	map._gui_input(first_touch)
	var touch_drag:=InputEventScreenDrag.new();touch_drag.index=0;touch_drag.position=Vector2(125,110);touch_drag.relative=Vector2(25,10)
	map._gui_input(touch_drag);check(map.pan.length()>0,"map touch pan")
	first_touch.pressed=false;map._gui_input(first_touch);map.reset_view()
	first_touch.pressed=true;first_touch.position=Vector2(100,100);map._gui_input(first_touch)
	var second_touch:=InputEventScreenTouch.new();second_touch.index=1;second_touch.pressed=true;second_touch.position=Vector2(200,100);map._gui_input(second_touch)
	touch_drag.index=1;touch_drag.position=Vector2(225,100);touch_drag.relative=Vector2(25,0);map._gui_input(touch_drag)
	check(map.zoom>1,"map pinch zoom")
	map.reset_view()
	OESnapshot.new().save_game(ui.session,"user://map-after.oe2")
	check(FileAccess.open("user://map-before.oe2",FileAccess.READ).get_var(false).checksum==FileAccess.open("user://map-after.oe2",FileAccess.READ).get_var(false).checksum,"map camera changed game")
	for path in ["user://map-before.oe2","user://map-after.oe2"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	# Enumerate original presentation states without advancing a synthetic scene.
	check(OESnapshot.new().load_game(ui.session,"res://../build/fixtures/world.oe2"),"world state fixture")
	for state in [0,1,2,3,4,5,6,7,8,9,12,13,14,15,17,19]:
		ui.session.vm.set_static("a","H","I",state)
		ui._process(0)
		check(not ui.classic_view.visible or ui.classic_view.texture==ui.world_texture,"no original UI state "+str(state))
		check(ui.classic_view.texture!=ui.original_atlas,"no original atlas state "+str(state))
		if state==5: check(ui.map_view.visible,"own map state")
		if state in [9,17]: check(ui.presentation_kind=="cinematic" and not ui.hud.visible,"cinematic has own presentation")
	# The cinematic predicate uses l.a:Lh;, not its same-named script field.
	ui.session.vm.set_static("l","k","Z",1)
	ui.session.vm.set_static("l","a","Lc;",JObject.new("c"))
	ui.session.vm.set_static("l","a","Lh;",null)
	check(not ui.presenter.cinematic(),"script reference is not a camera")
	ui.session.vm.set_static("l","a","Lh;",JObject.new("h"))
	check(ui.presenter.cinematic(),"exact original cinematic predicate")
	# Partial clip must not prevent a complete, separate world capture.
	var vm: OEVM=ui.session.vm
	var pixels: JObject=vm.new_array("[I",12)
	for index in 12: pixels.data[index]=0xff123456+index
	vm.set_static("k","m","[I",pixels)
	var graphics: OEMidpGraphics=ui.session.platform.screen.data
	graphics.set_clip(1,1,2,1)
	ui.session.platform.draw_rgb(graphics,[pixels,0,4,0,0,4,3,0])
	var image: Image=ui.session.platform.screen.extra.world_surface
	check(image.get_size()==Vector2i(4,3),"cinematic full size capture")
	check(image.get_pixel(0,0).to_rgba32()==Color8(0x12,0x34,0x56).to_rgba32(),"capture includes clipped-out world pixel")
	check(image.get_pixel(3,2).to_rgba32()==Color8(0x12,0x34,0x61).to_rgba32(),"capture preserves last pixel")
	var report: Dictionary={"checks":checks,"failures":failures,"errors":ui.session.vm.errors.duplicate()}
	FileAccess.open("res://../build/own_ui.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	ui.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
