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
	if params.has("opened_props") and params.opened_props is Array:
		opened = params.opened_props.map(func(element): return int(element))
	else:
		opened = []

	var object: Object = instance_from_id(object_id)
	return collect_object_properties(object, opened)


func collect_object_properties(object: Object, opened: Array) -> Array:
	var default_object: Object = ClassDB.instantiate(object.get_class())

	var prop_list = object.get_property_list()
	var res = []
	var where_to_push = [res]
	var group_prefixes = [""]
	var script = null
	for prop in prop_list:
		if prop.name == "script":
			script = prop
			continue
		var tusage = (
			prop.usage & (PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY)
		)
		if tusage:
			var grouping_index = -1
			match tusage:
				PROPERTY_USAGE_SUBGROUP:
					grouping_index = 3
				PROPERTY_USAGE_GROUP:
					grouping_index = 2
				PROPERTY_USAGE_CATEGORY:
					grouping_index = 1
			where_to_push.resize(grouping_index)
			group_prefixes.resize(where_to_push.size())
			if prop.name != "":
				var grouping = {"name": prop.name, "children": []}
				where_to_push.back().push_back(grouping)
				group_prefixes.push_back(prop.hint_string)
				where_to_push.push_back(grouping.children)
			else:
				where_to_push.push_back([])
			continue
		while where_to_push.size() > 2 && not prop.name.begins_with(group_prefixes.back()):
			where_to_push.pop_back()
			group_prefixes.pop_back()
		if prop.usage & PROPERTY_USAGE_EDITOR:
			var visible_name: String = prop.name.capitalize()

			if !group_prefixes.is_empty():
				visible_name = (
					visible_name.trim_prefix(group_prefixes.back().capitalize()).trim_prefix(" ")
				)
			var value = object.get(prop.name)
			var default_val = default_object.get(prop.name)
			var non_default = default_val != value
			if value is Object:
				var id = value.get_instance_id()
				if id in opened:
					prop.children = collect_object_properties(value, opened)
				value = id
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
