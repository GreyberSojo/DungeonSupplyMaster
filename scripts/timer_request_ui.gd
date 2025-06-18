extends PanelContainer

func _process(delta):
	var timer = get_node("Timer")
	var progress = get_node("VBox/ProgressBar")
	if timer and progress:
		# La ProgressBar se llena a medida que pasa el tiempo
		progress.value = timer.time_left
