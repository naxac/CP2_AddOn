local file = io.open("D:\\ST\\!rewrite_spawn_ids\\spawn_ids.script", "r")
local n = 0
local tmp = {}
if file then
	for line in file:lines() do
		if string.find(line, "^%-%-%-") then
			n = n - 1
			line = ""
		elseif string.find(line, "^%-%-%+") then
			n = n + 1
			line = string.sub( line, (string.find(line, "[%w_]")) )
		elseif n ~= 0 then
			local key, value = string.match(line, "^([%w_]+)%s*=%s*(%d+)")
			if key and value then
				value = tonumber(value) + n
				line = key.." = "..tostring(value)
			end
		end
		if line ~= "" then
			table.insert(tmp, line)
		end
	end
	file:close(file)
end

file = io.open("D:\\ST\\!rewrite_spawn_ids\\spawn_ids-new.script", "w")
if file then
	for i, v in ipairs(tmp) do
		file:write(v, "\n")
	end
	file:close(file)
	file = nil
end