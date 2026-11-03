extends SceneTree
func _initialize() -> void: call_deferred("run")
func plain(text: String) -> String:
	return text.replace("--","\ue000").replace("-","").replace("\ue000","-").replace("\\n","\n")
func run() -> void:
	var game:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(game,"res://../build/fixtures/world.oe2"): quit(1);return
	var presenter:=OEPresentationState.new(game.vm)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/locale_import.json"))
	var entries: Dictionary={}
	for row: Dictionary in source.rows:
		var english: String=""
		for i in str(row.en_raw).length():
			var code: int=str(row.en_raw).unicode_at(i)
			if code>=32 and code<127 or code in [10,124]: english+=String.chr(code)
		entries[str(int(row.id))]={"ru":presenter.chars(plain(row.ru_raw)),"en":plain(english).strip_edges()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/localization"))
	FileAccess.open("res://assets/localization/en.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha256":source.source_sha256,"entries":entries},"\t"))
	print(entries.size()," bilingual entries");game.close();quit()
