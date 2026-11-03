extends SceneTree
func _initialize() -> void:
	var game:=OEGameSession.new(false)
	if not OESnapshot.new().load_game(game,"res://../build/fixtures/user_world_015.oe2"): quit(1);return
	var vm: OEVM=game.vm;var sprites: Array=vm.get_static("k","j","[S").data
	var names:=OEPresentationState.new(vm);var rows: Array=[]
	for weapon in 11:
		vm.set_field(vm.get_static("v","b","Lq;"),"q","g","I",weapon)
		OEText.choose("ru");var ru: String=names.hud().weapon_name
		OEText.choose("en");var en: String=names.hud().weapon_name
		var end: int=vm.get_static("k","i","[S").data.size()/2
		for start in sprites:
			if int(start)!=32767 and int(start)>int(sprites[weapon+1]): end=mini(end,int(start))
		rows.append({"weapon":weapon,"sprite":weapon+1,"frames":end-int(sprites[weapon+1]),"ru":ru,"en":en})
	print(JSON.stringify(rows));FileAccess.open("res://../build/weapons.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"));names.vm=null;game.close();quit()
