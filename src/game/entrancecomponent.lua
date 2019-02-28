local class = require "lib.middleclass"

local BuildingComponent = require "src.game.buildingcomponent"

local EntranceComponent = class("EntranceComponent")

EntranceComponent.static.GRIDS = {
	[BuildingComponent.DWELLING] = {
	},
	[BuildingComponent.BLACKSMITH] = {
		ogi = 0, ogj = -8
	},
	[BuildingComponent.BAKERY] = {
	}
}

function EntranceComponent:initialize(buildingType)
	self.type = buildingType
	self.open = false
end

function EntranceComponent:getEntranceGrid()
	return EntranceComponent.GRIDS[self.type]
end

function EntranceComponent:isOpen()
	return self.open
end

function EntranceComponent:setOpen(open)
	self.open = open
end

return EntranceComponent
