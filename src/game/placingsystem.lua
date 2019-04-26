local lovetoys = require "lib.lovetoys.lovetoys"
local table = require "lib.table"

local BuildingComponent = require "src.game.buildingcomponent"
local TileComponent = require "src.game.tilecomponent"

local state = require "src.game.state"

local PlacingSystem = lovetoys.System:subclass("PlacingSystem")

PlacingSystem.static.OUTLINE_SHADER = love.graphics.newShader([[
extern vec2 stepSize;
extern vec4 outlineColor;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	number alpha = 4 * Texel(texture, texture_coords).a;
	alpha -= Texel(texture, texture_coords + vec2( stepSize.x, 0.0f)).a;
	alpha -= Texel(texture, texture_coords + vec2(-stepSize.x, 0.0f)).a;
	alpha -= Texel(texture, texture_coords + vec2(0.0f,  stepSize.y)).a;
	alpha -= Texel(texture, texture_coords + vec2(0.0f, -stepSize.y)).a;
	return vec4(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a * alpha);
}
]])

PlacingSystem.static.OUTLINE_COLOR = { 0, 0.8, 0.8, 0.8 }
PlacingSystem.static.OUTLINE_SIZE = 2

function PlacingSystem.requires()
	return { placing = {"PlacingComponent"}, runestones = {"RunestoneComponent"} }
end

function PlacingSystem:initialize(map)
	lovetoys.System.initialize(self)
	self.map = map
	self.validTiles = {}
	self.polygons = {}

	self.tileArea = nil
	self.recalculateTileArea = false

	PlacingSystem.OUTLINE_SHADER:send("outlineColor", PlacingSystem.OUTLINE_COLOR)
end

function PlacingSystem:update(dt)
	for _,entity in pairs(self.targets.placing) do
		if not state:isPlacing() then
			error("Not placing, but got a placing component")
		end

		local mx, my = state:getMousePosition()
		local ti, tj = self.map:worldToTileCoords(mx, my)
		ti, tj = math.floor(ti), math.floor(tj)

		local snap = self.map:isValidPosition(entity, ti, tj)

		if entity:get("PlacingComponent"):isTile() then
			snap = snap and self.validTiles[ti] and self.validTiles[ti][tj]
			if snap then
				local type = entity:get("PlacingComponent"):getType()
				entity:set(TileComponent(type, ti, tj))
			elseif entity:has("TileComponent") then
				entity:remove("TileComponent")
			end
		else
			if snap then
				local type = entity:get("PlacingComponent"):getType()
				entity:set(BuildingComponent(type, ti, tj))
			elseif entity:has("BuildingComponent") then
				entity:remove("BuildingComponent")
			end
		end

		local spriteComponent = entity:get("SpriteComponent")

		if entity:has("TileComponent") then
			local x, y = self.map:tileToWorldCoords(ti, tj)
			spriteComponent:setDrawPosition(x - self.map.halfTileWidth, y)
			spriteComponent:setColor(0.40, 1, 0.40, 0.8)
		elseif entity:has("BuildingComponent") then
			local x, y = self.map:tileToWorldCoords(ti, tj)
			spriteComponent:setDrawPosition(x - self.map.halfTileWidth,
					y - spriteComponent:getSprite():getHeight() + self.map.tileHeight)
			spriteComponent:setColor(0.40, 1, 0.40, 0.8)
		else
			local sprite = spriteComponent:getSprite()
			local dx, dy = mx - sprite:getWidth() / 2, my - sprite:getHeight() / 2
			spriteComponent:setDrawPosition(dx, dy)
			spriteComponent:setColor(1, 0.40, 0.40, 0.8)
		end
	end

	if self.recalculateTileArea then
		self:_recalculateTileArea()
		self.recalculateTileArea = false
	end
end

function PlacingSystem:draw()
	if not state:isPlacing() then
		return
	end

	--for _,polygon in pairs(self.polygons) do
		--love.graphics.polygon("line", polygon)
	--end

	if self.tileArea then
		local oldShader = love.graphics.getShader()
		love.graphics.setShader(PlacingSystem.OUTLINE_SHADER)

		love.graphics.draw(self.tileArea.img, self.tileArea.x, self.tileArea.y)

		love.graphics.setShader(oldShader)
	end

	--love.graphics.setColor(0, 1, 0, 1)
	--love.graphics.setPointSize(5)
	--for ti in pairs(self.validTiles) do
		--for tj in pairs(self.validTiles[ti]) do
			--love.graphics.points(self.map:tileToWorldCoords(ti + 0.5, tj + 0.5))
		--end
	--end
	--love.graphics.setColor(1, 1, 1, 1)
end

function PlacingSystem:onAddEntity(entity)
	if entity:has("RunestoneComponent") then
		local reach = entity:get("RunestoneComponent"):getLevel()
		local ti, tj = entity:get("PositionComponent"):getTile()

		for oi=-reach,reach do
			for oj=-reach,reach do
				if math.abs(oi) + math.abs(oj) <= reach then
					self:_addValidTile(ti + oi, tj + oj)
				end
			end
		end

		self.polygons[entity] = table.flatten({
			{ self.map:tileToWorldCoords(ti, tj-reach) },
			{ self.map:tileToWorldCoords(ti+1, tj-reach) },
			{ self.map:tileToWorldCoords(ti+reach+1, tj) },
			{ self.map:tileToWorldCoords(ti+reach+1, tj+1) },
			{ self.map:tileToWorldCoords(ti+1, tj+reach+1) },
			{ self.map:tileToWorldCoords(ti, tj+reach+1) },
			{ self.map:tileToWorldCoords(ti-reach, tj+1) },
			{ self.map:tileToWorldCoords(ti-reach, tj) }
		})

		self.recalculateTileArea = true
	end
end

function PlacingSystem:onRunestoneUpgraded(event)
	self:onAddEntity(event:getRunestone())
end

function PlacingSystem:_addValidTile(ti, tj)
	self.validTiles[ti] = self.validTiles[ti] or {}
	self.validTiles[ti][tj] = true
end

function PlacingSystem:_recalculateTileArea()
	-- The area limits the placement of the tiles.
	-- This only calculates the border, the actual placement of tiles is handled above.
	-- The border is a bit lazily calculated using filled polygons that then are limited to an outline using a shader.
	-- This requires to draw to a canvas, instead of having a list of points that are drawn. A bit more computational
	-- expensive, but easier to implement.
	-- FIXME: Sharp corners (e.g. L-shaped) are somewhat cut off.
	if not next(self.polygons) then
		self.tileArea = nil
		return
	end
	self.tileArea = {}

	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _,polygon in pairs(self.polygons) do
		for i=1,#polygon,2 do
			if polygon[i] < minX then
				minX = polygon[i]
			end
			if polygon[i] > maxX then
				maxX = polygon[i]
			end
			if polygon[i+1] < minY then
				minY = polygon[i+1]
			end
			if polygon[i+1] > maxY then
				maxY = polygon[i+1]
			end
		end
	end

	local w, h = maxX - minX, maxY - minY
	self.tileArea.img = love.graphics.newCanvas(w + PlacingSystem.OUTLINE_SIZE*2, h + PlacingSystem.OUTLINE_SIZE*2)

	local oldCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas(self.tileArea.img)
	love.graphics.push()

	self.tileArea.x, self.tileArea.y = minX - PlacingSystem.OUTLINE_SIZE, minY - PlacingSystem.OUTLINE_SIZE
	love.graphics.translate(-self.tileArea.x, -self.tileArea.y)
	for _,polygon in pairs(self.polygons) do
		love.graphics.polygon("fill", polygon)
	end

	love.graphics.pop()
	love.graphics.setCanvas(oldCanvas)

	PlacingSystem.OUTLINE_SHADER:send("stepSize", { PlacingSystem.OUTLINE_SIZE / w , PlacingSystem.OUTLINE_SIZE / h })
end

return PlacingSystem
