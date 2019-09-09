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

--- Defines a generic GUI widget interface.
-- @classmod Widget
-- @author Albert Diserholt
-- @license GPLv3+

local class = require("lib.middleclass")

local prefix = ... and (...):match("(.-%.?)[^%.]+$") or ""

local Bound = require(prefix .. "bound")
local Widget = class("Widget")

--- Call a callback hook.
-- @tparam Widget widget The widget to check the hook for.
-- @tparam string event The event that occurred.
-- @param ... Any extra arguments to the callback.
local function _call(widget, event, ...)
	if widget._hooks[event] then
		widget._hooks[event](widget, ...)
	end
end

--- Initializes a new dummy widget.
-- @tparam Bound bound The bounding area used by the widget.
-- Asserts that it exists and is of the right class.
function Widget:initialize(bound)
	assert(type(bound) == "table" and bound:isInstanceOf(Bound), "Only accepts instances of Bound, but got " .. tostring(bound))

	--- The bounding area for the widget.
	self._boundingArea = bound
	--- Whether the widget is currently focused.
	self._focused = false
	--- Whether the widget is pressed down.
	self._pressed = false
	--- Hooks for different events.
	-- @see setHook
	self._hooks = {}
end

--- Call when the widget is focused.
function Widget:focused()
	self._focused = true
	_call(self, "onFocus")
end

--- Call when the widget loses focus.
function Widget:unfocused()
	self._focused = false
	_call(self, "onUnfocus")
end

--- Determine whether the widget is focused.
-- @treturn bool Whether the widget is currently focused.
function Widget:isFocused()
	return self._focused
end

--- Call when the widget is pressed down.
-- @tparam[opt] number x The x-coordinate where the widget was pressed.
-- @tparam[opt] number y The y-coordinate where the widget was pressed.
function Widget:pressed(x, y)
	self._pressed = true
	_call(self, "onPress", x, y)
end

--- Call when the widget is released (after being pressed down).
-- @tparam[opt] number x The x-coordinate where the widget was pressed.
-- @tparam[opt] number y The y-coordinate where the widget was pressed.
function Widget:released(x, y)
	self._pressed = false
	_call(self, "onRelease", x, y)
end

--- Determine whether the widget is pressed.
-- @treturn bool Whether the widget is currently pressed.
function Widget:isPressed()
	return self._pressed
end

--- Call when the widget is dragged (pressed down and moved).
--function Widget:drag()
--end

--- Get the bounding area used by the widget.
-- @treturn Bound The widget's bounding area.
function Widget:getBound()
	return self._boundingArea
end

--- Set a hook to be called when the specified event occurs.
-- Only one callback can be set per action. Setting a new one will overwrite
-- the old one. Using `nil` clears the previous callback.
-- @tparam string event The event to receive a callback for. This can be either
-- "onFocus", "onUnfocus", "onPress", "onRelease", "onUpdate" or "onDraw".
-- @tparam function callback The function or callable table to invoke when the
-- event occurs. The first argument is always the widget instance. "onUpdate"
-- receives the delta time as second argument. "onPress" and "onRelease" might
-- receive x and y-coordinates where the press or release originated.
function Widget:setHook(event, callback)
	assert(event == "onFocus" or
	       event == "onUnfocus" or
	       event == "onPress" or
	       event == "onRelease" or
	       event == "onUpdate" or
	       event == "onDraw", "Received unknown event " .. tostring(event))

	self._hooks[event] = callback
end

--- Called to update the widget.
-- @tparam number dt Number of seconds since the last update.
function Widget:update(dt)
	_call(self, "onUpdate", dt)
end

--- Called to draw the widget.
-- Calls `draw()` on the bounding area as well.
function Widget:draw()
	self:getBound():draw()

	_call(self, "onDraw")
end

return Widget
