extends Node2D

var grid = []
var MAP_SIZE

func _draw():
	if grid.size() == 0:
		return
	
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			if grid[y][x].size() == 0:
				continue
			
			var val = grid[y][x][2]
			var ice_block = false
			
			# if it's an ice block, set value to 1
			if val == null: 
				val = 1
				ice_block = true
			
			# floating point precision errors => better give ourselves some margin
			elif val <= 0:
				continue
			
			# Draw rectangle
			# At right position, with blue color, and right height 
			# (anchor it to the bottom, that's why we do (y+1)*32 - height)
			
			# Normal tile => transparent, blue-ish color + dynamic height
			var col = Color(0.6, 0.6, 1, 0.5)
			var height = min(val, 1.0) * 32
			
			# Ice tile => opaque white color, fixed full height
			if ice_block:
				col = Color(1.0, 1.0, 1.0, 1.0)
				height = 32
			
			# Check if block above has water, if so, always set to full water
			var val_above = grid[ int(y - 1) % int(MAP_SIZE.y) ][x]
			
			if val_above.size() > 0 and val_above[2] != null:
				if val_above[2] > 0:
					height = 32

			# TO DO: Use pressure => if a cell has a value higher than 8.0, we push water upwards
			
			# LINKS ABOUT WATER/CELLULAR AUTOMATA
			# LINK: https://www.gamasutra.com/blogs/MattKlingensmith/20130811/198050/How_Water_Works_In_DwarfCorp.php
			#  => Using a flow vector might be a good idea
			
			# ALSO LINK: https://www.reddit.com/r/gamedev/comments/2048wv/help_with_cellular_automata_water/
			
			# LAST LINK ABOUT Cellular Automata: https://gamedev.stackexchange.com/questions/59278/how-would-i-go-about-programming-atmosphere-for-a-game
			
			var rect = Rect2(Vector2(x * 32, (y+1) * 32 - height), Vector2(32, height))
			draw_rect(rect, col)

func draw_water(grid, MAP_SIZE):
	self.grid = grid
	self.MAP_SIZE = MAP_SIZE
	
	self.update()