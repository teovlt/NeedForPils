extends Control

# Interface 2D du menu d'accueil, affichée dans un panneau 3D (Viewport2Din3D)

signal play_pressed
signal solo_pressed
signal quit_pressed
signal cancel_pressed

@onready var play_button: Button = %PlayButton
@onready var solo_button: Button = %SoloButton
@onready var quit_button: Button = %QuitButton
@onready var cancel_button: Button = %CancelButton
@onready var main_buttons: Control = %MainButtons
@onready var waiting: Control = %Waiting
@onready var status_label: Label = %StatusLabel
@onready var subtitle: Label = $Panel/Margin/VBox/Subtitle

var _default_subtitle := ""


func _ready() -> void:
	_default_subtitle = subtitle.text
	play_button.pressed.connect(func(): play_pressed.emit())
	solo_button.pressed.connect(func(): solo_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())
	cancel_button.pressed.connect(func(): cancel_pressed.emit())


## Partie à deux : message d'attente (recherche, attente de l'autre joueur...).
func show_waiting(text: String) -> void:
	main_buttons.visible = false
	waiting.visible = true
	status_label.text = text


## Retour aux boutons, avec éventuellement un message (connexion perdue...).
func show_main(message := "") -> void:
	main_buttons.visible = true
	waiting.visible = false
	subtitle.text = message if message != "" else _default_subtitle
