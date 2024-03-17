@tool
extends EditorPlugin

var dock: Control = null


func _enter_tree():
	dock = preload("res://addons/material_editor/dock.tscn").instantiate()
	dock.plugin_script = self
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree():
	if dock != null:
		remove_control_from_docks(dock)
		dock.free()
