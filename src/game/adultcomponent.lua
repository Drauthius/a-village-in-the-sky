local class = require "lib.middleclass"

local WorkComponent = require "src.game.workcomponent"

local AdultComponent = class("AdultComponent")

function AdultComponent:initialize()
	self.hairy = love.math.random(0, 1) == 1

	self:setWorkArea(nil)
	self:setWorkPlace(nil)
	self:setOccupation(WorkComponent.UNEMPLOYED)
end

function AdultComponent:isHairy()
	return self.hairy
end

function AdultComponent:setWorkArea(ti, tj)
	if ti and tj then
		self.workArea = { ti, tj }
	else
		self.workArea = nil
	end
end

function AdultComponent:getWorkArea()
	if self.workArea then
		return unpack(self.workArea)
	end

	return nil
end

function AdultComponent:getWorkPlace()
	return self.workPlace
end

function AdultComponent:setWorkPlace(entity)
	self.workPlace = entity
end

function AdultComponent:setOccupation(occupation)
	self.occupation = occupation
end

function AdultComponent:getOccupation()
	return self.occupation
end

function AdultComponent:getOccupationName()
	return WorkComponent.WORK_NAME[self.occupation]
end

return AdultComponent
