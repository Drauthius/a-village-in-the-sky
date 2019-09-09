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

local InfoPanelItem = require "src.game.gui.infopanelitem"

local spriteSheet = require "src.game.spritesheet"

local BuildingItem = InfoPanelItem:subclass("BuildingItem")

function BuildingItem:initialize(x, y, h, fontNormal, fontBold, entity)
	InfoPanelItem.initialize(self, x, y, 160, h)

	self.sprite = entity:get("SpriteComponent"):getSprite()
	self.fontNormal = fontNormal
	self.fontBold = fontBold
	self.entity = entity
end

function BuildingItem:drawOverride(offset)
	spriteSheet:draw(self.sprite, self.x + offset + 2, self.y + 2)
end

function BuildingItem:select()
	InfoPanelItem.select(self)

	return self:getEntity()
end

function BuildingItem:getEntity()
	return self.entity
end

return BuildingItem
