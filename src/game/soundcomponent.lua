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

local soundManager = require "src.soundmanager"

local SoundComponent = class("SoundComponent")

function SoundComponent.static:save(cassette)
	return {
		effect = self.effect,
		loop = self.loop,
		gi = type(self.gi) == "table" and cassette:saveGrid(self.gi) or self.gi,
		gj = self.gj
	}
end

function SoundComponent.static.load(cassette, data)
	return SoundComponent(data.effect, data.loop, data.gi, data.gj)
end

function SoundComponent:initialize(effect, loop, gi, gj)
	self.effect = effect
	self.loop = loop or false
	self.gi, self.gj = gi, gj

	if self.loop then
		-- Queued sources cannot loop, so this is a bit special.
		self.source = love.audio.newSource("asset/sfx/"..effect..".wav", "static")
		local _, x, y
		if gi and gj then
			if type(gi) == "table" then
				gi, gj = gi.gi, gi.gj
			end
			_, x, y = soundManager.positionFunc(gi, gj)
			self.source:setPosition(x, y, 0)
			self.source:setRelative(false)
		else
			self.source:setPosition(0, 0, 0)
			self.source:setRelative(true)
		end
		self.source:setLooping(true)
	else
		self.source = soundManager:playEffect(self.effect, gi, gj)
	end

	if self.source then
		self.source:play()
	end
end

function SoundComponent:setPitch(pitch)
	if self.source then
		self.source:setPitch(pitch)
	end
end

function SoundComponent:stop()
	if self.source then
		self.source:stop()
		self.source:release()
		self.source = nil
	end
end

return SoundComponent
