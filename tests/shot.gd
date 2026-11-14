extends SceneTree
## Developer tool, not a test: plays a level with a scripted policy and saves a screenshot.
## Needs a real renderer, so run it windowed (no --headless):
##   Godot --path . --resolution 1180x500 --script tests/shot.gd -- <out.png> <level> <seconds> [policy] [extra]
## policy: none | mito | chloro | both.  extra: reduced | noatp | large | pause | nostart | help | settings
var _done: bool = false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "shot.png"
	var level: int = int(args[1]) if args.size() > 1 else 1
	var seconds: float = float(args[2]) if args.size() > 2 else 5.0
	var policy: String = args[3] if args.size() > 3 else "none"
	var extra: String = args[4] if args.size() > 4 else ""
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if extra.contains("reduced"):
		main.settings.reduced_motion = true
	if extra.contains("noatp"):
		main.settings.show_atp_particles = false
	if extra.contains("large"):
		main.settings.text_size = 2
	main.load_level(level, 7)
	if not extra.contains("nostart"):
		main.press_start()
		var t: float = 0.0
		var stop_on_popup: bool = extra.contains("popup")
		while t < seconds and not main.model.is_finished():
			await process_frame
			t += 1.0 / 60.0
			if not main.overlays.is_empty():
				if stop_on_popup and main.model.time > 0.3:
					break
				main.close_topmost_overlay()
			var m: SimulationModel = main.model
			for o: SimulationModel.Org in m.organelles.duplicate():
				var want: bool = (policy == "mito" and o.kind == "mito") or (policy == "chloro" and o.kind == "chloro" and m.count("chloro") < 3) or policy == "both"
				if want and m.division_block(o.id) == "" and main.is_running():
					main._on_organelle_pressed(o.id)
	if extra.contains("pause"):
		main.toggle_pause()
	if extra.contains("help"):
		main._open_help()
		if extra.contains("help2"):
			main._next_help_page()
	if extra.contains("settings"):
		main._open_settings()
	if extra.contains("focus"):
		main.keyboard.move_focus(1)
		for i: int in range(6):
			main.keyboard.move_focus(1)
	for i: int in range(6):
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " t=", main.model.time, " size=", root.size)
	quit(0)
