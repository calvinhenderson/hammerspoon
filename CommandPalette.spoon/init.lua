--- @class CommandPalette
--- @alias CommandPalette.Action function<CommandPalette.Choice>
--- @alias CommandPalette.Choice {
---   text: string,
---   subText?: string,
---   image?: hs.image,
---   application?: string,
---   command?: string,
---   applescript?: string,
---   action?: CommandPalette.Action,
--- }
local CommandPalette = {}
CommandPalette.__index = CommandPalette

-- Metadata
CommandPalette.name = "CommandPalette"
CommandPalette.version = "0.1"
CommandPalette.author = "Calvin Henderson"
CommandPalette.homepage = "https://github.com/calvinhenderson/hammerspoon/blob/main/CommandPalette.spoon"
CommandPalette.license = "MIT - https://opensource.org/licenses/MIT"

local function sort_choices(choices)
	table.sort(choices, function(a, b)
		return a.subText < b.subText and a.text < b.text
	end)
end

--- Initializes the CommandPalette
--- @return CommandPalette # reference to self for chaining
function CommandPalette:init()
	if not self.chooser then
		self.chooser = hs.chooser.new(function(choice)
			self:choose(choice)
		end)
	end

	return self
end

--- Sets the default choices for the chooser
--- @param choices CommandPalette.Choice[]
--- @return CommandPalette # reference to self for chaining
function CommandPalette:defaultChoices(choices)
	self.actions = {}
	self.choices = {}

	for _, choice in ipairs(choices) do
		self:addChoice(choice)
	end

	return self
end

--- Removes a choice by matching a key in the given choice
--- @return CommandPalette # reference to self for chaining
function CommandPalette:removeChoice(choice)
	for i, c in ipairs(self.choices) do
		if string.find(c.text, choice.text) or string.find(c.subText, choice.subText) then
			table.remove(self.choices, i)
			return self
		end
	end

	return self
end

--- Adds a new choice
--- @param choice CommandPalette.Choice
--- @return CommandPalette # reference to self for chaining
function CommandPalette:addChoice(choice)
	-- Functions cannot be encoded in the chooser so we must
	-- replace functions with a key to lookup the function.
	if choice.action and type(choice.action) == "function" then
		local k = ("%s:%s"):format(choice.text, choice.subText)
		self.actions[k] = choice.action
		choice.action = k
	end

	table.insert(self.choices, #self.choices + 1, choice)

	return self
end

--- Performs the action specified by the given choice
--- @param choice CommandPalette.Choice
--- @return CommandPalette # reference to self for chaining
function CommandPalette:choose(choice)
	if not choice then
		return self
	elseif choice.command then
		hs.execute(choice.command, true)
	elseif choice.application then
		local app = hs.application.get(choice.application)
		if app then
			hs.execute("open -nb " .. app:bundleID())
		else
			hs.alert("Couldn't find application " .. choice.application)
		end
	elseif choice.applescript then
		hs.osascript.applescript(choice.applescript)
	elseif choice.action and type(self.actions[choice.action]) == "function" then
		self.actions[choice.action]()
	end

	return self
end

--- Sets the `hs.chooser` placeholder text to `placeholder`
--- @param placeholder? string
--- @return CommandPalette # reference to self for chaining
function CommandPalette:setPlaceholder(placeholder)
	self:init()
	self.chooser:placeholderText(placeholder or "")
	return self
end

--- Sets whether to include open windows in the command palette
--- @param include? boolean Defaults to true
--- @return CommandPalette # reference to self for chaining
function CommandPalette:includeWindows(include)
	self.exclude_windows = not include
	return self
end

--- Shows the `hs.chooser` with the current choices
--- @return CommandPalette # reference to self for chaining
function CommandPalette:show()
	local choices = {}

	if not self.exclude_windows then
		local windows = hs.window.filter.new():setCurrentSpace(nil):getWindows()
		for _, w in ipairs(windows) do
			local app = w:application()

			table.insert(choices, {
				wid = w:id(),
				text = w:title(),
				subText = app and app:name() or "",
				image = app and hs.image.imageFromAppBundle(app:bundleID()),
			})
		end
	end

	for _, c in ipairs(self.choices) do
		table.insert(choices, c)
	end

	sort_choices(choices)

	self:init()
	self.chooser:choices(choices)
	self.chooser:show()

	return self
end

return CommandPalette
