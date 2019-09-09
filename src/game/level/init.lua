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

local Level = class("Level")

function Level:initialize(engine, map, gui)
	self.engine = engine
	self.map = map
	self.gui = gui
end

function Level:initial()
	error("Must be overloaded")
end

function Level:update(dt)
	if not self.objectives then
		return
	end

	if not self.currentObjective then
		self.currentObjective = 1
		self.numObjectives = #self.objectives
	end

	for i=self.currentObjective,self.numObjectives do
		local objective = self.objectives[i]
		if i > self.currentObjective and not objective.withPrevious then
			break
		end

		if not objective.completed then
			if objective.cond() then
				if i == self.currentObjective then
					self.currentObjective = i + 1
				end
				if objective.id then
					self.gui:removeObjective(objective.id)
				end
				objective.completed = true
				if objective.post then
					objective.post()
				end
			elseif not objective.id then
				objective.id = self.gui:addObjective(objective.text)
				if objective.pre then
					objective.pre()
				end
			end
		elseif i == self.currentObjective then
			self.currentObjective = i + 1
		end
	end

	if self.currentObjective > self.numObjectives then
		self.objectives = nil
	end
end

function Level:getResources(tileType)
	return 0, 0
end

function Level:shouldPlaceRunestone(ti, tj)
	return false
end

function Level:save(cassette)
	return {
		currentObjective = self.currentObjective,
		numObjectives = self.numObjectives
	}
end

function Level:load(cassette, data)
	self.currentObjective = data.currentObjective
	self.numObjectives = data.numObjectives
end

return Level
