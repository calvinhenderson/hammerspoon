--- @class Vi.Tree
local Tree = {}
Tree.__index = Tree

function Tree.init() end

--- Initializes the event history buffer
--- @param tree table
function Tree:reset(tree)
	self.tree = tree
	self.head = self.tree
	self.history = {}
end

function Tree:peek(key)
	return self.head[key]
end

--- Finds the next branch of the tree.
--- @param key string
--- @return table|nil head
function Tree:push(key)
	-- Add the key to the lookup history
	self.history[#self.history + 1] = key

	self.head = self.head[key]

	if self.head == nil then
		self:reset(self.tree)
		return nil
	end

	return self.head
end

--- Pops an event from the history buffer, updating the head
--- @return table|nil head
function Tree:pop()
	self.history[#self.history] = nil

	if #self.history == 0 then
		self.head = self.tree
	else
		for i = 1, #self.history do
			self:push(self.history[i])
		end
	end
	return self.head
end

function Tree:numEvents()
	return #self.history
end

function Tree:getHead()
	return self.head
end

return Tree
