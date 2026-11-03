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

func buffer(owner: String, name: String) -> String:
	var value: Variant=vm.get_static(owner,name,"Ljava/lang/StringBuffer;")
	return chars(str(value.data)) if value is JObject and value.data is String else ""

func field(object: Variant, owner: String, name: String, desc: String) -> Variant:
	return vm.get_field(object,owner,name,desc) if object is JObject else vm.default_value(desc)

func hud() -> Dictionary:
	var state: int=vm.get_static("a","H","I")
	if state not in [3,4,7]: return {}
	var player: Variant=vm.get_static("v","b","Lq;")
	if not player is JObject: return {}
	var weapon: int=field(player,"q","g","I")
	var ammo_type: int=0
	var ammo: int=-1
	var weapon_table: Variant=vm.get_static("u","a","[B")
	if weapon_table is JObject and weapon*10+5<weapon_table.data.size():
		ammo_type=int(weapon_table.data[weapon*10+5])
	var ammunition: Variant=vm.get_static("v","b","[B")
	var effects: Variant=vm.get_static("v","a","[B")
	if ammo_type>0 and ammunition is JObject and ammo_type<ammunition.data.size():
		ammo=int(ammunition.data[ammo_type])
		if effects is JObject and int(effects.data[0])>0: ammo+=int(effects.data[0])
	var weapon_name: String=""
	var definitions: Variant=vm.get_static("p","a","[Lg;")
	if definitions is JObject:
		for definition: Variant in definitions.data:
			if field(definition,"g","a","B")==6 and field(definition,"g","b","B")==1 and field(definition,"g","c","B")==weapon:
				weapon_name=text_id((1<<10)|int(field(definition,"g","b" if weapon==4 else "c","S")))
				break
	var armor: int=vm.get_static("v","J","I")
	var armor_kind: int=vm.get_static("v","K","I")
	var armor_table: Variant=vm.get_static("App","e","[S")
	var armor_max: int=0
	if armor_table is JObject and armor_kind*2+1<armor_table.data.size(): armor_max=int(armor_table.data[armor_kind*2+1])
	var context: String=""
	var events: Variant=vm.get_static("e","a","[Ljava/lang/StringBuffer;")
	if int(vm.get_static("e","c","I"))>0 and events is JObject and events.data[0] is JObject:
		context=chars(str(events.data[0].data))
	elif not buffer("e","d").is_empty(): context=buffer("e","d")
	elif not buffer("e","c").is_empty(): context=buffer("e","c")
	var target: Variant=vm.get_static("v","a","Ls;")
	var target_health: int=-1
	var target_max: int=0
	if target is JObject:
		if context.is_empty(): context=buffer("e","e")
		var stats: Variant=field(target,"s","a","Ld;")
		var definition: Variant=field(target,"s","a","Lg;")
		var flags: int=field(target,"s","b","I")
		# Original e.l(): do not reveal health where the original hides it.
		if stats is JObject and (int(field(definition,"g","a","S"))&256)==0 and (field(definition,"g","b","B")!=2 or (flags&0x200000)!=0):
			var attributes: Variant=field(stats,"d","a","Lq;")
			if attributes is JObject:
				target_health=int(field(attributes,"q","e","I"))
				target_max=int(field(attributes,"q","f","I"))
	var notices: PackedStringArray=[]
	var bubbles: Variant=vm.get_static("e","b","[Ljava/lang/StringBuffer;")
	if bubbles is JObject:
		for index in mini(int(vm.get_static("e","e","I")),bubbles.data.size()):
			if bubbles.data[index] is JObject: notices.append(chars(str(bubbles.data[index].data)))
	return {"health":field(player,"q","e","I"),"max_health":field(player,"q","f","I"),"armor":armor,"max_armor":armor_max,"weapon":weapon,"weapon_name":weapon_name,"ammo":ammo,"context":context if context!="\"" else "","target_health":target_health,"target_max":target_max,"notices":"\n".join(notices)}

func readable(text: String) -> String:
	# Original text was wrapped for a 15-pixel glyph grid. Let native text wrap again.
	return chars(text.replace("-\n","").replace("-|","").replace("\n"," ").replace("|"," "))

func reader() -> Dictionary:
	var state: int=vm.get_static("a","H","I")
	if state in [8,13]:
		var source: Variant=vm.get_static("a","f","Ljava/lang/StringBuffer;")
		var pages: Variant=vm.get_static("a","n","[I")
		var page: int=vm.get_static("a","af","I")
		var count: int=vm.get_static("a","ag","I")
		if not source is JObject or not source.data is String or not pages is JObject or page<0 or page>=count: return {}
		var start: int=int(pages.data[page*2])
		var length: int=int(pages.data[page*2+1])
		var began: int=vm.get_static("a","aQ","I")
		var clock: int=vm.now_ms+vm.epoch_ms-OEVM.number(vm.get_static("App","b","J"))
		var shown: int=clampi((clock-began)/50,0,length) if began!=-1 else 0
		return {"kind":"story","page":page,"pages":count,"text":readable(source.data.substr(start,shown)),"full_text":readable(source.data.substr(start,length)),"complete":shown>=length,"left":text_id((10<<10)|78) if state==8 or page>0 else "","right":text_id(63 if page<count-1 else 44) if shown>=length else "Показать целиком"}
	if state==7:
		var source: Variant=vm.get_static("a","b","Ljava/lang/StringBuffer;")
		if not source is JObject or not source.data is String: return {}
		var flags: int=vm.get_static("a","at","I")
		var selected_choice: int=1 if int(vm.get_static("a","v","Z"))!=0 else 0
		var view: int=vm.get_static("a","av","I")
		var lines: int=vm.get_static("a","au","I")
		var visible: int=vm.get_static("a","ap","I")
		var revealed: int=vm.get_static("a","as","I")
		var positions: Variant=vm.get_static("a","b","[S")
		var text: String=""
		var complete: bool=true
		if positions is JObject:
			for row in mini(visible,lines-view):
				var index: int=(view+row)*2
				var start: int=int(positions.data[index])
				var length: int=int(positions.data[index+1])
				var shown: int=length
				if row==revealed: shown=clampi((int(vm.get_static("App","b","I"))-int(vm.get_static("a","aq","I")))/25,0,length)
				elif row>revealed: shown=0
				if shown<length: complete=false
				text+=source.data.substr(start,shown)+"\n"
		var choice: bool=(flags&4)!=0
		var more: bool=view<lines-visible
		return {"kind":"dialogue","text":readable(text),"choice":choice and not more and complete,"selected_choice":selected_choice,"choices":text_id(33).split(" ",false,1),"complete":complete,"can_back":(flags&1)==0,"more":more,"left":"Назад" if buffer("a","d")=="PgUp" else buffer("a","d"),"right":"Пропустить" if more else "Закрыть","primary":"Показать целиком" if not complete else ("Далее" if more else "Продолжить")}
	return {}
