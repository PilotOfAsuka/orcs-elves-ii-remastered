extends SceneTree
## Offline movie compositor: the actual game UI, original core frames and model.
var game: Control
var edit: Dictionary
var base: String
var overlay: Label
var caption_panel: Panel
var stage: SubViewport

func _init() -> void:
	call_deferred("run")

func present(frame: Dictionary) -> void:
	OEText.choose(frame.get("language","en"))
	var state: Dictionary=OEText.translate_state(frame.model)
	game.state=state;game.remastered=frame.get("mode","remastered")=="remastered";game.quality_index=2
	game.update_mode_button()
	game.picture.texture=ImageTexture.create_from_image(Image.load_from_file(base.path_join(frame.image)))
	game.picture.show();game.frame.show();game.status.hide();game.story_ru.hide();game.travel_title.hide();game.story_back.hide();game.story_next.hide()
	var kind: int=int(state.state)
	game.hud.show_state(state.hud);game.encounter.show_state(state.hud,bool(state.get("cinematic_active",false)))
	if frame.get("fly",false):game.encounter.hide()
	game.reader.show_state({"kind":"dialogue","text":str(state.dialogue),"title":OEText.localize("СОБЫТИЯ"),"page":0,"pages":1,"choice":false,"right":"","primary":OEText.localize("Продолжить")} if kind==7 else {})
	game.shade.visible=kind in [2,7];game.menu.visible=kind==2
	if kind==2:game.update_menu()
	game.map_view.show_state(state.get("map",{}));game.map_tools.visible=kind==5;game.lock.hide()
	var action_ids: Array=[5,7,16,9,1,10,3,6,4,12,2,14]
	for i in game.actions.size():
		var button: Button=game.actions[i];button.disabled=kind not in [3,4,5,20,21]
		button.modulate=Color(1.4,1.2,0.8) if int(frame.get("action",0))==action_ids[i] else Color.WHITE
	if kind==17:game.story_next.show();game.story_next.text=OEText.localize("Продолжить")+" ›"
	game.arrange()
	overlay.text=frame.get("caption","");caption_panel.visible=not overlay.text.is_empty()
	caption_panel.position=game.picture.position+Vector2(12,game.picture.size.y-100);caption_panel.size=Vector2(game.picture.size.x-24,88)
	caption_panel.modulate.a=float(frame.get("caption_alpha",1.0))
	overlay.position=Vector2(10,8);overlay.size=caption_panel.size-Vector2(20,16)

func no_mouse(node: Node) -> void:
	if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.tooltip_text=""
	for child in node.get_children():no_mouse(child)

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():push_error("Expected cinematic edit.json");quit(1);return
	base=args[0].get_base_dir();edit=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	stage=SubViewport.new();stage.size=Vector2i(1080,1920);stage.disable_3d=true;stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(stage)
	OEText.choose("en");game=load("res://main.tscn").instantiate();stage.add_child(game);game.set_process(false);game.set_process_unhandled_key_input(false)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	game.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);game.position=Vector2.ZERO;game.size=Vector2(360,640);game.scale=Vector2(3,3)
	var preview:=TextureRect.new();preview.texture=stage.get_texture();preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(preview)
	caption_panel=Panel.new();caption_panel.add_theme_stylebox_override("panel",OESkin.plate(Color(0.025,0.04,0.03,0.94),OESkin.BRONZE,10));game.add_child(caption_panel)
	overlay=Label.new();overlay.add_theme_color_override("font_color",OESkin.GOLD);overlay.add_theme_font_size_override("font_size",21);overlay.clip_text=true;overlay.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;overlay.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption_panel.add_child(overlay)
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN;no_mouse(game)
	await process_frame
	print("OFFSCREEN MOVIE ",stage.size," UI ",game.size)
	var movie:=FileAccess.open(base.path_join("render.mjpeg"),FileAccess.WRITE)
	var index:=0
	for frame: Dictionary in edit.frames:
		present(frame)
		await RenderingServer.frame_post_draw
		var rendered:=stage.get_texture().get_image()
		movie.store_buffer(rendered.save_jpg_to_buffer(0.97))
		if index==0:rendered.save_png(base.path_join("render-preview.png"))
		index+=1
		if index%300==0:print("Rendered ",index," / ",edit.frames.size())
	movie.close()
	await process_frame
	quit()
