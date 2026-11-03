extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := OEGameSession.new(false)
	var count: int = 1000
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: count = int(args[0])
	var actions: Dictionary = {}
	if args.size()>1:
		for pair: String in args[1].split(","):
			var parts := pair.split(":")
			actions[int(parts[0])] = int(parts[1])
	for n in count:
		if actions.has(n): session.key(actions[n])
		session.tick(50)
		if n%25==0:
			print("TICK ",n," ",JSON.stringify(session.report()))
			session.platform.screen.data.surface.save_png("res://../build/checkpoint_%03d.png" % n)
		if session.vm.halted: break
	var file := FileAccess.open("res://../build/smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(session.report(), "\t"))
	session.platform.screen.data.surface.save_png("res://../build/startup.png")
	print(JSON.stringify(session.report()))
	var failed: bool = session.vm.halted
	session.close()
	quit(1 if failed else 0)
