local class = require "lib.middleclass"

local ColorSwapComponent = class("ColorSwapComponent")

function ColorSwapComponent:initialize()
	self.oldColors = {}
	self.newColors = {}
end

function ColorSwapComponent:add(oldColors, newColors)
	for i=1,#oldColors do
		table.insert(self.oldColors, oldColors[i])
		table.insert(self.newColors, newColors[i])
	end
end

function ColorSwapComponent:getReplacedColors()
	return self.oldColors
end

function ColorSwapComponent:getReplacingColors()
	return self.newColors
end

return ColorSwapComponent
