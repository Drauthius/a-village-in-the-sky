local class = require "lib.middleclass"

local FieldEnclosureComponent = class("FieldEnclosureComponent")

function FieldEnclosureComponent:initialize()
end

function FieldEnclosureComponent:getFields()
	return self.fields
end

function FieldEnclosureComponent:setFields(fields)
	self.fields = fields
end

return FieldEnclosureComponent
