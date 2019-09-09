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

local TimerComponent = class("TimerComponent")

-- 1 minute is 1 year.
TimerComponent.static.YEARS_TO_SECONDS = 60
TimerComponent.static.YEARS_PER_SECOND = 1 / TimerComponent.YEARS_TO_SECONDS

function TimerComponent.static:save(cassette)
	local data = {
		delay = self.delay,
		time = self.time,
		callback = self.callback,
		oneshot = self.oneshot
	}

	if self.data then
		data.data = {}
		-- Handle very basic conversions here.
		for k,v in pairs(self.data) do
			if type(v) == "table" and v.class then
				assert(v.class.name == "Entity", "Unable to save non-entity class "..tostring(v.class.name))
				data.data[k] = cassette:saveEntity(v)
			else
				assert(type(v) ~= "userdata")
				data.data[k] = v
			end
		end
	end

	return data
end

function TimerComponent.static.load(cassette, data)
	local component = TimerComponent(data.delay, data.callback, data.oneshot)

	component.time = data.time

	if data.data then
		component.data = {}
		for k,v in pairs(data.data) do
			if cassette:isEntity(v) then
				component.data[k] = cassette:loadEntity(v)
			else
				component.data[k] = v
			end
		end
	end

	return component
end

-- @tparam number delay Number of seconds before issuing the callback.
-- @param[opt] data Data to give to the callback.
-- @tparam[noopt] callback function The callback to invoke. Note: Should not use upvalues to work with saving/loading.
-- @tparam[opt=true] boolean Whether the timer should be reset once it has completed.
function TimerComponent:initialize(delay, data, callback, oneshot)
	self.delay = assert(tonumber(delay), "Delay must be a number")
	self.time = self.delay

	-- Data can be omitted.
	if (callback == nil or type(callback) == "boolean") and type(data) == "function" then
		self.data = nil
		self.callback = data
		self.oneshot = callback or true
	else
		self.data = data
		self.callback = callback
		self.oneshot = oneshot or true
	end
	assert(self.callback, "Callback not specified")
end

function TimerComponent:increase(dt)
	if self.time > 0.0 then
		self.time = self.time - dt

		if self.time <= 0.0 then
			self.callback(self.data)
		end

		if not self.oneshot then
			self.time = self.time + self.delay
		end
	end
end

return TimerComponent
