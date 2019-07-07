local Screen = require "lib.gfx.screen"

Screen.static.MIN_WIDTH = 800
Screen.static.MIN_HEIGHT = 480

local screen = Screen:new()

screen.fullscreen = false

function screen:setUp()
	if love.system.getOS() == "Android" then
		-- Force fullscreen, or things will go bad.
		screen.fullscreen = true
	end

	local sw, sh = love.window.getDesktopDimensions()
	if self.fullscreen then
		self:resize(sw, sh)
	else
		-- TODO: Decide on maximum size/scale.
		local scale = math.min(2, math.min(math.floor(sw / Screen.MIN_WIDTH), math.floor(sh / Screen.MIN_HEIGHT)))
		self:resize(Screen.MIN_WIDTH * scale, Screen.MIN_HEIGHT * scale)
	end
end

function screen:resize(w, h)
	local guiScale
	if love.graphics.getDPIScale() <= 1 then
		guiScale = math.max(1, math.min(math.floor(w / Screen.MIN_WIDTH), math.floor(h / Screen.MIN_HEIGHT)))
	else
		guiScale = 1 -- GUI scaling will be taken care of (forcibly) by the device.
	end

	if self.fullscreen and not self:isValidFullscreenMode(w, h) then
		if love.window.getFullscreen() then
			-- Android will initiate the application without fullscreen, and then put it in "fullscreen" but with some
			-- bogus(?) dimensions.
			w, h = love.window.getDesktopDimensions()
		else
			self.fullscreen = false
		end
	end

	if not self.prefs then
		self.prefs = {
			overrideDraw = true,
			minFilter = "linear",
			magFilter = "nearest",
			flags = {
				--resizable = true, -- TODO: Set to true before release (tiling wms tiles it :()
				highdpi = true,
				fullscreen = self.fullscreen,
				borderless = true,
				vsync = true,
				minwidth = Screen.MIN_WIDTH,
				minheight = Screen.MIN_HEIGHT
			}
		}
	else
		-- Don't chain them.
		self.prefs.overrideDraw = false
		self.prefs.flags.fullscreen = self.fullscreen
	end

	self.prefs.screenWidth = w
	self.prefs.screenHeight = h
	self.prefs.drawWidth = w / guiScale
	self.prefs.drawHeight = h / guiScale

	Screen.setUp(self, self.prefs)
end

function screen:getDrawDimensions()
	return love.window.fromPixels(self.canvas:getDimensions())
end

return screen
