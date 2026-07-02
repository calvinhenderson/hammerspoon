--- @class Application.App
local Alacritty = {}
Alacritty.__index = Alacritty

Alacritty.bundleid = "org.alacritty"

function Alacritty.new_window()
	hs.execute(string.format("open -nb %s", Alacritty.bundleid))
end

function Alacritty.prev_tab()
	hs.eventtap.keyStroke({ "cmd", "shift" }, "[")
	return true
end

function Alacritty.next_tab()
	hs.eventtap.keyStroke({ "cmd", "shift" }, "]")
	return true
end

function Alacritty.interactive_command(command)
	local command_wait = command .. " ; echo -e 'Press [Return] to continue'; read -r "
	hs.task
		.new("/opt/homebrew/bin/alacritty", function(exit_code, stdout, stderr)
			if exit_code == 0 then
				return true
			else
				hs.alert("Command failed. See logs for details.")
				print(command, stdout, stderr)
				return false
			end
		end, { "-T", command, "-e", "/bin/zsh", "-lc", command_wait })
		:start()
end

return Alacritty
