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

local GameEvent = class("GameEvent")

GameEvent.static.TYPES = {
	BUILDING_COMPLETE = 0,
	WOOD_DEPLETED = 1,
	IRON_DEPLETED = 2,
	CHILD_BORN = 3,
	CHILD_DEATH = 4,
	VILLAGER_DEATH = 5,
	POPULATION = 6
}

function GameEvent:initialize(type, ti, tj, text)
	self.type = type
	self.ti, self.tj = ti, tj
	self.text = text
end

function GameEvent:getType()
	return self.type
end

function GameEvent:getText()
	return self.text
end

function GameEvent:getTile()
	return self.ti, self.tj
end

function GameEvent:__serialize()
	return { self.type, self.ti, self.tj, self.text }
end

return GameEvent
