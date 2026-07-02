-- \*,\*,\*,\*,\*,\*
-- ^ ^ ^ ^ ^ ^
-- | | | | | |
-- | | | | | |
-- | | | | | +-------- day of week (0 - 6) (Sunday=0)
-- | | | | +---------- month (1 - 12)
-- | | | +------------ day of month (1 - 31)
-- | | +-------------- hour (0 - 23)
-- | +---------------- min (0 - 59)
-- +------------------ sec (0 - 59)

---@class Alarms.Cron
local Cron = {}

function Cron:init() end

function Cron:inspect(cron_table)
	return ("%s %s %s %s %s"):format(table.unpack(cron_table.raw))
end

-- Helper: Split strings by a separator
local function split(str, sep)
	local result = {}
	for match in (str .. sep):gmatch("(.-)" .. sep) do
		table.insert(result, match)
	end
	return result
end

-- Helper: Parse a single cron field into a lookup table of allowed values
local function parse_field(field, min, max)
	local allowed = {}
	-- Default all to false
	for i = min, max do
		allowed[i] = false
	end

	-- Catch-all
	if field == "*" then
		for i = min, max do
			allowed[i] = true
		end
		return allowed
	end

	-- Process lists (e.g., "1,15,30" or "1-5,10")
	local parts = split(field, ",")
	for _, part in ipairs(parts) do
		local step = 1
		local range_str = part

		-- Process steps (e.g., "*/15" or "10-30/5")
		if part:find("/") then
			local step_parts = split(part, "/")
			range_str = step_parts[1]
			step = tonumber(step_parts[2]) or 1
		end

		-- Process ranges and wildcards
		if range_str == "*" then
			for i = min, max, step do
				allowed[i] = true
			end
		elseif range_str:find("-") then
			local bounds = split(range_str, "-")
			local start_val = tonumber(bounds[1]) or min
			local end_val = tonumber(bounds[2]) or max
			for i = start_val, end_val, step do
				allowed[i] = true
			end
		else
			-- Process single values
			local val = tonumber(range_str)
			if val and val >= min and val <= max then
				allowed[val] = true
			end
		end
	end

	return allowed
end

--- Parse a standard 5-part cron expression
function Cron:parse(expression)
	local parts = {}
	for p in expression:gmatch("%S+") do
		table.insert(parts, p)
	end

	if #parts ~= 5 then
		error("Invalid cron expression. Expected 5 parts (min hour dom month dow), got: " .. #parts)
	end

	return {
		min = parse_field(parts[1], 0, 59),
		hour = parse_field(parts[2], 0, 23),
		dom = parse_field(parts[3], 1, 31),
		month = parse_field(parts[4], 1, 12),
		dow = parse_field(parts[5], 0, 7),
		raw = parts, -- Stored to handle standard cron DOM/DOW OR-logic
	}
end

--- Check if a parsed cron expression matches a Lua time table (from os.date)
function Cron:matches(cron_table, time_table)
	local t = time_table or os.date("*t")

	-- Lua's wday is 1 (Sun) to 7 (Sat). Cron is usually 0-6 (Sun-Sat), with 7 also being Sun.
	local cron_dow = t.wday - 1

	local min_match = cron_table.min[t.min]
	local hour_match = cron_table.hour[t.hour]
	local month_match = cron_table.month[t.month]

	local dom_match = cron_table.dom[t.day]
	local dow_match = cron_table.dow[cron_dow]
	-- Handle 7 as Sunday
	if cron_dow == 0 and cron_table.dow[7] then
		dow_match = true
	end

	-- Standard cron quirk: If BOTH day of month and day of week are restricted,
	-- the job runs if EITHER matches (OR logic). Otherwise, it's AND logic.
	local day_match = false
	if cron_table.raw[3] ~= "*" and cron_table.raw[5] ~= "*" then
		day_match = dom_match or dow_match
	else
		day_match = dom_match and dow_match
	end

	return min_match and hour_match and month_match and day_match
end

return Cron
