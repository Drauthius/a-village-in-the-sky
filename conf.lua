function love.conf(t)
	t.version = "11.0"
	t.console = false

	t.window.title = "A Village in the Sky"
	t.window.icon = "asset/icon/icon-42x42.png"
	t.window.minwidth = 800
	t.window.minheight = 480
	t.window.highhdpi = true
	t.window.vsync = 1

	t.modules.joystick = false
	t.modules.physics = false
	t.modules.thread = false
	t.modules.video = false
end
