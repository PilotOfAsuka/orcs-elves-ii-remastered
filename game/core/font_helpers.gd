class_name OEFontHelpers
extends RefCounted
## Exact, side-effect-free equivalents of the original b font lookup methods.
## Full bytecode remains available as the oracle; tests/font_parity.gd compares it.
var vm: OEVM

func _init(machine: OEVM) -> void:
	vm=machine

func accepts(owner: String, key: String) -> bool:
	return owner=="b" and (key=="a(III)I" or (key=="a(S)S" and int(vm.get_static("a","a","B"))==4))

func invoke(key: String, args: Array) -> int:
	if key=="a(S)S":
		var value: int=int(args[0])
		var source_array: Variant=vm.get_static("b","a","[S")
		var target_array: Variant=vm.get_static("b","b","[S")
		if not source_array is JObject or not target_array is JObject:
			vm.throw_exception("java/lang/NullPointerException");return 0
		var source: Array=source_array.data
		var target: Array=target_array.data
		for index in mini(source.size(),maxi(0,value)):
			if value==int(source[index]):
				var slot: int=index if int(vm.get_static("a","a","B"))==4 or index>target.size()-source.size() else source.size()+index
				if slot<0 or slot>=target.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(slot));return 0
				return int(target[slot])
		return value
	return search(int(args[0]),int(args[1]),int(args[2]))

func search(value: int, low: int, high: int) -> int:
	var table: Variant=vm.get_static("b","a","[[S")
	if not table is JObject or table.data.is_empty() or not table.data[0] is JObject:
		vm.throw_exception("java/lang/NullPointerException");return 0
	var codes: Array=table.data[0].data
	while low<=high:
		var middle: int=(low+high)>>1
		if middle<0 or middle>=codes.size(): vm.throw_exception("java/lang/ArrayIndexOutOfBoundsException",str(middle));return 0
		var code: int=int(codes[middle])&65535
		if value==code: return middle
		if value<code: high=middle-1
		else: low=middle+1
	return int(vm.get_static("b","b","I"))-1
