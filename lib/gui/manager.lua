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

--- Defines a manager for GUI widgets.
-- @classmod WidgetManager
-- @author Albert Diserholt
-- @license GPLv3+

local class = require("lib.middleclass")

local prefix = ... and (...):match("(.-%.?)[^%.]+$") or ""
local Widget = require(prefix .. "widget")
local WidgetManager = class("WidgetManager")

--- Creates a new empty widget manager.
function WidgetManager:initialize()
	--- The ordered list of z-indices.
	self._zIndices = {}
	--- The list of added widgets.
	self._widgets = {}
end

--- Add a widget to the manager.
-- The widget will be automatically drawn and updated.
-- @tparam Widget widget The widget to manage.
-- @tparam[opt=0] number zIndex The stack order of the widget. A widget with
-- greater stack order is always in front of a widget with a lower stack order.
function WidgetManager:addWidget(widget, zIndex)
	assert(type(widget) == "table" and widget:isInstanceOf(Widget), "Only accepts instances of Widget, but got " .. tostring(widget))
	zIndex = zIndex or 0

	if not self._widgets[zIndex] then
		local n = 1
		for i,v in ipairs(self._zIndices) do
			if zIndex < v then
				n = i
				break
			end
		end

		table.insert(self._zIndices, n, zIndex)
		self._widgets[zIndex] = {}
	end

	table.insert(self._widgets[zIndex], widget)
end

--- Get the first widget with a bounding area at the specified point.
-- @tparam number x The x-coordinate of the point.
-- @tparam number y The y-coordinate of the point.
-- @treturn[1] Widget The widget with the highest z-index whose bounding area
-- contains the point, or the widget who was added first if z-indices overlap.
-- @return[2] `nil` No added widget has a bounding area containing the point.
function WidgetManager:getWidgetAt(x, y)
	for _,zIndex in ipairs(self._zIndices) do
		for _,widget in ipairs(self._widgets[zIndex]) do
			if widget:getBound() and widget:getBound():isWithin(x, y) then
				return widget
			end
		end
	end

	return nil
end

--- Get widgets with a bounding area at the specified point.
-- @tparam number x The x-coordinate of the point.
-- @tparam number y The y-coordinate of the point.
-- @treturn table An array with all widgets whose bounding area contains the
-- point. The array is ordered by z-index, or by the order they were added if
-- the widgets share a z-index.
function WidgetManager:getWidgetsAt(x, y)
	local ret = {}

	for _,zIndex in ipairs(self._zIndices) do
		for _,widget in ipairs(self._widgets[zIndex]) do
			if widget:getBound():isWithin(x, y) then
				table.insert(ret, widget)
			end
		end
	end

	return ret
end

--- Update the widget manager and all added widgets.
-- The order in which widgets are updated is not specified.
-- @tparam number dt Number of seconds since the last update.
function WidgetManager:update(dt)
	for _,layer in pairs(self._widgets) do
		for _,widget in ipairs(layer) do
			widget:update(dt)
		end
	end
end

--- Draw all added widgets.
-- The widgets are drawn by z-index, or by the order they were added if the
-- widgets share a z-index.
function WidgetManager:draw()
	for _,zIndex in ipairs(self._zIndices) do
		for _,widget in ipairs(self._widgets[zIndex]) do
			widget:draw()
		end
	end
end

return WidgetManager
