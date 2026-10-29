extends RefCounted
class_name InvestigationRules

static func can_open_file(evidence: Dictionary) -> bool:
 return evidence.has("terminal")

static func access_message(destination: String, evidence: Dictionary, decisions: Dictionary) -> String:
 if destination == "records" and not evidence.has("camera") and int(decisions.get("guard_trust", 0)) <= 0:
  return "غرفة السجلات مغلقة. وثّق كاميرا الممر، أو اطلب مساعدة الحارس."
 if destination == "maintenance" and not evidence.has("antenna") and decisions.get("phone_secret") != false:
  return "باب الصيانة لا يفتح. وثّق هوائي السطح أولًا."
 return ""

static func outcome(guard_trust: int, phone_secret: Variant, choice: String) -> String:
 var lines: Array[String] = [choice]
 if guard_trust > 0:
  lines.append("الحارس يساعدك على الهرب.")
 elif guard_trust < 0:
  lines.append("الحارس يبلغ الإدارة عنك.")
 else:
  lines.append("لا أحد ينتظرك عند الباب.")
 if phone_secret == null:
  lines.append("لم تحسم مصير الرسالة؛ بقيت على الهاتف.")
 elif phone_secret:
  lines.append("تظل الرسالة سرية، وتحتفظ برمز لم يصل إلى الإدارة.")
 else:
  lines.append("تصل الرسالة إلى الإدارة، لكن ردها يكشف طريقًا إلى جهاز التسجيل.")
 return "\n".join(lines)
