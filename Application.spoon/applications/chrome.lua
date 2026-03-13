local Chrome = {}
Chrome.__index = Chrome

Chrome.bundleid = "com.google.Chrome"

function Chrome.launch_profile(profile)
	hs.execute(string.format("open -nb %s --args --profile-directory='%s'", Chrome.bundleid, profile or "Default"))
end

return Chrome
