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

local SoundSystem = lovetoys.System:subclass("SoundSystem")

function SoundSystem.requires()
	return {"SoundComponent"}
end

function SoundSystem:playAll()
	for _,entity in pairs(self.targets) do
		entity:get("SoundComponent"):play()
	end
end

function SoundSystem:pauseAll()
	for _,entity in pairs(self.targets) do
		entity:get("SoundComponent"):pause()
	end
end

function SoundSystem:stopAll()
	for _,entity in pairs(self.targets) do
		entity:get("SoundComponent"):stop()
	end
end

function SoundSystem:onRemoveEntity(entity)
	entity:get("SoundComponent"):stop()
end

return SoundSystem
