--@name Starframe | Wire Library
--@author The Starframe Team
--@class none

require("src/libraries/utilities")

--[[

    The wire library is a modified version of the original wire library
    provided by Starfall, adapted to work within the Starframe ecosystem.

--]]

if CLIENT then return end

local inputs = {}
local outputs = {}

local starwire = {
    create = wire.create,
    delete = wire.delete,
    getInputs = wire.getInputs,
    getOutputs = wire.getOutputs,
    self = wire.self,

    ports = wire.ports,

    PORT_TYPE_ANGLE = wire.PORT_TYPE_ANGLE,
    PORT_TYPE_ARRAY = wire.PORT_TYPE_ARRAY,
    PORT_TYPE_ENTITY = wire.PORT_TYPE_ENTITY,
    PORT_TYPE_NUMBER = wire.PORT_TYPE_NUMBER,
    PORT_TYPE_STRING = wire.PORT_TYPE_STRING,
    PORT_TYPE_VECTOR = wire.PORT_TYPE_VECTOR,
    PORT_TYPE_VECTOR2 = wire.PORT_TYPE_VECTOR2,
    PORT_TYPE_VECTOR4 = wire.PORT_TYPE_VECTOR4,
    PORT_TYPE_WIRELINK = wire.PORT_TYPE_WIRELINK
}

local allowedIOTypes = {
	[wire.PORT_TYPE_ANGLE] = true,
	[wire.PORT_TYPE_ARRAY] = true,
	[wire.PORT_TYPE_ENTITY] = true,
	[wire.PORT_TYPE_NUMBER] = true,
	[wire.PORT_TYPE_STRING] = true,
	[wire.PORT_TYPE_VECTOR] = true,
	[wire.PORT_TYPE_VECTOR2] = true,
	[wire.PORT_TYPE_VECTOR4] = true,
	[wire.PORT_TYPE_WIRELINK] = true
}

local mainframeLoading = true
local function buildInputs()
    if mainframeLoading then return end

    local names = {}
    local types = {}
    local descriptions = {}

    for _, inputList in pairs(inputs) do
    	for i = 1, #inputList.names do
    		names[#names + 1] = inputList.names[i]
    		types[#types + 1] = inputList.types[i]
    		descriptions[#descriptions + 1] = inputList.descriptions[i] or ""
    	end
    end

    wire.createInputs(names, types, descriptions)
end


local function buildOutputs()
    if mainframeLoading then return end

    local names = {}
    local types = {}
    local descriptions = {}

    for _, outputList in pairs(outputs) do
    	for i = 1, #outputList.names do
    		names[#names + 1] = outputList.names[i]
    		types[#types + 1] = outputList.types[i]
    		descriptions[#descriptions + 1] = outputList.descriptions[i] or ""
    	end
    end

    wire.createOutputs(names, types, descriptions)
end


local function getInputCount(moduleID)
	if moduleID ~= nil then
		return #inputs[moduleID].names
	else
		local count = 0
		for _, value in pairs(inputs) do
			count = count + #value.names
		end

		return count
	end
end


local function getOutputCount(moduleID)
	if moduleID ~= nil then
		return #outputs[moduleID].names
	else
		local count = 0
		for _, value in pairs(outputs) do
			count = count + #value.names
		end

		return count
	end
end


---Replaces the standard wire library's createInput function
---@param names string[]
---@param types string[]
---@param descriptions string[]?
---@see wire.createInputs
function starwire.createInputs(names, types, descriptions)
    types.check(names, "table", "names", 2)
    types.check(types, "table", "types", 2)
    types.check(descriptions, "table?", "descriptions", 2)

    descriptions = descriptions or {}

    local moduleID = bootstrapper.getCallingModuleID() or 1
    local moduleInputs = {
        names = names,
        types = types,
        descriptions = descriptions
    }

    if #names ~= #types then
        error("Names and Types must have the same amount of values", 2)
    end

	--- Get total count - current inputs + expected inputs
	local expectedCount = getInputCount() - getInputCount(moduleID) + #moduleInputs.names
	if expectedCount > 64 then
		error("Expected input count is over the maximum of 64", 2)
	end

	for i = 1, #names do
		local name = names[i]
		local type = string.upper(types[i])
		local desc = descriptions[i]

		types.check(desc, "string?", "description #"..tostring(i))

		if not string.find(name, "^[A-Z][%a%d%s]*$") then
			error("Invalid input name at index "..tostring(i).." (must be alphanumeric starting with upper-case)", 2)
		end

		if not allowedIOTypes[type] then
			error("Invalid/unsupported input type at index "..tostring(i).. ": "..type, 2)
		end
	end

    inputs[moduleID] = moduleInputs
    buildInputs()
end


---Replaces the standard wire library's createOutput function
---@param names string[]
---@param types string[]
---@param descriptions string[]?
---@see wire.createOutputs
function starwire.createOutputs(names, types, descriptions)
	types.check(names, "table", "names", 2)
	types.check(types, "table", "types", 2)
	types.check(descriptions, "table?", "descriptions", 2)

	descriptions = descriptions or {}

	local moduleID = bootstrapper.getCallingModuleID() or 1
	local moduleOutputs = {
		names = names,
		types = types,
		descriptions = descriptions
	}

	if #names ~= #types then
		error("Names and Types must have the same amount of values", 2)
	end

	--- Get total count - current outputs + expected outputs
	local expectedCount = getOutputCount() - getOutputCount(moduleID) + #moduleOutputs.names
	if expectedCount > 64 then
		error("Expected output count is over the maximum of 64", 2)
	end

	for i = 1, #names do
		local name = names[i]
		local type = string.upper(types[i])
		local desc = descriptions[i]

		types.check(desc, "string?", "description #"..tostring(i))

		if not string.find(name, "^[A-Z][%a%d%s]*$") then
			error("Invalid output name at index "..tostring(i).." (must be alphanumeric starting with upper-case)", 2)
		end

		if not allowedIOTypes[type] or type == wire.PORT_TYPE_WIRELINK then
			error("Invalid/unsupported output type at index "..tostring(i).. ": "..type, 2)
		end
	end

	outputs[moduleID] = moduleOutputs
	buildInputs()
end


bootstrapper.addToEnvironment("wire", starwire)

-- Build all IO after all modules have loaded to avoid wire IO from being unliked on code load.
hook("postmoduleload", "starframe_wire_init", function()
    mainframeLoading = false
    buildInputs()
    buildOutputs()
end)