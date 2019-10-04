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

local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local TileComponent = require "src.game.tilecomponent"
local ScaledSprite = require "src.game.scaledsprite"

local spriteSheet = require "src.game.spritesheet"

local BuildItem = InfoPanelItem:subclass("BuildItem")

BuildItem.static.TILE_TO_ICON = {
	[TileComponent.FOREST] = "woodcutter",
	[TileComponent.MOUNTAIN] = "miner"
}

BuildItem.static.BUILDING_TO_ICON = {
	[BuildingComponent.DWELLING] = "house",
	[BuildingComponent.BLACKSMITH] = "blacksmith",
	[BuildingComponent.FIELD] = "farmer",
	[BuildingComponent.BAKERY] = "baker",
	[BuildingComponent.RUNESTONE] = "runestone"
}

function BuildItem:initialize(x, y, w, h, sprite, font, type, isBuilding, blueprint)
	InfoPanelItem.initialize(self, x, y, w, h)
	self.sprite = sprite
	self.type = type
	self.font = font
	self.isBuilding = isBuilding
	self.blueprint = blueprint

	local icon = BuildItem[self.isBuilding and "BUILDING_TO_ICON" or "TILE_TO_ICON"][self.type]
	if icon then
		self.icon = ScaledSprite:fromSprite(spriteSheet:getSprite("headers", icon .. "-icon"), 2.5)
	end

	-- Align the sprite in the centre.
	local dx = (self.w - sprite:getWidth()) / 2
	self.x = self.x + dx
	self.ox = self.ox - dx
	self.w = self.w - dx
	local dy = (self.h - sprite:getHeight()) / 2
	self.y = self.y + dy
	self.oy = self.oy - dy
	self.h = self.h - dy
end

function BuildItem:drawOverlay(offset)
	local name
	if self.isBuilding then
		name = BuildingComponent.BUILDING_NAME[self.type]
	else
		name = TileComponent.TILE_NAME[self.type]
	end
	name = babel.translate(name)

	-- Some common set up
	love.graphics.setFont(self.font)
	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle("rough")

	local sx, sy = self.x + self.ox + offset + 5, self.y + self.oy + 5
	local w, h = self.font:getWidth(name) + 1, self.font:getHeight() + 1
	local color = spriteSheet:getWoodPalette().bright

	-- Background for the label
	love.graphics.setColor(color[1], color[2], color[3], 0.5)
	love.graphics.rectangle("fill", sx, sy, w, h)
	love.graphics.setColor(spriteSheet:getWoodPalette().outline)
	love.graphics.rectangle("line", sx, sy, w + 1, h + 1)

	-- Print the label
	love.graphics.setColor(spriteSheet:getOutlineColor())
	love.graphics.print(name, sx, sy)

	if self.icon then
		love.graphics.setColor(1, 1, 1, 1)
		spriteSheet:draw(self.icon,
		                 self.x + (self.w - self.icon:getWidth()) / 2 + offset,
		                 self.y + self.h - self.icon:getHeight() - 5)

	end

	if self.isBuilding then
		local materials = ConstructionComponent.MATERIALS[self.type]

		-- First pass to get the proper dimensions
		w, h = 0, 0
		for resource,amount in pairs(materials) do
			if amount > 0 then
				local icon = spriteSheet:getSprite("headers", ResourceComponent.RESOURCE_NAME[resource] .. "-icon")
				w = math.max(w, self.font:getWidth(amount.."x") + 1 + icon:getWidth()) + 1
				h = h + math.max(self.font:getHeight() + 1, icon:getHeight()) + 1
			end
		end

		sx, sy = self.x + self.w - w + offset - 5, self.y + self.oy + 5

		-- Background for the material cost
		love.graphics.setColor(color[1], color[2], color[3], 0.5)
		love.graphics.rectangle("fill", sx, sy, w, h)
		love.graphics.setColor(spriteSheet:getWoodPalette().outline)
		love.graphics.rectangle("line", sx, sy, w + 1, h + 1)

		local oy = 2
		for resource,amount in pairs(materials) do
			if amount > 0 then
				local icon = spriteSheet:getSprite("headers", ResourceComponent.RESOURCE_NAME[resource] .. "-icon")

				love.graphics.setColor(1, 1, 1, 1)
				spriteSheet:draw(icon, sx + w - icon:getWidth(), sy + oy + 1)

				love.graphics.setColor(spriteSheet:getOutlineColor())
				love.graphics.printf(amount.."x", sx + 1, sy + oy, w - icon:getWidth() - 2, "right")

				oy = oy + math.max(self.font:getHeight() + 1, icon:getHeight()) + 1
			end
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function BuildItem:getType()
	return self.type
end

function BuildItem:select()
	InfoPanelItem.select(self)

	return self:blueprint()
end

return BuildItem
