local class = require "lib.middleclass"

local DwellingComponent = class("DwellingComponent")

function DwellingComponent.static:save(cassette)
	return {
		food = self.food,
		gettingFood = self.gettingFood,
		numBoys = self.numBoys,
		numGirls = self.numGirls,
		children = cassette:saveEntityList(self.children),
		related = self.related
	}
end

function DwellingComponent.static.load(cassette, data)
	local component = DwellingComponent()

	component.food = data.food
	component.gettingFood = data.gettingFood
	component.numBoys = data.numBoys
	component.numGirls = data.numGirls
	component.children = cassette:loadEntityList(data.children)
	component.related = data.related

	return component
end

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

	if child:get("VillagerComponent"):getGender() == "male" then
		self:setNumBoys(self:getNumBoys() + 1)
	else
		self:setNumGirls(self:getNumGirls() + 1)
	end
end

function DwellingComponent:removeChild(child)
	local found = false
	for k,v in ipairs(self.children) do
		if child == v then
			found = true
			table.remove(self.children, k)
			break
		end
	end
	assert(found, "Called to remove child not part of this dwelling.")

	if child:get("VillagerComponent"):getGender() == "male" then
		self:setNumBoys(self:getNumBoys() - 1)
	else
		self:setNumGirls(self:getNumGirls() - 1)
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
