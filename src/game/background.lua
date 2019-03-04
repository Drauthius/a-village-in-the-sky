local class = require "lib.middleclass"
local Camera = require "lib.hump.camera"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local Background = class("Background")

Background.static.SCALE_DIFF = 5

local function _createParticleSystem(variant, scale)
	local drawArea = screen:getDrawArea()
	local particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 1000)

	local sprite = spriteSheet:getSprite("clouds "..variant)
	local _, _, w, h = sprite:getQuad():getViewport()
	particleSystem:setQuads(sprite:getQuad())
	particleSystem:setOffset(w/2, h/2)
	particleSystem:setColors(1, 1, 1, 1)
	particleSystem:setSpeed(-0.2, 0)
	particleSystem:setEmitterLifetime(-1)
	particleSystem:setEmissionRate(0.002)
	particleSystem:setEmissionArea("uniform", drawArea.width / 1.5, drawArea.height / 1.5)
	particleSystem:setParticleLifetime(100000)
	particleSystem:setSizeVariation(0.8)
	particleSystem:setSizes(unpack(scale))

	return particleSystem
end

function Background:initialize(worldCamera, parallaxLevel, scale)
	self.worldCamera = worldCamera
	self.backgroundCamera = Camera()
	self.backgroundCamera:lookAt(0, 0)
	self.parallaxLevel = parallaxLevel
	self.color = { 1.0, 1.0, 1.0, 1.0 }

	local scaleDiff = scale / Background.SCALE_DIFF
	local scaleRange = { scale - scaleDiff, scale + scaleDiff }
	self.clouds = {
		_createParticleSystem("0", scaleRange),
		_createParticleSystem("1", scaleRange)
	}

	for _=1,10000 do
		self:update(0.5)
	end
end

function Background:setZoom(scale)
	self.backgroundCamera:zoomTo(scale)
end

function Background:setColor(color)
	self.color = color
end

function Background:update(dt)
	local x, y = self.worldCamera:position()
	self.backgroundCamera:lookAt(math.floor(x * self.parallaxLevel), math.floor(y * self.parallaxLevel))
	for _,cloud in ipairs(self.clouds) do
		cloud:update(dt)
	end
end

function Background:draw()
	local drawArea = screen:getDrawArea()
	self.backgroundCamera:draw(drawArea.x, drawArea.y, drawArea.width, drawArea.height, function()
		love.graphics.setColor(self.color)
		for _,cloud in ipairs(self.clouds) do
			love.graphics.draw(cloud)
		end
		love.graphics.setColor(1, 1, 1, 1)
	end)
end

return Background
