extends CanvasLayer

@export var cars: car
@export var speed: Label
@export var litr: Label

func _process(delta):
	var speed_car = "%d км/ч" % (cars.current_speed*1.5)
	speed.text = speed_car
	
	var litr_car = "%d литров" % cars.current_fuel
	litr.text = litr_car
