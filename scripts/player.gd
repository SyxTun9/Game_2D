
extends CharacterBody2D

@export var speed: float = 200.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var transformation_menu = $"../TransformationMenu"

var facing: String = "down"


func _ready() -> void:
	transformation_menu.form_selected.connect(_on_form_selected)


func _physics_process(_delta: float) -> void:

	# Xu ly phim Space
	if Input.is_action_just_pressed("open_transformation"):
		if transformation_menu.is_selecting:
			transformation_menu.confirm_selection()
		else:
			transformation_menu.open_menu()

		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Dung nhan vat khi menu dang mo
	if transformation_menu.is_selecting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Doc phim di chuyen
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# Di chuyen
	velocity = direction * speed
	move_and_slide()

	# Xu ly animation
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				facing = "right"
			else:
				facing = "left"
		else:
			if direction.y > 0:
				facing = "down"
			else:
				facing = "up"

		anim.play("walk_" + facing)
	else:
		anim.play("idle_" + facing)


func _on_form_selected(form_data: Dictionary) -> void:
	anim.sprite_frames = form_data["animations"]
	anim.play("idle_" + facing)

	print("Transformed into: ", form_data["id"])
