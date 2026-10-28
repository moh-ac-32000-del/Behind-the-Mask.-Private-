extends Control

# Prototype 0.2: text-first interactive vertical slice.
# Player-entered names and choices are stored only in user://.
const SAVE_PATH = "user://behind_the_mask_save.json"
const ROLES = ["مدير المبنى", "الحارس", "الجار", "الساكن المنعزل", "مسؤول السجلات", "الساكن المختفي"]
const DEFAULT_NAMES = ["سليم", "نادر", "ليان", "آدم", "رامي", "مروان"]

var state: Dictionary = {}
var names_input: Array[LineEdit] = []
var content: VBoxContainer

func _ready() -> void:
    _menu()

func _fresh_state() -> Dictionary:
    return {"version": 2, "player": "الزائر", "names": DEFAULT_NAMES.duplicate(), "scene": 0, "phone": "", "evidence": [], "decisions": [], "consent": false, "finished": false}

func _save() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(state))

func _load() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return false
    if int(parsed.get("version", 0)) != 2:
        return false
    state = parsed
    return true

func _layout(title: String) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    add_child(margin)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 12)
    scroll.add_child(content)
    _label(title, 28)

func _label(value: String, size: int = 20) -> void:
    var item := Label.new()
    item.text = value
    item.add_theme_font_size_override("font_size", size)
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(item)

func _button(label: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(0, 54)
    b.pressed.connect(callback)
    content.add_child(b)

func _menu() -> void:
    _layout("ما وراء القناع — المبنى رقم 17")
    _label("نموذج تفاعلي مبكر. القرارات هنا سردية وليست اختبارًا نفسيًا.", 17)
    _button("بدء جولة جديدة", _setup)
    if FileAccess.file_exists(SAVE_PATH):
        _button("متابعة", _resume)

func _resume() -> void:
    if _load():
        _scene()
    else:
        _menu()

func _setup() -> void:
    state = _fresh_state()
    _layout("اختر أسماء الشخصيات الرئيسية")
    _label("يمكنك ترك الأسماء الافتراضية. كل اسم يشغل دورًا رئيسيًا في القصة.", 17)
    var player_field := LineEdit.new()
    player_field.placeholder_text = "اسم اللاعب أو اسم مستعار"
    content.add_child(player_field)
    names_input.clear()
    for i in range(ROLES.size()):
        _label(ROLES[i], 16)
        var field := LineEdit.new()
        field.text = DEFAULT_NAMES[i]
        content.add_child(field)
        names_input.append(field)
    var consent := CheckBox.new()
    consent.text = "أوافق على حفظ سجل قرارات وصفي محليًا (اختياري)"
    content.add_child(consent)
    _button("الدخول إلى المبنى", func():
        state["player"] = player_field.text.strip_edges() if not player_field.text.strip_edges().is_empty() else "الزائر"
        var assigned: Array[String] = []
        for i in range(names_input.size()):
            var value := names_input[i].text.strip_edges()
            assigned.append(value if not value.is_empty() else DEFAULT_NAMES[i])
        state["names"] = assigned
        state["consent"] = consent.button_pressed
        _save()
        _scene()
    )

func _name(role: int) -> String:
    return str(state["names"][role])

func _record(choice: String) -> void:
    if bool(state.get("consent", false)):
        var decisions: Array = state["decisions"]
        decisions.append({"scene": state["scene"], "choice": choice})
        state["decisions"] = decisions
    _save()

func _advance(next_scene: int, choice: String) -> void:
    state["scene"] = next_scene
    _record(choice)
    _scene()

func _scene() -> void:
    var chapter := int(state.get("scene", 0))
    _layout("المبنى رقم 17")
    match chapter:
        0:
            _label("ليلة ممطرة. يستقبلك الحارس " + _name(1) + " في بهو المبنى ويسلمك مفتاح شقتك.")
            _button("اشكره واسأله عن السكان", func(): _advance(1, "asked_guard"))
            _button("خذ المفتاح واصعد مباشرة", func(): _advance(1, "went_upstairs"))
        1:
            _label("ترى هاتفًا منسيًا قرب مكتب الاستقبال. لا تعرف صاحبه.")
            _button("سلّم الهاتف للحارس", func(): _phone_choice("guard"))
            _button("احتفظ به للبحث عن صاحبه", func(): _phone_choice("keep"))
            _button("اتركه مكانه", func(): _phone_choice("leave"))
        2:
            _label("في الممر يقابلك الجار " + _name(2) + ". يسألك إن كنت قد رأيت هاتفًا مفقودًا.")
            _button("أخبره بما حدث", func(): _advance(3, "told_neighbor"))
            _button("اسأله أولًا لمن الهاتف", func(): _advance(3, "questioned_neighbor"))
        3:
            _label("في شقتك تسمع صوتًا خلف باب مغلق. تصلك رسالة: «لقد رأينا ما فعلته في الاستقبال».")
            _button("دوّن الرسالة في دفتر الأدلة", func(): _discover())
            _button("تجاهل الرسالة مؤقتًا", func(): _advance(4, "ignored_message"))
        4:
            _label("نهاية النموذج الأولي. ما حدث هنا هو بداية القصة، وليس تقريرًا عن شخصيتك.")
            _label("قرار الهاتف: " + str(state.get("phone", "غير محدد")), 16)
            _label("الأدلة: " + ", ".join(PackedStringArray(state.get("evidence", []))), 16)
            _button("العودة للقائمة", _menu)
        _:
            _button("العودة للقائمة", _menu)
    if chapter > 0 and chapter < 4:
        _button("عرض دفتر الأدلة", _notebook)

func _phone_choice(choice: String) -> void:
    state["phone"] = choice
    _advance(2, "phone_" + choice)

func _discover() -> void:
    var evidence: Array = state["evidence"]
    if not evidence.has("الرسالة الغامضة"):
        evidence.append("الرسالة الغامضة")
    state["evidence"] = evidence
    _advance(4, "saved_message")

func _notebook() -> void:
    _layout("دفتر الأدلة")
    var evidence: Array = state.get("evidence", [])
    _label("لم تُكتشف أدلة بعد." if evidence.is_empty() else "\n".join(PackedStringArray(evidence)))
    _button("عودة إلى القصة", _scene)
