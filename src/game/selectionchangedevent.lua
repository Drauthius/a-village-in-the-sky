local class = require "lib.middleclass"

local SelectionChangedEvent = class("SelectionChangedEvent")

function SelectionChangedEvent:initialize(selection)
	self.selection = selection
end

function SelectionChangedEvent:getSelection()
	return self.selection
end

return SelectionChangedEvent
