extends RefCounted
## Local duel constants and profile-name validation.
const SNAPSHOT_HZ := 20.0
const MATCH_SECONDS := 180.0
const COUNTDOWN_SECONDS := 3.0
const AIM_MIN := 415.0
const AIM_MAX := 1025.0
const MAX_PLAYER_NAME_LENGTH := 20

static func normalize_player_name(value: Variant) -> String:
	if not value is String:
		return ""
	var normalized := ""
	for character in value:
		var code: int = character.unicode_at(0)
		normalized += " " if code < 32 or code == 127 else character
	return normalized.strip_edges().left(MAX_PLAYER_NAME_LENGTH)
