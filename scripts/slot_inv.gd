extends PanelContainer

@export var item : Item:
	set(value):
		item = value
		$Icon.texture = item.icon
