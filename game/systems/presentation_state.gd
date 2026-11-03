class_name OEPresentationState
extends RefCounted
## Read-only projections of original state. No original methods are executed here.
var vm: OEVM
var font_map: Dictionary = {}
var font_language: int = -999

func _init(machine: OEVM) -> void:
	vm=machine

func chars(text: String) -> String:
	var language: int = vm.get_static("a","a","B")
	if language!=font_language:
		font_map.clear()
		var source: Variant = vm.get_static("b","a","[S")
		var targets: Variant = vm.get_static("b","b","[S")
		if source is JObject and targets is JObject:
			for i in source.data.size():
				var code: int=int(source.data[i])
				if i>=code: continue
				var index: int=i if language==4 or i>targets.data.size()-source.data.size() else source.data.size()+i
				if index<targets.data.size(): font_map[code]=int(targets.data[index])
			font_language=language
	var result: String=""
	for n in text.length():
		var code: int=int(font_map.get(text.unicode_at(n),text.unicode_at(n)))
		if code in [10,124]: result+="\n"
		elif code>=32 and not (code>=127 and code<192): result+=String.chr(code)
	return result.strip_edges()

func text_id(id: int, dynamic: bool=false, raw: bool=false) -> String:
	var result: String=""
	if dynamic:
		var pool: Variant=vm.get_static("w","a","Ljava/lang/StringBuffer;")
		if pool is JObject and pool.data is String:
			var start: int=id&65535
			var end: int=(id>>16)&65535
			result=pool.data.substr(start,maxi(0,end-start))
	else:
		# Original a.a(int,StringBuffer) -> a.a(short,short,StringBuffer).
		var group: int=(id>>10)*5
		var index: int=id&1023
		var data: Variant=vm.get_static("a","a","[[B")
		var offsets: Variant=vm.get_static("a","a","[[S")
		if not data is JObject or not offsets is JObject or group<0 or group>=data.data.size(): return ""
		var bytes: Variant=data.data[group]
		var positions: Variant=offsets.data[group]
		if not bytes is JObject or not positions is JObject or index>=positions.data.size(): return ""
		var cursor: int=int(positions.data[index])
		var objects: Variant=vm.get_static("a","a","[Ljava/lang/Object;")
		var integers: Variant=vm.get_static("a","g","[I")
		var count: int=vm.get_static("a","ab","I")
		while cursor>=0 and cursor<bytes.data.size():
			var code: int=int(bytes.data[cursor])&255
			if code==0: break
			cursor+=1
			if code==92 and cursor<bytes.data.size():
				code=int(bytes.data[cursor]);cursor+=1
				result+="\n" if code==110 else ("%" if code==37 else "\\"+String.chr(code&65535))
			elif code==37 and cursor<bytes.data.size():
				var argument: int=int(bytes.data[cursor])-49;cursor+=1
				if argument>=0 and argument<count:
					var object: Variant=objects.data[argument] if objects is JObject else null
					if object!=null: result+=str(object.data if object is JObject else object)
					elif integers is JObject: result+=str(integers.data[argument])
			else: result+=String.chr(code)
	if not raw: result=result.replace("--","\ue000").replace("-","").replace("\ue000","-")
	return chars(result)

func menu() -> Dictionary:
	if int(vm.get_static("a","H","I"))!=2: return {}
	var items: Variant=vm.get_static("w","a","[Lt;")
	if not items is JObject: return {}
	var count: int=vm.get_static("w","f","I")
	var selected: int=vm.get_static("w","j","I")
	var sentinel: int=vm.get_static("w","b","I")
	var rows: Array[Dictionary]=[]
	var description: String=""
	for index in mini(count,items.data.size()):
		var row: Variant=items.data[index]
		if not row is JObject: continue
		var flags: int=vm.get_field(row,"t","e","I")
		var id: int=vm.get_field(row,"t","b","I")
		if id==sentinel and (flags&0x1040)==0: continue
		var label: String=text_id(id,(flags&4096)!=0,(flags&2)!=0)
		var value_id: int=vm.get_field(row,"t","c","I")
		var value: String="" if value_id==sentinel else text_id(value_id,(flags&8192)!=0,(flags&2)!=0)
		rows.append({"index":index,"text":label,"value":value,"readonly":(flags&1)!=0,"disabled":(flags&5)!=0,"adjustable":(flags&32)!=0})
		if index==selected:
			var help_id: int=vm.get_field(row,"t","d","I")
			if help_id!=sentinel: description=text_id(help_id)
	return {"id":vm.get_static("w","g","I"),"selected":selected,"rows":rows,"description":description}
