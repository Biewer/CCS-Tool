
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
	UI.pseuCoEditor = new UIPseuCoHack($$("pseucoField"), $$("pseucoJSField"))
	UI.ccsEditor = new UICCSEditor($$("ccsField"))
	UI.app = new UIAppController(UI.pseuCoEditor, UI.ccsEditor, UI.executor, UI.console, UI.history)


UILog = (msg) -> UI.console.log(msg)
UIWarn = (msg) -> UI.console.warn(msg)
UIError = (msg) -> UI.console.error(msg)


registerLoadCallback UILoad