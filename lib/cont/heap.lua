--- Defines a d-ary heap.
-- @classmod Heap
-- @author Albert Diserholt

--- Local namespace
local heap = {}

--- Traverse upwards, to place the item at the correct location.
-- @tparam heap self The heap object.
-- @tparam number i The location of the item to push upwards.
-- @param item The item to push.
local function _upHeap(self, i, item)
	local parent = math.floor(i / self.numChildren)

	while parent > 0 and parent ~= i do
		-- We're done if the parent should be before the inserted item.
		if self.comp(self.queue[parent], item) then
			break
		end

		-- Traverse upwards, swapping the parent backwards.
		self.queue[i] = self.queue[parent]
		i = parent
		parent = math.floor(i/self.numChildren)
	end

	self.queue[i] = item
end

--- Traverse downwards, to place the item at the correct location.
-- @tparam heap self The heap object.
-- @tparam number i The location of the item to push downwards.
-- @param item The item to push.
local function _downHeap(self, i, item)
	local newParent, firstChild

	while true do
		newParent = -1
		firstChild = self.numChildren * i

		-- Go through all the children, and keep track of the one that
		-- should be the new parent.
		for j=firstChild,firstChild + self.numChildren do
			if j <= self.queue.n then
				--if self.comp(self.queue[j] self.queue[newParent] or item) then
					--newParent = j
				if newParent == -1 then
					if self.comp(self.queue[j], item) then
						newParent = j
					end
				elseif self.comp(self.queue[j], self.queue[newParent]) then
					newParent = j
				end
			end
		end

		-- No child should be the new parent. We're done here.
		if newParent == -1 then
			break
		end

		-- Make a child a parent
		self.queue[i] = self.queue[newParent]
		i = newParent
	end

	-- Lastly, move the item to the correct position.
	self.queue[i] = item
end

--- The heap namespace.
local Heap = {}
--- The heap metatable.
local Heap_mt = { __index = Heap }

--
-- Object functions.
--

--- Get the item at the top of the heap.
-- @return[1] The item at the top of the heap.
-- @return[2] `nil` No item available.
function Heap:front()
	return self.queue[1]
end

--- Push a new item onto the heap.
-- @param item The item to add to the heap.
function Heap:push(item)
	self.queue.n = self.queue.n + 1
	_upHeap(self, self.queue.n, item)
end

--- Pop the top of the heap.
-- @return[1] The item which was previously at the top.
-- @return[2] `nil` The heap is empty.
function Heap:pop()
	if self:empty() then
		return nil
	end

	local item = self:front()

	self.queue.n = self.queue.n - 1
	_downHeap(self, 1, self.queue[self.queue.n+1])
	self.queue[self.queue.n+1] = nil

	return item
end

--- Get the number of children each node can have.
-- @treturn number The number of children the heap was configured to use.
function Heap:getNumChildren()
	return self.numChildren
end

--- Get the size of the heap.
-- @treturn number The number of items in the heap.
function Heap:size()
	return self.queue.n
end

--- Determine whether the heap is currently empty.
-- @tparam bool Whether the heap has no items.
function Heap:empty()
	return self:size() <= 0
end

--
-- Module functions.
--

--- Create a new heap.
-- @tparam[opt=2] number numChildren The number of children for every node in
-- the tree.
-- @tparam[opt=lessThan] function comparator The function to determine the
-- order of the items in the heap. By default the less than operator (`<`) is
-- used, but it can be any function receiving two items to create a strict
-- order.
function heap.newHeap(numChildren, comparator)
	numChildren = numChildren or 2
	comparator = comparator or function(a,b) return a < b end

	assert(numChildren > 0, "Wrong number of children specified.")

	local newHeap = setmetatable({
		numChildren = numChildren,
		comp = comparator,
		queue = { n = 0 }
	}, Heap_mt)

	return newHeap
end

return heap
