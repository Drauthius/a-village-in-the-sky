local class = require "lib.middleclass"

local spriteSheet = require "src.game.spritesheet"

local Hint = class("Hint")

Hint.static.SPEED = 2.0

function Hint:initialize()
	self.shown = false
	self.preventDraw = false
	self.pos = 0

	local sprite = spriteSheet:getSprite("spark")

	self.particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 64)
	self.particleSystem:setQuads(sprite:getQuad())
	self.particleSystem:setColors(0.565, 0.827, 0.971, 0.7,
	                              0.565, 0.827, 0.971, 0.4)
	self.particleSystem:setEmissionRate(35)
	self.particleSystem:setEmitterLifetime(-1)
	local _, _, w, h = sprite:getQuad():getViewport()
	self.particleSystem:setOffset(w/2, h/2)
	self.particleSystem:setInsertMode("random")
	self.particleSystem:setRadialAcceleration(-2, -10)
	self.particleSystem:setEmissionArea("uniform", 1, 1)
	self.particleSystem:setParticleLifetime(0.8)
	self.particleSystem:setRotation(-math.pi, math.pi)
	self.particleSystem:setSpeed(10, 10)
	self.particleSystem:setSpread(2*math.pi)
	self.particleSystem:setSizeVariation(0.2)
	self.particleSystem:setSizes(2.5, 1.5)
	self.particleSystem:setSpin(-math.pi, math.pi)
	self.particleSystem:setSpinVariation(1)
end

function Hint:update(dt)
	if self.shown then
		self.pos = self.pos + dt * Hint.SPEED

		local x = self.x + math.cos(self.pos) * self.radius
		local y = self.y + math.sin(self.pos) * self.radius

		self.particleSystem:setPosition(x, y)
		self.particleSystem:update(dt)
	end
end

function Hint:draw(forceDraw, ...)
	if self.shown and (forceDraw or not self.preventDraw) then
		love.graphics.draw(self.particleSystem, ...)
	end
end

function Hint:rotateAround(x, y, radius)
	self.x, self.y = x, y
	self.radius = radius
	self.shown = true
end

function Hint:hide()
	self.shown = false
end

function Hint:setPreventDraw(prevent)
	self.preventDraw = prevent
end

return Hint()
