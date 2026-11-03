class_name OEText
extends RefCounted
## Presentation-only localization. The VM, its strings and save graph stay intact.
static var language: String="ru"
static var entries: Dictionary={}
static var lookup: Dictionary={}
static var templates: Array=[]
static var cache: Dictionary={}
const UI={
	"Здоровье":"Health","Броня":"Armor","Заряды":"Charges","Оружие":"Weapon",
	"Меню":"Menu","Карта":"Map","Назад":"Back","Выбрать":"Select",
	"Шаг влево":"Strafe left","Вперёд":"Forward","Шаг вправо":"Strafe right",
	"Повернуть влево":"Turn left","Повернуть вправо":"Turn right","Действие / удар":"Action / attack",
	"Следующее оружие":"Next weapon","Предыдущее оружие":"Previous weapon","Пропустить ход":"Wait a turn",
	"Сохранить":"Save","Загрузить":"Load","Звук":"Sound","Полный экран":"Fullscreen",
	"Быстро сохранить · F5":"Quick save · F5","Быстро загрузить · F9":"Quick load · F9",
	"Включить / выключить звук":"Toggle sound","Исходная пиксельная графика · F2":"Original pixel graphics · F2",
	"Увеличенный игровой вид · F2":"Expanded game view · F2",
	"Игра сохранена":"Game saved","Не удалось сохранить":"Save failed",
	"Сохранение загружено":"Save loaded","Нет сохранения":"No saved game",
	"Подготовка игры…":"Preparing the game…","СОБЫТИЯ":"EVENTS","В ПУТИ":"ON THE ROAD",
	"СОЗДАТЕЛИ":"CREDITS","ЛЕТОПИСЬ":"CHRONICLE","Показать целиком":"Reveal text",
	"Продолжить":"Continue","Далее":"Next","Пропустить":"Skip","Закрыть":"Close",
	"Закрыть сообщение":"Close message","ПУТЕШЕСТВИЕ":"ADVENTURE","РЮКЗАК":"RUCKSACK",
	"КАРТА ПОДЗЕМЕЛЬЯ":"DUNGEON MAP","СЮЖЕТНАЯ СЦЕНА":"STORY SCENE","ПУТЬ ОКОНЧЕН":"JOURNEY'S END",
	"Вы пали в бою…":"You have fallen…","Уменьшить карту":"Zoom out","Увеличить карту":"Zoom in",
	"Сбросить вид карты":"Reset map view","Язык":"Language",
	"WASD — ход · Z/C — шаг вбок · Q/E — оружие · Enter — действие · M — карта":"WASD move · Z/C strafe · Q/E weapon · Enter action · M map"
}

static func spaces(value: String) -> String:
	return " ".join(value.replace("-\n","").replace("-|","").replace("\n"," ").replace("|"," ").replace("\t"," ").split(" ",false))

static func canonical(value: String) -> String:
	var result: String=spaces(value).to_lower()
	# Original Russian fonts mix Latin lookalikes with Cyrillic code points.
	for pair in [["a","а"],["b","в"],["c","с"],["e","е"],["h","н"],["k","к"],["m","м"],["o","о"],["p","р"],["t","т"],["x","х"],["y","у"]]: result=result.replace(pair[0],pair[1])
	return result

static func ensure_catalog() -> void:
	if not entries.is_empty(): return
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/en.json")).entries
	for entry: Dictionary in entries.values():
		var key: String=canonical(entry.ru)
		if key.is_empty(): continue
		lookup[key]=str(entry.en).replace("|","\n")
		if key.contains("%"):
			var pattern: String="^";var ids: Array=[];var cursor: int=0;var literals: int=0
			while cursor<key.length():
				var ch: String=key[cursor]
				if ch=="%" and cursor+1<key.length() and key[cursor+1] in ["1","2","3","4","5","6"]:
					ids.append(key[cursor+1]);pattern+="(.+?)";cursor+=2;continue
				if ch in ["\\",".","+","*","?","^","$","(",")","[","]","{","}","|"]: pattern+="\\"
				pattern+=ch;cursor+=1;literals+=1
			if ids.is_empty() or literals<4: continue
			var regex:=RegEx.new()
			if regex.compile(pattern+"$")==OK: templates.append({"regex":regex,"ids":ids,"en":str(entry.en).replace("|","\n")})
	for key: String in UI: lookup[canonical(key)]=UI[key]

static func choose(value: String) -> void:
	language="en" if value=="en" else "ru";cache.clear()
	if language=="en": ensure_catalog()

static func english(id: int) -> String:
	ensure_catalog()
	return str(entries.get(str(id),{}).get("en","")).replace("|","\n")

static func localize(text: String) -> String:
	if language!="en" or text.is_empty(): return text
	ensure_catalog()
	if cache.has(text): return cache[text]
	var key: String=canonical(text)
	var result: String=str(lookup.get(key,text))
	if result==text and text.contains(" · "):
		var parts: PackedStringArray=text.rsplit(" · ",true,1)
		var prefix: String=str(lookup.get(canonical(parts[0]),parts[0]))
		if prefix!=parts[0]: result=prefix+" · "+parts[1]
	if result==text:
		var display: String=spaces(text)
		for item: Dictionary in templates:
			var match: RegExMatch=item.regex.search(key)
			if match==null: continue
			result=item.en
			for i in item.ids.size():
				var value: String=display.substr(match.get_start(i+1),match.get_end(i+1)-match.get_start(i+1))
				result=result.replace("%"+str(item.ids[i]),str(lookup.get(canonical(value),value)))
			break
	if cache.size()>512: cache.clear()
	cache[text]=result
	return result

static func segment(source: String, translated: String, start: int, end: int) -> String:
	# Retain original paging / reveal timing while using native text wrapping.
	var first: int=roundi(translated.length()*float(start)/maxi(1,source.length()))
	var last: int=roundi(translated.length()*float(end)/maxi(1,source.length()))
	if first>0:
		while first<translated.length() and translated[first-1]!=" ": first+=1
	if last<translated.length():
		while last<translated.length() and translated[last-1]!=" ": last+=1
	return translated.substr(first,maxi(0,last-first)).strip_edges()
