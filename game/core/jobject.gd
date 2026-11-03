class_name JObject
extends RefCounted
## JVM references use identity, including mutable arrays. Field descriptors are essential:
## Obfuscated Java bytecode has many fields called 'a' with different types.
var type: String
var fields: Dictionary = {}
var data: Variant = null
var extra: Dictionary = {}

func _init(class_type: String = "java/lang/Object") -> void:
	type = class_type
