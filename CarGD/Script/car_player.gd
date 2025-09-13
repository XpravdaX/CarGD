extends VehicleBody3D
class_name car

@export_category("Настройка управления")
@export var MAX_STEER_ANGLE: float = 0.6
@export var STEER_SPEED: float = 0.8
@export var HANDBRAKE_FORCE: float = 50.0
@export var BRAKE_FORCE: float = 20.0

@export_category("Настройка двигателя")
@export var MAX_ENGINE_POWER: float = 400.0
@export var MAX_RPM: float = 8000.0
@export var IDLE_RPM: float = 1000.0
@export var RPM_RESPONSE: float = 0.3

@export_category("Настройка топлива")
@export var FUEL_TANK_CAPACITY: float = 50.0
@export var FUEL_CONSUMPTION: float = 25.25
var current_fuel: float = FUEL_TANK_CAPACITY
var distance_traveled: float = 0.0
var fuel_consumption_rate: float = 0.0

@export_category("Настройка коробки передач")
enum Gear {NEUTRAL, REVERSE, FIRST, SECOND, THIRD, FOURTH, FIFTH}
@export var current_gear: Gear = Gear.FIRST
var gear_speeds = {
	Gear.REVERSE: {"max_speed": 20, "power_mult": 3.6},
	Gear.FIRST: {"max_speed": 20, "power_mult": 3.6},
	Gear.SECOND: {"max_speed": 40, "power_mult": 3.0},
	Gear.THIRD: {"max_speed": 60, "power_mult": 2.5},
	Gear.FOURTH: {"max_speed": 90, "power_mult": 2.2},
	Gear.FIFTH: {"max_speed": 120, "power_mult": 2.0}
}

@export_category("Настройка света")
@export var lightF: Array[Node3D] = []
@export var lightZ: Array[OmniLight3D] = []
@export var lightPovorotnikL: Array[Node3D] = []
@export var lightPovorotnikR: Array[Node3D] = []

@export_category("Настройка звука")
@export var engine_sound: AudioStreamPlayer3D
@export var min_pitch: float = 0.5
@export var max_pitch: float = 2.0
@export var min_volume: float = -10.0
@export var max_volume: float = 0.0

@export_category("Полёт")
@export var wheel:Array[Node3D] = []

# Настройки освещения
var headlights_on: bool = false
var left_blinker_on: bool = false
var right_blinker_on: bool = false
var hazard_lights_on: bool = false
var brake_lights_on: bool = false
var blinker_timer: float = 0.0
var blinker_interval: float = 0.5
var blinker_state: bool = false

var current_speed: float = 0.0
var engine_rpm: float = IDLE_RPM
var handbrake_active: bool = false
var break_pressed: bool = false
var is_moving_forward: bool = true
var engine_running: bool = true

func _ready():
	_update_headlights()
	_update_brake_lights()
	_update_blinkers()
	if engine_sound:
		engine_sound.play()

func _physics_process(delta):
	if current_fuel <= 0:
		engine_running = false
		engine_force = 0.0
		engine_rpm = 0.0
		if engine_sound:
			engine_sound.volume_db = min_volume
		return
	
	var steer_input = Input.get_axis("D", "A")
	steering = move_toward(steering, steer_input * MAX_STEER_ANGLE, delta * STEER_SPEED)
	
	var throttle_input = Input.get_axis("W", "S")
	var forward_velocity = linear_velocity.dot(-transform.basis.z)
	current_speed = abs(forward_velocity) * 3.6
	is_moving_forward = forward_velocity > 0
	
	distance_traveled += (current_speed / 3600.0) * delta
	
	_update_fuel_consumption(delta)
	
	_handle_handbrake()
	
	_handle_light_controls()
	
	_update_blinker_animation(delta)
	
	if not handbrake_active and engine_running:
		_auto_shift_gear()
		_handle_engine(throttle_input, delta)
		
		if Input.is_action_pressed("S") and is_moving_forward and current_speed > 1.0:
			brake = BRAKE_FORCE * throttle_input
			engine_force = 0.0
			brake_lights_on = true
		elif throttle_input == 0 and current_speed > 10.0:
			brake = 8.0
			brake_lights_on = true
		else:
			brake = 0.0
			brake_lights_on = false
	else:
		brake = HANDBRAKE_FORCE
		engine_force = 0.0
		engine_rpm = lerp(engine_rpm, IDLE_RPM, delta * 2.0)
		brake_lights_on = handbrake_active
	
	_update_brake_lights()
	
	_update_engine_sound(delta)

func _update_engine_sound(delta):
	if not engine_sound:
		return
	
	if not engine_running:
		engine_sound.volume_db = lerp(engine_sound.volume_db, min_volume, delta * 2.0)
		return
	
	var rpm_ratio = clamp(engine_rpm / MAX_RPM, 0.0, 1.0)
	
	engine_sound.pitch_scale = lerp(min_pitch, max_pitch, rpm_ratio)
	
	var throttle_input = Input.get_axis("W", "S")
	var target_volume = lerp(min_volume, max_volume, rpm_ratio * abs(throttle_input))
	
	if rpm_ratio > 0.1 or abs(throttle_input) > 0.1:
		engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume, delta * 5.0)
	else:
		engine_sound.volume_db = lerp(engine_sound.volume_db, min_volume + 5.0, delta * 2.0)

func _update_fuel_consumption(delta):
	var consumption_factor = clamp(engine_rpm / MAX_RPM, 0.2, 1.5)
	var distance_km = (current_speed / 3600.0) * delta
	var fuel_used = (FUEL_CONSUMPTION ) * distance_km * consumption_factor
	
	current_fuel -= fuel_used
	current_fuel = max(current_fuel, 0.0)
	
	fuel_consumption_rate = FUEL_CONSUMPTION * consumption_factor

func _handle_engine(throttle_input, delta):
	if current_gear == Gear.NEUTRAL:
		engine_rpm = lerp(engine_rpm, IDLE_RPM, delta * 2.0)
		engine_force = 0.0
		return
	
	if throttle_input < 0 and current_gear >= Gear.FIRST:
		var gear_data = gear_speeds[current_gear]
		var speed_ratio = current_speed / gear_data["max_speed"]
		
		engine_rpm = lerp(engine_rpm, 
						 IDLE_RPM + (-throttle_input) * (MAX_RPM - IDLE_RPM), 
						 delta * RPM_RESPONSE)
		
		if speed_ratio < 1.0:
			engine_force = throttle_input * MAX_ENGINE_POWER * gear_data["power_mult"]
		else:
			engine_force = 0.0
	
	elif throttle_input > 0 and current_gear == Gear.REVERSE:
		var speed_ratio = current_speed / gear_speeds[Gear.REVERSE]["max_speed"]
		
		engine_rpm = lerp(engine_rpm, 
						 IDLE_RPM + throttle_input * (MAX_RPM - IDLE_RPM), 
						 delta * RPM_RESPONSE)
		
		if speed_ratio < 1.0:
			engine_force = throttle_input * MAX_ENGINE_POWER * gear_speeds[Gear.REVERSE]["power_mult"]
		else:
			engine_force = 0.0
	
	else:
		engine_rpm = lerp(engine_rpm, IDLE_RPM, delta * 2.0)
		engine_force = 0.0

func _auto_shift_gear():
	if Input.is_action_pressed("Break"):
		return
	
	if Input.is_action_pressed("S") and current_speed < 1.0:
		current_gear = Gear.REVERSE
		return
	
	if current_gear == Gear.REVERSE and Input.is_action_pressed("W"):
		current_gear = Gear.FIRST
		return
	
	if current_gear >= Gear.FIRST and current_gear < Gear.FIFTH:
		var gear_data = gear_speeds[current_gear]
		if current_speed > gear_data["max_speed"] * 0.9:
			current_gear += 1
			engine_rpm = MAX_RPM * 0.6
	
	if current_gear > Gear.FIRST:
		var prev_gear_speed = gear_speeds[current_gear - 1]["max_speed"]
		if current_speed < prev_gear_speed * 0.6:
			current_gear -= 1
			engine_rpm = MAX_RPM * 0.8

func _handle_handbrake():
	if Input.is_action_pressed("Break") and not break_pressed:
		handbrake_active = not handbrake_active
		break_pressed = true
	elif not Input.is_action_pressed("Break"):
		break_pressed = false

func _handle_light_controls():
	if Input.is_action_just_pressed("L"):
		headlights_on = not headlights_on
		_update_headlights()

	if Input.is_action_just_pressed("F"):
		hazard_lights_on = not hazard_lights_on
		if hazard_lights_on:
			left_blinker_on = false
			right_blinker_on = false
		_update_blinkers()
	
	if Input.is_action_just_pressed("Q") and not hazard_lights_on:
		left_blinker_on = not left_blinker_on
		if left_blinker_on:
			right_blinker_on = false
			hazard_lights_on = false
		_update_blinkers()
	
	if Input.is_action_just_pressed("E") and not hazard_lights_on:
		right_blinker_on = not right_blinker_on
		if right_blinker_on:
			left_blinker_on = false
			hazard_lights_on = false
		_update_blinkers()

func _update_blinker_animation(delta):
	blinker_timer += delta
	if blinker_timer >= blinker_interval:
		blinker_timer = 0.0
		blinker_state = not blinker_state
		_update_blinker_visibility()

func _update_blinker_visibility():
	if hazard_lights_on or left_blinker_on or right_blinker_on:
		if (hazard_lights_on or left_blinker_on) and blinker_state:
			for light in lightPovorotnikL:
				if light is OmniLight3D:
					light.visible = true
				elif light is SpotLight3D:
					light.visible = true
				elif light is MeshInstance3D:
					light.visible = true
		else:
			for light in lightPovorotnikL:
				if light is OmniLight3D:
					light.visible = false
				elif light is SpotLight3D:
					light.visible = false
				elif light is MeshInstance3D:
					light.visible = false
		
		if (hazard_lights_on or right_blinker_on) and blinker_state:
			for light in lightPovorotnikR:
				if light is OmniLight3D:
					light.visible = true
				elif light is SpotLight3D:
					light.visible = true
				elif light is MeshInstance3D:
					light.visible = true
		else:
			for light in lightPovorotnikR:
				if light is OmniLight3D:
					light.visible = false
				elif light is SpotLight3D:
					light.visible = false
				elif light is MeshInstance3D:
					light.visible = false
	else:
		for light in lightPovorotnikL:
			if light is OmniLight3D:
				light.visible = false
			elif light is SpotLight3D:
				light.visible = false
			elif light is MeshInstance3D:
				light.visible = false
		for light in lightPovorotnikR:
			if light is OmniLight3D:
				light.visible = false
			elif light is SpotLight3D:
				light.visible = false
			elif light is MeshInstance3D:
				light.visible = false

func _update_headlights():
	for light in lightF:
		if light is OmniLight3D:
			light.visible = headlights_on
		elif light is SpotLight3D:
			light.visible = headlights_on
		elif light is MeshInstance3D:
			light.visible = headlights_on

func _update_brake_lights():
	for light in lightZ:
		if light is OmniLight3D:
			if brake_lights_on:
				light.light_energy = 2.0 
			else:
				light.light_energy = 0.5


func _update_blinkers():
	blinker_timer = 0.0
	blinker_state = true
	_update_blinker_visibility()

func refuel(amount: float):
	current_fuel = min(current_fuel + amount, FUEL_TANK_CAPACITY)

func get_fuel_info() -> Dictionary:
	return {
		"current": current_fuel,
		"capacity": FUEL_TANK_CAPACITY,
		"consumption": fuel_consumption_rate,
		"distance": distance_traveled
	}

func set_headlights(state: bool):
	headlights_on = state
	_update_headlights()

func set_hazard_lights(state: bool):
	hazard_lights_on = state
	_update_blinkers()

func set_left_blinker(state: bool):
	left_blinker_on = state
	_update_blinkers()

func set_right_blinker(state: bool):
	right_blinker_on = state
	_update_blinkers()
