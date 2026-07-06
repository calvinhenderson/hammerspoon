---@class Alarms
---@field alarmIcon? hs.image|nil The image to replace the hammerspoon icon with in the alarm notifications.
---@field savePath? string The path where the alarms JSON store will be written.
---@field overlayColor? hs.drawing.color The light mode color of the overlay.
---@field overlayDarkColor? hs.drawing.color The dark mode color of the overlay. Defaults to light mode color if not specified
---@field overlayFrame? hs.geometry|function The rectangle specifying the frame of the overlay or a function returning the frame.
---@field windowFrame? hs.geometry The rectangle specifying the frame of the ui window.
---@field keepPastAlarms? boolean Whether to keep one-off timers. Default is to delete past timers.

local Alarms = {}
Alarms.__index = Alarms

-- Metadata
Alarms.name = "Alarms"
Alarms.version = "0.1"
Alarms.author = "Calvin Henderson"
Alarms.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/Alarms.spoon"
Alarms.license = "MIT - https://opensource.org/licenses/MIT"

---@class Alarms.Alarm
---@field id string The unique identifier for the alarm.
---@field title string The title to identify the alarm. Shown in the system notification.
---@field desc? string A description of the alarm. Shown in the system notification.
---@field timestamp? string An optional ISO8601 timestamp of when the alarm is to be triggered.
---@field cron? string An optional cron expression for when the alarm is triggered.
---@field fn? string An optional callback function to be called when the alarm is triggered. Must be registered first with `Alarms:register_fn(name, fn)`.
---@field disabled? boolean An optional boolean to disable the alarm.

local Cron = dofile(hs.spoons.scriptPath() .. "cron.lua")

function Alarms:init()
	self.state = {}

	-- load saved alarms
	self.alarms = nil
	self.timer = hs.timer.new(1, function()
		self:_tick()
	end, true)
end

---Starts processing alarms.
function Alarms:start()
	self.savePath = self.savePath or os.getenv("HOME") .. "/.alarms.json"
	local f = io.open(self.savePath, "r")
	if f then
		f:close()
	else
		-- create the persistent store
		assert(io.open(self.savePath, "a"), "failed to create persistent store"):write("{}"):close()
	end

	self:_restore_alarms()
	self.timer:start()
end

---Stops processing alarms.
---
---**NOTICE** Some alarms may be skipped!
function Alarms:stop()
	self.timer:stop()
end

---Opens the webview for creating and modifying alarms.
function Alarms:open_ui()
	if not self.form then
		self.form = dofile(hs.spoons.scriptPath() .. "form.lua")
		self.form:init(function(params)
			return self:save_alarm(params)
		end, function(alarm)
			return self:delete_alarm(alarm)
		end, self.windowFrame)
	end

	self.form:show(self.alarms)
end

function Alarms:_update_alarm(k, v)
	local old = self.alarms[k]
	self.alarms[k] = v
	if not hs.json.write(self.alarms, self.savePath, true, true) then
		self.alarms[k] = old
		if self.form then
			self.form:post_error("Save failed", "Failed to write to " .. self.savePath)
		end
		print("[Alarms]: failed to save alarm to " .. self.savePath)
	elseif self.alarms[k] == nil and self.form then
		self.form:delete_alarm(k)
	elseif self.alarms[k] and self.form then
		self.form:add_alarm(self.alarms[k])
	end
end

function Alarms:_restore_alarms()
	-- load alarms from persistent store
	self.alarms = hs.json.read(self.savePath) or {}
end

--- Saves an alarm with the given options
---@param params table
---@return table
function Alarms:save_alarm(params)
	assert(params["title"] and params["title"] ~= "", "title is required")
	assert(
		params["duration"] or params["cron"] or params["timestamp"],
		"one of duration, timestamp, or cron is required"
	)

	---@type Alarms.Alarm
	local alarm = {
		id = params["id"] or hs.host.uuid(),
		title = params["title"],
		desc = params["desc"],
		fn = params["fn"],
		disabled = params["disabled"],
	}

	if params["timestamp"] then
		self:_parse_timestamp(params["timestamp"])
		alarm.timestamp = params["timestamp"]
	elseif params["duration"] then
		alarm.timestamp = self:_parse_duration(params["duration"])
	elseif params["cron"] then
		alarm.cron = params["cron"]
	end

	self:_update_alarm(alarm.id, alarm)

	return alarm
end

local function is_dark()
	local _, dark =
		hs.osascript.applescript('tell application "System Events" to return dark mode of appearance preferences')

	return dark
end

---Gets the overlay attributes
---@return {frame: hs.geometry, fill_color: hs.drawing.color}
function Alarms:_get_overlay_attrs()
	local attrs = {}

	attrs.frame = (
		(type(self.overlayFrame) == "function" and self.overlayFrame())
		or (type(self.overlayFrame) == "table" and self.overlayFrame)
		or assert(hs.screen.mainScreen():frame(), "could not get main screen frame")
	)

	attrs.fill_color = (
		(is_dark() and self.overlayDarkColor)
		or self.overlayColor
		or { red = 1, green = 1, blue = 1, alpha = 1 }
	)

	return attrs
end

---Triggers an alarm
---@param alarm_id string
---@return boolean triggered Whether the alarm was successfully triggered.
function Alarms:trigger(alarm_id)
	local alarm = self:get_alarm(alarm_id)

	if type(self.state[alarm.id]) == "table" then
		self:reset_alarm(alarm)
		self.state[alarm.id].cleanup:setNextTrigger(5)
	else
		self.state[alarm.id] = {

			notification = assert(
				hs.notify.new(nil, {
					title = "",
					subTitle = "",
					informativeText = "",
					contentImage = self.alarmIcon,
					alwaysPresent = true,
					withdrawAfter = 30,
				}),
				"could not create notification"
			),

			cleanup = assert(
				hs.timer.doAfter(5, function()
					self:reset_alarm(alarm)
				end),
				"could not create timer"
			),

			overlay = assert(hs.canvas.new({ x = 0, y = 0, w = 0, h = 0 }), "could not create overlay canvas"):insertElement({
				type = "rectangle",
				id = "backdrop",
			}),
		}
	end

	local title = "Alarm"
	local subTitle = alarm.title

	if alarm.desc ~= "" then
		title = alarm.title
		subTitle = alarm.desc
	end

	self.state[alarm.id].notification:title(title)
	self.state[alarm.id].notification:subTitle(subTitle)
	self.state[alarm.id].notification:send()

	local attrs = self:_get_overlay_attrs()
	self.state[alarm.id].overlay:frame(attrs.frame)
	self.state[alarm.id].overlay:elementAttribute(1, "fillColor", attrs.fill_color)
	self.state[alarm.id].overlay:show(0)
	self.state[alarm.id].overlay:hide(5)

	return true
end

---@return string timestamp YYYY-MM-DDTHH:MM:SS
function Alarms:_parse_duration(duration)
	assert(string.match(duration, "(%d+)[DdHhMmSs]"), "invalid duration")

	-- calculate the time diff
	local diff = (
		(tonumber(string.match(duration, "(%d+)[Dd]")) or 0) * 86400
		+ (tonumber(string.match(duration, "(%d+)[Hh]")) or 0) * 3600
		+ (tonumber(string.match(duration, "(%d+)[Mm]")) or 0) * 60
		+ (tonumber(string.match(duration, "(%d+)[Ss]")) or 0)
	)

	local now = os.date("*t")
	assert(type(now) == "table")

	local timestamp = os.date("%Y-%m-%dT%H:%M:%S", os.time(now) + diff)
	assert(type(timestamp) == "string")

	return timestamp
end

---Gets an alarm by its ID. Asserting that it exists.
---@param alarm string|{id: string} A table or its id.
---@return Alarms.Alarm alarm The requested alarm.
function Alarms:get_alarm(alarm)
	local alarm_id = type(alarm) == "string" and alarm or alarm["id"]
	return assert(self.alarms[alarm_id], "does not exist")
end

---@param alarm Alarms.Alarm
function Alarms:_do_reset_alarm(alarm)
	if self.state[alarm.id] then
		self.state[alarm.id].overlay:delete()
		self.state[alarm.id].cleanup:stop()
		if self.state[alarm.id].notification:delivered() then
			self.state[alarm.id].notification:withdraw()
		end
	end
end

---Resets an alarm for the next trigger.
---@param alarm string|{id: string} The alarm to delete.
function Alarms:reset_alarm(alarm)
	alarm = self:get_alarm(alarm)

	self:_do_reset_alarm(alarm)

	local is_dated = (alarm.timestamp or ""):match("(T)")
	if is_dated and self.keepPastAlarms ~= true then
		-- delete one-off timers automatically.
		self:delete_alarm(alarm)
	end
end

---Deletes an alarm
---@param alarm string|{id: string} The alarm to delete.
---@return table Alarms.Alarm The deleted alarm.
function Alarms:delete_alarm(alarm)
	alarm = self:get_alarm(alarm)

	self:_do_reset_alarm(alarm)
	self:_update_alarm(alarm.id, nil)

	return alarm
end

function Alarms:get_alarms(filters)
	if not filters then
		return self.alarms
	else
		local filtered = {}
		for _, alarm in pairs(self.alarms) do
			for facet, filter in pairs(filters) do
				if
					(filter[1] == "eq" and alarm[facet] == filter[2])
					or (filter[1] == "ge" and alarm[facet] >= filter[2])
					or (filter[1] == "le" and alarm[facet] <= filter[2])
					or (filter[1] == "ne" and alarm[facet] ~= filter[2])
				then
					filtered[alarm.id] = alarm
				end
			end
		end
		return filtered
	end
end

function Alarms:_parse_timestamp(timestamp)
	local patterns = {
		{
			pattern = "^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)$",
			fields = { "year", "month", "day", "hour", "min", "sec" },
		},
		{
			pattern = "^(%d+)-(%d+)-(%d+)T(%d+):(%d+)$",
			fields = { "year", "month", "day", "hour", "min" },
		},
		{
			pattern = "^(%d+)-(%d+)T(%d+):(%d+):(%d+)$",
			fields = { "month", "day", "hour", "min", "sec" },
		},
		{
			pattern = "^(%d+)-(%d+)T(%d+):(%d+)$",
			fields = { "month", "day", "hour", "min" },
		},
		{
			pattern = "^T?(%d+):(%d+):(%d+)$",
			fields = { "hour", "min", "sec" },
		},
		{
			pattern = "^T?(%d+):(%d+)$",
			fields = { "hour", "min" },
		},
	}

	local datetime = os.date("*t")
	assert(type(datetime) == "table", "invalid datetime")

	datetime.sec = 0

	local i = 1
	while i <= #patterns do
		local params = table.pack(timestamp:match(patterns[i].pattern))
		if params[1] ~= nil and params.n == #patterns[i].fields then
			for j, field in ipairs(patterns[i].fields) do
				datetime[field] = params[j]
			end
			i = #patterns + 1
		end
		i = i + 1
	end

	assert(i == #patterns + 2, "invalid timestamp")
	return os.time(datetime)
end

function Alarms:_tick()
	local now = os.date("*t")

	for _, alarm in pairs(self.alarms) do
		if alarm.disabled then
		-- skip disabled alarms
		elseif alarm.timestamp then
			if os.difftime(self:_parse_timestamp(alarm.timestamp), os.time(now)) == 0 then
				self:trigger(alarm)
			end
		elseif alarm.cron and now.sec == 0 then
			local cron = Cron:parse(alarm.cron)
			if Cron:matches(cron, now) then
				self:trigger(alarm)
			end
		end
	end
end

return Alarms
