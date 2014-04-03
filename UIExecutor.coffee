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



class UIExecutor
	constructor: (@button) ->
		@button.__executor = @
		$(@button).on("click", (event) -> event.target.__executor.execute())
		
	
	_enableButton: -> @button.removeAttribute("DISABLED")
	_disableButton: -> @button.setAttribute("DISABLED", "disabled")
	setButtonEnabled: (enabled) -> if enabled then @_enableButton() else @_disableButton()
	
	appWillChangeCCS: (app) -> @setButtonEnabled(false)
	appDidChangeCCS: (app) -> @setButtonEnabled(if app.ccs then true else false)
	
	
	# Executor delegate
	executorPrint: (exec, msg) ->
		UILog msg
	
	executorDidPerformStep: (exec, step, system) ->
		# Tell app..
	
	
	
	execute: ->
		@executor = new PCExecutor(UI.app.ccs, @)
		@executor.execute()
		
		# @setButtonEnabled(false)
# 		app = UI.app
# 		app.resetCCS()
# 		debugger
# 		return if not ccs
# 		UILog("Starting CCS execution.")
# 		t =  new Date()
# 		steps = app.system.getPossibleSteps()
# 		stepCount = 0
# 		while steps.length > 0
# 			app.performStep(steps[0])
# 			steps = app.system.getPossibleSteps()
# 			stepCount++
# 		elapsedMS = ((new Date()).getTime()-t.getTime())
# 		perStep = Math.round(elapsedMS / stepCount * 100) / 100
# 		UILog("Finished CCS execution after performing #{stepCount} steps in #{elapsedMS/1000} seconds (#{perStep}ms per step).\n-------------------------------------------------------------------------------------------")
# 		@setButtonEnabled(if UI.app.ccs then true else false)
		