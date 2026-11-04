extends SceneTree
## Exercise the actual UI translator, including formatted native combat text.
func _init() -> void:
	OEText.choose("ru");OEText.prepare()
	var failures: Array[String]=[]
	for id: String in OEText.catalog.ids:
		var row: Dictionary=OEText.catalog.ids[id]
		if OEText.localize(str(row.en))!=str(row.ru):failures.append("Catalog: "+id)
	var fixtures: Dictionary={
		"Orc took 7 damage!":"Орк получает 7 ед. урона!",
		"Necromancer raises Rat!":"Некромант воскрешает крысу!",
		"Necromancer's raise failed!":"Некроманту не удаётся воскресить мёртвого!",
		"Base Damage: 3 - 7\nBase Accuracy: 75\nIdeal Range: 1 - 2":"Базовый урон: 3 - 7\n\nБазовая меткость: 75\n\nОптимальная дальность: 1–2\n",
	}
	for source: String in fixtures:
		var actual:=OEText.localize(source)
		if actual!=fixtures[source]:failures.append(source+" => "+actual)
	var prompt:=OEText.merge_menu_text([{"flags":9,"text":"This will erase"},{"flags":9,"text":"your saved game."},{"flags":9,"text":"Are you sure?"}])
	if OEText.localize(str(prompt[0].text))!="Ваше сохранение будет стёрто.\n\nВы уверены?":failures.append("Wrapped confirmation")
	var tutorial: String="Dagger\nThis magic dagger can\nbe used to backstab,\ntoss at your enemies,\nor strike at close\nrange. When tossed, it\nwill return to you once\ndamage has been inflicted on an enemy."
	if OEText.localize(tutorial)!="Кинжал\n"+str(OEText.catalog.ids["1:24"].ru):failures.append("Wrapped weapon tutorial: "+OEText.localize(tutorial))
	var samples_path: String=ProjectSettings.globalize_path("res://../build/ui-text-samples.json")
	var samples: Variant=JSON.parse_string(FileAccess.get_file_as_string(samples_path))
	var remaining: Array=[]
	if samples is Array:
		for source: String in samples:
			var actual:=OEText.localize(source)
			if RegEx.create_from_string("[A-Za-z]{3}").search(actual)!=null:remaining.append({"en":source,"ru":actual})
	var report: Dictionary={"catalog":OEText.catalog.coverage,"failures":failures,"remaining_sample_text":remaining}
	var file:=FileAccess.open("res://../build/localization-check.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"coverage":OEText.catalog.coverage,"failures":failures,"remaining_samples":remaining.size()}))
	quit(1 if not failures.is_empty() else 0)
