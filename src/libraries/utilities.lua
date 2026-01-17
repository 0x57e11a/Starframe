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

	local errorMsg = string.format(errorFormat, name, desiredType, type(value))
	error(errorMsg, 1 + level)
end

bootstrapper.addToEnvironment("types", types)