#!/usr/bin/env lua

local json = require("dkjson")
local lfs = require("lfs")
local http = require("socket.http")

if lfs.currentdir():find("garrysmod[/\\]data[/\\]starfall") then
	warning("this repo should not be in starfall, instead move it out of starfall and use the `link` command to hardlink the files")
end

local sch = require("src/lib/schema")

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
	local content = assert(fi:read("*all"), "failed to read " .. path)
	fi:close()
	return content
end

-- main logic

if args.command:sub(1, 5) == "sfdoc" then
	if args.command == "sfdoc-fetch" then
		local downloaded, code, headers, status = http.request("http://51.68.206.223/sfdoc/docs.json")
		if not downloaded then error("failed to fetch sfdoc: " .. tostring(code)) end

		local sfdoc = assert(json.decode(downloaded), "failed to decode sfdoc")

		info("fetched sfdoc")

		local file = assert(io.open("sfdoc.json", "w+"), "failed to open sfdoc.json")
		assert(file:write(json.encode(sfdoc)), "failed to write sfdoc.json")
		assert(file:close(), "failed to close sfdoc.json")

		info("wrote sfdoc.json")
	elseif args.command == "sfdoc-gen" then
		error("todo")
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
