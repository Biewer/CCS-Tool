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


CCS = require "CCS"
PC = require "PseuCo"
PCC = require "CCSCompiler"


UIEditorState = 
	possible: 0
	invalid: 1
	valid: 2


UIID = 
	fileLabel: null
	fileTitle: null
	fileType: null
	fileDropDownButton: null
	fileAdd: null
	pseucoField: null
	pseucoJSField: null
	hresizer: null
	ccsField: null
	vresizer: null
	tabBar: null
	console: null

UI = 
	console: null
	toolTabBar: null
	history: null
	executor: null
	app: null

$$ = (id) -> UIID[id][0]

UILoad = ->
	UIID = 
		fileLabel: $("#fileLabel")
		fileTitle: $("#fileTitle")
		fileType: $("#fileType")
		fileDropDownButton: $("#fileDropDownButton")
		fileAdd: $("#fileAdd")
		pseucoField: $("#pseuco_field")
		pseucoJSField: $("#pseucojs_field")
		hresizer: $("#hresizer")
		ccsField: $("#ccs_field")
		vresizer: $("#vresizer")
		tabBar: $("#tabBar")
		tabContent: $("#tabContent")
		console: $("#console")
		history: $("#history")
		runButton: $("#ccsRun")
	UI.console = new UIConsole($$("console"))
	UI.toolTabBar = new UITabBar($$("tabBar"), $$("tabContent"))
	UI.history = new UICCSHistory($$("history"))
	UI.executor = new UIExecutor($$("runButton"))
	UI.pseuCoEditor = new UIPseuCoEditor($$("pseucoField"))#, $$("pseucoJSField"))
	UI.ccsEditor = new UICCSEditor($$("ccsField"))
	UI.app = new UIAppController(UI.pseuCoEditor, UI.ccsEditor, UI.executor, UI.console, UI.history)


UILog = (msg) -> UI.console.log(msg)
UIWarn = (msg) -> UI.console.warn(msg)
UIError = (msg) -> UI.console.error(msg)


registerLoadCallback UILoad