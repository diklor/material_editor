@tool
extends VBoxContainer


const EXTRA_TEXTURE_NAMES: Array[String] = [
	'normal',
	'detail',
	'backlight',
	'clearcoat',
	'emission',
	'subsurf_scatter',
	'heightmap',
	'refraction',
	'rim',
	'ao',
]

@onready var box: VBoxContainer = $vsplit/bg/scroll/margin/box
@onready var up_hbox: HBoxContainer = $mode/vbox/hbox
@onready var apply_button: Button = $apply
@onready var path_vbox: VBoxContainer = $path/vbox
@onready var path_line_edit: LineEdit = path_vbox.get_node('hbox/line_edit')
@onready var transparency_mode_buttons: HBoxContainer = box.get_node('transparency_mode/vbox/hbox/buttons_hbox')
@onready var albedo_color_picker: ColorPickerButton = box.get_node('albedo_color/vbox/hbox/color_picker')
@onready var cull_mode_buttons: HBoxContainer = box.get_node('cull_mode/vbox/hbox/buttons_hbox')
@onready var for_surface_checkbox_label: CheckBox = box.get_node('for_surface/vbox/hbox/checkbox_label')
@onready var for_surface_spinbox: SpinBox = box.get_node('for_surface/vbox/hbox/spinbox')
@onready var for_surfaces_up_to_checkbox_label: CheckBox = box.get_node('for_surfaces_up_to/vbox/hbox/checkbox_label')
@onready var for_surfaces_up_to_spinbox: SpinBox = box.get_node('for_surfaces_up_to/vbox/hbox/spinbox')
@onready var disable_pbr_vbox: VBoxContainer = box.get_node('disable_pbr/vbox')


var mode := 'selected_objects'
var cull_mode := 'back'
var transparency_mode := 'disabled'
var strict_mode := false

var plugin_script: EditorPlugin
#Set from script plugin.gd


func _press_cont_button(cont: BoxContainer, button_name: String) -> void: #like radio button
	for v: Button in cont.get_children():
		v.set_pressed_no_signal(false)
	
	cont.get_node(button_name).set_pressed_no_signal(true)



func _on_expand_tip_pressed(in_vbox: VBoxContainer) -> void:
	var is_pressed: bool = in_vbox.get_node('expand_tip').button_pressed
	in_vbox.get_node('expand_tip').text = ('▲' if is_pressed else '▼')
	in_vbox.get_node('label').visible = is_pressed



func _ready() -> void:
	_press_cont_button(up_hbox.get_node('buttons_hbox'), 'selected_objects')
	_press_cont_button(transparency_mode_buttons, 'disabled')
	_press_cont_button(cull_mode_buttons, 'back')
	
	if 1:
		#for p: Node in ([up_hbox.get_node('buttons_hbox'), transparency_mode_buttons, cull_mode_buttons] as Array[Node]):
			#for v: Button in p.get_children():
				#v.pressed.connect(func() -> void:
					#_press_cont_button(up_hbox.get_node('buttons_hbox'), v.name)
					#self[p.name] = v.name
				#)
		for v: Button in up_hbox.get_node('buttons_hbox').get_children():
			v.pressed.connect(func() -> void:
				_press_cont_button(up_hbox.get_node('buttons_hbox'), v.name)
				mode = v.name
			)
		for v: Button in transparency_mode_buttons.get_children():
			v.pressed.connect(func() -> void:
				_press_cont_button(transparency_mode_buttons, v.name)
				transparency_mode = v.name
			)
		for v: Button in transparency_mode_buttons.get_children():
			v.pressed.connect(func() -> void:
				_press_cont_button(transparency_mode_buttons, v.name)
				cull_mode = v.name
			)
	
	if 1:
		_on_expand_tip_pressed(path_vbox)
		path_vbox.get_node('expand_tip').pressed.connect(_on_expand_tip_pressed.bind(path_vbox))
		_on_expand_tip_pressed(disable_pbr_vbox)
		disable_pbr_vbox.get_node('expand_tip').pressed.connect(_on_expand_tip_pressed.bind(disable_pbr_vbox))
	
	for v: Node in box.get_children():
		if v.name.ends_with('_slider'):
			(v.get_node('vbox/hbox/slider') as HSlider).value_changed.connect(func(value: float) -> void:
				(v.get_node('vbox/hbox/spinbox') as SpinBox).set_value_no_signal(v.get_node('vbox/hbox/slider').value)
			) #slider to indicator
			(v.get_node('vbox/hbox/spinbox') as SpinBox).value_changed.connect(func(value: float) -> void:
				(v.get_node('vbox/hbox/slider') as HSlider).set_value_no_signal(v.get_node('vbox/hbox/spinbox').value)
			) #input from indicator to slider
	
	
	apply_button.pressed.connect(apply)





static func _load_material_resource(path: String, materials_array: Array[BaseMaterial3D], print_errors := false) -> void:
	var material_object := ResourceLoader.load(path, 'Resource')
	if !(material_object is BaseMaterial3D):
		if print_errors:
			printerr('Path "' + path + '" was not a material resource')
		return
	materials_array.append(material_object)


static func _add_mesh_material(mesh: Mesh, materials_array: Array[BaseMaterial3D]) -> void:
	var mesh_class_name: String = mesh.get_class()
	
	if 1: #I hate regions
		if mesh_class_name.begins_with('CSG'):
			materials_array.append(mesh)
			return
		match mesh_class_name:
			&'ArrayMesh': #just for StringName
				mesh = (mesh as ArrayMesh)
				for i: int in mesh.get_surface_count(): #if 0 does nothing
					var material_object := mesh.surface_get_material(i)
					if material_object != null:
						materials_array.append(material_object)
				return
	
	materials_array.append(mesh)



func _scan_folder_materials(path: String, materials_array: Array[BaseMaterial3D]) -> void:
	for folder_name: String in DirAccess.get_directories_at(path):
		_scan_folder_materials(path + folder_name + '/', materials_array)
	
	for file_name: String in DirAccess.get_files_at(path):
		if file_name.ends_with('.tres'):
			_load_material_resource(path + file_name, materials_array, false)



func apply() -> void:
	var materials: Array[BaseMaterial3D] = []
	
	match mode:
		'file':
			_load_material_resource(path_line_edit.text, materials)
		
		'folders':
			if 1:
				for folder_path: String in path_line_edit.text.split(';'):
					folder_path = folder_path.trim_suffix('/') + '/' #add slash if exists and if not
					
					if !DirAccess.open(folder_path):
						printerr('Path not found: "' + folder_path + '"')
						continue
					
					for file_name: String in DirAccess.get_files_at(folder_path):
						_load_material_resource(folder_path + file_name, materials)
		
		'folders_and_descendants':
			if 1:
				for folder_path: String in path_line_edit.text.split(';'):
					folder_path = folder_path.trim_suffix('/') + '/' #Same
					
					if !DirAccess.open(folder_path):
						printerr('Path not found: "' + folder_path + '"')
						continue
					
					_scan_folder_materials(folder_path, materials)
		
		'selected_objects':
			var selection := EditorInterface.get_selection()
			
			if selection != null and !selection.get_selected_nodes().is_empty():
				var selected_list: Array[Node] = selection.get_selected_nodes()
				
				for object: Node in selected_list:
					if (object is GeometryInstance3D):
						if (object is CSGPrimitive3D):
							materials.append(object.material)
							continue
						else:
							if (object is MeshInstance3D):
								_add_mesh_material(object.mesh, materials)
								continue
							else:
								var object_class_name := object.get_class()
								match object_class_name:
									&'CPUParticles3D', &'GPUParticles3D':
										if 1:
											if object.material_override != null:
												object.material_override.append(object.material_override)
											if strict_mode:
												if object.material_overlay != null:
													object.material_overlay.append(object.material_overlay)
										
										if (object_class_name == 'GPUParticles3D'):
											for i: int in object.draw_passes:
												_add_mesh_material(object['draw_pass_' + str(i + 1)], materials) #draw passes start with 1
											
											if ('mesh' in object):
												_add_mesh_material(object.mesh, materials)
												continue
	
	
	
	var changes_dict: Dictionary = {} #Dictionary[BaseMaterial3D, Dictionary[String, Array[Variant]]]
	
	for material_object: BaseMaterial3D in materials:
		if (material_object == null):		continue
		
		if box.get_node('albedo_color/vbox/hbox/checkbox_label').button_pressed:
			_add_material_change(material_object, 'albedo_color', albedo_color_picker.color, changes_dict)
		
		if box.get_node('transparency_mode/vbox/hbox/checkbox_label').button_pressed:
			_add_material_change(material_object, 'transparency', BaseMaterial3D['TRANSPARENCY_'  + transparency_mode.to_upper()], changes_dict)
			#TRANSPARENCY_DISABLED, TRANSPARENCY_DEPTH_PRE_PASS ...
		if box.get_node('cull_mode/vbox/hbox/checkbox_label').button_pressed:
			_add_material_change(material_object, 'cull_mode', BaseMaterial3D['CULL_'  + cull_mode.to_upper()], changes_dict)
			#CULL_DISABLED, CULL_BACK ...
		
		
		if box.get_node('disable_pbr/vbox/hbox/checkbox_label').button_pressed:
			_add_material_change(material_object, 'specular_mode', 0, changes_dict)
			_add_material_change(material_object, 'metallic', 0, changes_dict)
			_add_material_change(material_object, 'roughness', 0, changes_dict)
			_add_material_change(material_object, 'normal_scale', 0, changes_dict)
			_add_material_change(material_object, 'specular_mode', BaseMaterial3D.SPECULAR_DISABLED, changes_dict)
			for extra_texture_name: String in EXTRA_TEXTURE_NAMES:
				_add_material_change(material_object, extra_texture_name + '_enabled', false, changes_dict)
				if strict_mode:
					_add_material_change(material_object, extra_texture_name + '_texture', null, changes_dict) #clear textures
		else:
			for v: String in (['metallic_specular', 'metallic', 'roughness', 'normal_scale'] as Array[String]):
				if box.get_node(v + '_slider/vbox/hbox/checkbox_label').button_pressed:
					_add_material_change(material_object, v, (box.get_node(v + '_slider/vbox/hbox/spinbox') as SpinBox).value, changes_dict)
	
	var properties_changed_count := 0
	for material_object: BaseMaterial3D in changes_dict:
		if (material_object == null):		continue
		for property: String in changes_dict[material_object]:
			properties_changed_count += 1
	
	print('Change properties for ' + str(materials.size()) + ' materials (' + str(properties_changed_count) + ' properties summary)')
	var editor_undoredo := plugin_script.get_undo_redo()
	editor_undoredo.create_action('Change properties for ' + str(materials.size()) + ' materials (' + str(properties_changed_count) + ' properties summary)')
	#'.bind()' is like _back_material_value.call(changes_dict, 1, ...)
	#But there is no ... arguments in callback at the first argument of function 'add_do_method' so that's just for space
	editor_undoredo.add_do_method(self, &'_back_material_value', changes_dict, 1)
	# Index 1 in changes array is new value, 'do' method must be before 'undo'
	editor_undoredo.add_undo_method(self, &'_back_material_value', changes_dict, 0)
	# Index 0 in changes array is old value (in '_back_material_value' function)
	
	editor_undoredo.commit_action(true)



func _back_material_value(changes_dict: Dictionary, changes_index: int) -> void:
	for material_object: BaseMaterial3D in changes_dict:
		if (material_object == null):		continue
		
		for property: String in changes_dict[material_object]:
			var value: Variant = changes_dict[material_object][property][changes_index] #0 - old_value, 1 - new_value
			material_object[property] = value
	#Check function below


static func _add_material_change(material_object: BaseMaterial3D, property: String, new_value: Variant, changes_dict: Dictionary) -> void:
	if !changes_dict.has(material_object):
		changes_dict[material_object] = {}
	
	#FOR UNDO, REDO ACTIONS
	changes_dict[material_object][property] = []
	changes_dict[material_object][property].append(material_object[property]) #[0]; old value
	changes_dict[material_object][property].append(new_value) #[1]; new value
	
	#material_object[property] = new_value
