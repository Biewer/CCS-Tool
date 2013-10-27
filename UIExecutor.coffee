class UIExecutor
	constructor: (@button) ->
		@button.__executor = @
		$(@button).on("click", (event) -> event.target.__executor.execute())
	
	_enableButton: -> @button.removeAttribute("DISABLED")
	_disableButton: -> @button.setAttribute("DISABLED", "disabled")
	setButtonEnabled: (enabled) -> if enabled then @_enableButton() else @_disableButton()
	
	appWillChangeCCS: (app) -> @setButtonEnabled(false)
	appDidChangeCCS: (app) -> @setButtonEnabled(if app.ccs then true else false)
	
	execute: ->
		@setButtonEnabled(false)
		app = UI.app
		app.resetCCS()
		return if not ccs
		UILog("Starting CCS execution.")
		t =  new Date()
		steps = app.system.getPossibleSteps()
		stepCount = 0
		while steps.length > 0
			app.performStep(steps[0])
			steps = app.system.getPossibleSteps()
			stepCount++
		elapsedMS = ((new Date()).getTime()-t.getTime())
		perStep = Math.round(elapsedMS / stepCount * 100) / 100
		UILog("Finished CCS execution after performing #{stepCount} steps in #{elapsedMS/1000} seconds (#{perStep}ms per step).\n-------------------------------------------------------------------------------------------")
		@setButtonEnabled(if UI.app.ccs then true else false)
		