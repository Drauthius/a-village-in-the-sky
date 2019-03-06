local class = require "lib.middleclass"

local DwellingComponent = class("DwellingComponent")

function DwellingComponent:initialize()
	self.food = 0
	self.gettingFood = false
end

function DwellingComponent:addFood(amount)
	self.food = self.food + amount
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

return DwellingComponent
