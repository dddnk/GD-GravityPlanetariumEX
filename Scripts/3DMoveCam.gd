extends Camera3D

@export var ViewSensitivity:float = 1
@export var LookAround:bool = true
@export var MoveAround:bool = true
var OldMousePosition:Vector2 = Vector2.ZERO
var vP:Viewport
# Called when the node enters the scene tree for the first time.
func _ready():
	vP = get_viewport()
	OldMousePosition = vP.get_mouse_position()
func GetAxis(CA,CB):
	return 1 if CA else (-1 if CB else 0)

func _input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			# zoom in
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				fov /= 1.1
				# call the zoom function
			# zoom out
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				fov *= 1.1
				# call the zoom function

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if MoveAround:
		var Mod = delta*16
		var BAS = self.global_transform.basis
		var camera_forward = BAS.z.normalized()
		var Camera_side = BAS.x.normalized()
		var Camera_vert = BAS.y.normalized()
		var FB = GetAxis(Input.is_action_pressed('CamBack'),Input.is_action_pressed('CamForward'))*Mod
		var LR = GetAxis(Input.is_action_pressed('CamRight'),Input.is_action_pressed('CamLeft'))*Mod
		var UD = GetAxis(Input.is_action_pressed('CamUp'),Input.is_action_pressed('CamDown'))*Mod
		self.position += (camera_forward * FB) + (Camera_side * LR) + (Camera_vert * UD)
	if LookAround:
		var mouse_pos:Vector2 = vP.get_mouse_position()
		var ModI = delta*0.1 * ViewSensitivity
		self.rotate_x((mouse_pos.y - OldMousePosition.y)*ModI)
		self.rotate_y((mouse_pos.x - OldMousePosition.x)*ModI)
		
		OldMousePosition = mouse_pos
	if Input.is_action_just_pressed("CamHold") and LookAround:
		pass
		
