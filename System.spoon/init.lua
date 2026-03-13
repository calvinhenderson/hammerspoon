local System = {}
System.__index = System

-- Metadata
System.name = "System"
System.version = "0.1"
System.author = "Calvin Henderson"
System.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/System.spoon"
System.license = "MIT - https://opensource.org/licenses/MIT"

function System.log(...)
	print("[System]:", ...)
end

function System.focusSpace(space_index, screen)
	if not screen then
		screen = hs.screen.mainScreen()
	end

	local spaces = hs.spaces.spacesForScreen(screen)

	if not spaces then
		System.log("no spaces for screen " .. screen:name())
		return false, "no spaces"
	elseif space_index > #spaces then
		System.log("space_index out of range: " .. #spaces)
		return false, "invalid index"
	end

	local focused_space = hs.spaces.focusedSpace()
	local space_id = spaces[space_index]

	if not space_id then
		return false, "invalid index"
	end

	if focused_space == spaces[space_index] then
		-- Space is already focused
		return true
	end

	local focused_idx = nil
	for i, id in ipairs(spaces) do
		if id == focused_space then
			focused_idx = i
		end
	end

	if not focused_idx then
		System.log(focused_idx)
		return hs.spaces.gotoSpace(space_id)
	end

	for _ = 1, math.max(focused_idx, space_index) - math.min(focused_idx, space_index) do
		local direction = focused_idx < space_index and "right" or "left"
		hs.eventtap.keyStroke({ "fn", "ctrl" }, direction, 500)
	end

	return true
end

return System
