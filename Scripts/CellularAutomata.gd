extends Node

var generation_timer
var last_known_grid = null

onready var tilemap = get_node("/root/Node2D/TileMap")

onready var freezed_block = preload("res://Effects/FreezedBlock.tscn")

var FIRE_THRESHOLD = 0.6

func _ready():
	# Initialize timer
	generation_timer = Timer.new()
	add_child(generation_timer)
	
	generation_timer.connect("timeout",self,"new_generation") 
	generation_timer.set_one_shot(false)
	generation_timer.set_wait_time(0.2)
	generation_timer.start()
	
	# Call a function when the window resizes
	# TURNED OFF => Decided to use scaling from Godot itself, with black bars at the sides
	get_tree().get_root().connect("size_changed", self, "window_resize")
	
	# Set some settings on the algorithm thread
	get_node("Semaphore").UPDATE_SPEED = 0.2

func window_resize():
	print("Resizing: ", get_viewport().size)
	
	# Hand new size to the shader
	self.material.set_shader_param("screen_size", get_viewport().size)

func new_generation():
	# this is where we add new impulses to the system => trees give oxygen, players take it, etc.
	
	###
	# Giving/taking oxygen and carbon
	###
	var impulses = []
	for obj in get_tree().get_nodes_in_group("OxygenGivers"):
		# If this object is about to be removed (like a tree that died from fire), ignore this!
		if not is_instance_valid(obj):
			continue
		
		var transformed_position = obj.get_transformed_position()
		var true_position = get_safe_position( transformed_position )
		
		var cell = last_known_grid[true_position.y][true_position.x]
		
		# If this object is already on fire ...
		if obj.is_on_fire():
			# Expel carbon and heat
			impulses.append( [true_position, -0.2, 0] )
			impulses.append( [true_position, 0.2, 1] )
			
			# Check if the fire should stop
			#  => The heat has decreased enough, or there's loads of water here
			if cell.size() > 0:
				if cell[1] < FIRE_THRESHOLD*0.2 or cell[2] >= 0.6:
					obj.extinguish_fire()
			
			# Damage the tree
			obj.damage(-0.01)
	
		# If this object is NOT on fire ...
		else:
			if cell.size() > 0:
				# Check if it's too hot, and there's no water to cool us
				if cell[1] >= FIRE_THRESHOLD and cell[2] <= 0.2:
					# If so, start a fire!
					obj.start_fire()
					
					# increase oxygen (as this is an oxygen giver)
					impulses.append( [true_position, 0.2, 0] )
	
	for obj in get_tree().get_nodes_in_group("OxygenTakers"):
		var true_position = get_safe_position( obj.get_position() )
		var cell = last_known_grid[true_position.y][true_position.x]
		
		impulses.append( [true_position, -0.3, 0] )
		
		# if an oxygen taker is under water, it should have a particle effect with bells popping up!
		var bell_part =  obj.get_node("BellParticles")
		
		if bell_part.is_emitting():
			# if we're already emitting, check if we should continue or not
			if cell.size() == 0 or cell[2] < 0.75:
				bell_part.restart()
				bell_part.set_emitting(false)
				bell_part.set_visible(false)
				
		else:
			if cell.size() > 0 and cell[2] >= 0.75:
				bell_part.set_emitting(true)
				bell_part.set_visible(true)
	
	###
	# Giving/taking heat
	###
	for obj in get_tree().get_nodes_in_group("WarmthGivers"):
		var true_position = get_safe_position( obj.get_position() )
		
		impulses.append( [true_position, 0.2, 1] )
	
	get_node("Semaphore").calculate_new_grid(impulses)

func get_safe_position(pos):
	var temp = tilemap.world_to_map( pos )
	temp.x = int(temp.x) % int(Global.MAP_SIZE.x)
	temp.y = int(temp.y) % int(Global.MAP_SIZE.y)
	
	return temp

func update_texture(grid, MAP_SIZE, raining, freezed_blocks):

	# Display the grid inside a texture
	# Create an Image
	var texture = Image.new()
	texture.create(MAP_SIZE.x, MAP_SIZE.y, false, Image.FORMAT_RGBA8)
	texture.lock()
	
	# Fill the texture with the right values for each grid cell
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var val = grid[y][x]
			
			var new_color = Color(0,0,0)
			if val.size() > 0:
				
				# blend RED and BLUE for the HEAT
				new_color = Color(0.0, 0.0, 1.0).linear_interpolate(Color(1.0, 0.0, 0.0), val[1])
			
				# change ALPHA based on oxygen level
				# Thicker = more carbon, less oxygen
				# ??? Perhaps we need a background to show this properly, and perhaps only change alpha at extremes
				new_color.a = (1.0 - val[0])
			
			texture.set_pixel(x, y, new_color)
	
	texture.unlock()
	
	# Convert Image to ImageTexture
	var image_tex = ImageTexture.new()
	image_tex.create_from_image(texture)
	
	# Hand texture to the shader
	self.material.set_shader_param("grid_tex", image_tex)
	
	# Save the grid values, so other nodes can use it
	last_known_grid = grid
	
	###
	# WATER
	###
	
	# Start/stop the rain particle
	get_node("/root/Node2D/Rain_Particles").set_emitting(raining)
	
	# Also ask the water node to draw the water
	get_node("/root/Node2D/WeatherLayer/DrawWater").draw_water(grid, MAP_SIZE)
	
	# Go through all currently freezed blocks, and check if they should be unfreezed
	for block in get_tree().get_nodes_in_group("FreezedBlocks"):
		var my_val = tilemap.world_to_map( block.get_position() )
		if grid[my_val.y][my_val.x][2] != null:
#			print("Unfreezed block ", my_val)
#
			block.queue_free()
	
	# Add any blocks that should be freezed
	for block in freezed_blocks:
#		print("Freezed block", block)
#
		var new_block = freezed_block.instance()
		new_block.set_position( tilemap.map_to_world(block) )
		get_node("/root/Node2D").add_child(new_block)
	
	# OLD METHOD (without shader, using Sprite node)
	# Add texture to the sprite
#	var sprite = get_node("Sprite")
#	sprite.set_texture(image_tex)
