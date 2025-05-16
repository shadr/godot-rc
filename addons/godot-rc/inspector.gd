@tool
class_name GRCCommandsInspector
extends Node

var grc: GodotRC


func register_commands() -> void:
	grc.register_command("node-properties", get_node_properties, true)


func get_node_properties(params: Dictionary) -> Array:
	var node_id: int = params.node_id
	var opened: Array
	# TODO: handle unfolded properties
	if params.opened_props:
		opened = params.opened_props
	else:
		opened = []

	var node: Node = instance_from_id(node_id)

	var prop_list = node.get_property_list()
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
			var serialized_prop = {
				"property": prop.name,
				"visible_name": visible_name,
				"usage": prop.usage,
				"hint": prop.hint,
				"hint_string": prop.hint_string
			}

			where_to_push.back().push_back(serialized_prop)
	if script:
		var serialized_script = {
			"property": script.name,
			"visible_name": "Script",
			"usage": script.usage,
			"hint": script.hint,
			"hint_string": script.hint_string
		}
		res[0].children.push_back(serialized_script)
	res.reverse()

	return res
