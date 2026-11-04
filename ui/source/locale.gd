class_name OEText
extends RefCounted
## UI-only localization. BREW game text comes from its original resources.
static var language: String="ru"
const UI={
	"ВЗЛОМ ЗАМКА":"PICK LOCK","Вверх":"Up","Вниз":"Down","Влево":"Left","Вправо":"Right","Попытки":"Attempts","Отменить взлом":"Cancel lockpicking",
	"Выберите направление. Верное направление подтвердите повторным нажатием.":"Choose a direction. Confirm a correct direction by pressing it again.","БЫСТРЫЕ ДЕЙСТВИЯ":"QUICK ACTIONS",
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
const BREW_MENUS={"Choose Game Mode:":"Выберите сложность:","Difficult":"Сложно","Inventory":"Рюкзак","Quest Log":"Дневник заданий","View Map":"Карта","Status":"Персонаж","Help/About":"Помощь / Об игре","More Games":"Другие игры","Restart Level":"Начать уровень заново","Save & Quit":"Сохранить и выйти","Enable Sounds?":"Включить звук?","Yes":"Да","No":"Нет","New Game":"Новая игра","Load Game":"Загрузить игру","Save Game":"Сохранить игру","Continue":"Продолжить","Options":"Настройки","Help":"Помощь","Exit":"Выход","Credits":"Создатели","Back":"Назад","Select":"Выбрать","Sound":"Звук","Easy":"Легко","Normal":"Обычно","Hard":"Сложно","Nightmare":"Кошмар","Main Menu":"Главное меню","Resume Game":"Продолжить игру"}
static func choose(value: String) -> void:
	language="en" if value=="en" else "ru"
static func localize(text: String) -> String:
	if language=="en": return str(UI.get(text,{"Да":"Yes","Нет":"No"}.get(text,text)))
	return str(BREW_MENUS.get(text.strip_edges(),text))
