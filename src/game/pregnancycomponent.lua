local class = require "lib.middleclass"

local PregnancyComponent = class("PregnancyComponent")

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
