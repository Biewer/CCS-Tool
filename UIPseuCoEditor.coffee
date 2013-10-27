

class UIPseuCoEditor
	constructor: -> 
		@state = UIEditorState.possible
		@tree = null
	
	setText: (text) -> throw new Error("Not yet implemented!")
	setTree: (program) ->
	
	_setState: (state) ->
		@state = state
		UI.app.didChangeEditorState @




class UIPseuCoHack extends UIPseuCoEditor						#PseuCo editor
	constructor: (@editor, @jsField) ->
		@editor.__hack = @
		$(@editor).on("dblclick", (event) ->
			@__hack.jsField.style.display = "block"
			@__hack.jsField.focus())
		@jsField.__hack = @
		handler = -> 
			@.style.display = "none"
			@__hack.handleJS()
		$(@jsField).on("blur", handler)
		$(@jsField).on("input", handler)
	handleJS: ->
		js = @jsField.value
		if js.search(/[^ \t\n\r]/) == -1
			@_setState UIEditorState.possible
			@tree = null
		try
			obj = eval("__t = " + js)
			if (obj)
				@tree = obj.tree
				@editor.value = @tree.toString()
				@_setState UIEditorState.valid
				#ccs = compiler.compile()
				#$$("ccsField")[0].value = ccs.toString()
		catch e
			col = if e.column then ", column " + e.column else ""
			UIError("Line " + e.line + col + ": " + e.message)
			#$$("ccsField")[0].value = ""
			@tree = null
			@editor.value = ""
			@_setState UIEditorState.invalid
	
	

