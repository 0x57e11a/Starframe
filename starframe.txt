--@name Starframe
--@author The Starframe Team
--@mainfile

--@require starframe/bootstrapper.txt

--@includedir starframe/libraries
--@includedir starframe/modules

--[[

	**** Starfarme ****
	Starframe's main file acts as the entrypoint for the mainframe.
	It loads all the necessary components for the mainframe to properly initialise.

	You may also define mainframe-wide settings here using mainframe.<name> = <value>

--]]


--[[
	Run pre-initialisation logic after this comment.
--]]

bootstrapper.loadLibraries()

--[[
	Run logic after libraries have been defined but before module load.
	This allows for extra content to be passed to all modules before full initialisation.
--]]

bootstrapper.loadModules()

--[[
	Run post-initialisation logic after this comment.
--]]