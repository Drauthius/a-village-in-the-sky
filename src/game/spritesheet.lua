local class = require "lib.middleclass"
local json = require "lib.json"

local Sprite = require "src.game.sprite"

local SpriteSheet = class("SpriteSheet")

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
		if #name == 1 then
			name = name[1]
			cacheName = name
		else
			for _,v in ipairs(name) do
				cacheName = cacheName .. v .. "¦"
			end
		end
	else
		cacheName = name
	end

	cacheName = cacheName .. (slice and ("|" .. slice) or "")

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
			Sprite(self, #quads == 1 and quads[1] or quads),
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
	return { 0.15, 0.15, 0.15, 1.0 }
end

function SpriteSheet:draw(sprite, x, y)
	sprite:draw(self.image, x, y)
end

return SpriteSheet()
