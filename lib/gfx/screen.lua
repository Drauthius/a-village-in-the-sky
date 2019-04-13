--- This class includes functions to help with managing different screen sizes.
-- Code taken from Jasoco @ https://love2d.org/forums/viewtopic.php?f=4&t=9636&p=59471#p59471
-- @author Albert Diserholt

local class = require("lib.middleclass")

local Screen = class("Screen")

--- The preferences available to a screen.
-- @table pref
-- @tfield number drawWidth The width of the draw area.
-- @tfield number drawHeight The height of the draw area.
-- @tfield[opt=drawWidth] number screenWidth The width of the screen.
-- @tfield[opt=drawHeight] number screenHeight The height of the screen.
-- @tfield[opt=false] bool overrideDraw Whether to override the `love.draw()` function
-- with a custom function to draw the screen. The old `love.draw()` function
-- will be called within the screen's context.
-- @tfield[opt="linear"] FilterMode minFilter Filter mode to use when minifying.
-- @tfield[opt="nearest"] FilterMode magFilter Filter mode to use when
-- magnifying.
-- @tfield table flags Any extra flags to pass to `love.window.setMode()`.

--- Create a new screen object.
-- @tparam table pref Preferences for the new screen. See @{pref} for
-- understood preferences.
-- @raise Asserts that the specified screen width and high is supported if
-- going into fullscreen mode.
function Screen:setUp(pref)
	assert(type(pref) == "table", "The preference must be a table.")
	setmetatable(pref, { __index = {
		screenWidth = pref.drawWidth,
		screenHeight = pref.drawHeight,
		overrideDraw = false,
		flags = {}
	}})

	if pref.overrideDraw then
		assert(love.draw, "love.draw() was not defined before Screen:new() was called with overrideDraw = true.")
		self.oldDraw = love.draw
		love.draw = function()
			self:prepare()
			self.oldDraw()
			self:present()
		end
	end

	if pref.flags.fullscreen then
		local modes = love.window.getFullscreenModes()
		local valid = false
		for _,mode in ipairs(modes) do
			if mode.width == pref.screenWidth and mode.height == pref.screenHeight then
				valid = true
				break
			end
		end

		assert(valid,
			"Fullscreen mode " .. tostring(pref.screenWidth) .. "x" .. tostring(pref.screenHeight) .. " is not supported.")
	end

	love.window.setMode(pref.screenWidth, pref.screenHeight, pref.flags)

	self.verticalScale = pref.screenHeight / pref.drawHeight
	self.horizontalScale = self.verticalScale

	self.offsetX = (pref.screenWidth - (pref.drawWidth * self.verticalScale)) / 2
	self.offsetY = (pref.screenHeight - (pref.drawHeight * self.horizontalScale)) / 2

	self.canvas = love.graphics.newCanvas(pref.drawWidth, pref.drawHeight, { msaa = pref.flags.msaa })
	self.canvas:setFilter(pref.minFilter, pref.magFilter)
end

--- Prepare to draw to the screen. This function should be called before
-- drawing anything. It is automatically invoked if `overrideDraw` was enabled.
function Screen:prepare()
	love.graphics.setCanvas({self.canvas, stencil = true})
	love.graphics.clear(0, 0, 0, 0, true)
end

--- Present the contents to the screen. This function should be called after
-- everything has been drawn. It is automatically invoked if `overrideDraw` was
-- enabled.
function Screen:present()
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.canvas, self.offsetX, self.offsetY, 0,
	                   self.verticalScale, self.horizontalScale)
	love.graphics.setBlendMode("alpha")
end

function Screen:getDrawArea()
	return {
		x = self.offsetX,
		y = self.offsetY,
		width = self.canvas:getDimensions(),
		height = select(2, self.canvas:getDimensions())
	}
end

--- Converts screen coordinates depending on scaling and offset.
-- @tparam number x The screen x-coordinate to translate to the draw area.
-- @tparam number y The screen y-coordinate to translate to the draw area.
-- @treturn number The x-coordinate in the draw area.
-- @treturn number The y-coordinate in the draw area.
function Screen:getCoordinate(x, y)
	x = math.max(x - self.offsetX, 0) / self.verticalScale
	y = math.max(y - self.offsetY, 0) / self.horizontalScale

	return x, y
end

--- Zoom the screen by a factor.
-- @tparam number x The zoom factor for the horizontal scale.
-- @tparam[opt] number y The zoom factor for the vertical scale, or the same as
-- the horizontal one if omitted.
function Screen:zoomBy(x, y)
	y = y or x
	self.verticalScale = self.verticalScale + x
	self.horizontalScale = self.horizontalScale + y
end

return Screen
