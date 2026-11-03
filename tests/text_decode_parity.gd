extends SceneTree
var game: OEGameSession
var failures: Array=[]
var comparisons: int=0
func _initialize() -> void: call_deferred("run")
func probe(group: int,index: int,target: Variant) -> Dictionary:
	var ref: Dictionary={"owner":"a","name":"a","desc":"(SSLjava/lang/StringBuffer;)V","params":["S","S","Ljava/lang/StringBuffer;"],"return":"V"}
	var code: Array=[[17,123],[17,group],[17,index],[178,{"owner":"TextProbe","name":"target","desc":"Ljava/lang/StringBuffer;"}],[184,ref],[179,{"owner":"TextProbe","name":"marker","desc":"I"}],[177],[179,{"owner":"TextProbe","name":"error","desc":"Ljava/lang/Throwable;"}],[177]]
	game.vm.classes.TextProbe={"parent":"java/lang/Object","interfaces":[],"fields":[{"name":"target","desc":"Ljava/lang/StringBuffer;","flags":8},{"name":"marker","desc":"I","flags":8},{"name":"error","desc":"Ljava/lang/Throwable;","flags":8}],"methods":{"run()V":{"name":"run","desc":"()V","params":[],"return":"V","flags":8,"max_locals":0,"exceptions":[{"start":0,"end":7,"handler":7,"type":"java/lang/Throwable"}],"code":code}}}
	game.vm.statics.TextProbe={"target:Ljava/lang/StringBuffer;":target,"marker:I":0,"error:Ljava/lang/Throwable;":null};game.vm.initialized.TextProbe=true
	var main: Array[Dictionary]=game.vm.fibers.duplicate();game.vm.fibers.clear()
	var fiber: Dictionary=game.vm.launch("TextProbe","run()V")
	for n in 10000:
		if fiber.frames.is_empty() or game.vm.halted: break
		game.vm.tick(0)
	game.vm.fibers.assign(main)
	var error: Variant=game.vm.statics.TextProbe["error:Ljava/lang/Throwable;"]
	OESnapshot.new().save_game(game,"user://text-decode-proof.oe2")
	return {"text":target.data if target is JObject else null,"marker":game.vm.statics.TextProbe["marker:I"],"error":null if error==null else [error.type,error.data],"graph":FileAccess.open("user://text-decode-proof.oe2",FileAccess.READ).get_var(false).checksum}
func case(input: PackedByteArray, kind: String="normal", group: int=0,index: int=0) -> void:
	var results: Array=[]
	for fast in [false,true]:
		OESnapshot.new().load_game(game,"res://../build/fixtures/user_f9_015.oe2");game.vm.resource_helpers.fast_text=fast
		var target:=JObject.new("java/lang/StringBuffer");target.data="PREFIX:"
		var bytes: JObject=game.vm.new_array("[B",input.size());bytes.data.assign(Array(input).map(func(value: Variant): return OEVM.signed(int(value),8)))
		var offsets: JObject=game.vm.new_array("[S",10 if kind=="diagnostic_index" else 1);offsets.data[0]=32767 if kind=="short_wrap" else (99 if kind=="offset_bounds" else 0)
		game.vm.get_static("a","a","[[B").data[0]=null if kind=="null_bytes" else bytes
		game.vm.get_static("a","a","[[S").data[0]=null if kind=="null_offsets" else offsets
		var args: JObject=game.vm.get_static("a","a","[Ljava/lang/Object;");var ints: JObject=game.vm.get_static("a","g","[I")
		var value:=JObject.new("java/lang/Integer");value.data=-7
		args.data[0]=target if kind=="alias" else "GOLD";args.data[1]=null;args.data[2]=value
		ints.data[1]=-2147483648;game.vm.set_static("a","ab","I",3)
		results.append(probe(group,index,null if kind=="null_target" else target))
	comparisons+=1
	if results[0]!=results[1]: failures.append({"kind":kind,"group":group,"index":index,"input":Array(input.slice(0,30)),"results":results})
func run() -> void:
	game=OEGameSession.new(false)
	for text in ["","hello","%1/%2/%3/%0/%7", "\\% / \\n / \\q", "unclosed %", "unclosed \\"]:
		var bytes: PackedByteArray=text.to_utf8_buffer();bytes.append(0);case(bytes)
	for byte in range(1,256): case(PackedByteArray([byte,0]))
	for byte in [0,1,37,110,127,128,255]: case(PackedByteArray([92,byte,0]))
	for kind in ["null_bytes","null_offsets","null_target","offset_bounds","alias"]: case(PackedByteArray([37,49,0]),kind)
	for group in [-1,60,61]: case(PackedByteArray([65,0]),"normal",group)
	for index in [-1,1,100]: case(PackedByteArray([65,0]),"normal",0,index)
	case(PackedByteArray([65,0]),"diagnostic_index",0,4)
	case(PackedByteArray([0]),"null_target")
	case(PackedByteArray([65,66]),"unterminated")
	var wrap:=PackedByteArray();wrap.resize(32769);wrap.fill(65);case(wrap,"short_wrap")
	var report: Dictionary={"comparisons":comparisons,"failures":failures,"errors":game.vm.errors.duplicate()}
	FileAccess.open("res://../build/text_decode_parity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify({"comparisons":comparisons,"failures":failures.size(),"errors":game.vm.errors}))
	for suffix in ["",".bak"]:
		if FileAccess.file_exists("user://text-decode-proof.oe2"+suffix): DirAccess.remove_absolute("user://text-decode-proof.oe2"+suffix)
	game.close();quit(0 if failures.is_empty() else 1)
