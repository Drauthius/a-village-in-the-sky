local class = require "lib.middleclass"

local AnimationComponent = class("AnimationComponent")

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
