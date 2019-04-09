local class = require "lib.middleclass"

local BuildingComponent = class("BuildingComponent")

BuildingComponent.static.DWELLING = 0
BuildingComponent.static.BLACKSMITH = 1
BuildingComponent.static.FIELD = 2
BuildingComponent.static.BAKERY = 3

BuildingComponent.static.BUILDING_NAME = {
	[BuildingComponent.static.DWELLING] = "dwelling",
	[BuildingComponent.static.BLACKSMITH] = "blacksmith",
	[BuildingComponent.static.FIELD] = "field",
	[BuildingComponent.static.BAKERY] = "bakery"
}

function BuildingComponent:initialize(type, ti, tj)
	self:setType(type)
	self:setPosition(ti, tj)
	self.villagersInside = {}
	self.chimneys = {}
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

return BuildingComponent
