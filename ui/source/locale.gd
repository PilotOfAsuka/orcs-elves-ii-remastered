class_name OEText
extends RefCounted
## UI-only localization. BREW game text comes from its original resources.
static var language: String="ru"
const UI={
	"Дальность освещения":"Lighting distance","Кольцо не надето":"No ring equipped","Снять кольцо":"Remove ring",
	"Новая игра":"New game","Настройки":"Settings","Помощь / Об игре":"Help / About",
	"ПАУЗА":"PAUSED","Продолжить игру":"Resume game","Ещё":"More","Свернуть":"Show less","ОБЛАСТЬ ПРОЙДЕНА":"AREA CLEARED","Персонаж":"Character","Золото: %d":"Gold: %d","Цена: %s":"Price: %s","Подробнее":"Details","Зелья":"Potions","Кольца":"Rings","Прочее":"Other","Вернуться в игру":"Return to game","ТОРГОВЛЯ":"TRADE","Уйти":"Leave","Ваше предложение":"Your offer","Предложить":"Make offer","Отмена":"Cancel",
	"Фамильяр":"Familiar","Уклонение":"Avoidance","Очищение":"Remedy","Ускорение":"Haste","Опьянение":"Drunkenness","Регенерация":"Regeneration","Точность":"Accuracy","Сила":"Strength","Защита":"Defense","Заморозка":"Frozen","Отравление":"Poisoned","Уменьшение":"Shrunk","Осталось ходов: %d":"Turns remaining: %d",
	"Подберите направление. Следите за замком.":"Find the direction. Watch the lock.",
	"Скачать сохранение":"Download save","Загрузить копию сохранения":"Import save backup","Копия сохранения скачана":"Save backup downloaded","Копия сохранения восстановлена":"Save backup restored","Не удалось скачать сохранение":"Save download failed","Не удалось загрузить копию сохранения":"Save import failed","Загружаем сохранение…":"Importing save…",
	"Подберите направление. Жёлтый — верно: нажмите ещё раз. Зелёный — позиция закреплена.":"Find the direction. Yellow means correct: press again. Green means the tumbler is set.",
	"Позиция %d из %d · Попытки: %d":"Tumbler %d of %d · Attempts: %d","Выберите направление":"Choose a direction","Позиция закреплена":"Tumbler set","Верно! Повторите направление":"Correct! Repeat the direction","Другое направление":"Try another direction",
	"ВЗЛОМ ЗАМКА":"PICK LOCK","Вверх":"Up","Вниз":"Down","Влево":"Left","Вправо":"Right","Попытки":"Attempts","Отменить взлом":"Cancel lockpicking",
	"Выберите направление. Верное направление подтвердите повторным нажатием.":"Choose a direction. Confirm a correct direction by pressing it again.","БЫСТРЫЕ ДЕЙСТВИЯ":"QUICK ACTIONS",
	"Здоровье":"Health","Броня":"Armor","Заряды":"Charges","Оружие":"Weapon",
	"Меню":"Menu","Карта":"Map","Назад":"Back","Выбрать":"Select",
	"Шаг влево":"Strafe left","Вперёд":"Forward","Шаг вправо":"Strafe right",
	"Повернуть влево":"Turn left","Повернуть вправо":"Turn right","Действие / удар":"Action / attack",
	"Следующее оружие":"Next weapon","Предыдущее оружие":"Previous weapon","Пропустить ход":"Wait a turn",
	"Отладка":"Debug",
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
const BREW_MENUS={"Choose Game Mode:":"Выберите сложность:","Difficult":"Сложно","Inventory":"Рюкзак","Quest Log":"Дневник заданий","View Map":"Карта","Status":"Персонаж","Help/About":"Помощь / Об игре","More Games":"Другие игры","Restart Level":"Начать уровень заново","Save & Quit":"Сохранить и выйти","Enable Sounds?":"Включить звук?","Yes":"Да","No":"Нет","New Game":"Новая игра","Load Game":"Загрузить игру","Save Game":"Сохранить игру","Continue":"Продолжить","Options":"Настройки","Help":"Помощь","Exit":"Выход","Credits":"Создатели","Back":"Назад","Select":"Выбрать","Sound":"Звук","Easy":"Легко","Normal":"Обычно","Hard":"Сложно","Nightmare":"Кошмар","Main Menu":"Главное меню","Resume Game":"Продолжить игру"}
static func choose(value: String) -> void:
	language="en" if value=="en" else "ru"
static func localize(text: String) -> String:
	if language=="en": return str(UI.get(text,{"Да":"Yes","Нет":"No"}.get(text,text)))
	return translate(text)

static var catalog: Dictionary={}
static var ru_cache: Dictionary={}
static var help_cache: Dictionary={}
static var lowered: Dictionary={}
static var patterns: Array=[]
static var spaces: RegEx
static var soft_hyphen: RegEx
static var non_ascii: RegEx
const HELP_EN={
	"2:1":"HOW TO PLAY\nMove with the on-screen controls, WASD or the arrow keys. Press Enter or the sword button to talk, attack and interact.\n\nUse the top buttons to open the menu, map and inventory. M opens the map, I opens the inventory and Escape opens the menu. Space skips a turn. F5 saves, F9 loads and F2 switches graphics.",
	"2:2":"HOW TO MOVE\nW / Up: move forward\nS / Down: move back\nA / Left: turn left\nD / Right: turn right\nZ / C: step sideways\n\nThe on-screen arrows perform the same actions. In menus, use Up / Down to choose, Enter to select and Escape to go back.",
	"2:3":"HOW TO ATTACK\nPress Enter or the sword button to attack, talk or use an object. Q and E select the previous and next weapon. The weapon button also cycles weapons. Press Space or the hourglass to skip a turn.",
	"2:7":"LOCK PICKING\nFace a lock and press Enter or the sword button. Choose a direction with the arrows or WASD. Press the same direction again to set the tumbler. Repeat until all tumblers are set.\n\nLOCKED OBJECTS\nChests and doors may open with lock picks, a key or a lever."
}

static func prepare() -> void:
	if not catalog.is_empty():return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://locales/ru.json"))
	catalog=parsed if parsed is Dictionary else {"texts":{},"templates":[],"ids":{},"phrases":[],"cases":{}}
	spaces=RegEx.create_from_string("\\s+")
	soft_hyphen=RegEx.create_from_string("(?<=[A-Za-z])-(?=[A-Za-z])")
	non_ascii=RegEx.create_from_string("[^\\x20-\\x7e\\n]")
	for source: String in catalog.texts:lowered[source.to_lower()]=catalog.texts[source]
	for entry: Dictionary in catalog.templates:
		var chunks: Array=[];var slots: Array[int]=[];var start:=0
		var args:=RegEx.create_from_string("%([1-6])").search_all(str(entry.en))
		for arg in args:
			chunks.append(escape_regex(str(entry.en).substr(start,arg.get_start()-start)))
			chunks.append("(.*?)");slots.append(int(arg.get_string(1)));start=arg.get_end()
		chunks.append(escape_regex(str(entry.en).substr(start)))
		patterns.append({"regex":RegEx.create_from_string("(?i)^"+"".join(chunks)+"$"),"slots":slots,"ru":str(entry.ru),"multiline":entry.get("multiline",false)})

static func escape_regex(text: String) -> String:
	var out: String=""
	for c in text:
		if c in "\\.^$|?*+()[]{}":out+="\\"
		out+=c
	return out

static func normalized(text: String) -> String:
	prepare()
	text=text.replace("-\n","").replace("|","\n").replace("@","")
	text=soft_hyphen.sub(text,"",true);text=non_ascii.sub(text,"",true)
	return spaces.sub(text," ",true).strip_edges()

static func entry(id: String) -> String:
	prepare();var item: Dictionary=catalog.ids.get(id,{})
	if language=="en" and HELP_EN.has(id):return str(HELP_EN[id])
	return str(item.get("ru" if language=="ru" else "en","")).replace("@","").replace("€","")

static func inflect(text: String, grammatical_case: String, sentence_start: bool=false) -> String:
	if grammatical_case.is_empty():return text
	var forms: Dictionary=catalog.cases.get(text.to_lower(),{})
	var result: String=str(forms.get(grammatical_case,text))
	if sentence_start and not text.is_empty() and text[0]==text[0].to_upper():result=result.left(1).to_upper()+result.substr(1)
	return result

static func expand_native_help(text: String) -> String:
	# The phone UI cuts descriptions at a word and appends its 0x7f glyph.
	# Recover only a unique complete resource, never guess an arbitrary prefix.
	if not text.contains("\u007f") and not text.contains("…"):return text
	if help_cache.has(text):return str(help_cache[text])
	prepare();var prefix:=normalized(text).to_lower();var found: String=""
	if prefix.length()<16:return text
	for phrase: String in catalog.phrases:
		if phrase.to_lower().begins_with(prefix):
			if not found.is_empty():return text
			found=phrase
	if help_cache.size()>2048:help_cache.clear()
	help_cache[text]=found if not found.is_empty() else text
	return str(help_cache[text])

static func translate(text: String, depth: int=0) -> String:
	if text.is_empty() or depth>6:return text
	if text.strip_edges().begins_with("✓"):return "✓ "+translate(text.strip_edges().substr(1).strip_edges(),depth+1)
	prepare()
	# Our own Russian UI labels are already localized; don't reinterpret them.
	for c in text:
		if c.unicode_at(0)>=0x400 and c.unicode_at(0)<=0x52f:return text
	text=expand_native_help(text)
	var key: String=normalized(text)
	if ru_cache.has(key):return str(ru_cache[key])
	var result: String=str(catalog.texts.get(key,lowered.get(key.to_lower(),"")))
	if result.is_empty():
		for rule: Dictionary in patterns:
			if (text.strip_edges().contains("\n") or text.strip_edges().contains("|")) and not rule.multiline:continue
			var found: RegExMatch=rule.regex.search(key)
			if found==null:continue
			var args: Dictionary={}
			for i in rule.slots.size():args[rule.slots[i]]=translate(found.get_string(i+1),depth+1)
			result=str(rule.ru)
			var tokens:=RegEx.create_from_string("%([1-6])(?:\\{(acc|dat)\\})?").search_all(result)
			for i in range(tokens.size()-1,-1,-1):
				var token: RegExMatch=tokens[i]
				var value:=inflect(str(args.get(int(token.get_string(1)),token.get_string())),token.get_string(2),token.get_start()==0)
				result=result.substr(0,token.get_start())+value+result.substr(token.get_end())
			break
	if result.is_empty():
		# Native tutorials combine a title with a phone-wrapped resource body.
		# Match complete resource paragraphs across those artificial line breaks.
		for phrase: String in catalog.phrases:
			if phrase.length()<32 or phrase.length()>key.length():continue
			var at:=key.to_lower().find(phrase.to_lower())
			if at<0:continue
			if at>0 and key[at-1] not in " :;.,!?\"()[]":continue
			var end:=at+phrase.length()
			if end<key.length() and key[end] not in " :;.,!?\"()[]":continue
			var parts: Array[String]=[]
			if at>0:parts.append(translate(key.left(at).strip_edges(),depth+1))
			parts.append(str(catalog.texts[phrase]))
			if end<key.length():parts.append(translate(key.substr(end).strip_edges(),depth+1))
			result="\n".join(parts);break
	if result.is_empty() and (text.contains("\n") or text.contains("|")):
		var lines: Array[String]=[]
		for line in text.replace("-\n","").replace("|","\n").split("\n"):lines.append(translate(line,depth+1))
		result="\n".join(lines)
	if result.is_empty():
		var suffix:=RegEx.create_from_string("^(.+?) [x×]([0-9]+)$").search(key)
		if suffix!=null:
			var name:=translate(suffix.get_string(1),depth+1)
			if name!=suffix.get_string(1):result=name+" ×"+suffix.get_string(2)
	if result.is_empty():
		# Numeric inventory quantities are a presentation format, not grammar.
		var quantity:=RegEx.create_from_string("^([+\\-]?[0-9]+)x? +(.+)$").search(key)
		if quantity!=null:
			var name:=translate(quantity.get_string(2),depth+1)
			if name!=quantity.get_string(2):result=quantity.get_string(1)+" × "+name
	if result.is_empty():
		# Store results join separately translated native resources into one row.
		for phrase: String in catalog.phrases:
			if key.to_lower().begins_with(phrase.to_lower()+" "):
				result=str(catalog.texts[phrase])+" "+translate(key.substr(phrase.length()+1),depth+1)
				break
	if result.is_empty():
		result=text
		# Native builders sometimes concatenate catalog fragments (speaker/log lines).
		for phrase: String in catalog.phrases:
			if result.contains(phrase):result=result.replace(phrase,str(catalog.texts[phrase]))
		if result==text:
			var colon:=text.find(": ")
			if colon>0:result=translate(text.left(colon),depth+1)+": "+translate(text.substr(colon+2),depth+1)
	if ru_cache.size()>8192:ru_cache.clear()
	ru_cache[key]=result
	return result

static func translate_state(value: Variant, field: String="") -> Variant:
	if language=="en":return value
	if value is Dictionary:
		var result: Dictionary={}
		for key: String in value:result[key]=translate_state(value[key],key)
		return result
	if value is Array:
		var result: Array=[]
		for item in value:result.append(translate_state(item,field))
		return result
	if value is String and field in ["text","help","value","dialogue","left","right","context","notices","cinematic","weapon_name","name","travel_name","stats","target_name","events","level_name","dialog_speaker","dialog_title","ring_name","ring_description"]:return translate(str(value))
	return value

static func merge_menu_text(items: Array) -> Array:
	# Confirmation text was wrapped for a 176 px phone before reaching this UI.
	var result: Array=[]
	for source: Dictionary in items:
		if (int(source.flags)&1)!=0 and not result.is_empty() and (int(result[-1].flags)&1)!=0:
			var previous: String=str(result[-1].text)
			result[-1].text=previous.trim_suffix("-")+str(source.text) if previous.ends_with("-") else previous+" "+str(source.text)
		else:result.append(source.duplicate())
	return result
