local class = require "lib.middleclass"

local ParticleComponent = class("ParticleComponent")

function ParticleComponent:initialize(particleSystem, destroyWhenDone)
	self:setParticleSystem(particleSystem)
	self:setDestroyWhenDone(destroyWhenDone)
end

function ParticleComponent:getParticleSystem()
	return self.particleSystem
end

function ParticleComponent:setParticleSystem(particleSystem)
	self.particleSystem = particleSystem
end

function ParticleComponent:getDestroyWhenDone()
	return self.destroyWhenDone
end

function ParticleComponent:setDestroyWhenDone(destroyWhenDone)
	self.destroyWhenDone = destroyWhenDone
end

return ParticleComponent
