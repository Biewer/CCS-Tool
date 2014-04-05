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



CCSExecutorCopyOnPerformStepPolicy = false
CCSExecutorStepCountPerExecutionUnit = 20
CCSExecutorDefaultStepPicker = (steps) ->
	steps[0]	# ToDo: random!

class CCSExecutor
	constructor: (@ccs, @delegate) ->
	
	
	execute: (system) ->
		@prepareExecution(system)
		{} while @continueExecution()
		@finishExecution()
	
	prepareExecution: (@system=@ccs.system.copy()) ->
		throw new Error("No CCS system available!") if not @system
		@_printExecutionIntro()
		@executionStart = new Date()
		@stepCount = 0
	
	_printExecutionIntro: -> @_output("Starting CCS execution.")
	
	
	continueExecution: ->
		steps = @system.getPossibleSteps(CCSExecutorCopyOnPerformStepPolicy)
		throw new Error("Time exceeded. Info: \n\t" + steps.join("\n\t")) if @stepCount > 5000
		count = CCSExecutorStepCountPerExecutionUnit
		while steps.length > 0 and count > 0
			step = @_chooseStep(steps)
			@_performStep(step)
			@_printStep(step)
			steps = @system.getPossibleSteps(CCSExecutorCopyOnPerformStepPolicy)
			@stepCount++
			count--
		steps.length > 0
	
	_printStep: (step) ->
		if step.action.channel.name != CCSInternalChannel
			exp = step.action.expression
			value = if exp then exp.evaluate() else ""
			value = "\"#{value}\"" if (exp.typeOfEvaluation() == "string")
			value = ": #{value}"
			if step.action.isOutputAction()
				@_output("Output on channel <b>#{step.action.channel.toString()}</b>#{value}")
			else if step.action.isInputAction()
				@_output("Input on channel #{step.action.channel.toString()}#{value}")
			else
				@_output("Message on channel #{step.action.channel.toString()}")
	
	
	finishExecution: ->
		@_printExecutionSummary()
		@system = null
	
	_printExecutionSummary: ->
		elapsedMS = ((new Date()).getTime()-@executionStart.getTime())
		perStep = Math.round(elapsedMS / @stepCount * 100) / 100
		@_output("Finished CCS execution after performing #{@stepCount} steps in #{elapsedMS/1000} seconds (#{perStep}ms per step).\n-------------------------------------------------------------------------------------------")
		
		
		
		
		
		
		
	
	_output: (msg) -> @delegate.executorPrint(@, msg) if @delegate.executorPrint
	_chooseStep: (steps) -> 
		if @delegate.executorChooseStep
			@delegate.executorChooseStep(@, step)
		else
			CCSExecutorDefaultStepPicker(steps)
	_performStep: (step) ->
		@delegate.executorWillPerformStep(@, step) if @delegate.executorWillPerformStep
		@system = step.perform()
		@delegate.executorDidPerformStep(@, step, @system) if @delegate.executorDidPerformStep
		@system
	
	
	
	
	
	
	
	

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
		