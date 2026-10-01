extends VBoxContainer
## Local standings read their immutable records without external services.
var hud: Control

func _ready() -> void:
	name = "LeaderboardPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	var old: bool = hud._building_dialog
	hud._building_dialog = true
	var count := 0
	for record in hud.game.leaderboard.rows:
		if not record.eligible: continue
		count += 1
		hud.text_label(self,"leaderboard.row",18,{"rank":count,"name":record.name if record.name != "" else hud.t("ui.player"),"score":int(record.score)})
		hud.text_label(self,"leaderboard.row_detail",13,{"seconds":int(record.duration),"outcome":hud.t("leaderboard."+record.outcome)})
	if count == 0: hud.text_label(self,"leaderboard.empty",18)
	hud._building_dialog = old
