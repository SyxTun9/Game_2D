
extends CanvasLayer

signal form_selected(form_data: Dictionary)

@onready var form_list: HBoxContainer = $UI/Background/CenterContainer/PanelContainer/VBoxContainer/FormList

var forms: Array[Dictionary] = []

var selected_index: int = 0
var is_selecting: bool = false


func _ready() -> void:
	load_forms()


func load_forms() -> void:
	var directory = DirAccess.open("res://assets/transformations")

	if directory == null:
		print("Cannot open transformations folder!")
		return

	var folders = directory.get_directories()
	folders.sort()

	for folder in folders:
		var avatar_path = "res://assets/transformations/" + folder + "/avatar.png"
		var animation_path = "res://assets/transformations/" + folder + "/animations.tres"

		if not ResourceLoader.exists(avatar_path):
			print("Missing avatar: ", folder)
			continue

		if not ResourceLoader.exists(animation_path):
			print("Missing animations: ", folder)
			continue

		var form_data = {
			"id": folder,
			"avatar": load(avatar_path),
			"animations": load(animation_path)
		}

		forms.append(form_data)

		var avatar = TextureRect.new()
		avatar.texture = form_data["avatar"]
		avatar.custom_minimum_size = Vector2(100, 100)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		form_list.add_child(avatar)
	
	update_selection()

	print("Loaded forms: ", forms.size())

func update_selection() -> void:
	for i in range(form_list.get_child_count()):
		var avatar = form_list.get_child(i)

		if i == selected_index:
			avatar.modulate = Color(1, 1, 1, 1)
			avatar.scale = Vector2(1.2, 1.2)
		else:
			avatar.modulate = Color(0.5, 0.5, 0.5, 0.7)
			avatar.scale = Vector2.ONE


func _process(_delta: float) -> void:
	if not is_selecting:
		return
	
	if Input.is_action_just_pressed("menu_cancel"):
		close_menu()
		return

	if Input.is_action_just_pressed("menu_left"):
		selected_index -= 1

		if selected_index < 0:
			selected_index = forms.size() - 1

		update_selection()

	if Input.is_action_just_pressed("menu_right"):
		selected_index += 1

		if selected_index >= forms.size():
			selected_index = 0

		update_selection()


func open_menu() -> void:
	if forms.is_empty():
		return

	is_selecting = true
	selected_index = 0
	visible = true
	update_selection()


func close_menu() -> void:
	is_selecting = false
	visible = false
	
func confirm_selection() -> void:
	if forms.is_empty():
		return

	var selected_form = forms[selected_index]

	form_selected.emit(selected_form)
	close_menu()
