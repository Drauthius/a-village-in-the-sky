local lovetoys = require "lib.lovetoys.lovetoys"

local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local RenderSystem = lovetoys.System:subclass("RenderSystem")

function RenderSystem:initialize()
	lovetoys.System.initialize(self)

	self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
end

function RenderSystem.requires()
	return {"SpriteComponent"}
end

function RenderSystem:draw()
	love.graphics.setColor(1, 1, 1)
	local ground = {}
	local objects = {}

	-- TODO: Can be optimized (spritebatched)
	for _,entity in pairs(self.targets) do
		if entity:has("TileComponent") then
			table.insert(ground, entity)
			table.sort(ground, function(a, b)
				local ai, aj = a:get("TileComponent"):getPosition()
				local bi, bj = b:get("TileComponent"):getPosition()
				if aj < bj then
					return true
				elseif aj == bj then
					return ai < bi
				else
					return false
				end
			end)
		end
	end

	-- TODO: Can probably cache (overwrite addEntity/removeEntity?)
	for _,entity in pairs(self.targets) do
		if entity:has("PositionComponent") then
			table.insert(objects, entity)
			table.sort(objects, function(a, b)
				local agrid = a:get("PositionComponent"):getPosition()
				local bgrid = b:get("PositionComponent"):getPosition()
				--if aj < bj then
					--return false
				--elseif aj == bj then
					--return ai > bi
				--else
					--return false
				--end
				if agrid.gi == bgrid.gi then
					return agrid.gj < bgrid.gj
				end
				return agrid.gi < bgrid.gi
			end)
		end
	end

	if state:isPlacing() then
		table.insert(objects, state:getPlacing())
	end

	for _,entity in ipairs(ground) do
		local sprite = entity:get("SpriteComponent")
		love.graphics.setColor(sprite:getColor())
		spriteSheet:draw(sprite:getSprite(), sprite:getDrawPosition())
	end

	for _,entity in ipairs(objects) do
		local sprite = entity:get("SpriteComponent")

		if entity:has("UnderConstructionComponent") then
			local percent = entity:get("UnderConstructionComponent"):getPercentDone()
			local dx, dy = sprite:getDrawPosition()

			-- Shadowed background
			love.graphics.setColor(1, 1, 1, 0.5)
			spriteSheet:draw(sprite:getSprite(), dx, dy)

			local quad = sprite:getSprite():getQuad()
			local x, y, w, h = quad:getViewport()
			local _, ty, _, th = sprite:getSprite():getTrimmedDimensions()

			-- Completed overlay
			local deficit = th - th * percent / 100
			quad:setViewport(x, y + ty + deficit, w, th - deficit)
			love.graphics.setColor(1, 1, 1, 1)
			spriteSheet:draw(sprite:getSprite(), dx, dy + ty + deficit)
			-- Reset
			quad:setViewport(x, y, w, h)

			-- Prepare text
			love.graphics.setFont(self.font)
			local grid = entity:get("PositionComponent"):getPosition()
			local gi, gj = grid.gi, grid.gj
			-- TODO
			local ox, oy = 4, 2
			local Fx, Fy = (gi - gj) * ox, (gi + gj) * oy
			Fy = Fy - oy * 2 - self.font:getHeight()

			-- Drop shadow
			love.graphics.setColor(0, 0, 0, 0.5)
			love.graphics.print(percent .. "%", Fx + 1, Fy + 1)
			-- Text
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(percent .. "%", Fx, Fy)
		else
			love.graphics.setColor(sprite:getColor())
			spriteSheet:draw(sprite:getSprite(), sprite:getDrawPosition())
		end
	end

	for _,entity in ipairs(objects) do
		local sprite = entity:get("SpriteComponent")

		if false and entity:has("VillagerComponent") then
			local villager = entity:get("VillagerComponent")

			local header = spriteSheet:getSprite("headers", "person-header")
			local x, y = sprite:getDrawPosition()
			x = x - 5
			if villager:isAdult() then
				y = y - 10
			else
				y = y - 8
			end
			--self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
			local font = love.graphics.newFont("asset/font/Norse.otf", 14)
			font:setFilter("linear", "linear", 1)
			--print(font:getFilter())
			love.graphics.setFont(font)
			spriteSheet:draw(header, x, y)
			love.graphics.print("Lars Larsson", x, y)
		elseif entity:has("UnderConstructionComponent") and mode == 1 then
			local header = spriteSheet:getSprite("headers", "4-spot-building-header")
			local x, y = sprite:getDrawPosition()
			local w, h = header:getDimensions()
			local tw = sprite:getSprite():getWidth()

			x = x + (tw - w) / 2
			y = y - h / 2
			spriteSheet:draw(header, x, y)

			local icon = spriteSheet:getSprite("headers", "occupied-icon")
			for i=1,#entity:get("UnderConstructionComponent"):getAssignedVillagers() do
				-- TODO: Value
				spriteSheet:draw(icon, 9 + x + ((i - 1) * (icon:getWidth() + 1)), y + 1)
			end
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return RenderSystem
