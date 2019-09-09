--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

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
