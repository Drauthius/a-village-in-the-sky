local class = require "lib.middleclass"

local spriteSheet = require "src.game.spritesheet"

local ProgressBar = class("ProgressBar")

function ProgressBar:initialize(x, y, w, h, icon)
	self.x, self.y = x, y
	self.w, self.h = w, h
	self.icon = icon

	self.oy = (icon:getHeight() - self.h) / 2
end

function ProgressBar:draw(progress, max)
	assert(progress <= max and max <= 1.0, "["..tostring(progress)..","..tostring(max).."] is invalid")
	-- Convert to number of pixels.
	progress = progress * self.w
	max = max * self.w

	-- Draw the bar background(s)
	local background = spriteSheet:getWoodPalette().dark
	love.graphics.setColor(background[1], background[2], background[3], 0.5)
	love.graphics.rectangle("fill", self.x, self.y + self.oy, max, self.h)

	if max < self.w then
		background = spriteSheet:getWoodPalette().outline
		love.graphics.setColor(background[1], background[2], background[3], 0.5)
		love.graphics.rectangle("fill", self.x + max, self.y + self.oy, self.w - max, self.h)
	end

	-- Draw the bar "progress"
	love.graphics.setColor(spriteSheet:getWoodPalette().bright)
	love.graphics.rectangle("fill", self.x, self.y + self.oy, progress, self.h)

	-- Draw the bar outline
	love.graphics.setColor(spriteSheet:getWoodPalette().outline)
	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle("rough")
	love.graphics.rectangle("line", self.x, self.y + self.oy, self.w, self.h)

	-- Draw the icon
	love.graphics.setColor(1, 1, 1, 1)
	spriteSheet:draw(self.icon,
	                 math.max(self.x - 4,
	                          math.min(self.x + self.w - self.icon:getWidth() + 4,
	                                   self.x + progress - self.icon:getWidth() / 2)),
	                 self.y)
end

return ProgressBar
