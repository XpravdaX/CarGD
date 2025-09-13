extends Node3D
class_name TrafficSign

@export_category("Цвета светофора")
@export var lightRed: OmniLight3D
@export var lightYellow: OmniLight3D
@export var lightGreen: OmniLight3D

@export_category("Настройки длительности сигналов (в секундах)")
@export var red_duration: float = 30.0
@export var red_yellow_duration: float = 2.0
@export var yellow_duration: float = 3.0 
@export var green_duration: float = 30.0

@export_category("Настройки интенсивности света")
@export var light_intensity: float = 10.0
@export var light_energy_off: float = 0.0
@export var light_energy_on: float = 5.0

@export_category("Начальное состояние")
@export var start_with_green: bool = false # Если true - начинает с зеленого, false - с красного
@export var emergency_mode: bool = false  # Если true - мигающий желтый, false - нормальный режим

# Таймер для управления светофором
var timer: Timer
var current_state: String = "red"
var yellow_blink_state: bool = false  # Для мигания желтым

func _ready():
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	
	_setup_lights()
	
	if emergency_mode:
		_start_emergency_mode()
	else:
		if start_with_green:
			_switch_to_green()
		else:
			_switch_to_red()

func _setup_lights():
	if lightRed:
		lightRed.light_energy = light_energy_off
	if lightYellow:
		lightYellow.light_energy = light_energy_off
	if lightGreen:
		lightGreen.light_energy = light_energy_off

func _start_emergency_mode():
	current_state = "emergency"
	_blink_yellow()
	timer.start(0.5)

func _blink_yellow():
	yellow_blink_state = !yellow_blink_state
	_set_lights(false, yellow_blink_state, false)

func _switch_to_red():
	current_state = "red"
	_set_lights(true, false, false)
	timer.start(red_duration)

func _switch_to_red_yellow():
	current_state = "red_yellow"
	_set_lights(true, true, false)
	timer.start(red_yellow_duration)

func _switch_to_green():
	current_state = "green"
	_set_lights(false, false, true)
	timer.start(green_duration)

func _switch_to_yellow():
	current_state = "yellow"
	_set_lights(false, true, false)
	timer.start(yellow_duration)

func _set_lights(red: bool, yellow: bool, green: bool):
	if lightRed:
		lightRed.light_energy = light_energy_on if red else light_energy_off
	if lightYellow:
		lightYellow.light_energy = light_energy_on if yellow else light_energy_off
	if lightGreen:
		lightGreen.light_energy = light_energy_on if green else light_energy_off

func _on_timer_timeout():
	if emergency_mode:
		_blink_yellow()
		timer.start(0.5)
	else:
		match current_state:
			"red":
				_switch_to_red_yellow()
			"red_yellow":
				_switch_to_green()
			"green":
				_switch_to_yellow()
			"yellow":
				_switch_to_red()
