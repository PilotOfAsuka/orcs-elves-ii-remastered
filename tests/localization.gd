extends SceneTree
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func run() -> void:
	var ui=load("res://main.tscn").instantiate()
	ui.testing=true;ui.paused=true;root.add_child(ui);ui.set_process(false)
	OESnapshot.new().load_game(ui.session,"res://../build/fixtures/world.oe2")
	ui._process(0)
	OESnapshot.new().save_game(ui.session,"user://locale-before.oe2")
	ui.select_language("en");ui._process(0)
	check(OEText.entries.size()==1605,"complete ID catalogue")
	check(ui.presenter.text_id(44)=="Continue","original text ID in English")
	check(ui.presenter.hud().weapon_name=="Wand","English weapon")
	check(ui.hud.weapon_text.text=="Wand","English HUD")
	check(OEText.localize("Повернуть влево · A")=="Turn left · A","English icon tooltip")
	check(OEText.localize("Игра сохранена")=="Game saved","English toast")
	OESnapshot.new().save_game(ui.session,"user://locale-after.oe2")
	check(FileAccess.open("user://locale-before.oe2",FileAccess.READ).get_var(false).checksum==FileAccess.open("user://locale-after.oe2",FileAccess.READ).get_var(false).checksum,"language switch preserves complete game graph")
	var samples: Dictionary={}
	for fixture in ["story","dialogue"]:
		OESnapshot.new().load_game(ui.session,"res://../build/fixtures/"+fixture+".oe2")
		ui._process(0)
		if fixture=="story":
			ui.session.key(-7)
			for n in 15: ui.session.tick(50)
		else:
			ui.session.key(53)
			for n in 15: ui.session.tick(50)
		var reader: Dictionary=ui.presenter.reader();samples[fixture]=reader
		var cyrillic:=RegEx.new();cyrillic.compile("[А-Яа-яЁё]")
		check(not str(reader.get("text","")).is_empty(),fixture+" English text exists")
		check(cyrillic.search(str(reader.get("text","")))==null,fixture+" has no Russian text")
	check(str(samples.story.text).begins_with("Dark times"),"English introduction")
	# Gate execution while the startup choice is visible.
	ui.language_ready=false
	var count: int=ui.session.vm.instructions
	ui._process(0)
	check(ui.session.vm.instructions==count,"startup chooser gates VM")
	ui.select_language("ru")
	check(OEText.language=="ru" and ui.language_ready,"Russian choice resumes UI")
	check(OEText.localize("Игра сохранена")=="Игра сохранена","Russian UI preserved")
	check(ui.keypad.get_child(0).tooltip_text=="Шаг влево · Z","Russian icon tooltip restored")
	for path in ["user://locale-before.oe2","user://locale-after.oe2"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var result: Dictionary={"checks":checks,"failures":failures,"samples":samples,"errors":ui.session.vm.errors.duplicate()}
	FileAccess.open("res://../build/localization.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));ui.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
