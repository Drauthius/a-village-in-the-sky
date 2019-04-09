local class = require "lib.middleclass"

local FertilityComponent = class("FertilityComponent")

function FertilityComponent:initialize()
	-- This is the chance to produce a baby per intercourse.
	self.fertility = love.math.random(55, 95) / 100.0
end

function FertilityComponent:getFertility()
	return self.fertility
end

function FertilityComponent:setFertility(fertility)
	self.fertility = fertility
end

return FertilityComponent
