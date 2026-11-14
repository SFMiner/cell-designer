class_name Announcer
extends Node
## Mirrors significant game events to the hidden live regions in web/shell.html, so a screen reader
## has something to read. Reduced from data-detectives' announcer (same shell contract, renamed hook).
## Outside a web export it only records what would have been said. Not yet tested with a screen reader.

# === CONSTANTS ===
const HISTORY_SIZE: int = 30

# === PUBLIC VARIABLES ===
## The last messages sent, newest last: {"text", "assertive"}. Read by tests.
var history: Array[Dictionary] = []


# === PUBLIC METHODS ===
## Polite announcement (waits for the screen reader to finish).
func say(text: String) -> void:
	_send(text, false)


## Urgent announcement (interrupts): failures and blocked actions.
func alert(text: String) -> void:
	_send(text, true)


func last_text() -> String:
	return "" if history.is_empty() else str(history[-1]["text"])


# === PRIVATE METHODS ===
func _send(text: String, assertive: bool) -> void:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return
	history.append({"text": clean, "assertive": assertive})
	while history.size() > HISTORY_SIZE:
		history.pop_front()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.cdAnnounce) window.cdAnnounce(%s, %s)" % [JSON.stringify(clean),
			"true" if assertive else "false"])
