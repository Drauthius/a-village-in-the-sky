--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

function love.conf(t)
	t.identity = "village-in-the-sky"
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
