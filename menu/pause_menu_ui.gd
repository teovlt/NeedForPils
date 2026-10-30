extends Control

# Interface 2D du menu pause (affichée sur un panneau 3D par PauseMenu)

signal resume_pressed
signal restart_pressed
signal quit_pressed

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var info: Label = %Info


func _ready() -> void:
	resume_button.pressed.connect(func(): resume_pressed.emit())
	restart_button.pressed.connect(func(): restart_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())


## Partie à deux : la partie continue pendant le menu ; seul le conducteur relance.
func setup(online: bool, driver: bool) -> void:
	restart_button.visible = not online or driver
	if not online:
		info.text = "Partie en pause"
	elif driver:
		info.text = "Partie à deux : elle continue pendant le menu.\nREJOUER relance la partie pour vous deux."
	else:
		info.text = "Partie à deux : elle continue pendant le menu.\nSeul le conducteur peut relancer la partie."
