extends Control

var aspect_mode = "false"

func _ready():
	switch_aspect_aspect_mode("widescreen")	

func _process(delta):
	var aspect_ratio = get_viewport_rect().size.x/(0.00001 if get_viewport_rect().size.y == 0 else get_viewport_rect().size.y)
	if aspect_ratio <= 3.0/4.0:
		switch_aspect_aspect_mode("tallscreen")
	elif aspect_ratio <= 4.0/3.0:
		switch_aspect_aspect_mode("classic")
	else:
		switch_aspect_aspect_mode("widescreen")	

func switch_aspect_aspect_mode(mode):
	
	var scale = get_viewport_rect().size.x/1920;
	
	if aspect_mode != mode:
		var size = int(120*scale)
		pass
		# resize game title
		if mode == "tallscreen":
			$HBoxContainer/VBoxContainer/VBoxContainer/title.add_theme_font_size_override("font_size", int(260*scale))
		elif mode == "classic":
			$HBoxContainer/VBoxContainer/VBoxContainer/title.add_theme_font_size_override("font_size", int(220*scale))
		else:
			$HBoxContainer/VBoxContainer/VBoxContainer/title.add_theme_font_size_override("font_size", int(190*scale))
			
		if mode == "tallscreen":
			size = int(300*scale)
		elif mode == "classic":
			size = int(180*scale)
		
		# resize menu options
		for obj in $HBoxContainer/VBoxContainer/VBoxContainer.get_children():
			if obj is Label and obj.name != "title":
				obj.add_theme_font_size_override("font_size", size)
	aspect_mode = mode
