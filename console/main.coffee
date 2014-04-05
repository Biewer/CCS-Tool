`/* ###
PseuCo Compiler  
Copyright (C) 2013  
Saarland University (www.uni-saarland.de)  
Sebastian Biewer (biewer@splodge.com)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
### */`

NJSReadline = require "readline"

Jasmine = require "jasmine-node"


NJSReadlineOptions = 
	input:
		process.stdin
	output:
		process.stdout

class NJSMain
	constructor: ->
		cmd = process.argv[2]
		if cmd == "-help" or cmd == "-h"
			@printHelp()
		else if cmd == "-test" or cmd == "-t"
			@performTests(process.argv[3..])
		else
			@printSummary()
	
	
	
	
	performTests: (paths) ->
		fs = require "fs"
		coffee = require "coffee-script"
		for path in paths
			info = fs.statSync path
			if not info
				console.warn "WARNING: File #{path} not found!"
			else if info.isDirectory()
				@performTests ("#{path}/#{file}" for file in fs.readdirSync path)
			else if info.isFile()
				code = fs.readFileSync path, "utf8"
				comps = path.split(".")
				if comps[comps.length-1] == "coffee"
					coffee.run code
				else
					eval code
	
	
	printHelp: ->
		console.log "First line of help"
		console.log "Second line of help?"
	
	printSummary: ->
		console.log "ToDo"
	
	






NJSSharedMain = new NJSMain()
		