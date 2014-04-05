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



class UICCSHistory
	constructor: (@container) -> @clear()
	appDidResetCCS: (app, system) ->
		@clear()
		@system = system
		@_addState(null)
	clear: ->
		@system = null
		@container.innerHTML = ""
		@stepStack = []
	performStep: (step) -> 
		throw new Error("Step must not be null!") if not step
		@addState step, step.perform()
		@system
	addState: (step, newSystem) ->
		@stepStack.push step if step.copyOnPerform
		@system = newSystem
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
	
	
	
	
	
	
	
		