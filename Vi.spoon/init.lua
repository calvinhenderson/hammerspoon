--- @class Vi
--- @field Alert Vi.Alert
--- @field Config Vi.Config
--- @field Keymap Vi.Keymap
--- @field Mode Vi.Mode
--- @field Tree Vi.Tree
--- @field Events Vi.Events
--- @field Cheatsheet Vi.Cheatsheet
local Vi = {}
Vi.__index = Vi

-- Metadata
Vi.name = "Vi"
Vi.version = "0.1"
Vi.author = "Calvin Henderson"
Vi.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/Vi.spoon"
Vi.license = "MIT - https://opensource.org/licenses/MIT"

function Vi.log(module, ...)
	print("[Vi][" .. module .. "]:", ...)
end

-- Load and initialize modules
for m, f in pairs({
	Alert = "alert",
	Config = "config",
	Keymap = "keymap",
	Mode = "mode",
	Tree = "tree",
	Events = "events",
	Cheatsheet = "cheatsheet",
}) do
	Vi[m] = dofile(hs.spoons.resourcePath(f .. ".lua"))
	Vi[m]:init(Vi)
end

function Vi:keymap(mode)
	if mode == nil then
		mode = self.Mode.current
	end

	return self.Keymap:forMode(mode)
end

--- Start Vi listeners
function Vi:start()
	self.Mode:start()
	self:enterMode("i")

	self.Events:start()
end

--- Stop Vi listeners
function Vi:stop()
	self:enterMode("i")
	self.Events:stop()
end

--- @param config Vi.Configuration
function Vi:mergeConfig(config)
	self.Config:mergeConfig(config)
end

function Vi:mergeBindings(bindings)
	self.Keymap:mergeBindings(bindings)
end

function Vi:getMode()
	return self.Mode.current
end

function Vi:enterMode(mode)
	self.Mode:setMode(mode)
	self.Tree:reset(Vi:keymap())

	if self.Mode.current ~= "i" then
		self:showCheatsheet()
	end
end

function Vi:leaveMode()
	self.Mode:leave()
	self.Tree:reset(Vi:keymap())
	if self:getMode() == "i" then
		self:hideCheatsheet()
	end
end

function Vi:pushEvent(event)
	return self.Tree:push(event)
end

function Vi:popEvent()
	return self.Tree:pop()
end

function Vi:peekEvent(event)
	return self.Tree:peek(event)
end

function Vi:numEvents()
	return self.Tree:numEvents()
end

function Vi:showCheatsheet()
	self.Cheatsheet:show(self.Tree:getHead())
end

function Vi:hideCheatsheet()
	self.Cheatsheet:hide()
end

function Vi:resetMode()
	self.Tree:reset(self:keymap())
end

function Vi:config(key, default)
	return self.Config[key] or default
end

function Vi:alert()
	return self.Alert.alert()
end

-- Helper to minify function calls in the key mappings
function Vi._(fn, ...)
	local args = table.pack(...)
	return function(...)
		local all = table.pack(...)

		for i = #args, 1, -1 do
			table.insert(all, 1, args[i])
		end

		return fn(table.unpack(all))
	end
end

return Vi
