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

local AnimationComponent = class("AnimationComponent")

function AnimationComponent.static:save(cassette)
	local data = {
		updateTimer = self.updateTimer,
		animation = self.animation,
		currentFrame = self.currentFrame,
		frames = {}
	}

	for _,frame in ipairs(self.frames) do
		table.insert(data.frames, { cassette:saveSprite(frame[1]), frame[2] })
	end

	return data
end

function AnimationComponent.static.load(cassette, data)
	local component = AnimationComponent()

	component.updateTimer = data.updateTimer
	component.animation = data.animation
	component.currentFrame = data.currentFrame

	for _,frame in ipairs(data.frames) do
		table.insert(component.frames, { cassette:loadSprite(frame[1]), frame[2] })
	end

	return component
end

function AnimationComponent:initialize()
	self.updateTimer = 0
	self.animation = nil
	self.currentFrame = 0
	self.frames = {}
end

function AnimationComponent:advance()
	self.currentFrame = math.max((self.currentFrame + 1) % (self.animation.to + 1), self.animation.from)
end

function AnimationComponent:getAnimation()
	return self.animation
end

function AnimationComponent:setAnimation(animation)
	self.updateTimer = 0
	self.animation = animation
	self.currentFrame = animation.from
end

function AnimationComponent:getCurrentFrame()
	return self.currentFrame
end

function AnimationComponent:setCurrentFrame(currentFrame)
	self.currentFrame = currentFrame
end

function AnimationComponent:getFrames()
	return self.frames
end

function AnimationComponent:setFrames(frames)
	self.frames = frames
end

function AnimationComponent:getTimer()
	return self.updateTimer
end

function AnimationComponent:setTimer(t)
	self.updateTimer = t
end

return AnimationComponent
