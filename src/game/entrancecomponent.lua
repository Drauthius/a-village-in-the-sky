local class = require "lib.middleclass"

local BuildingComponent = require "src.game.buildingcomponent"

local EntranceComponent = class("EntranceComponent")

EntranceComponent.static.GRIDS = {
	[BuildingComponent.DWELLING] = {
		ogi = -3, ogj = 1
	},
	[BuildingComponent.BLACKSMITH] = {
		ogi = 0, ogj = -8
	},
	[BuildingComponent.BAKERY] = {
		ogi = 1, ogj = -6
	}
}

function EntranceComponent.static:save()
	return {
		type = self.type,
		open = self.open
	}
end

function EntranceComponent.static.load(_, data)
	local component = EntranceComponent(data.type)

	component.open = data.open

	return component
end

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
