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



class UICCSEditor
	constructor: (@textarea) ->
	
	appDidChangeEditorState: (app, editor) ->
		return if editor != app.pseuCoEditor or editor.state != UIEditorState.valid
		compiler = new PCC.Compiler(editor.tree)
		ccs = compiler.compileProgram()
		app.setCCS(ccs)
	
	appDidChangeCCS: (app, newCCS) ->
		@textarea.value = newCCS.toString()
		
		