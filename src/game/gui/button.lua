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

local Widget = require "src.game.gui.widget"

local soundManager = require "src.soundmanager"
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
		self:addText("", font, spriteSheet:getOutlineColor(), self.data.bounds.x, oyText, self.data.bounds.w, "center")
	end
end

function Button:setDisabled(disabled)
	self.disabled = disabled
end

function Button:isDisabled()
	return self.disabled == true
end

function Button:setPressed(pressed)
	if pressed and not self.isDown then
		self.sprite = self.spriteDown
		self.isDown = true
		soundManager:playEffect("button_down")
	elseif self.isDown then
		self.sprite = self.spriteUp
		self.isDown = false
		soundManager:playEffect("button_up")
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
