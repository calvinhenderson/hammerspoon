local System = {}
System.__index = System

-- Metadata
System.name = "System"
System.version = "0.1"
System.author = "Calvin Henderson"
System.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/System.spoon"
System.license = "MIT - https://opensource.org/licenses/MIT"

System.logger = hs.logger.new("System", "info")

function System.focusSpace(space_index, screen)
	if not screen then
		screen = hs.screen.mainScreen()
	end

	local spaces = hs.spaces.spacesForScreen(screen)

	if not spaces then
		System.logger.i("no spaces for screen " .. screen:name())
		return false, "no spaces"
	elseif space_index > #spaces then
		System.logger.i("space_index out of range: " .. #spaces)
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
		return hs.spaces.gotoSpace(space_id)
	end

	for _ = 1, math.max(focused_idx, space_index) - math.min(focused_idx, space_index) do
		local direction = focused_idx < space_index and "right" or "left"
		hs.eventtap.keyStroke({ "fn", "ctrl" }, direction, 500)
	end

	return true
end

function System.align_window(alignment, win)
	assert(type(alignment) == "table", "expected a table, got: " .. type(alignment))
	assert(alignment.x or alignment.y, "expected an x and/or y alignment")

	if not win then
		win = hs.window.focusedWindow()
	end

	local scr = win:screen():frame()
	local frame = win:frame()

	if alignment.x == "left" then
		frame.x = scr.x
	elseif alignment.x == "center" then
		frame.x = scr.x + scr.w / 2 - frame.w / 2
	elseif alignment.x == "right" then
		frame.x = scr.x + scr.w - frame.w
	end

	if alignment.y == "top" then
		frame.y = scr.y
	elseif alignment.y == "center" then
		frame.y = scr.y + scr.h / 2 - frame.h / 2
	elseif alignment.y == "bottom" then
		frame.y = scr.y + scr.h - frame.h
	end

	win:move(frame)
end

--- @param app_name string The name of the application
function System.bundleid_for_app_name(app_name)
	if hs.application.get(app_name) then
		return hs.application.get(app_name):bundleID()
	end

	local script = ([[
  get id of application "%s"
  ]]):format(app_name)

	local success, result, errors = hs.osascript.applescript(script)
	if success then
		return result
	else
		System.logger.e("Failed to get bundleid for app name", app_name, hs.inspect(errors))
		return nil
	end
end

function System.application_icon(hint)
	local bundleid = System.bundleid_for_app_name(hint)

	if bundleid then
		return hs.image.imageFromAppBundle(bundleid)
	else
		System.logger.e("Application not found for " .. hs.inspect(hint))
		return nil
	end
end

function System.chooser(select_fn, choices, placeholder)
	local chooser = hs.chooser.new(select_fn)
	chooser:width(25)
	chooser:searchSubText(true)
	chooser:placeholderText(placeholder or "")
	chooser:choices(choices)
	return chooser
end

function System.window_chooser(hint, order)
	local filter = hs.window.filter.new()
	local placeholder = "Search open windows"
	order = order or hs.window.filter.sortByFocusedLast

	if hint == "app" then
		local app = hs.application.frontmostApplication()
		if app then
			placeholder = "Search application windows"
			filter = hs.window.filter.new(app:name()):setCurrentSpace(nil)
		end
	elseif hint == "space" then
		filter = filter:setCurrentSpace(true)
		placeholder = "Search current space windows"
	end

	local choices = {}

	for _, w in ipairs(filter:getWindows(order)) do
		if w:id() ~= hs.window.focusedWindow():id() then
			local app = w:application()
			local icon = app and System.application_icon(app:bundleID()) or nil
			table.insert(choices, {
				id = w:id(),
				image = icon,
				text = w:title(),
				subText = app and app:name() or "",
			})
		end
	end

	System.chooser(function(choice)
		if not choice then
			return
		end

		hs.window.get(choice.id):raise():focus()
	end, choices, placeholder):show()
end

function System.audio_output_chooser()
	local devices = hs.audiodevice.allDevices()
	local input_uid = hs.audiodevice.defaultInputDevice() and hs.audiodevice.defaultInputDevice():uid()
	local output_uid = hs.audiodevice.defaultInputDevice() and hs.audiodevice.defaultOutputDevice():uid()
	local input_img = hs.image.imageFromName("NSTouchBarAudioInputTemplate")
	local output_img = hs.image.imageFromName("NSTouchBarAudioOutputVolumeHighTemplate")

	if not devices then
		return
	end

	local choices = {}
	for _, d in ipairs(devices) do
		local type = d:isOutputDevice() and "output device" or "input device"
		local selected = d:uid() == input_uid or d:uid() == output_uid
		table.insert(choices, {
			id = d:uid(),
			image = d:isOutputDevice() and output_img or input_img,
			text = d:name(),
			subText = selected and "(selected) " .. type or type,
			valid = not selected,
		})
	end

	System.chooser(function(choice)
		if not choice then
			return
		end

		local d = hs.audiodevice.findDeviceByUID(choice.id)

		if d and d:isOutputDevice() then
			d:setDefaultOutputDevice()
		elseif d then
			d:setDefaultInputDevice()
		end
	end, choices, "Search audio devices"):show()
end

return System
