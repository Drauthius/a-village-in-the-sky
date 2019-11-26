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
local Camera = require "lib.hump.camera"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local Background = class("Background")

Background.static.SCALE_DIFF = 5

local function _createParticleSystem(variant, scale, dw, dh)
	local particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 1000)

	local sprite = spriteSheet:getSprite("clouds "..variant)
	local _, _, w, h = sprite:getQuad():getViewport()
	particleSystem:setQuads(sprite:getQuad())
	particleSystem:setOffset(w/2, h/2)
	particleSystem:setColors(1, 1, 1, 1)
	particleSystem:setSpeed(-0.2, 0)
	particleSystem:setEmitterLifetime(-1)
	particleSystem:setEmissionRate(0.002)
	particleSystem:setEmissionArea("uniform", dw, dh)
	particleSystem:setParticleLifetime(500000)
	particleSystem:setSizeVariation(0.8)
	particleSystem:setSizes(unpack(scale))

	return particleSystem
end

function Background:initialize(worldCamera, opts)
	self.worldCamera = worldCamera
	self.backgroundCamera = Camera()
	self.backgroundCamera:lookAt(0, 0)
	self.parallaxLevel = opts.parallax or 1
	self.color = { 1.0, 1.0, 1.0, 1.0 }

	local dw, dh = screen:getDrawDimensions()
	dw, dh = dw * (opts.widthModifier or 1), dh * (opts.heightModifier or 1)
	local scale = opts.scale or 1
	local scaleDiff = scale / Background.SCALE_DIFF
	local scaleRange = { scale - scaleDiff, scale + scaleDiff }
	self.clouds = {
		_createParticleSystem("0", scaleRange, dw, dh),
		_createParticleSystem("1", scaleRange, dw, dh)
	}

	for _=1,opts.spawn or 10000 do
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
	local dx, dy, dw, dh = screen:getDrawArea()
	self.backgroundCamera:draw(dx, dy, dw, dh, function()
		love.graphics.setColor(self.color)
		for _,cloud in ipairs(self.clouds) do
			love.graphics.draw(cloud)
		end
		love.graphics.setColor(1, 1, 1, 1)
	end)
end

return Background
