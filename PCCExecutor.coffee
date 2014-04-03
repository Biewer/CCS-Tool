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


class PCCExecutor extends CCS.Executor
	_printStep: (step) ->
		if step.action.channel.name == "println" and step.action.isOutputAction() and step.action.expression	# Intercept println
			@_output "#{step.action.expression.evaluate()}"
	
	_printExecutionIntro: -> @_output("<i>Starting CCS execution.</i>")
	_printExecutionSummary: ->
		elapsedMS = ((new Date()).getTime()-@executionStart.getTime())
		perStep = Math.round(elapsedMS / @stepCount * 100) / 100
		@_output("<i>Finished CCS execution after performing #{@stepCount} steps in #{elapsedMS/1000} seconds (#{perStep}ms per step).<\/i> \n-------------------------------------------------------------------------------------------")