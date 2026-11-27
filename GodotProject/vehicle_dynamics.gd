extends RefCounted

# Fictional game tuning. These are not measured vehicle specifications.
var body: VehicleBody3D
var wheels: Array[VehicleWheel3D]=[]
var is_van := false
var throttle := 0.0
var steering := 0.0
var brake_pressure := 0.0
var speed_kmh := 0.0
var gear := 0
var contact_count := 0
var suspension_load := 0.0
var surface := "ASPHALT"

const GRIP := {"ASPHALT":3.0,"GRAVEL":1.9,"SOIL":1.65,"GRASS":1.45,"MUD":0.95,"SNOW":0.72}
const RESISTANCE := {"ASPHALT":0.016,"GRAVEL":0.035,"SOIL":0.045,"GRASS":0.055,"MUD":0.12,"SNOW":0.08}

func configure(car: VehicleBody3D,van: bool) -> void:
	body=car
	is_van=van
	body.mass=2200.0 if van else 1850.0
	body.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass=Vector3(0,-0.10 if van else -0.18,0.08)
	body.linear_damp=0.08
	body.angular_damp=0.65
	body.can_sleep=false
	for child in body.get_children():
		if child is VehicleWheel3D:
			var wheel := child as VehicleWheel3D
			wheels.append(wheel)
			wheel.wheel_radius=0.43
			wheel.wheel_rest_length=0.30 if van else 0.27
			wheel.suspension_travel=0.25
			wheel.suspension_stiffness=30.0 if van else 27.0
			wheel.damping_compression=3.8 if van else 3.4
			wheel.damping_relaxation=4.8 if van else 4.4
			wheel.suspension_max_force=12000.0
			wheel.wheel_friction_slip=3.0

func step(dt: float,move: Vector2,stop: bool,terrain: Node3D, wet := false) -> void:
	var forward := body.global_transform.basis.z.normalized()
	var signed_speed := body.linear_velocity.dot(forward)
	var speed := absf(signed_speed)
	speed_kmh=speed*3.6
	var desired := -move.y
	var reverse_brake := absf(desired)>0.08 and desired*signed_speed < -0.9
	var request_brake := stop or reverse_brake
	throttle=move_toward(throttle,0.0 if request_brake else desired,dt*(2.2 if absf(desired)<0.05 else 1.5))
	brake_pressure=move_toward(brake_pressure,1.0 if request_brake else 0.0,dt*5.0)
	var steer_limit := lerpf(0.52,0.16,smoothstep(3.0,24.0,speed))
	steering=move_toward(steering,-move.x*steer_limit,dt*1.15)
	body.steering=steering
	surface=terrain.surface_at(body.position.x,body.position.z)
	contact_count=0
	var rolling := 0.0
	var load_sum := 0.0
	for wheel in wheels:
		var p := wheel.global_position
		if wheel.is_in_contact():
			p=wheel.get_contact_point()
			contact_count+=1
			load_sum+=clampf(1.0-wheel.get_skidinfo(),0.0,1.0)
		var kind: String=terrain.surface_at(p.x,p.z)
		var grip: float=GRIP.get(kind,1.5)
		wheel.wheel_friction_slip=move_toward(wheel.wheel_friction_slip,grip*(0.71 if wet else 1.0),dt*5.0)
		rolling+=float(RESISTANCE.get(kind,0.05))
	suspension_load=load_sum/maxf(float(contact_count),1.0)
	var speed_limit := 26.0 if is_van else 32.0
	if throttle<0:
		speed_limit=7.0
	var torque_falloff := 1.0-smoothstep(speed_limit*0.65,speed_limit,speed)
	var drive := 2900.0 if is_van else 3150.0
	body.engine_force=0.0 if request_brake else throttle*drive*torque_falloff
	body.brake=brake_pressure*42.0
	if not request_brake and absf(desired)<0.04:
		body.brake=0.8
	if contact_count>0 and speed>0.15:
		var drag := rolling/maxf(float(wheels.size()),1.0)*body.mass*9.81+0.46*speed*speed
		drag=minf(drag,body.mass*speed/maxf(dt,0.001))
		body.apply_central_force(-forward*signf(signed_speed)*drag)
	gear=0 if speed<0.4 and absf(throttle)<0.05 else -1 if signed_speed < -0.4 or throttle < -0.05 else clampi(int(speed_kmh/22.0)+1,1,5)
