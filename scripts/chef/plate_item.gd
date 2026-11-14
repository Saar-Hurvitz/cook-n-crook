## PlateItem.gd
## Helpers for items on the chef's serve plate and prep stations.
## Each item tracks an ingredient with a prep state, or a combined cooked group.
class_name PlateItem
extends RefCounted

const PREP_RAW := "raw"
const PREP_CUT := "cut"
const PREP_COOKED := "cooked"


## One pantry ingredient with an optional prep state (defaults to raw).
static func single(ingredient_id: String, prep: String = PREP_RAW) -> Dictionary:
	return {"ingredient": ingredient_id, "prep": prep, "combined": false}


## Several ingredients cooked together as one plate entry.
static func combined(parts: Array) -> Dictionary:
	return {"combined": true, "parts": parts.duplicate(true), "prep": PREP_COOKED}


## Stable string token used to compare plate contents against a dish recipe.
static func token(item: Dictionary) -> String:
	if item.get("combined", false):
		var bits: Array[String] = []
		for part in item.get("parts", []):
			bits.append("%s:%s" % [String(part.get("ingredient", "")), String(part.get("prep", PREP_RAW))])
		bits.sort()
		return "combined:" + "|".join(bits)
	return "%s:%s" % [String(item.get("ingredient", "")), String(item.get("prep", PREP_RAW))]


## Sorted multiset of tokens for an entire plate.
static func tokens_from_plate(plate: Array) -> Array[String]:
	var out: Array[String] = []
	for item in plate:
		out.append(token(item))
	out.sort()
	return out


## True when two token lists contain the same entries (order ignored).
static func tokens_match(a: Array[String], b: Array[String]) -> bool:
	if a.size() != b.size():
		return false
	var aa := a.duplicate()
	var bb := b.duplicate()
	aa.sort()
	bb.sort()
	return aa == bb
