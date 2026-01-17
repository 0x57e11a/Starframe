package = "starframe"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/0x57e11a/Starframe",
}
description = {
	homepage = "https://github.com/0x57e11a/Starframe",
	license = "MIT",
}
dependencies = {
	"lua >= 5.2",
	"argparse = 0.7.1-1",
	"luasocket = 3.1.0-1",
	"dkjson = 2.8-2",
	"luafilesystem = 1.8.0-1",
}
build = {
	type = "builtin",
	modules = {
		sftools = "tools/docgen/tools.lua",
	},
}
