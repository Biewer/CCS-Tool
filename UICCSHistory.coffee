class UICCSHistory
	constructor: (@container) ->
	appDidResetCCS: (app, system) ->
		@clear()
		@system = system
		@_addState(null)
	clear: ->
		@system = null
		@container.innerHTML = ""
	performStep: (step) -> 
		throw new Error("Step must not be null!") if not step
		@system = step.perform()
		@_addState step
		@system
	_addState: (step) ->
		action = ""
		if step
			action = step.action.transferDescription()
			details = ""
			if step.actionDetails
				details = step.actionDetails
			if details.length > 0
				details = " <span class=\"action_detail\">(#{details})</span>"
			action = "<span class=\"h_action\">#{action}#{details}</span>"
		system = "<span class=\"h_ccs\">#{@system.toString()}</span>"
		li = document.createElement("LI")
		li.innerHTML = action + system
		if @container.hasChildNodes()
			@container.insertBefore(li, @container.firstChild)
		else
			@container.appendChild(li)
	
	
	
	
	
	
	
		