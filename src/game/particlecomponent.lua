local class = require "lib.middleclass"
local table = require "lib.table"

local spriteSheet = require "src.game.spritesheet"

local ParticleComponent = class("ParticleComponent")

function ParticleComponent.static:save(cassette)
	local data = {
		def = {}
	}

	for k,v in pairs(self.def) do
		if k == "_sprite" then
			v = cassette:saveSprite(v)
		elseif k == "_sprites" then
			local sprites = {}
			for _,sprite in ipairs(v) do
				table.insert(sprites, cassette:saveSprite(sprite))
			end
			v = sprites
		end

		data.def[k] = v
	end

	data.destroyWhenDone = self.destroyWhenDone

	if self.particleSystem:isPaused() then
		data.state = "paused"
	elseif self.particleSystem:isStopped() then
		data.state = "stopped"
	elseif self.particleSystem:isActive() then
		data.state = "active"
	else
		data.state = "unknown"
	end

	return data
end

function ParticleComponent.static.load(cassette, data)
	local def = {}

	for k,v in pairs(data.def) do
		if k == "_sprite" then
			v = cassette:loadSprite(v)
		elseif k == "_sprites" then
			local sprites = {}
			for _,sprite in ipairs(v) do
				table.insert(sprites, (cassette:loadSprite(sprite)))
			end
			v = sprites
		end

		def[k] = v
	end

	local component = ParticleComponent(def, 0, data.destroyWhenDone)

	if data.state == "paused" then
		component:getParticleSystem():pause()
	elseif data.state == "stopped" then
		component:getParticleSystem():stop()
	elseif data.state == "active" then
		component:getParticleSystem():start()
	end

	return component
end

function ParticleComponent:initialize(definition, emit, destroyWhenDone)
	self.def = definition
	self:setDestroyWhenDone(destroyWhenDone)

	self:create()

	if emit then
		if emit < 0 then
			self.particleSystem:pause()
		else
			self.particleSystem:emit(emit)
		end
	end
end

function ParticleComponent:create()
	local particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), self.def._buffer)

	for k,v in pairs(self.def) do
		if k:sub(1, 1) ~= "_" then
			local method = "set"..k:gsub("^%l", string.upper)
			if type(v) == "table" then
				particleSystem[method](particleSystem, unpack(v))
			else
				particleSystem[method](particleSystem, v)
			end
		end
	end

	if self.def._sprite then
		local quad = self.def._sprite:getQuad()
		local _, _, w, h = quad:getViewport()

		particleSystem:setQuads(quad)
		particleSystem:setOffset(w / 2, h / 2)
	elseif self.def._sprites then
		local quads = {}
		for _,sprite in ipairs(self.def._sprites) do
			table.insert(quads, sprite:getQuad())
		end

		local _, _, w, h = quads[1]:getViewport()

		particleSystem:setQuads(quads)
		particleSystem:setOffset(w / 2, h / 2)
	end

	self:setParticleSystem(particleSystem)
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
