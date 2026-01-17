#!/usr/bin/env lua

local version = _VERSION:match("%d+%.%d+")

package.path =
	"lua_modules/share/lua/" .. version
	.. "/?.lua;lua_modules/share/lua/" .. version
	.. "/?/init.lua;" .. package.path
package.cpath =
	"lua_modules/lib/lua/" .. version
	.. "/?.so;" .. package.cpath

local json = require("dkjson")
local lfs = require("lfs")
local http = require("socket.http")
local sch = require("lib/schema")

local parser = require("argparse")() {
	name = "tools",
	description = "various tools for sf dev",
	command_target = "command",
}
parser:flag("-v --verbose", "show verbose output")

local commands = {}

commands.sfdoc = parser:command("sfdoc-fetch")
commands.sfdoc:summary("pull the docs json and emit it to sfdocs.json")

commands.sfdoc = parser:command("sfdoc-gen")
commands.sfdoc:summary("read sfdocs.json and generate a luals declaration file")

commands.link = parser:command("link")
commands.link:summary([[hardlink files to .txt in the starfall directory
- `./src/<path>.lua` <-hardlinked-> `<sfdir>/<path>.txt`
  (where <path> is a path within the project, and <sfdir> is the absolute path to the project directory in starfall)
  (this repo should *not* be in the starfall directory)
- if one dir has a file the other does not, it is hardlinked to the other
- if both have a file and they are identical, they are hardlinked together
- if both have a file and they are not, the tool will not touch either, and will print a message about it
- NOTE: if a file is deleted on one side only, this command will recreate the link.
  deletion must be done any of the following ways:
  - manually
  - using the `link-rm <path>` command
  - using the `--purge` flag]])
commands.link:flag("-p --purge", "purge any files in sfdir that arent present in src")
commands.link:flag("-o --overwrite", "overwrite any conflicting files in sfdir with src")

commands.link_rm = parser:command("link-rm")
commands.link_rm:summary("remove a file from both src and sfdir")
commands.link_rm:argument("path", "the path (relative to src and sfdir) to remove")

commands.link_mv = parser:command("link-mv")
commands.link_mv:summary("move a file in both src and sfdir")
commands.link_mv:argument("from", "the path (relative to src and sfdir) to move from")
commands.link_mv:argument("to", "the path (relative to src and sfdir) to move to")

commands.link_shell = parser:command("link-shell")
commands.link_shell:summary("quickly open a shell in sfdir")

local args = parser:parse()

-- utils

function error(fmt, ...)
	print("  \x1b[1;31merror\x1b[0m > " .. (fmt):format(...))
	os.exit(1)
end

local function warning(fmt, ...)
	print("   \x1b[1;33mwarn\x1b[0m > " .. (fmt):format(...))
end

local function info(fmt, ...)
	print("   \x1b[1;34minfo\x1b[0m > " .. (fmt):format(...))
end

local verbose = args.verbose
	and function(fmt, ...)
		print("\x1b[0;90mverbose\x1b[0m > " .. (fmt):format(...))
	end
	or function() end

local function read_file(path)
	local fi = assert(io.open(path), "failed to open " .. path)
	---@cast fi file*
	local content = assert(fi:read("*all"), "failed to read " .. path)
	fi:close()
	return content
end

if lfs.currentdir():find("garrysmod[/\\]data[/\\]starfall") then
	warning("this repo should not be in starfall, instead move it out of starfall and use the `link` command to hardlink the files")
end

-- main logic

if args.command:sub(1, 5) == "sfdoc" then
	if args.command == "sfdoc-fetch" then
		local downloaded, code, _, _ = http.request("http://51.68.206.223/sfdoc/docs.json")
		if not downloaded then error("failed to fetch sfdoc: " .. tostring(code)) end

		local sfdoc = assert(json.decode(downloaded), "failed to decode sfdoc")

		info("fetched sfdoc")

		local fi = assert(io.open("sfdoc.json", "w+"), "failed to open sfdoc.json")
		---@cast fi file*
		assert(fi:write(json.encode(sfdoc)), "failed to write sfdoc.json")
		assert(fi:close(), "failed to close sfdoc.json")

		info("wrote sfdoc.json")
	elseif args.command == "sfdoc-gen" then
		info("read sfdoc.json")

		local sfdoc = assert(json.decode(read_file("sfdoc.json")), "failed to decode sfdoc.json")
		---@cast sfdoc table

		local output = {}
		local function line(...) table.insert(output, table.concat({ ... }, "\n")) end
		local function prefixall(prefix, str) return prefix .. str:gsub("\n", "\n" .. prefix) end
		local function doc(...) line(prefixall("---", table.concat({ ... }, "\n"))) end

		-- the sfdoc iterator
		local function sdi(over)
			if not over then return function() end end

			local i = 0
			return function()
				i = i + 1
				local k = tostring(i)
				if over[k] then return over[k], over[over[k]] end
			end
		end

		local function collect_keys(iter)
			local keys = {}
			for key in iter do table.insert(keys, key) end
			return keys
		end

		local function realm(thing)
			if (thing.client and thing.server) or (not thing.client and not thing.server) then return "[shared]"
			elseif thing.client then return "[client]"
			elseif thing.server then return "[server]" end
		end

		local keyword_sanitize = {
			["function"] = "fn",
			["local"] = "loc",
			["end"] = "endd",
		}

		local typemap = {
			["Any"] = "any",
			["Any..."] = "any ...",
			["any..."] = "any ...",
		}

		local function strtype(ty)
			if not ty then return "unknown" end
			ty = type(ty) == "table" and table.concat(ty, "|") or ty
			return typemap[ty] or ty
		end

		doc("@meta")

		info("generating directives...")
		line("", "-- directives")

		for dctv_name, dctv in sdi(sfdoc.directives) do
			line(
				"",
				"--[============================[--",
				"directive: --@" .. dctv_name,
				"",
				dctv.description
			)
			if dctv.param then
				line(
					"",
					"params:"
				)
				for param_name, param in sdi(dctv.param) do
					line(("- `%s`: %s"):format(param_name, param))
				end
			end
			if dctv.usage then
				line(
					"",
					"usage:",
					"```lua",
					dctv.usage,
					"```"
				)
			end
			if dctv.deprecated then
				line(
					"",
					"deprecated: " .. dctv.deprecated
				)
			end
			line("--]============================]--")
		end

		info("generating tables...")
		line("", "-- tables")

		for tbl_name, tbl in sdi(sfdoc.tables) do
			line()
			doc(
				realm(tbl),
				tbl.description,
				"@class (exact) " .. tbl_name
			)
			for field_name, field in sdi(tbl.field) do
				doc(("@field %s %s '%s'"):format( field_name, field.type, field.desc))
			end
		end

		info("generating classes...")
		line("", "-- classes")

		for class_name, class in sdi(sfdoc.classes) do
			line()
			doc(
				realm(class),
				class.description,
				"@class (exact) " .. class_name
			)
			for field_name, field in sdi(class.field) do
				doc(("@field %s %s '%s'"):format(field_name, field.type, field.desc))
			end
			for op_name, op in sdi(class.operators) do
				local operator, lhs, rhs = op_name:match("(.+)_(.+)_(.+)")
				if rhs ~= "nil" then doc(("@operator %s(%s): %s"):format(operator, lhs, op.returntypes[1]))
				else doc(("@operator %s: %s"):format(operator, op.returntypes[1]))	end
			end
			line("local " .. class_name .. " = {}")
			for meth_name, meth in sdi(class.methods) do
				line()
				doc(meth.description)
				for param_name, param in sdi(meth.param) do
					doc(("@param %s %s '%s'"):format(keyword_sanitize[param_name] or param_name, strtype(meth.paramtypes and meth.paramtypes[param_name]), param))
				end
				if meth.returntypes then
					for i, ret in ipairs(meth.returntypes) do
						doc(("@return %s '%s'"):format(
							strtype(ret),
							type(meth.ret) == "table"
								and (
									meth.ret[i] or "unknown"
								)
								or (i == 1 and meth.ret)
								or ""
						))
					end
				end
				local params = collect_keys(sdi(meth.param or {}))
				for k, v in ipairs(params) do
					if keyword_sanitize[v] then params[k] = keyword_sanitize[v] end
				end
				line(("function %s:%s(%s) end"):format(class_name, meth_name, table.concat(params, ", ")))
			end
		end

		info("generating libraries...")
		line("", "-- libraries")

		for lib_name, lib in sdi(sfdoc.libraries) do
			if lib_name ~= "builtin" then
				line()
				doc(
					realm(lib),
					lib.description
				)
				line(lib_name .. " = {}")
				for field_name, field in sdi(lib.field) do
					doc(("@field %s %s '%s'"):format(field_name, field.type, field.desc))
				end
			else
				for field_name, field in sdi(lib.field) do
					line()
					doc(
						field.desc,
						("@type %s"):format(field.type)
					)
					line(("%s = nil"):format(field_name))
				end
			end
			for func_name, func in sdi(lib.functions) do
				line()
				doc(func.description)
				for param_name, param in sdi(func.param) do
					doc(("@param %s %s '%s'"):format(keyword_sanitize[param_name] or param_name, strtype(func.paramtypes and func.paramtypes[param_name]), param))
				end
				if func.returntypes then
					for i, ret in ipairs(func.returntypes) do
						doc(("@return %s '%s'"):format(
							strtype(ret),
							type(func.ret) == "table"
								and (
									func.ret[i] or "unknown"
								)
								or (i == 1 and func.ret)
								or ""
						))
					end
				end

				local params = collect_keys(sdi(func.param or {}))
				for k, v in ipairs(params) do
					if keyword_sanitize[v] then params[k] = keyword_sanitize[v] end
				end
				if lib_name ~= "builtin" then line(("function %s.%s(%s) end"):format(lib_name, func_name, table.concat(params, ", ")))
				else line(("function %s(%s) end"):format(func_name, table.concat(params, ", "))) end
			end
		end

		info("finished generating")

		local fi = assert(io.open("tscm.d.lua", "w+"), "failed to open tscm.d.lua")
		---@cast fi file*
		assert(fi:write(table.concat(output, "\n")), "failed to write tscm.d.lua")
		assert(fi:close(), "failed to close tscm.d.lua")

		info("wrote tscm.d.lua")
	end
elseif args.command:sub(1, 4) == "link" then
	assert(lfs.attributes("toolconfig.json"), [[no toolconfig.json.
create one in the current directory, it should contain an "sfdir" field that is an absolute path to the starfall
version of the project

it should look something like "C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/data/starfall/projectnamehere"
this command will replicate the structure of ./src/ to that directory but hardlinked as txt files]])

	local toolconfig = assert(json.decode(read_file("toolconfig.json")), "failed to decode toolconfig")
	sch.expect({
		sfdir = sch.string * sch.validator(function(value, fail)
			local attrs = lfs.attributes(value)
			if not attrs then fail.leaf("path does not exist")
			elseif attrs.mode ~= "directory" then fail.leaf("path exists, but is not a directory") end
		end),
	}, toolconfig, "toolconfig validation failed")
	---@cast toolconfig table

	info("sfdir: %s", toolconfig.sfd)

	local function strip_extension(path)
		return (path:gsub("%.txt$", ""):gsub("%.lua$", ""))
	end

	if args.command == "link" then
		local checked = {}

		local function walk(base, dir, fn_dir, fn_file)
			for entry in lfs.dir(base .. dir) do
				if entry ~= "." and entry ~= ".." then
					local path = dir .. "/" .. entry
					local attrs = lfs.attributes(base .. path)
					if attrs.mode == "directory" then
						if not checked[path] then
							checked[path] = true
							fn_dir(path)
						end
						walk(base, path, fn_dir, fn_file)
					elseif attrs.mode == "file" then
						path = strip_extension(path)
						if not checked[path] then
							checked[path] = true
							fn_file(path)
						end
					end
				end
			end
		end

		local function logic_dir(path)
			verbose("dir %s", path)

			local src_path = lfs.currentdir() .. "/src" .. path
			local src = lfs.attributes(src_path)
			local dst_path = toolconfig.sfdir .. path
			local dst = lfs.attributes(dst_path)

			if not src then
				info("$%s: mkdir src%s", path, path)
				assert(lfs.mkdir(src_path), "failed to mkdir")
			elseif not dst then
				info("$%s: mkdir sfdir%s", path, path)
				assert(lfs.mkdir(dst_path), "failed to mkdir")
			end
		end

		local function logic_file(path)
			verbose("file %s", path)

			local src_path = lfs.currentdir() .. "/src" .. path .. ".lua"
			local src = lfs.attributes(src_path)
			local dst_path = toolconfig.sfdir .. path .. ".txt"
			local dst = lfs.attributes(dst_path)

			if not src then
				if args.purge then
					info("$%s: purge file not present in src", path)
					assert(os.remove(dst_path), "failed to remove")
				else
					info("$%s: hardlink sfdir -> src", path)
					assert(lfs.link(dst_path, src_path), "failed to hardlink")
				end
			elseif not dst then
				info("$%s: hardlink src -> sfdir", path)
				assert(lfs.link(src_path, dst_path), "failed to hardlink")
			elseif src and dst then
				local same = true
				for k, v in pairs(src) do
					if v ~= dst[k] then
						same = false
						break
					end
				end
				if same then return verbose("$%s: files have identical attributes, skipping", path) end
				local src_contents = read_file(src_path)
				local dst_contents = read_file(dst_path)
				if src_contents == dst_contents then
					info("$%s: hardlink identical files", path)
					assert(os.remove(dst_path), "failed to remove from sfdir")
					assert(lfs.link(src_path, dst_path), "failed to hardlink")
				elseif args.overwrite then
					info("$%s: overwrite sfdir file with src file")
					assert(os.remove(dst_path), "failed to remove from sfdir")
					assert(lfs.link(src_path, dst_path), "failed to hardlink")
				else warning("$%s: files are different, no actions taken (src: %dB, sfdir: %dB)", path, #src_contents, #dst_contents) end
			end
		end

		walk(lfs.currentdir() .. "/src", "", logic_dir, logic_file)
		walk(toolconfig.sfdir, "", logic_dir, logic_file)

		info("done")
	elseif args.command == "link-rm" then
		local path = "/" .. strip_extension(args.path)

		local src_path = lfs.currentdir() .. "/src" .. path .. ".lua"
		local src = lfs.attributes(src_path)
		local dst_path = toolconfig.sfdir .. path .. ".txt"
		local dst = lfs.attributes(dst_path)

		if src then
			info("$%s: removed from src", path)
			assert(os.remove(src_path), "failed to remove from src")
		else info("$%s: not present in src", path) end

		if dst then
			info("$%s: removed from sfdir", path)
			assert(os.remove(dst_path), "failed to remove from sfdir")
		else info("$%s: not present in sfdir", path) end
	elseif args.command == "link-mv" then
		local from = "/" .. strip_extension(args.from)
		local to = "/" .. strip_extension(args.to)

		local src_path_from = lfs.currentdir() .. "/src" .. from .. ".lua"
		local src_from = lfs.attributes(src_path_from)
		local dst_path_from = toolconfig.sfdir .. from .. ".txt"
		local dst_from = lfs.attributes(dst_path_from)

		local src_path_to = lfs.currentdir() .. "/src" .. to .. ".lua"
		local src_to = lfs.attributes(src_path_to)
		local dst_path_to = toolconfig.sfdir .. to .. ".txt"
		local dst_to = lfs.attributes(dst_path_to)

		if src_from then
			if not src_to then
				info("$%s: moved in src", from)
				assert(os.rename(src_path_from, src_path_to), "failed to move in src")
			else info("$%s: a file already exists with the destination name in src", from) end
		else info("$%s: not present in src", from) end

		if dst_from then
			if not dst_to then
				info("$%s: moved in sfdir", from)
				assert(os.rename(dst_path_from, dst_path_to), "failed to move in sfdir")
			else info("$%s: a file already exists with the destination name in sfdir", from) end
		else info("$%s: not present in sfdir", from) end
	elseif args.command == "link-shell" then
		lfs.chdir(toolconfig.sfdir)
		os.execute(os.getenv("SHELL"))
	end
end
