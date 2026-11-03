extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var session:=OEGameSession.new(false)
	var vm:=session.vm
	vm.fibers.clear()
	var methods: Dictionary={}
	for name in ["first","second"]:
		var field: Dictionary={"owner":"QuotaProbe","name":name,"desc":"I"}
		methods[name+"()V"]={"name":name,"desc":"()V","params":[],"flags":8,"max_locals":0,"exceptions":[],"code":[[178,field],[4],[96],[179,field],[167,0]]}
	vm.classes.QuotaProbe={"parent":"java/lang/Object","interfaces":[],"fields":[{"name":"first","desc":"I","flags":8},{"name":"second","desc":"I","flags":8}],"methods":methods}
	vm.statics.QuotaProbe={"first:I":0,"second:I":0}
	vm.initialized.QuotaProbe=true
	vm.launch("QuotaProbe","first()V")
	vm.launch("QuotaProbe","second()V")
	vm.max_slice=1000000
	vm.frame_budget_us=1000
	var worst: int=0
	for tick in 12:
		var began: int=Time.get_ticks_usec()
		vm.tick(16)
		worst=maxi(worst,Time.get_ticks_usec()-began)
	var a: int=vm.get_static("QuotaProbe","first","I")
	var b: int=vm.get_static("QuotaProbe","second","I")
	var passed: bool=a>0 and b>0 and not vm.halted and vm.instructions<1000000
	print(JSON.stringify({"passed":passed,"first":a,"second":b,"worst_tick_us":worst,"instructions":vm.instructions}))
	session.close()
	quit(0 if passed else 1)
