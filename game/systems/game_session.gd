class_name OEGameSession
extends RefCounted

var vm: OEVM
var platform: OEJavaNative
var saves: OESaveManager
var texture: ImageTexture
var last_flush: int = -1

func _init(persistent: bool = true, sound: Node = null) -> void:
	vm = OEVM.new()
	# Bound main-thread work so touch/key events can be processed between slices.
	if OS.has_feature("web"): vm.max_slice=12000
	if not persistent: vm.epoch_ms = 1170000000000
	saves = OESaveManager.new()
	saves.persistent = persistent
	saves.load_all()
	platform = OEJavaNative.new(vm, saves, sound)
	vm.native = platform
	texture = ImageTexture.create_from_image(platform.screen.data.surface)
	var app: JObject = vm.new_object("App")
	vm.launch("App", "<init>()V", app)
	vm.launch("App", "startApp()V", app)

func tick(delta_ms: int) -> void:
	vm.tick(delta_ms)
	if platform.flush_count != last_flush:
		texture.update(platform.screen.data.surface)
		last_flush = platform.flush_count

func key(raw: int) -> void:
	var canvas: Variant = platform.display.data
	if canvas is JObject and canvas.type == "a":
		vm.launch("a", "keyPressed(I)V", canvas, [raw])

func report() -> Dictionary:
	var stacks: Array = []
	for fiber: Dictionary in vm.fibers:
		var frames: Array = []
		for frame: Dictionary in fiber.frames:
			frames.append(str(frame.owner) + "." + str(frame.method.name) + str(frame.method.desc) + ":" + str(frame.pc))
		stacks.append(frames)
	return {"clock_ms":vm.now_ms,"instructions":vm.instructions,"flushes":platform.flush_count,"errors":vm.errors.duplicate(),"unsupported":platform.unsupported.keys(),"stacks":stacks,"state":vm.get_static("a","H","I"),"menu":vm.get_static("w","g","I")}

func release_state() -> void:
	# Break Java object cycles before releasing Godot's reference-counted session.
	var pending: Array = [vm.statics, vm.fibers, vm.class_locks, vm.active, platform.screen, platform.display, platform.image_cache]
	var seen: Dictionary = {}
	var objects: Array[JObject] = []
	while not pending.is_empty():
		var value: Variant = pending.pop_back()
		if value is JObject:
			var id: int = value.get_instance_id()
			if seen.has(id): continue
			seen[id] = true
			objects.append(value)
			pending.append_array([value.fields,value.data,value.extra])
		elif value is Array: pending.append_array(value)
		elif value is Dictionary:
			for key: Variant in value:
				if key!="method": pending.append(value[key])
	for object: JObject in objects:
		object.fields.clear()
		object.data = null
		object.extra.clear()
	vm.statics.clear()
	vm.fibers.clear()
	vm.class_locks.clear()
	vm.active.clear()
	platform.image_cache.clear()

func close() -> void:
	release_state()
	vm.font_helpers.vm=null
	platform.vm = null
	vm.native = null
