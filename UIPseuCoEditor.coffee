###
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
###



class UIPseuCoEditor
	constructor: (@editor) -> 
		@editor._editorController = @
		handler = -> 
			@_editorController.handleChange()
		$(@editor).on("blur", handler)
		$(@editor).on("input", handler)
		@state = UIEditorState.possible
		@tree = null
	
	handleChange: ->
		@setText @editor.value
	
	setText: (text) -> 
		@_setState UIEditorState.possible
		try
			@tree = PseuCoParser.parse(text);
			@_setState UIEditorState.valid
		catch e
			col = if e.column then ", column " + e.column else ""
			UIError("Line " + e.line + col + ": " + e.message)
			#$$("ccsField")[0].value = ""
			@tree = null
			@_setState UIEditorState.invalid
		
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
	
	

