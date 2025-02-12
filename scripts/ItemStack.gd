# ItemStack.gd (Asegúrate de que el nombre del archivo es exactamente este)
# ItemStack.gd (Asegúrate de que la class_name coincide con el nombre del archivo)
class_name ItemStack

var item_data : ItemData
var quantity : int = 1

func _init(item_data_resource : ItemData):
	item_data = item_data_resource
