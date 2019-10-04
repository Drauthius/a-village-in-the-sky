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

local babel = require "lib.babel"

local GameEvent = require "src.game.gameevent"
local ScaledSprite = require "src.game.scaledsprite"

local spriteSheet = require "src.game.spritesheet"

local InfoPanelItem = require "src.game.gui.infopanelitem"

local EventItem = InfoPanelItem:subclass("EventItem")

EventItem.static.TYPE_TO_ICON = {
	[GameEvent.TYPES.BUILDING_COMPLETE] = "builder",
	[GameEvent.TYPES.WOOD_DEPLETED] = "missing-woodcutter",
	[GameEvent.TYPES.IRON_DEPLETED] = "missing-miner",
	[GameEvent.TYPES.CHILD_BORN] = "child",
	[GameEvent.TYPES.CHILD_DEATH] = "death",
	[GameEvent.TYPES.VILLAGER_DEATH] = "death",
	[GameEvent.TYPES.POPULATION] = "occupied"
}

EventItem.static.WIDTH = 100

function EventItem:initialize(x, y, h, fontNormal, fontBold, event)
	InfoPanelItem.initialize(self, x, y, EventItem.WIDTH, h)

	self.fontNormal = fontNormal
	self.fontBold = fontBold
	self.event = event
	self.unseen = false

	self.icon = ScaledSprite:fromSprite(
		spriteSheet:getSprite("headers", EventItem.TYPE_TO_ICON[event:getType()] .. "-icon"),
		3.0)

	self.text = love.graphics.newText(self.fontNormal)
	self.text:setf(babel.translate(self.event:getText()), self.w - 10, "center")
end

function EventItem:draw(offset)
	self.selected = self.unseen
	InfoPanelItem.draw(self, offset)
end

function EventItem:drawOverlay(offset)
	love.graphics.setFont(self.fontNormal)
	love.graphics.setColor(spriteSheet:getOutlineColor())

	local y = math.max(self.y + 5, self.y + (self.h - self.icon:getHeight() - select(2, self.text:getDimensions())) / 2)
	love.graphics.draw(self.text, self.x + 5 + offset, y)

	love.graphics.setColor(1, 1, 1, 1)
	spriteSheet:draw(self.icon,
	                 self.x + (self.w - self.icon:getWidth()) / 2 + offset,
	                 self.y + self.h - self.icon:getHeight() - 5)
end

function EventItem:setUnseen()
	self.unseen = true
end

function EventItem:select()
	self.unseen = false
	return self.event
end

return EventItem
