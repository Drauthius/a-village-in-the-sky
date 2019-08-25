local class = require "lib.middleclass"

local SeniorComponent = class("SeniorComponent")

function SeniorComponent.static:save()
end

function SeniorComponent.static.load()
	return SeniorComponent()
end

return SeniorComponent
