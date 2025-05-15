# Overview
Godot-rc hosts a websocket server inside godot editor, clients can send commands and request information from an editor over a socket, made in first place for integrating scenes node manipulations and node property editing

# DISCLAIMER
Please refrain from using `godot-rc` in production.

This project is in early stages of development, there are a lot of missing safety checks and hidden bugs. 
If you anyway want to use it then use a version control system, commit early, commit often.

# Requirements
Tested only on Godot 4.4.1, should work with Godot 4+

# Installation
1. Download this repo
2. Move `addons/godot-rc` to `your_projects/addons/godot-rc`
3. Enable this plugin in `Project -> Project Settings -> Plugins`

# Supported text editors
emacs - [godot-rc-emacs](https://github.com/shadr/godot-rc-emacs)

# Documentation
Clients communicate with `godot-rc` by sending JSON objects.
Each client request should have this structure:

- `method` string, which tells server which function to execute
- `params` number, string or dictionary, arguments passed to `method` when function is executed
- `id` number, an optional parameter which used for differentiating responses

While server sends responses and notifications
Here is response structure:

- `result` a return value of an executed function
- `id` number, response `id` is equal to `id` of a request which led to this response

Notifications are messages sent by server and not triggered by client's requests (e.g. scene-changed notification is sent when something in scene changes)
Notification structure is similar to a client request's:

- `method` string, notification identifier
- `params` additional information about event which triggered this notification

## Methods
TODO, read [plugin.gd](addons/godot-rc/plugin.gd)

