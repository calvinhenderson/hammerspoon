--- @class Vi.Events
local Events = {}
Events.__index = Events

local CONSUME_EVENT = true
local PASS_EVENT = false
local NUMBER_KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }

function Events:init(vi)
	Events.Vi = vi
end

function Events:start()
	local function eventHandler(event)
		return self:handleKeyDown(event)
	end

	-- Set keydown listener with the primary event handler
	self.listener = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, eventHandler)

	self.listener:start()
end

function Events:stop()
	self.listener:stop()
end

local function serializeKeyEvent(event)
	local key_code = event:getKeyCode()
	local key_name = hs.keycodes.map[key_code]
	if not key_name then
		return nil
	end

	local flags = event:getFlags()
	local mods = {}

	-- Check flags explicitly
	if flags.alt then
		table.insert(mods, "alt")
	end
	if flags.cmd then
		table.insert(mods, "cmd")
	end
	if flags.ctrl then
		table.insert(mods, "ctrl")
	end
	if flags.shift then
		table.insert(mods, "shift")
	end

	table.sort(mods) -- Must sort alphabetically to match parseKeyString

	if #mods > 0 then
		return table.concat(mods, "-") .. "-" .. key_name
	else
		return key_name
	end
end

--- @param event table
--- @return boolean Whether the event is handled or not
function Events:handleKeyDown(event)
	local key_name = serializeKeyEvent(event)
	-- Ignore empty
	if not key_name then
		return false
	end

	local event_num = self.Vi:numEvents()
	local is_escape = key_name == "escape" and not self.Vi:peekEvent("escape")
	local is_delete = key_name == "delete" and not self.Vi:peekEvent("delete")
	local is_insert = self.Vi:getMode() == "i"
	local is_first = event_num == 0

	-- Handle special cases first
	if is_escape and (not is_insert and is_first) then
		self.Vi:leaveMode()
		self.Vi:hideCheatsheet()
		return CONSUME_EVENT
	elseif is_escape and not is_first then
		self.Vi:resetMode()
		if not is_insert then
			self.Vi:showCheatsheet()
		end
		return CONSUME_EVENT
	elseif is_delete and (not is_insert or not is_first) then
		self.Vi:popEvent()
		self.Vi:showCheatsheet()
		return CONSUME_EVENT
	end

	local is_number = (
		event_num == 0
		and hs.fnutils.contains(NUMBER_KEYS, key_name)
		and not self.Vi:peekEvent(key_name)
	)

	-- Get number to repeat the command X times
	if not is_insert and is_number then
		if not self.multiplier then
			self.multiplier = ""
		end

		self.multiplier = self.multiplier .. key_name
		return true
	end

	local count = tonumber(self.multiplier) or 1
	local node = self.Vi:pushEvent(key_name)

	-- Pass through unhandled mappings in insert mode
	if node == nil and is_insert then
		self.multiplier = nil

		if event_num > 1 then
			self.Vi:showCheatsheet()
		else
			self.Vi:hideCheatsheet()
		end

		return PASS_EVENT
	elseif node and type(node.action) == "function" then
		self.listener:stop()

		for _ = 1, count, 1 do
			node.action()
		end

		self.listener:start()
		self.multiplier = nil

		local do_leave = node.metadata and node.metadata.leave
		if do_leave or (do_leave == nil and self.Vi:config("actions_leave_modes")) then
			self.Vi:leaveMode()
			self.Vi:hideCheatsheet()
		else
			self.Vi:resetMode()
			self.Vi:showCheatsheet()
		end

		return CONSUME_EVENT
	elseif node then
		self.Vi:showCheatsheet()
		return CONSUME_EVENT
	end

	-- Otherwise don't handle the key press and alert the user.
	self.Vi:alert()
	if self.Vi:config("actions_leave_modes") then
		self.Vi:leaveMode()
	else
		self.Vi:resetMode()
		self.Vi:showCheatsheet()
	end
	self.multiplier = nil
	return PASS_EVENT
end

return Events
