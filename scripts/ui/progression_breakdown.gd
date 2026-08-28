class_name ProgressionBreakdown
extends RefCounted

## Filas de XP, nivel y logros para la pantalla de resultados.
##
## Devuelve el mismo tipo de fila que ScoreBreakdown, asi que la pantalla las
## dibuja sin distinguir de donde salen: el puntaje cuenta la partida, esto
## cuenta lo que la partida le dejo al jugador.


## Devuelve [{"label": String, "value": String, "kind": ScoreBreakdown.Kind}].
## `next_level_name` es el nombre del nivel que se abrio, si se abrio uno.
static func rows_for(report: Dictionary, next_level_name := "") -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if report.is_empty():
		return rows
	rows.append({"label": "", "value": "", "kind": ScoreBreakdown.Kind.SEPARATOR})
	rows.append(_row(_t("XP_GAINED"), _t("XP_VALUE").format({"xp": ScoreBreakdown.thousands(int(report.get("xp_earned", 0)))}), ScoreBreakdown.Kind.TOTAL))
	if bool(report.get("leveled_up", false)):
		rows.append(_row(_t("LEVELUP_ROW"), _t("LEVELUP_ROW_VALUE").format({
			"from": str(report.get("level_name_before", "")),
			"to": str(report.get("level_name", "")),
		}), ScoreBreakdown.Kind.RECORD))
	else:
		var progress: Dictionary = report.get("progress", {})
		if not progress.is_empty():
			rows.append(_row(_t("XP_NEXT_ROW"), _t("XP_NEXT_LEVEL").format({
				"xp": ScoreBreakdown.thousands(int(progress.get("remaining", 0))),
				"name": str(progress.get("next_name", "")),
			})))
	for badge_variant in report.get("badges", []):
		var badge := badge_variant as Dictionary
		rows.append(_row(_t("BADGE_ROW"), AchievementCatalog.display_name(badge), ScoreBreakdown.Kind.RECORD))
	if bool(report.get("first_clear", false)) and not next_level_name.is_empty():
		rows.append(_row(_t("LEVELUP_UNLOCKED"), next_level_name, ScoreBreakdown.Kind.RECORD))
	return rows


## Texto de un motivo de XP. Sin traduccion se muestra el motivo en crudo.
static func reason_text(reason: String) -> String:
	var key := "XP_REASON_%s" % reason.to_upper()
	var translated := _t(key)
	return reason.capitalize() if translated == key else translated


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


static func _row(label: String, value: String, kind := ScoreBreakdown.Kind.ROW) -> Dictionary:
	return {"label": label, "value": value, "kind": kind}
