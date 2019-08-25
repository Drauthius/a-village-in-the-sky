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
