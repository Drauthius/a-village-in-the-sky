local class = require "lib.middleclass"

local DwellingComponent = class("DwellingComponent")

function DwellingComponent:initialize()
	self.food = 0
	self.gettingFood = false
	self.numBoys = 0
	self.numGirls = 0
	self.children = {}
	self.related = false
end

function DwellingComponent:setFood(amount)
	self.food = amount
end

function DwellingComponent:getFood()
	return self.food
end

function DwellingComponent:isGettingFood()
	return self.gettingFood
end

function DwellingComponent:setGettingFood(gettingFood)
	self.gettingFood = gettingFood
end

function DwellingComponent:getNumBoys()
	return self.numBoys
end

function DwellingComponent:setNumBoys(numBoys)
	self.numBoys = numBoys
end

function DwellingComponent:getNumGirls()
	return self.numGirls
end

function DwellingComponent:setNumGirls(numGirls)
	self.numGirls = numGirls
end

function DwellingComponent:addChild(child)
	table.insert(self.children, child)
end

function DwellingComponent:removeChild(child)
	for k,v in ipairs(self.children) do
		if child == v then
			table.remove(self.children, k)
			return
		end
	end
end

function DwellingComponent:getChildren()
	return self.children
end

function DwellingComponent:isRelated()
	return self.related
end

function DwellingComponent:setRelated(related)
	self.related = related
end

return DwellingComponent
