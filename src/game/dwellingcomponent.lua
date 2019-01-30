local class = require "lib.middleclass"

local DwellingComponent = class("DwellingComponent")

function DwellingComponent:initialize()
	self.villagers = setmetatable({}, { __mode = 'v' })
end

function DwellingComponent:assign(villager)
	table.insert(self.villagers, villager)
end

function DwellingComponent:getAssignedVillagers()
	return self.villagers
end

return DwellingComponent
