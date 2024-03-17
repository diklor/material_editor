@tool
extends Button


enum PARAM_TYPE {SLIDER, COLOR, OPTIONS, NUMBER}

@export var icon_name := 'Reload'
@export var param_type := PARAM_TYPE.SLIDER
@export var default_value := 0.0

@onready var parent := $'../'


func _enter_tree():
	icon = get_theme_icon(icon_name, 'EditorIcons')
	set_button_icon(icon)
	
	pressed.connect(func() -> void:
		match param_type:
			PARAM_TYPE.OPTIONS:
				for v: Button in parent.get_node('buttons_hbox').get_children():
					v.set_pressed_no_signal(false)
				
				parent.get_node('buttons_hbox').get_child(int(default_value)).set_pressed_no_signal(true)
			
			PARAM_TYPE.SLIDER:
				parent.get_node('slider').set_value_no_signal(default_value)
				parent.get_node('spinbox').set_value_no_signal(default_value)
		
			PARAM_TYPE.COLOR:
				(parent.get_node('color_picker') as ColorPickerButton).color = Color.WHITE
			
			PARAM_TYPE.NUMBER:
				parent.get_node('spinbox').set_value_no_signal(default_value)
	
	)
