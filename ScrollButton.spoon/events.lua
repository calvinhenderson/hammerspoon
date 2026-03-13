local CONSUME_EVENT = true
local TYPES = hs.eventtap.event.types
local PROPS = hs.eventtap.event.properties

local Events = {}
Events.__index = Events

--- @param scroll_button table
function Events.init(scroll_button)
	Events.ScrollButton = scroll_button
end

function Events:config(key)
	return Events.ScrollButton.Config:get(key)
end

local function configure_mouse_button(button)
	local function check_state(event)
		return event:getButtonState(button)
	end

	if button == 0 then
		return { TYPES.leftMouseDown, TYPES.leftMouseUp, TYPES.leftMouseDragged }, check_state
	elseif button == 1 then
		return { TYPES.rightMouseDown, TYPES.rightMouseUp, TYPES.rightMouseDragged }, check_state
	else
		return { TYPES.otherMouseDown, TYPES.otherMouseUp, TYPES.otherMouseDragged }, check_state
	end
end

local function configure_key(key)
	local function check_state(event)
		local keyName = event:getKeyCode(key)
		local modifiers = event:getFlags()
		return key == keyName or modifiers.contain({ key })
	end

	return { TYPES.keyDown, TYPES.keyUp, TYPES.mouseMoved }, check_state
end

function Events:start()
	local events, check_state
	if self:config("button") then
		events, check_state = configure_mouse_button(self:config("button"))
	elseif self:config("key") then
		events, check_state = configure_key(self:config("key"))
	end

	self.events = events
	self.check_state = check_state

	table.insert(self.events, TYPES.mouseDragged)

	self.listener = hs.eventtap.new(self.events, function(event)
		return self:_handleEvent(event)
	end)

	self.listener:start()
end

function Events:stop()
	self.listener:stop()
end

function Events:_absoluteMousePos()
	local pos = hs.mouse.absolutePosition()
	return pos.x, pos.y
end

function Events:_adjustScrollDeltas(dx, dy)
	local sd = self:config("scroll_direction")
	local xs = self:config("x_scale")
	local ys = self:config("y_scale")

	local xd, yd = sd, sd

	if sd == 0 then
		if hs.mouse.scrollDirection() == "natural" then
			xd, yd = 1, -1
		else
			xd, yd = 1, 1
		end
	end

	return dx * xs * xd, -dy * ys * yd
end

--- @private
function Events:_resetMouse()
	hs.mouse.absolutePosition({ x = self.x, y = self.y })
end

--- @private
function Events:_handleEvent(event)
	local type = event:getType()
	local down, _, dragged = table.unpack(self.events)

	if type == down and self.check_state(event) then
		self.pressEvent = event
		self.pressed = true
		self.dragged = false

		self.x, self.y = self:_absoluteMousePos()

		return CONSUME_EVENT
	elseif type == dragged and self.pressed then
		self.dragged = true

		local dx, dy = self:_adjustScrollDeltas(
			event:getProperty(PROPS["mouseEventDeltaX"]),
			event:getProperty(PROPS["mouseEventDeltaY"])
		)

		local scroll_event = hs.eventtap.event.newScrollEvent({ dx, dy }, {}, self:config("unit"))
		self:_resetMouse()

		return CONSUME_EVENT, { scroll_event }
	else
		self.pressed = false

		if not self.dragged then
			return CONSUME_EVENT, { self.pressEvent, event }
		else
			return CONSUME_EVENT
		end
	end
end

return Events
