

NJSReadline = require "readline"
fs = require('fs')
coffee = require("coffee-script")


NJSReadlineOptions = 
	input:
		process.stdin
	output:
		process.stdout

class NJSMain
	constructor: ->
		@src = []
		@out = []
		@valid = true
		i = 2
		t = 0
		while i < process.argv.length
			if process.argv[i] == "-s"
				t = 1
			else if process.argv[i] == "-o"		#ignoring out right now
				t = 2
			else if t == 1
				@src.push(process.argv[i])
			else if t == 2
				@out.push(process.argv[i])
			else
				console.log "Unknown command!"
				@valid = false
				break
			i++
	
	
	
	_filesForPath: (path) ->
		console.log "files"
		stats = fs.statSync(path)
		if (stats.isDirectory())
			res = []
			files = fs.readdirSync(path)
			console.log "expanding folder"
			for f in files
				f = "#{path}/#{f}"
				res.push(f) if fs.statSync(f).isFile()
			console.log "folder expanded"
			res
		else
			[path]
	
	_getInputFiles: ->
		res = {"pseuco": [], "coffee": []}
		for path in @src
			console.log "exploring path"
			files = @_filesForPath path
			console.log "exploring items"
			for f in files
				comps = f.split(".")
				if comps[comps.length-1] == "coffee"
					res.coffee.push(f)
				else if comps[comps.length-1] == "pseuco"
					res.pseuco.push(f)
		res
	
	createTest: ->
		return if not @valid
		files = @_getInputFiles()
		pseuco = {}
		console.log "collecting pseuco"
		for p in files.pseuco
			content = fs.readFileSync(p, {"encoding": "utf8"})
			comps = p.split(".")
			comps = comps[comps.length-2].split("/")
			pseuco[comps[comps.length-1]] = content
		pseucoString = JSON.stringify(pseuco)
		console.log "collecting test code"
		for c in files.coffee
			content = fs.readFileSync(c, {"encoding": "utf8"})
			content = coffee.compile(content)
			comps = c.split(".")
			comps[comps.length-1] = "js"
			comps[comps.length-2] += "Spec"
			c2 = comps.join(".")
			spec = "var testCases = #{pseucoString}; \n\n\n#{content}\n\n"
			fs.writeFileSync(c2, spec)
		
		
		

main = new NJSMain()
main.createTest()


		