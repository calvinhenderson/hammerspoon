--- @class System.HttpApi
--- @field base_url string The base url of the remote api
--- @field headers table The default headers included on every request
local HttpApi = {}
HttpApi.__index = HttpApi

--- @param base_url string
--- @param headers table
--- @return System.HttpApi
function HttpApi.new(base_url, headers)
	local self = setmetatable({}, HttpApi)
	self.base_url = base_url
	self.headers = headers
	return self
end

-- Merge a set of headers into another set
local function merge_tables(a, b)
	local c = {}
	for k, v in pairs(a) do
		c[k] = v
	end
	for k, v in pairs(b) do
		c[k] = v
	end
	return c
end

-- Query the API using a GET method
function HttpApi:get(endpoint, headers, callback)
	headers = merge_tables(headers, self.headers)
	hs.http.asyncGet(self.base_url .. endpoint, headers, callback)
end

-- Query the API using a POST method
function HttpApi:post(resource, headers, body, callback)
	headers = merge_tables(headers, self.headers)
	hs.http.asyncPost(self.base_url .. resource, body, headers, callback)
end

-- Query the API using a PUT method
function HttpApi:put(resource, headers, body, callback)
	headers = merge_tables(headers, self.headers)
	hs.http.doAsyncRequest(self.base_url .. resource, "PUT", body, headers, callback)
end

return HttpApi
