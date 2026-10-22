extends Control

# Interface 2D du menu d'accueil, affichée dans un panneau 3D (Viewport2Din3D)

signal play_pressed
signal quit_pressed

@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	play_button.pressed.connect(func(): play_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())
