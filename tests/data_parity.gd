extends SceneTree
var session: OEGameSession
var failures: Array=[]
var comparisons: int=0
var graphs: int=0
func _initialize() -> void: call_deferred("run")
func snapshot(path: String) -> String:
	if not OESnapshot.new().save_game(session,path): failures.append("save");return ""
	return FileAccess.open(path,FileAccess.READ).get_var(false).checksum
func probe(owner: String,key: String,args: Array,object: Variant=null) -> Variant:
	var method: Dictionary=session.vm.classes[owner].methods[key]
	var is_static: bool=(int(method.flags)&8)!=0
	var code: Array=[]
	if not is_static: code.append([42])
	for value: Variant in args: code.append([19,value])
	code.append([184 if is_static else 182,{"owner":owner,"name":method.name,"desc":method.desc,"params":method.params,"return":"S"}])
	code.append([179,{"owner":"DataProbe","name":"value","desc":"I"}])
	code.append([177])
	var handler: int=code.size()
	code.append([179,{"owner":"DataProbe","name":"error","desc":"Ljava/lang/Throwable;"}]);code.append([177])
	var desc: String="()V" if is_static else "(Ls;)V"
	var wrapper: Dictionary={"flags":8,"name":"run","desc":desc,"params":[] if is_static else ["Ls;"],"max_locals":0 if is_static else 1,"exceptions":[{"start":0,"end":handler,"handler":handler,"type":"java/lang/Throwable"}],"code":code}
	session.vm.classes.DataProbe={"parent":"java/lang/Object","interfaces":[],"fields":[{"name":"value","desc":"I"},{"name":"error","desc":"Ljava/lang/Throwable;"}],"methods":{"run"+desc:wrapper}}
	session.vm.statics.DataProbe={"value:I":12345,"error:Ljava/lang/Throwable;":null};session.vm.initialized.DataProbe=true
	var main: Array[Dictionary]=session.vm.fibers.duplicate()
	var next: int=session.vm.next_id
	session.vm.fibers.clear()
	var fiber: Dictionary=session.vm.launch("DataProbe","run"+desc,null,[] if is_static else [object])
	for tick in 1000:
		if fiber.frames.is_empty() or session.vm.halted: break
		session.vm.tick(0)
	if not fiber.frames.is_empty() or session.vm.halted: failures.append("probe failed "+key)
	session.vm.fibers.assign(main);session.vm.next_id=next
	var error: Variant=session.vm.get_static("DataProbe","error","Ljava/lang/Throwable;")
	return {"value":session.vm.get_static("DataProbe","value","I"),"error":null if error==null else [error.type,error.data],"cursor":session.vm.get_static("n","b","I")}
func run() -> void:
	session=OEGameSession.new(false)
	if not OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2"): quit(1);return
	session.vm.max_slice=1000000
	var bytes:=JObject.new("[B")
	bytes.data=[]
	for index in 256: bytes.data.append(index-128)
	for key in ["a()B","a()S","a(I)S","b(I)S","b()S","a()I","b()I","c()S"]:
		var indexes: Array=range(256)
		indexes.append_array([-2147483648,-1,256,2147483646,2147483647])
		for index: int in indexes:
			var sums: Array=[]
			var results: Array=[]
			for fast in [false,true]:
				session.vm.fast_resources=fast
				session.vm.set_static("n","a","[B",bytes);session.vm.set_static("n","b","I",index)
				results.append(probe("n",key,[index] if key.contains("(I)") else []))
				if index in [-1,0,254,255,256,2147483647]: sums.append(snapshot("user://data-check.oe2"))
			if results[0]!=results[1]: failures.append([key,index,results])
			if not sums.is_empty():
				graphs+=1
				if sums[0]!=sums[1]: failures.append([key,index,"graph"])
			comparisons+=1
		var null_results: Array=[]
		for fast in [false,true]:
			session.vm.fast_resources=fast;session.vm.set_static("n","a","[B",null);session.vm.set_static("n","b","I",1)
			null_results.append(probe("n",key,[1] if key.contains("(I)") else []))
		if null_results[0]!=null_results[1]: failures.append([key,"null",null_results])
		comparisons+=1
	# Identity lookup, absent references, duplicates and overlong bounds.
	OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2")
	var table: Array=session.vm.get_static("l","b","[Ls;").data
	var original_count: int=session.vm.get_static("l","e","I")
	var receivers: Array=[table[0],table[original_count-1],JObject.new("s")]
	if original_count>3: table[1]=table[original_count-1]
	for size in [0,1,original_count,table.size()+1]:
		for object: JObject in receivers:
			var results: Array=[];var sums: Array=[]
			for fast in [false,true]:
				session.vm.fast_resources=fast;session.vm.set_static("l","e","I",size)
				results.append(probe("s","a()S",[],object));sums.append(snapshot("user://data-check.oe2"))
			if results[0]!=results[1] or sums[0]!=sums[1]: failures.append(["identity",size])
			comparisons+=1;graphs+=1
	for fixture in ["resource_texels","world"]:
		OESnapshot.new().load_game(session,"res://../build/fixtures/"+fixture+".oe2")
		var queries: Array=[]
		if fixture=="resource_texels":
			var loaded: Array=session.vm.get_static("k","k","[I").data
			for index in int(session.vm.get_static("k","aL","I")): queries.append(["b(I)I",[loaded[index]]])
		else:
			for x in range(-32,2080,64):
				for y in range(-32,2080,64): queries.append(["a(II)S",[x,y]])
		for q: Array in queries:
			var results: Array=[];var sums: Array=[]
			for fast in [false,true]:
				session.vm.fast_geometry=fast
				results.append(probe("k",q[0],q[1]))
				if comparisons%64==0: sums.append(snapshot("user://data-check.oe2"))
			if results[0]!=results[1]: failures.append(q)
			if not sums.is_empty():
				graphs+=1
				if sums[0]!=sums[1]: failures.append([q,"graph"])
			comparisons+=1
	# Cross-class initialization must still run before the identity scan.
	OESnapshot.new().load_game(session,"res://../build/fixtures/world.oe2")
	var receiver: JObject=session.vm.get_static("l","b","[Ls;").data[0]
	var saved_initializer: Variant=session.vm.classes.l.methods.get("<clinit>()V")
	session.vm.classes.l.methods["<clinit>()V"]={"flags":8,"name":"<clinit>","desc":"()V","params":[],"max_locals":0,"exceptions":[],"code":[[4],[179,{"owner":"l","name":"e","desc":"I"}],[177]]}
	var init_results: Array=[];var init_sums: Array=[]
	for fast in [false,true]:
		session.vm.fast_resources=fast;session.vm.initialized.erase("l");session.vm.set_static("l","e","I",0)
		init_results.append(probe("s","a()S",[],receiver));init_sums.append(snapshot("user://data-check.oe2"))
	if init_results[0]!=init_results[1] or init_sums[0]!=init_sums[1] or init_results[1].value!=0: failures.append("cross class initialization")
	comparisons+=1;graphs+=1
	if saved_initializer!=null: session.vm.classes.l.methods["<clinit>()V"]=saved_initializer
	var report: Dictionary={"comparisons":comparisons,"graphs":graphs,"failures":failures,"errors":session.vm.errors.duplicate()}
	FileAccess.open("res://../build/data_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://data-check.oe2"+suffix): DirAccess.remove_absolute("user://data-check.oe2"+suffix)
	session.close();quit(0 if failures.is_empty() else 1)
