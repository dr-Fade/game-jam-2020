extends RichTextLabel

var START_MS = 0
var START_S = 0
var START_M = 2

var ms = START_MS
var s = START_S
var m = START_M

func reset_timer():
	ms=START_MS
	s=START_S
	m=START_M
	
func _process(delta):
	var menu = get_tree().get_root().get_node("Game").find_node("MenuOverlay")
	if menu.visible:
		return
	if ms <= 0 && s <= 0 && m <= 0:
		menu.visible = true
		menu.get_node("Label").text = "You lose!"
		menu.get_node("Continue").disabled = true
	
	if ms < 0:
		s -= 1
		ms = 9
	
	if s < 0:
		m -= 1
		s = 59
	
	set_text(str(m)+":"+str(s)+":"+str(ms))
	
func _on_Timer_timeout():
	ms-=1
