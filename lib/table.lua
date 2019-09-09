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

local table = table

function table.clone(tbl, deep)
	local newTbl = {}

	for k,v in pairs(tbl) do
		if type(v) == "table" and deep then
			newTbl[k] = table.clone(v, deep)
		else
			newTbl[k] = v
		end
	end

	return newTbl
end

-- Note: in place
function table.shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = love.math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end

	return tbl
end

-- Note: Flattens one level.
function table.flatten(tbl)
	local ret = {}
	for _,v in ipairs(tbl) do
		for _,vv in ipairs(v) do
			table.insert(ret, vv)
		end
	end

	return ret
end

return table
