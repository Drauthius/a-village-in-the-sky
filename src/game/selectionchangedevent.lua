local class = require "lib.middleclass"

local SelectionChangedEvent = class("SelectionChangedEvent")

function SelectionChangedEvent:initialize(selection, isPlacing)
	self.selection = selection
	self.placing = isPlacing
end

function SelectionChangedEvent:getSelection()
	return self.selection
end

function SelectionChangedEvent:isPlacing()
	return self.placing
end

return SelectionChangedEvent
