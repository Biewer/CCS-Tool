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



class UIAppController
	constructor: (@pseuCoEditor, @ccsEditor, @executor, @console, @history) ->
		@observers = [@pseuCoEditor, @ccsEditor, @executor, @console, @history]
		@stepObservers = [@console, @history]
	
	didChangeEditorState: (editor) ->
		o.appDidChangeEditorState?(@, editor) for o in @observers
		null
	
	didUpdateConsole: (console) ->
		o.appDidUpdateConsole?(@, console) for o in @observers
		null
	
	willChangeCCS: (newCCS) ->
		o.appWillChangeCCS?(@, newCCS) for o in @observers
		null
	
	didChangeCCS: (newCCS) ->
		o.appDidChangeCCS?(@, newCCS) for o in @observers
		null
	
	setCCS: (newCCS) ->
		@willChangeCCS(newCCS)
		@ccs = newCCS
		@system = null
		@didChangeCCS(newCCS)
	
	resetCCS: ->
		@system = @ccs.system.copy()
		o.appDidResetCCS?(@, @system) for o in @observers
		@system
	
	willPerformStep: (step) ->
		o.appWillPerformStep?(@, step) for o in @stepObservers
		null
	
	didPerformStep: (step) ->
		o.appDidPerformStep?(@, step) for o in @stepObservers
		null
	
	performStep: (step) ->
		throw new Error("Cannot perform step when no CCS is available!") if not @ccs
		@willPerformStep step
		@system = @history.performStep step
		if step.action.channel.name == "println" and step.action.isOutputAction() and step.action.expression
			UILog "#{step.action.expression.evaluate()}"
		@didPerformStep step
	
	
	
	
	
	willOpenDocument: (document) ->
		# Coming later...
	didOpenDocument: (document) ->
		# Coming later...