class UICCSEditor
	constructor: (@textarea) ->
	
	appDidChangeEditorState: (app, editor) ->
		return if editor != app.pseuCoEditor or editor.state != UIEditorState.valid
		compiler = new PCCCompiler(editor.tree)
		ccs = compiler.compile()
		app.setCCS(ccs)
	
	appDidChangeCCS: (app, newCCS) ->
		@textarea.value = newCCS.toString()
		
		