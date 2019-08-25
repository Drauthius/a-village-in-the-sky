local class = require "lib.middleclass"

local WorkComponent = require "src.game.workcomponent"

local AdultComponent = class("AdultComponent")

function AdultComponent.static:save(cassette)
	return {
		workArea = self.workArea,
		workPlace = self.workPlace and cassette:saveEntity(self.workPlace) or nil,
		occupation = self.occupation
	}
end

function AdultComponent.static.load(cassette, data)
	local component = AdultComponent()

	if data.workArea then
		component:setWorkArea(unpack(data.workArea))
	end

	component:setWorkPlace(data.workPlace and cassette:loadEntity(data.workPlace) or nil)
	component:setOccupation(data.occupation)

	return component
end

function AdultComponent:initialize()
	self:setWorkArea(nil)
	self:setWorkPlace(nil)
	self:setOccupation(WorkComponent.UNEMPLOYED)
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
