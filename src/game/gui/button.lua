local Widget = require "src.game.gui.widget"

local spriteSheet = require "src.game.spritesheet"

local Button = Widget:subclass("Button")

function Button:initialize(x, y, ox, oy, type, font)
	self.spriteUp = spriteSheet:getSprite(type.." (Up)")
	self.spriteDown = spriteSheet:getSprite(type.." (Down)")
	self.isDown = false

	Widget.initialize(self, x, y, ox, oy, self.spriteUp)

	if font ~= false then
		self.data = spriteSheet:getData(type.."-textposition")
		local oyText = (self.data.bounds.h - font:getHeight()) / 2 + self.data.bounds.y
		self:addText("", font, { 0, 0, 0, 1 }, self.data.bounds.x, oyText, self.data.bounds.w, "center")
	end
end

function Button:setDisabled(disabled)
	self.disabled = disabled
end

function Button:isDisabled()
	return self.disabled == true
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

function Button:getAction()
	return self.action
end

function Button:setAction(action)
	self.action = action
end

return Button
