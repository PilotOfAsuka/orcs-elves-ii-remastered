extends SceneTree
var failures: Array[String]=[]
var checks: int=0
var game: OEGameSession
var presenter: OEPresentationState
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func equal_fresh(label: String) -> void:
	var fresh:=OEPresentationState.new(game.vm);fresh.menu_cache_enabled=false
	check(presenter.menu()==fresh.menu(),label)
func graph(path: String) -> String:
	OESnapshot.new().save_game(game,path)
	return FileAccess.open(path,FileAccess.READ).get_var(false).checksum
func run() -> void:
	game=OEGameSession.new(false)
	check(OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_015.oe2"),"load current user menu")
	presenter=OEPresentationState.new(game.vm)
	var before: String=graph("user://menu-cache-before.oe2")
	var cold: Dictionary=presenter.menu();check(not cold.is_empty(),"menu exists")
	for n in 10: check(presenter.menu()==cold,"warm projection equals cold")
	check(presenter.menu_cache_hits>=10,"warm cache hits")
	var copy: Dictionary=presenter.menu();copy.rows[0].text="MUTATED RETURN"
	check(presenter.menu()==cold,"caller cannot modify cached rows")
	check(before==graph("user://menu-cache-after.oe2"),"read-only complete VM graph")
	var items: JObject=game.vm.get_static("w","a","[Lt;")
	var row: JObject=items.data[0]
	var id: int=game.vm.get_field(row,"t","b","I")
	var bytes: JObject=game.vm.get_static("a","a","[[B").data[(id>>10)*5]
	var offsets: JObject=game.vm.get_static("a","a","[[S").data[(id>>10)*5]
	var at: int=offsets.data[id&1023]
	var previous: int=bytes.data[at];bytes.data[at]=65 if previous!=65 else 66
	equal_fresh("same-object byte mutation invalidates cache");check(presenter.menu()!=cold,"changed source text visible")
	bytes.data[at]=previous;equal_fresh("source byte restoration")
	offsets.data[id&1023]=at+1;equal_fresh("same-object offset mutation")
	offsets.data[id&1023]=at;equal_fresh("offset restoration")
	game.vm.set_static("w","j","I",0);equal_fresh("selected row and help")
	game.vm.set_field(row,"t","e","I",4096)
	var pool: JObject=game.vm.get_static("w","a","Ljava/lang/StringBuffer;")
	pool.data="DYNAMIC ONE";game.vm.set_field(row,"t","b","I",11<<16);equal_fresh("dynamic text pool")
	pool.data="DYNAMIC TWO";equal_fresh("same-object dynamic pool mutation")
	game.vm.set_field(row,"t","e","I",0);game.vm.set_field(row,"t","b","I",id)
	game.vm.set_static("a","ab","I",1)
	var args: JObject=game.vm.get_static("a","a","[Ljava/lang/Object;")
	var arg:=JObject.new("java/lang/StringBuffer");arg.data="FIRST ARGUMENT";args.data[0]=arg
	equal_fresh("object arguments")
	OEText.ensure_catalog()
	for key: String in OEText.entries:
		if int(key)<1024 and str(OEText.entries[key].ru).contains("%1"):
			game.vm.set_field(row,"t","b","I",int(key));break
	var with_arg: String=str(presenter.menu().rows[0].text)
	arg.data="SECOND ARGUMENT";equal_fresh("same-object mutable argument")
	check(str(presenter.menu().rows[0].text)!=with_arg,"placeholder argument visible after mutation")
	var ints: JObject=game.vm.get_static("a","g","[I")
	arg.data=null;equal_fresh("non-null argument with null data")
	var null_text: String=str(presenter.menu().rows[0].text)
	args.data[0]=null;ints.data[0]=21;equal_fresh("integer argument")
	check(str(presenter.menu().rows[0].text)!=null_text,"null object differs from absent argument")
	ints.data[0]=22;equal_fresh("changed integer argument")
	for language in ["en","ru","en","ru"]:
		OEText.choose(language);equal_fresh("locale "+language)
	check(OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_015.oe2"),"snapshot reload")
	equal_fresh("restored source arrays")
	var ui=load("res://main.tscn").instantiate();ui.testing=true;ui.paused=true;root.add_child(ui);ui.set_process(false)
	OESnapshot.new().load_game(ui.session,"res://../build/fixtures/user_f9_015.oe2")
	var timings: Array=[]
	for enabled in [false,true]:
		ui.presenter.menu_cache_enabled=enabled;ui._process(0)
		var times: Array=[]
		for n in 25:
			var started: int=Time.get_ticks_usec();ui._process(0);times.append(Time.get_ticks_usec()-started)
		times.sort();timings.append({"cache":enabled,"median_us":times[12],"max_us":times.back()})
	var report: Dictionary={"checks":checks,"failures":failures,"timings":timings,"errors":game.vm.errors.duplicate()}
	FileAccess.open("res://../build/menu_cache.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	for path in ["user://menu-cache-before.oe2","user://menu-cache-after.oe2"]:
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	ui.queue_free();game.close();await process_frame;quit(0 if failures.is_empty() else 1)
