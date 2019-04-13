local Screen = require "lib.gfx.screen"

local screen = Screen:new()

function screen:setUp()
	--local _, sh = love.window.getDesktopDimensions()

	self.dw, self.dh = 800, 480

	--self.modY = (sh - 50) / self.dh
	--self.modX = self.modY
	self.modX, self.modY = 2, 2

	-- Set up the screen.
	screen = Screen.setUp(self, {
		overrideDraw = true,
		drawWidth = self.dw,
		drawHeight = self.dh,
		screenWidth = self.dw * self.modX,
		screenHeight = self.dh * self.modY,
		minFilter = "linear",
		magFilter = "nearest",
		flags = {
			--resizable = true, -- tiling wms tiles it :(
			fullscreen = false,
			vsync = true,
			minwidth = 800,
			minheight = 480
		}
	})
end

function screen:getDimensions()
	return self.dw, self.dh
end

function screen:getModifiers()
	return self.modX, self.modY
end

return screen
