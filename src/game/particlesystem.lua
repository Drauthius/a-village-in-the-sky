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

local lovetoys = require "lib.lovetoys.lovetoys"

local ParticleSystem = lovetoys.System:subclass("ParticleSystem")

function ParticleSystem.requires()
	return {"ParticleComponent"}
end

function ParticleSystem:initialize(engine)
	lovetoys.System.initialize(self)
	self.engine = engine
end

function ParticleSystem:update(dt)
	for _,entity in pairs(self.targets) do
		local particle = entity:get("ParticleComponent")
		local particleSystem = particle:getParticleSystem()

		particleSystem:update(dt)

		if particle:getDestroyWhenDone() and not particleSystem:isActive() and particleSystem:getCount() < 1 then
			self.engine:removeEntity(entity)
		end
	end
end

return ParticleSystem
