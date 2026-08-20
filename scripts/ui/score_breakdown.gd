class_name ScoreBreakdown
extends RefCounted

## Desglose del puntaje de un nivel, en filas listas para mostrar.
##
## El resumen se lee en dos lugares: el panel chico del HUD y la pantalla de
## resultados. Que el orden y el formato de las filas salgan de un solo lugar
## evita que las dos pantallas cuenten historias distintas del mismo intento.

enum Kind { ROW, TOTAL, RECORD, SEPARATOR }


## Devuelve [{"label": String, "value": String, "kind": Kind}].
static func rows_for(summary: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry_variant in summary.get("bonuses", []):
		var entry := entry_variant as Dictionary
		rows.append(_row(str(entry.label), "+%s" % thousands(int(entry.points))))
	rows.append({"label": "", "value": "", "kind": Kind.SEPARATOR})
	rows.append(_row("TOTAL", thousands(int(summary.total)), Kind.TOTAL))
	var ceiling := int(summary.get("ceiling", 0))
	if ceiling > 0:
		rows.append(_row("LEVEL CEILING", "%s   %d%%" % [thousands(ceiling), roundi(float(summary.ratio) * 100.0)]))
	rows.append(_row("BEST CHAIN", "%d HITS   x%.1f" % [int(summary.best_chain), float(summary.best_multiplier)]))
	rows.append(_row("BIGGEST BANK", thousands(int(summary.best_bank))))
	var record: Dictionary = summary.get("record", {})
	if bool(record.get("had_previous", false)):
		var delta := int(record.delta)
		rows.append(_row("PREVIOUS BEST", "%s   %s%s" % [thousands(int(record.previous)), "+" if delta >= 0 else "", thousands(delta)]))
	if bool(record.get("is_new", false)):
		rows.append(_row("NEW PERSONAL BEST", "", Kind.RECORD))
	return rows


static func title_for(summary: Dictionary) -> String:
	if bool(summary.get("completed", false)):
		return "LEVEL COMPLETE"
	return "RUN FAILED // %s" % str(summary.get("reason", "")).to_upper()


## El rango solo tiene sentido en un nivel terminado: un intento cortado por el
## reloj no compite contra el techo.
static func rank_text(summary: Dictionary) -> String:
	if not bool(summary.get("completed", false)):
		return ""
	var rank: Dictionary = summary.get("rank", {})
	return "RANK %s - %s" % [str(rank.get("letter", "-")), str(rank.get("label", ""))]


static func thousands(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = " " + grouped
	return "-" + grouped if value < 0 else grouped


static func _row(label: String, value: String, kind := Kind.ROW) -> Dictionary:
	return {"label": label, "value": value, "kind": kind}
