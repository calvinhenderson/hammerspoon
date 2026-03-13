--- @class Vi.Mode
local Mode = {}
Mode.__index = Mode

function Mode:init(vi)
	self.Vi = vi
end

function Mode:log(...)
	self.Vi.log("Mode", ...)
end

--- Intitializes the modes switcher
function Mode:start()
	-- We always start in insert mode
	self.current = "i"
end

--- @param mode Mode
function Mode:setMode(mode)
	self.current = mode and mode or "i"
	self:log("entering", self.current)
end

--- Leaves the current mode
function Mode:leave()
	if self.current == "i" then
		return
	end

	-- We always go back to insert mode
	self:log("leaving ", self.current)
	self.current = "i"
end

return Mode
