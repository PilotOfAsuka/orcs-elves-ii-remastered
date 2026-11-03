extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := OEGameSession.new(false)
	for n in 150: session.tick(50)
	var failures: Array[String] = []
	var before: Dictionary = session.report()
	var path: String = "user://test-snapshot.oe2"
	if not OESnapshot.new().save_game(session,path): failures.append("save")
	for n in 12: session.tick(50)
	session.vm.resume_after=99999
	if not OESnapshot.new().load_game(session,path): failures.append("load")
	if session.vm.resume_after!=0 or not session.vm.active.is_empty(): failures.append("reset obsolete scheduler state")
	var after: Dictionary = session.report()
	for key in ["clock_ms","state","menu","stacks","errors"]:
		if before[key]!=after[key]: failures.append("restore "+key)
	var copy: String = "user://test-snapshot-copy.oe2"
	if not OESnapshot.new().save_game(session,copy): failures.append("resave")
	var left: Dictionary = FileAccess.open(path,FileAccess.READ).get_var(false)
	var right: Dictionary = FileAccess.open(copy,FileAccess.READ).get_var(false)
	if left.checksum!=right.checksum: failures.append("round-trip graph checksum")
	session.close()
	for file in [path,path+".bak",copy,copy+".bak"]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	print(JSON.stringify({"failures":failures,"restored_state":after.state}))
	quit(0 if failures.is_empty() else 1)
