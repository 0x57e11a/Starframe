local sch = {}

function sch.format_key(key)
	local ty = type(key)
	if ty == "string" then
		if key:match("^[_a-zA-Z][_a-zA-Z0-9]*$") then return (".%s"):format(key)
		else return ("[%q]"):format(key) end
	elseif ty == "nil" or ty == "boolean" or ty == "number" then return ("[%s]"):format(tostring(key))
	else return ("[<%s>]"):format(tostring(key)) end
end

function sch.format_value(value)
	local ty = type(value)
	if ty == "string" then return ("%q"):format(value)
	elseif ty == "nil" or ty == "boolean" or ty == "number" then return ("%s"):format(tostring(value))
	else return ("<%s>"):format(tostring(value)) end
end

local validator_mt = {
	__add = function(self, rhs)
		return sch.validator(function(value, fail)
			local failed = false
			fail.handle(function()
				failed = true
				return false
			end, self, value)
			if failed then rhs(value, fail) end
		end)
	end,
	__mul = function(self, rhs)
		return sch.validator(function(value, fail)
			local failed = false
			fail.handle(function()
				failed = true
				return true
			end, self, value)
			if not failed then rhs(value, fail) end
		end)
	end,
	__call = function(self, value, fail) self[1](value, fail) end,
	__tostring = function() return "validator" end,
}

function sch.validator(fn)
	assert(type(fn) == "function", "fn must be a function")
	return setmetatable({ fn }, validator_mt)
end

function sch.type(ty, custom)
	assert(type(ty) == "string", "ty must be a string")
	assert(custom == nil or type(custom) == "string", "custom must be a string or nil")
	return sch.validator(function(value, fail)
		if type(value) ~= ty then
			if type(value) ~= "nil" then fail.expected("type", custom or ty, type(value))
			else fail.missing(custom or ty) end
		end
	end)
end

function sch.eq(match)
	return sch.validator(function(value, fail)
		if value ~= match then fail.expected("value", sch.format_value(match), sch.format_value(value)) end
	end)
end

function sch.neq(match)
	return sch.validator(function(value, fail)
		if value == match then fail.expected_not("value", sch.format_value(match), sch.format_value(value)) end
	end)
end

function sch.any(options)
	local lookup = {}
	local expected = {}
	for _, value in ipairs(options) do
		lookup[value] = true
		table.insert(expected, sch.format_value(value))
	end
	expected = table.concat(expected, " | ")
	return sch.validator(function(value, fail)
		if not lookup[value] then fail.expected("value", expected, sch.format_value(value)) end
	end)
end

function sch.list(schema, min, max)
	assert(min == nil or type(min) == "number", "min must be an integer or nil")
	assert(max == nil or type(max) == "number", "max must be an integer or nil")
	if min and max then assert(min <= max, "min must be less than or equal to max") end
	return sch.type("table", "list") * sch.validator(function(value, fail)
		if min and #value < min then fail.expected("length", "at least "..tostring(min), #value) end
		if max and #value > max then fail.expected("length", "at most "..tostring(max), #value) end
		for i, elem in ipairs(value) do
			fail.branch(sch.format_key(i), schema, elem)
		end
	end)
end

sch.vnil = sch.eq(nil)
sch.vtrue = sch.eq(true)
sch.vfalse = sch.eq(false)

sch.boolean = sch.type("boolean")
sch.number = sch.type("number")
sch.integer = sch.type("number", "integer") * sch.validator(function(value, fail)
	if value ~= math.floor(value) then fail() end
end)
sch.string = sch.type("string")
sch.table = sch.type("table")
sch.fn = sch.type("function")
sch.coroutine = sch.type("thread")
sch.userdata = sch.type("userdata")

function sch.subvalidate(schema, value, fail)
	local ty = type(schema)
	if getmetatable(schema) == validator_mt then schema(value, fail)
	elseif ty ~= "table" then
		if value ~= schema then fail.expected("value", sch.format_value(schema), sch.format_value(value)) end
	else
		if type(value) ~= "table" then
			fail.expected("type", "fields", type(value))
			return
		end
		if #value ~= #schema then fail.expected("length", sch.format_value(#schema), sch.format_value(#value)) end

		for key, subschema in pairs(schema) do
			fail.branch(sch.format_key(key), subschema, value[key])
		end
	end
end

function sch.match(schema, value)
	local results = {}

	local branch_stack = { "$" }
	local handler_stack = {}
	local fail
	fail = {
		branch = function(branch, schema, value)
			assert(type(branch) == "string", "branch must be a string")
			table.insert(branch_stack, branch)
			local ok, res = pcall(sch.subvalidate, schema, value, fail)
			table.remove(branch_stack)
			if not ok then error(res) end
		end,
		handle = function(handler, schema, value)
			assert(type(handler) == "function", "handler must be a function")
			table.insert(handler_stack, handler)
			local ok, res = pcall(sch.subvalidate, schema, value, fail)
			table.remove(handler_stack)
			if not ok then error(res) end
		end,
		leaf = function(message)
			assert(type(message) == "string", "message must be a string")
			local res = ("(%s) %s"):format(table.concat(branch_stack), message)
			for i = #handler_stack, 1, -1 do
				if not handler_stack[i](res) then return end
			end
			table.insert(results, res)
		end,
		missing = function(expected)
			fail.leaf(("missing: expected %s"):format(expected))
		end,
		expected = function(category, expected, found)
			fail.leaf(("%s: expected %s, found %s"):format(category, expected, found))
		end,
		expected_not = function(category, forbidden)
			fail.leaf(("%s: cannot be %s"):format(category, forbidden))
		end,
	}

	sch.subvalidate(schema, value, fail)

	if #results == 0 then return true
	else
		table.sort(results)
		return false, table.concat(results, "\n")
	end
end

function sch.expect(schema, value, msg)
	local ok, results = sch.match(schema, value)
	if not ok then error((msg or "schema validation failed")..":\n"..results) end
end

return sch
