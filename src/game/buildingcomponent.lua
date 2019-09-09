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

local class = require "lib.middleclass"

local BuildingComponent = class("BuildingComponent")

BuildingComponent.static.DWELLING = 0
BuildingComponent.static.BLACKSMITH = 1
BuildingComponent.static.FIELD = 2
BuildingComponent.static.BAKERY = 3
BuildingComponent.static.RUNESTONE = 4 -- Not technically a building, but required for construction sites.

BuildingComponent.static.BUILDING_NAME = {
	[BuildingComponent.static.DWELLING] = "dwelling",
	[BuildingComponent.static.BLACKSMITH] = "blacksmith",
	[BuildingComponent.static.FIELD] = "field",
	[BuildingComponent.static.BAKERY] = "bakery",
	[BuildingComponent.static.RUNESTONE] = "runestone",
}

function BuildingComponent.static:save(cassette)
	return {
		type = self.type,
		ti = self.ti,
		tj = self.tj,
		villagersInside = cassette:saveEntityList(self.villagersInside),
		chimneys = cassette:saveEntityList(self.chimneys),
		children = cassette:saveEntityList(self.children)
	}
end

function BuildingComponent.static.load(cassette, data)
	local component = BuildingComponent(data.type, data.ti, data.tj)

	component.villagersInside = cassette:loadEntityList(data.villagersInside)
	component.chimneys = cassette:loadEntityList(data.chimneys)
	component.children = cassette:loadEntityList(data.children)

	return component
end

function BuildingComponent:initialize(type, ti, tj)
	self:setType(type)
	self:setPosition(ti, tj)
	self.villagersInside = {}
	self.chimneys = {}
	self.children = {}
end

function BuildingComponent:setType(type)
	self.type = type
end

function BuildingComponent:getType()
	return self.type
end

function BuildingComponent:getPosition()
	return self.ti, self.tj
end

function BuildingComponent:setPosition(ti, tj)
	self.ti, self.tj = ti, tj
end

function BuildingComponent:getInside()
	return self.villagersInside
end

function BuildingComponent:addInside(villager)
	table.insert(self.villagersInside, villager)
end

function BuildingComponent:removeInside(villager)
	for k,v in ipairs(self.villagersInside) do
		if v == villager then
			table.remove(self.villagersInside, k)
			return
		end
	end

	error("Villager was not inside.")
end

function BuildingComponent:addChimney(chimney)
	table.insert(self.chimneys, chimney)
end

function BuildingComponent:getChimneys()
	return self.chimneys
end

function BuildingComponent:addChildEntity(entity)
	table.insert(self.children, entity)
end

function BuildingComponent:getChildEntities()
	return self.children
end

return BuildingComponent
