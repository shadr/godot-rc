@tool
class_name GRCCommandsInspector
extends Node

var grc: GodotRC


func register_commands() -> void:
	grc.register_command("object-properties", get_object_properties, true)
	grc.register_command("inspector-change-property", change_property)


func get_object_properties(params: Dictionary) -> Array:
	var object_id: int
	if params.object_id is String:
		object_id = int(params.object_id)
	else:
		object_id = params.object_id
	var opened: Array
	# TODO: handle unfolded properties
	if params.has("opened_props") and params.opened_props is Array:
		opened = params.opened_props
	else:
		opened = []

	var object: Object = instance_from_id(object_id)
	var default_object: Object = ClassDB.instantiate(object.get_class())

	var prop_list = object.get_property_list()
	var res = []
	var group_base = ""
	var subgroup_base = ""
	var where_to_push = [res]
	# TODO: remove these booleans, just use where_to_pus length
	var pushing_to_category = false
	var pushing_to_group = false
	var pushing_to_subgroup = false
	var script = null
	for prop in prop_list:
		if prop.name == "script":
			script = prop
			continue
		if prop.usage & PROPERTY_USAGE_SUBGROUP:
			pushing_to_subgroup = true
			subgroup_base = prop.hint_string
			var subgroup = {"name": prop.name, "children": []}
			where_to_push.back().push_back(subgroup)
			where_to_push.push_back(subgroup.children)
			continue
		elif prop.usage & PROPERTY_USAGE_GROUP:
			if pushing_to_subgroup:
				where_to_push.pop_back()
				pushing_to_subgroup = false
			if pushing_to_group:
				where_to_push.pop_back()
				pushing_to_group = false
			pushing_to_group = true
			group_base = prop.hint_string
			var group = {"name": prop.name, "children": []}
			where_to_push.back().push_back(group)
			where_to_push.push_back(group.children)
			continue
		elif prop.usage & PROPERTY_USAGE_CATEGORY:
			if pushing_to_subgroup:
				where_to_push.pop_back()
				pushing_to_subgroup = false
			if pushing_to_group:
				where_to_push.pop_back()
				pushing_to_group = false
			if pushing_to_category:
				where_to_push.pop_back()
				pushing_to_category = false
			pushing_to_category = true
			var category = {"name": prop.name, "children": []}
			where_to_push.back().push_back(category)
			where_to_push.push_back(category.children)
			continue
		if pushing_to_subgroup && !prop.name.begins_with(subgroup_base):
			where_to_push.pop_back()
			subgroup_base = ""
			pushing_to_subgroup = false
		if pushing_to_group && !prop.name.begins_with(group_base):
			where_to_push.pop_back()
			group_base = ""
			pushing_to_group = false
		if prop.usage & PROPERTY_USAGE_EDITOR:
			var visible_name: String = prop.name.capitalize()
			if pushing_to_subgroup:
				visible_name = visible_name.trim_prefix(subgroup_base.capitalize()).trim_prefix(" ")
			elif pushing_to_group:
				visible_name = visible_name.trim_prefix(group_base.capitalize()).trim_prefix(" ")
			var value = object.get(prop.name)
			var default_val = default_object.get(prop.name)
			var non_default = default_val != value
			if value is Object:
				value = value.get_instance_id()
			prop.property = prop.name
			prop.visible_name = visible_name
			prop.value = value
			prop.non_default = non_default

			where_to_push.back().push_back(prop)
	if script:
		var non_default = object.get_script() != null
		script.property = script.name
		script.visible_name = "Script"
		script.value = object.get_script()
		script.non_default = object.get_script() != null
		res[0].children.push_back(script)
	res.reverse()

	return res


func change_property(params: Dictionary) -> void:
	var object_id: int = params.object_id
	var property = params.property
	var value = params.value

	var object = instance_from_id(object_id)

	if property is String:
		object.set(property, value)
	elif property is Array:
		var prop_path = ":".join(property)
		object.set_indexed(prop_path, value)

	grc.send_notification_to_all_peers(
		"property-changed", {"object": object_id, "property": property, "value": value}
	)
