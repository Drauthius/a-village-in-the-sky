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
	local x, y = self.x + offset + 2, self.y + 2
	local w, h = self.w - 4, self.h - 4
	local th = self.fontBold:getHeight() * 1.2

	if self.entity:has("ConstructionComponent") then
		love.graphics.setFont(self.fontBold)
		love.graphics.setColor(spriteSheet:getOutlineColor())
		love.graphics.printf(babel.translate("Under construction"), x, y, w, "center")

		love.graphics.setColor(1, 1, 1, 1)
	end

	y = y + th

	spriteSheet:draw(self.sprite, x + (w - self.sprite:getWidth()) / 2, y)

	love.graphics.setFont(self.fontNormal)
	love.graphics.setColor(spriteSheet:getOutlineColor())

	y = y + h - 2 * th
	if self.entity:has("AssignmentComponent") then
		local assignment = self.entity:get("AssignmentComponent")
		love.graphics.printf(string.format("%s: %d/%d",
		                                   babel.translate("Villagers"),
		                                   assignment:getNumAssignees(),
		                                   assignment:getMaxAssignees()),
		                     x, y, w, "center")
	end

	y = y - th
	if self.entity:has("RunestoneComponent") then
		love.graphics.printf(string.format("%s: %d",
		                                   babel.translate("Stage"),
		                                   self.entity:get("RunestoneComponent"):getLevel()),
		                     x, y, w, "center")
	elseif self.entity:has("DwellingComponent") then
		love.graphics.printf(string.format("%s: %.1f",
		                                   babel.translate("Food"),
		                                   self.entity:get("DwellingComponent"):getFood()),
		                     x, y, w, "center")
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function BuildingItem:select()
	InfoPanelItem.select(self)

	return self:getEntity()
end

function BuildingItem:getEntity()
	return self.entity
end

return BuildingItem
