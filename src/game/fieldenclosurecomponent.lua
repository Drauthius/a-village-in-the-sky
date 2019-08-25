local class = require "lib.middleclass"

local FieldEnclosureComponent = class("FieldEnclosureComponent")

function FieldEnclosureComponent.static:save(cassette)
	return {
		fields = cassette:saveEntityList(self.fields)
	}
end

function FieldEnclosureComponent.static.load(cassette, data)
	local component = FieldEnclosureComponent()

	component.fields = cassette:loadEntityList(data.fields)

	return component
end

function FieldEnclosureComponent:initialize()
	self.fields = {}
end

function FieldEnclosureComponent:getFields()
	return self.fields
end

function FieldEnclosureComponent:setFields(fields)
	self.fields = fields
end

return FieldEnclosureComponent
