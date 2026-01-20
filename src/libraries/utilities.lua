--@name Starframe | Utilities Library
--@author The Starframe Team
--@class none


--[[

	The utilities library adds all sorts of utilities in order to facilitate
	the development of libraries & modules within Starframe :)

--]]

-- Types library for type checking ease
types = {}

local customTypeChecks = {}
function customTypeChecks.integer(n)
	return type(n) == "number" and math.round(n) == n
end

function customTypeChecks.Color(n)
	return getmetatable(n) == "Color"
end

function customTypeChecks.any(n)
	return n ~= nil
end

-- Adds a custom type check for the desired type
---@param typeName string The type name to add a custom check for.
---@param func function? The function to return on the value to check, return true if it fits the type, pass nil to remove the type check.
function types.addCustomCheck(typeName, func)
	types.check(typeName, "string", "typeName", 2)
	types.check(func, "function?", "func", 2)

	customTypeChecks[typeName] = func
end

-- Checks the given value for the desired type.
-- Errors if the value's type does not correspond
---@param value any The value to check
---@param desiredType string The desired type string, use "?" for nillable and "|" for multiple types.
---@param name string The name of the argument
---@param level integer The
function types.check(value, desiredType, name, level)

	local errorFormat = "Invalid value for parameter %s (expected %s, got %s)"

	if type(desiredType) ~= "string" then
		local errorMsg = string.format(errorFormat, "desiredType", "string", type(desiredType))
		error(errorMsg, 2)
	end

	if type(name) ~= "string" then
		local errorMsg = string.format(errorFormat, "name", "string", type(name))
		error(errorMsg, 2)
	end

	if level ~= nil and (type(level) ~= "number" or math.round(level) ~= level) then
		local errorMsg = string.format(errorFormat, "name", "integer?", type(level))
		error(errorMsg, 2)
	end

	level = level or 1

	-- Parse the desiredType string
	local typeInfos = {}
	for typeStr in string.gmatch(desiredType, "[^|]*") do
		local typeInfo = {
			type = typeStr,
			nillable = false
		}

		if string.sub(typeStr, #typeStr) == "?" then
			typeInfo.type = string.sub(typeStr, 1, #typeStr-1)
			typeInfo.nillable = true
		end

		typeInfos[#typeInfos + 1] = typeInfo
	end

	-- Check value for every type specified
	for _, typeInfo in ipairs(typeInfos) do
		if value == nil and typeInfo.nillable then
			return
		elseif customTypeChecks[typeInfo.type] ~= nil then
			if customTypeChecks[typeInfo.type](value) then
				return
			end
		elseif type(value) == typeInfo.type then
			return
		end
	end

	-- Value did not fit any type! (omg, how dare it)
	local errorMsg = string.format(errorFormat, name, desiredType, type(value))
	error(errorMsg, 1 + level)
end

bootstrapper.addToEnvironment("types", types)


--Table library extension

---Filters the given table's value and returns a copy with each value that passed the filter
---@param t table The table to filter
---@param filter function The filter function, it is passed key and value and should return true to keep the pair
---@return table result The new table whose key/value pair passed the filter
function table.filter(t, filter)
	types.check(t, "table", "t", 2)
	types.check(filter, "function", "filter", 2)

	local result = {}
	for key, value in pairs(t) do
		if filter(key, value) then
			result[key] = value
		end
	end

	return result
end


---Returns a copy of the given table whose entries have been mapped by the given function
---@param t table The input table
---@param map function The mapping function, it is given the current value to map
---@return table result The mapped table
function table.map(t, map)
	types.check(t, "table", "t", 2)
	types.check(map, "function", "map", 2)

	local result = {}

	for key, value in pairs(t) do
		result[key] = map(value)
	end

	return result
end


---Returns an array containing keys that are present in both tables.
---@param a table The first table
---@param b table The second table
---@return table result An array containing keys that are present in both tables.
function table.intersectKeys(a, b)
	types.check(a, "table", "a", 2)
	types.check(b, "table", "b", 2)

	local result = {}
	for key in pairs(a) do
		if b[key] ~= nil then
			result[#result+1] = key
		end
	end

	return result
end


---Returns an array containing values that are present in both tables.
---@param a table The first table
---@param b table The second table
---@return table result An array containing values that are present in both tables.
function table.intersectValues(a, b)
	types.check(a, "table", "a", 2)
	types.check(b, "table", "b", 2)

	local resultA = {}
	local resultB = {}

	for _, value in pairs(a) do
		resultA[value] = true
	end

	for _, value in pairs(b) do
		resultB[value] = true
	end

	local result = {}
	for key in pairs(resultA) do
		if resultB[key] == true then
			result[#result+1] = key
		end
	end

	return result
end


-- String library extension

---Capitalises the first letter of the string (e.g "my amazing string" -> "My amazing string")
---@param str string The string to capitalise
---@return string result The capitalised string
function string.capitalise(str)
	types.check(str, "string", "str", 2)
	return string.sub(str, 1, 1):upper() .. string.sub(str, 2)
end


---Escapes the given string to avoid possible injection when using string pattern functions.
---@param str string The string to escape
---@return string escapedString The escaped string
function string.escape(str)
	types.check(str, "string", "str", 2)
	local escapedString = string.gsub(str, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
	return escapedString
end


---Returns an array containing the split string (including the parts that the string got split by)
---@param str string The input string
---@param pattern string The pattern to split the string by
---@param plainText boolean? Whether to treat the pattern as a lua pattern or as a plain string (defaults to false)
---@return table result An array containing the split string
function string.splitNoLoss(str, pattern, plainText)
	types.check(str, "string", "str", 2)
	types.check(pattern, "string", "pattern", 2)
	types.check(plainText, "boolean?", "plainText", 2)

	plainText = plainText or false

	local lastEnd = 0
	local result = {}

	while true do
		local searchIndex = lastEnd + 1
		local startIndex, endIndex = string.find(str, pattern, searchIndex, plainText)

		if startIndex and endIndex then
			result[#result + 1] = string.sub(str, lastEnd + 1, startIndex - 1)
			result[#result + 1] = string.sub(str, startIndex, endIndex)
			lastEnd = endIndex
		else
			break
		end
	end

	-- Only add the rest of the string if it's not empty. 
	if lastEnd ~= #str then
		result[#result + 1] = string.sub(str, lastEnd + 1, #str)
	end

	return result
end