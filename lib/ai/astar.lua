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

--- Library for performing an A* search over a graph.
-- @author Albert Diserholt
-- @license GPLv3+

local heap = require("lib.cont.heap")

--- Local namespace.
local astar = {}

--- Reverse a table.
-- @tparam table tbl The table to reverse (in-place).
-- @treturn table Returns the table.
local function _reverse(tbl)
	local len, j = #tbl
	for i=1,math.floor(len / 2) do
		j = len - i + 1
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

--- Perform an A* search on the specified graph.
-- The nodes have to be unique in some way, for example table or userdata
-- types.
-- @param graph The graph to perform the search on. It must implement the
-- following functions:
-- `neighbours(self, currentNode)`, which receives the graph object and a node, and
-- should return all available neighbours.
-- `cost(self, currentNode, nextNode)` which receives the graph object, the
-- current node and a destination node, and should return the cost to travel
-- between the nodes.
-- `heuristic(graph, nextNode, target)` which receives the graph object, a node
-- and the target node, and should return the estimated cost to the target.
-- @param start The starting node.
-- @param target The destination node.
-- @treturn table A table of open nodes.
-- @treturn table A table of costs.
function astar.search(graph, start, target)
	local open = heap.newHeap(2, function(a,b) return a.cost < b.cost end)
	open:push({ node = start, cost = 0 })

	local cameFrom = {}
	local costSoFar = {}

	cameFrom[start] = start
	costSoFar[start] = 0

	while not open:empty() do
		local current = open:pop()

		if current.node == target then
			break
		end

		for _,nextNode in pairs(graph:neighbours(current.node)) do
			local newCost = costSoFar[current.node] + graph:cost(current.node, nextNode)

			if costSoFar[nextNode] == nil or newCost < costSoFar[nextNode] then
				costSoFar[nextNode] = newCost
				local priority = newCost + graph:heuristic(nextNode, target)
				open:push({ node = nextNode, cost = priority })
				cameFrom[nextNode] = current.node
			end
		end
	end

	return cameFrom, costSoFar
end

--- Construct a path in reversed order from a search.
-- @param start The starting node.
-- @param target The destination node.
-- @tparam table cameFrom The table returned by @{astar.search}.
-- @treturn table A table of nodes to travel to reach the destination.
-- Will be empty if the target could not be reached.
function astar.reconstructReversedPath(start, target, cameFrom)
	local path = {}
	if cameFrom[target] ~= nil then
		while target ~= start do
			table.insert(path, target)
			target = cameFrom[target]
		end
		table.insert(path, start)
	end
	return path
end

--- Construct a path from a search.
-- @param start The starting node.
-- @param target The destination node.
-- @tparam table cameFrom The table returned by @{astar.search}.
-- @treturn table A table of nodes to travel to reach the destination.
-- Will be empty if the target could not be reached.
function astar.reconstructPath(start, target, cameFrom)
	return _reverse(astar.reconstructReversedPath(start, target, cameFrom))
end

return astar
