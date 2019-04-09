local class = require "lib.middleclass"

local ChildbirthEndedEvent = class("ChildbirthEndedEvent")

function ChildbirthEndedEvent:initialize(mother, father, motherDied, childDied, isIndoors)
	self.mother = mother
	self.motherDied = motherDied
	self.childDied = childDied
	self.isIndoors = isIndoors
end

function ChildbirthEndedEvent:getMother()
	return self.mother
end

function ChildbirthEndedEvent:getFather()
	return self.father
end

function ChildbirthEndedEvent:didMotherSurvive()
	return not self.motherDied
end

function ChildbirthEndedEvent:didChildSurvive()
	return not self.childDied
end

function ChildbirthEndedEvent:wasIndoors()
	return self.isIndoors
end

return ChildbirthEndedEvent
