local Form = {}

---@param save_fn function The callback function to save alarms.
---Should accept one parameter, the table of alarm params.
---@param delete_fn function The callback function to delete alarms.
---Should accept one parameter, the id of the alarm to delete.
---@param window_frame? hs.geometry The optional frame geometry of the webview.
function Form:init(save_fn, delete_fn, window_frame)
	self.frame = window_frame
	self.save_fn = save_fn
	self.delete_fn = delete_fn
end

---Shows the webview for editing alarms.
---@param alarms table<string, Alarms.Alarm> The table of alarms.
function Form:show(alarms)
	local ucc = assert(hs.webview.usercontent.new("alarms_ui"), "couldn't create content controller")
	ucc:setCallback(function(msg)
		self:_handle_msg(msg.body)
	end)

	local frame = self.frame
	if not frame then
		local sf = hs.screen.mainScreen():frame()
		local w, h = math.min(sf.w * 0.8, 640), math.min(sf.h * 0.8, 960)
		local x = sf.x + sf.w / 2 - w / 2
		local y = sf.y + sf.h / 2 - h / 2
		frame = { x = x, y = y, w = w, h = h }
	end

	local html = self:_render({ alarms = hs.json.encode(alarms) })
	local _, is_dark =
		hs.osascript.applescript('tell application "System Events" to return dark mode of appearance preferences')

	self.webview = assert(hs.webview.new(frame, { developerExtrasEnabled = true }, ucc), "failed to create webview")
		:windowStyle({ "titled", "resizable", "closable", "utility" })
		:darkMode(is_dark)
		:windowTitle("Alarms Editor")
		:closeOnEscape(true)
		:deleteOnClose(true)
		:allowTextEntry(true)
		:allowGestures(false)
		:html(html)
		:level(hs.drawing.windowLevels.normal)
		:show()

	self.webview:hswindow():becomeMain():focus()
end

---Handles messages sent from the webview
function Form:_handle_msg(msg)
	if msg.action == "save" and type(self.save_fn) == "function" then
		local success, alarm_or_err = pcall(function()
			return self.save_fn(msg.payload)
		end)

		if success then
			self:close_modal()
		else
			self:post_error("Failed to save alarm", alarm_or_err)
		end
	elseif msg.action == "delete" and type(self.delete_fn) == "function" then
		local success, alarm_or_err = pcall(function()
			return self.delete_fn(msg.payload.id)
		end)

		if not success then
			self:post_error("Failed to delete alarm", alarm_or_err)
		end
	end
end

---Posts an error message to the ui.
---@param title string The title of the error message
---@param message string The description of the error
function Form:post_error(title, message)
	print("[ERROR][Alarms][Form]: " .. title)
	print(message)
	self.webview:evaluateJavaScript(string.format("postError('%s', '%s');", title, message))
end

---Closes the edit modal
function Form:close_modal()
	self.webview:evaluateJavaScript("closeModal();")
end

---Adds an alarm to the list of displayed alarms.
---Conflicting alarms are updated.
---@param alarm Alarms.Alarm An alarm object
function Form:add_alarm(alarm)
	local safe_json = hs.json.encode(alarm)
	self.webview:evaluateJavaScript(string.format("addAlarmToTable(%s);", safe_json))
end

---Removes an alarm from the list of displayed alarms.
---@param alarm_id string The ID of the alarm to be deleted.
function Form:delete_alarm(alarm_id)
	self.webview:evaluateJavaScript(string.format("removeAlarmFromTable('%s');", alarm_id))
end

function Form:_render(assigns)
	local file = assert(io.open(hs.spoons.resourcePath("form.html"), "r"), "failed to read form.html")
	local html = file:read("*a")
	file:close()

	for k, v in pairs(assigns) do
		html = html:gsub("{{%s-" .. k .. "%s-}}", v)
	end

	return html
end

return Form
