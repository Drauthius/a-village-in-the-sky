local Widget = require "src.game.gui.widget"

local spriteSheet = require "src.game.spritesheet"

local Button = Widget:subclass("Button")

function Button:initialize(x, y, ox, oy, type, font)
	self.spriteUp = spriteSheet:getSprite(type.." (Up)")
	self.spriteDown = spriteSheet:getSprite(type.." (Down)")
	self.data = spriteSheet:getData(type.."-textposition")
	self.isDown = false

	Widget.initialize(self, x, y, ox, oy, self.spriteUp)

	local oyText = (self.data.bounds.h - font:getHeight()) / 2 + self.data.bounds.y
	self:addText("", font, { 0, 0, 0, 1 }, self.data.bounds.x, oyText, self.data.bounds.w, "center")
end

function Button:setPressed(pressed)
	if pressed then
		self.sprite = self.spriteDown
		self.isDown = true
	else
		self.sprite = self.spriteUp
		self.isDown = false
	end
end

function Button:isPressed()
	return self.isDown
end

return Button
