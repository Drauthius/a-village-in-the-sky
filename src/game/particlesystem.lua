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
