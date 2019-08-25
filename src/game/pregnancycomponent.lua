local class = require "lib.middleclass"

local PregnancyComponent = class("PregnancyComponent")

function PregnancyComponent.static:save(cassette)
	return {
		expected = self.expected,
		father = cassette:saveEntity(self.father),
		inLabour = self.inLabour
	}
end

function PregnancyComponent.static.load(cassette, data)
	local component = PregnancyComponent(data.expected, cassette:loadEntity(data.father))

	component.inLabour = data.inLabour

	return component
end

function PregnancyComponent:initialize(expected, father)
	self.expected = expected
	self.father = father
	self.inLabour = false
end

function PregnancyComponent:getExpected()
	return self.expected
end

function PregnancyComponent:setExpected(expected)
	self.expected = expected
end

function PregnancyComponent:isInLabour()
	return self.inLabour
end

function PregnancyComponent:setInLabour(inLabour)
	self.inLabour = inLabour
end

function PregnancyComponent:getFather()
	return self.father
end

return PregnancyComponent
