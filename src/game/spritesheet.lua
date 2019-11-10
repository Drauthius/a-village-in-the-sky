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
local json = require "lib.json"

local Sprite = require "src.game.sprite"

local SpriteSheet = class("SpriteSheet")

SpriteSheet.static.NAME_SEPARATOR = "\30"
SpriteSheet.static.SLICE_SEPARATOR = "\29"

function SpriteSheet:initialize()
	self.innerMargin = 1
	self:load()
end

function SpriteSheet:load()
	self.image = love.graphics.newImage("asset/gfx/spritesheet.png")
	self.imageData = love.image.newImageData("asset/gfx/spritesheet.png")
	self.data = json.decode(love.filesystem.read("asset/gfx/spritesheet.json"))

	self.spriteCache = {}
end

-- @tparam string/table name The name of the Aseprite source file.
-- @tparam[opt] string slice The slice to get from the source file.
function SpriteSheet:getSprite(name, slice, frame)
	if not self.data then
		error("No data loaded. Cannot load sprite '" .. name .. "'")
	end

	local cacheName = ""
	if type(name) == "table" then
		for i,v in ipairs(name) do
			if i ~= 1 then
				cacheName = cacheName .. SpriteSheet.NAME_SEPARATOR
			end
			cacheName = cacheName .. v
		end
	else
		cacheName = name
	end

	if slice and slice:len() < 1 then
		slice = nil
	end

	cacheName = cacheName .. (slice and (SpriteSheet.SLICE_SEPARATOR .. slice) or "")

	if not self.spriteCache[cacheName] then
		if type(name) ~= "table" then
			name = { name }
		end

		local quads = {}
		local duration
		for _,v in ipairs(name) do
			local def = self.data.frames[v]
			if not def then
				print("Failed to find sprite '"..v.."'")
				return Sprite()
			end
			duration = def.duration

			local x, y, w, h =
				def.frame.x + self.innerMargin, def.frame.y + self.innerMargin,
				def.sourceSize.w, def.sourceSize.h

			if slice then
				local data = self:getData(slice, frame)

				x, y = x + data.bounds.x, y + data.bounds.y
				w, h = data.bounds.w, data.bounds.h
			end

			table.insert(quads, love.graphics.newQuad(x, y, w, h, self.image:getDimensions()))
		end

		self.spriteCache[cacheName] = {
			Sprite(self, cacheName, #quads == 1 and quads[1] or quads),
			duration
		}
	end

	return unpack(self.spriteCache[cacheName])
end

function SpriteSheet:getData(name, frame)
	if not self.data then
		error("No data loaded. Cannot load data '" .. name .. "'")
	end

	frame = frame or 0

	for _,slice in ipairs(self.data.meta.slices) do
		if slice.name == name then
			for _,keys in ipairs(slice.keys) do
				if keys.frame == frame then
					return keys
				end
			end
			break
		end
	end

	print("Failed to find slice '" .. name .. "' frame " .. frame)
	return { bounds = { x = 0, y = 0,  w = 0, h = 0 } }
end

function SpriteSheet:getFrameTag(name)
	if not self.data then
		error("No data loaded. Cannot load data '" .. name .. "'")
	end

	for _,frameTag in ipairs(self.data.meta.frameTags) do
		if frameTag.name == name then
			return frameTag
		end
	end

	print("Failed to find frame tag '" .. name .. "'")
	return { name = name, from = 0, to = 0, direction = "forward" }
end

function SpriteSheet:getImage()
	return self.image
end

function SpriteSheet:getImageData()
	return self.imageData
end

function SpriteSheet:getWoodPalette()
	if not self.woodPalette then
		local woodPalette = self:getSprite("wood-palette")
		self.woodPalette = {
			outline = { woodPalette:getPixel(1, 0) },
			bright = { woodPalette:getPixel(2, 0) },
			medium = { woodPalette:getPixel(3, 0) },
			dark = { woodPalette:getPixel(4, 0) }
		}
	end

	return self.woodPalette
end

-- TODO: Only needed because the current font isn't a pixel font.
function SpriteSheet:getOutlineColor()
	return { 0.10, 0.10, 0.10, 1.0 }
end

function SpriteSheet:draw(sprite, x, y)
	sprite:draw(self.image, x, y)
end

return SpriteSheet()
