extends RefCounted

static func ready_to_resolve(state) -> bool:
 return state.deductions.has("arrival_gap") and state.evidence.has("phone") and state.decisions.has("phone_secret")

static func objective(state) -> String:
 if state.chapter_flags.get("finished", false):
  return "اكتمل فصل الوصول. يمكنك مراجعة الأدلة أو العودة إلى القائمة."
 if not state.decisions.has("guard_trust"):
  return "تحدّث إلى الحارس لاستلام المفتاح. ليس عليك أن تثق به."
 if not state.chapter_flags.get("lift_ready", false):
  return "وثّق إعلان الصيانة وبطاقة التسجيل، ثم شغّل المصعد."
 if not state.evidence.has("phone"):
  return "استكشف الشقة 703. هناك هاتف يضيء فوق الطاولة."
 if not state.decisions.has("phone_secret"):
  return "احسم مصير الرسالة: احتفظ بها أو أرسلها إلى الإدارة."
 if not state.evidence.has("receipt"):
  return "اقرأ إيصال المفتاح في الشقة، وقارنه بما كُتب في الاستقبال."
 if not state.deductions.has("arrival_gap"):
  return "افتح دفتر التحقيق واربط بطاقة التسجيل بإيصال المفتاح."
 return "اختر لمن تكشف التناقض: الحارس في البهو، الجار في الممر، أو احتفظ به عند الظرف."

static func access(state, destination: String) -> String:
 if destination == "lift" and not state.decisions.has("guard_trust"):
  return "الحارس يناديك: مفتاحك ما زال هنا. تحدث إليه قبل الصعود."
 if destination == "hall" and state.room == "lift" and not state.chapter_flags.get("lift_ready", false):
  return "المصعد لا يعمل بعد. افحص لوحة التشغيل وقارن أوراق الاستقبال."
 return ""

static func matches(state, conditions: Dictionary) -> bool:
 for key in conditions:
  var parts := str(key).split(".", true, 1)
  var actual: Variant
  if parts[0] == "decision":
   actual = state.decisions.get(parts[1])
  elif parts[0] == "flag":
   actual = ready_to_resolve(state) if parts[1] == "ready" else state.chapter_flags.get(parts[1], false)
  elif parts[0] == "evidence":
   actual = state.evidence.has(parts[1])
  if actual != conditions[key]:
   return false
 return true

static func event(state, action: String, value: Variant = null) -> String:
 if state.mode != "chapter_one" or state.chapter_flags.get("finished", false):
  return "هذا الفصل مكتمل. يمكنك مراجعة الدفتر."
 match action:
  "intro":
   state.chapter_flags["arrived"] = true
  "code":
   if state.room != "lift":
    return "افحص لوحة المصعد أولًا."
   if not state.evidence.has("notice") or not state.evidence.has("visitor_log"):
    return "تحتاج إلى توثيق إعلان الصيانة وبطاقة التسجيل لفهم الرمز. يمكنك الرجوع إلى البهو."
   if str(value) != str(state.world["chapter_one"]["code"]):
    state.chapter_flags["code_attempts"] = int(state.chapter_flags.get("code_attempts", 0)) + 1
    state.persist()
    return "لم يستجب المصعد. الإعلان يطلب توقيت البطاقة بأربع خانات، دون النقطتين. لا توجد عقوبة للمحاولة."
   state.chapter_flags["lift_ready"] = true
   state.evidence["panel"] = true
  "neighbor":
   if state.room != "hall" or state.decisions.has("neighbor_response") or not value in ["question", "private"]:
    return "يمكنك متابعة الحديث عند باب الجار."
   state.decisions["neighbor_response"] = value
   state.evidence["neighbor"] = true
  "resolve":
   if not ready_to_resolve(state):
    return "وثّق الرسالة واحسم مصيرها، ثم اربط بطاقة التسجيل بإيصال المفتاح في الدفتر."
   var rooms := {"guard":"lobby", "neighbor":"hall", "private":"apartment"}
   if not rooms.has(value) or state.room != rooms[value]:
    return "اذهب إلى الشخصية التي تريد مواجهتها، أو إلى ظرف الشقة للاحتفاظ بالاستنتاج."
   state.decisions["chapter_resolution"] = value
   state.chapter_flags["finished"] = true
   state.chapter_result = ending(state)
  _:
   return "إجراء غير متاح."
 state._record("chapter_" + action, value)
 state.persist()
 return state.notice

static func ending(state) -> String:
 var lines: Array[String] = []
 match state.decisions.get("chapter_resolution", "private"):
  "guard":
   if int(state.decisions.get("guard_trust", 0)) > 0:
    lines.append(state.character(1) + " يقارن الورقتين ويسحب من جيبه نسخة أخرى من المفتاح: لا تفتح الباب إذا سمعت طرقًا مرتين.")
   else:
    lines.append(state.character(1) + " يرفض تسليم دفتر الزوار. خلفه يتصل هاتف الإدارة، فيتركك منتظرًا قبل أن يجيب.")
  "neighbor":
   lines.append(state.character(2) + " يفتح بابه كاملًا: لم أسألك عن الرسالة مصادفة. نسخة من هذه البطاقة ظهرت تحت بابي أمس.")
  "private":
   lines.append("تخفي الورقتين داخل الظرف. على ظهره، تحت الضوء، ترى آثار كتابة ممسوحة: لا تعد البطاقة إلى الاستقبال.")
 if state.decisions.get("phone_secret") == true:
  lines.append("يبقى الرمز م-17 بينك وبين صاحب الرسالة. تضيء الشاشة: «احتفظت بشيء لك هذه المرة». من عرف قرارك؟")
 else:
  lines.append("بسبب الرسالة التي أرسلتها، يأتيك اتصال من الإدارة: «موظفنا أمام الشقة الآن». تسمع طرقتين من آخر الممر.")
 lines.append("نهاية الفصل الأول — من استعمل اسمك قبل وصولك؟\nالفصول التالية قيد التطوير.")
 return "\n\n".join(lines)
