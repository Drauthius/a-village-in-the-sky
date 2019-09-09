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

local FieldEnclosureComponent = class("FieldEnclosureComponent")

function FieldEnclosureComponent.static:save(cassette)
	return {
		fields = cassette:saveEntityList(self.fields)
	}
end

function FieldEnclosureComponent.static.load(cassette, data)
	local component = FieldEnclosureComponent()

	component.fields = cassette:loadEntityList(data.fields)

	return component
end

function FieldEnclosureComponent:initialize()
	self.fields = {}
end

function FieldEnclosureComponent:getFields()
	return self.fields
end

function FieldEnclosureComponent:setFields(fields)
	self.fields = fields
end

return FieldEnclosureComponent
