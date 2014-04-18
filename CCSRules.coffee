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


# - CCSStep
class CCSStep
	constructor: (@index, @process, @action, @rule, @copyOnPerform, @actionDetails, @substeps...) ->	
		(if s == undefined or s == null then throw "substep must not be nil!") for s in @substeps
		if !@actionDetails
			@actionDetails = if @substeps.length == 1 then @substeps[0].actionDetails else ""
	
	getLeafProcesses: ->
		if @substeps.length == 0 then [@process]
		else SBArrayConcatChildren(step.getLeafProcesses() for step in @substeps)
	perform : (info) -> 
		info = {} if not info
		@rule.performStep @, info
	toString: (fullExp) -> @action.toString(!fullExp)
	toDetailedString: (fullExp) -> @toString(fullExp) + (if @actionDetails.length>0 then " (#{@actionDetails})" else "")
	
	_getMutableProcess: -> if @copyOnPerform then @process.copy() else @process


# - CCSBaseStep  -> Der Ur-Schritt :D, also das was prefix, input, output oder match liefert
class CCSBaseStep extends CCSStep		
	constructor: (prefix, rule, copyOnPerform) -> super 0, prefix, prefix.action, rule, copyOnPerform

class CCSInputStep extends CCSStep
	constructor: (inputStep, @value) -> super 0, null, inputStep.action, null, inputStep.copyOnPerform, null, inputStep
	perform: (info) ->
		info = {} if not info
		info["inputValue"] = @value
		@substeps[0].perform info
	toString: (fullExp) -> @action.toString(!fullExp, @value)


CCSExpandInput = (stepList) ->
	res = []
	for step in stepList
		if step.action.isInputAction() and step.action.supportsValuePassing() and not (step instanceof CCSInputStep)
			throw new Error("Unrestricted input action!") if not step.action.range
			for v in step.action.range.possibleValues()
				res.push(new CCSInputStep(step, v))
		else
			res.push(step)
	res
	

###
class CCSInputStep extends CCSBaseStep
	performWithInputValue: (inputValue) -> @rule.performStep(this, inputValue)
	perform: -> throw new Error("perform is not supported on input steps! Use performWithInputValue with an input value as argument instead!")

CCSBaseStep::performWithInputValue = -> throw new Error("performWithInputValue is only allowed for input steps!");
CCSStep::performWithInputValue = (inputValue) ->
	throw new Error("Forwarding of performWithInputValue only supported for linear step tree!") if @substeps.length != 1
	@substeps[0].performWithInputValue inputValue
	###


# - PrefixRule
CCSPrefixRule =
	getPossibleSteps: (prefix, copyOnPerform) -> 
		if prefix?.action.isSimpleAction() or !prefix.action.supportsValuePassing() 
		then [(new CCSBaseStep(prefix, @, copyOnPerform))] 
		else []
	performStep: (step, info) -> step.process.getProcess()

# - OutputRule
CCSOutputRule = 
	getPossibleSteps: (prefix, copyOnPerform) -> # ToDo: Check if evaluatable!
		if prefix?.action.isOutputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @, copyOnPerform)]
		else []
	performStep: (step, info) -> step.process.getProcess()

# - InputRule
CCSInputRule = 
	getPossibleSteps: (prefix, copyOnPerform) ->
		if prefix?.action.isInputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @, copyOnPerform)]
		else []
	performStep: (step, info) ->
		if not info["inputValue"] #step.process.action.incommingValue == undefined
			throw new Error("Input value was not set!")
		result = step._getMutableProcess().getProcess()
		result.replaceVariableWithValue(step.process.action.variable, info["inputValue"])
		result

# - MatchRule
CCSMatchRule = 
	getPossibleSteps: (prefix, copyOnPerform) -> # ToDo: Check if evaluatable!
		if prefix?.action.isMatchAction() then [new CCSBaseStep(prefix, @, copyOnPerform)] else []
	performStep: (step, info) -> step.process.getProcess()


# - ChoiceLRule
CCSChoiceLRule = 
	getPossibleSteps: (choice, copyOnPerform) -> 
		i = 0
		new CCSStep(i++, choice, step.action, @, copyOnPerform, null, step) for step in choice.getLeft()._getPossibleSteps(copyOnPerform).filterActVPPlusSteps()
	performStep: (step, info) -> step.substeps[0].perform(info)

# - ChoiceRRule
CCSChoiceRRule = 
	getPossibleSteps: (choice, copyOnPerform) ->
		i = 0
		new CCSStep(i++, choice, step.action, @, copyOnPerform, null, step) for step in choice.getRight()._getPossibleSteps(copyOnPerform).filterActVPPlusSteps()
	performStep: (step, info) -> step.substeps[0].perform(info)


# - ParLRule
# ToDo: Caching does not consider copyOnPerform
CCSParLRule = 
	getPossibleSteps: (parallel, copyOnPerform) ->
		if not parallel._CCSParLRule
			i = 0
			parallel._CCSParLRule = (new CCSStep(i++, parallel, step.action, @, copyOnPerform, null, step) for step in parallel.getLeft()._getPossibleSteps(copyOnPerform).filterActVPSteps())
		parallel._CCSParLRule
	performStep: (step, info) -> 
		res = step._getMutableProcess()
		res._CCSSyncRule = undefined
		res._CCSParRRule = undefined
		res._CCSParLRule = undefined
		res.setLeft(step.substeps[0].perform(info))
		res

# - ParRRule
CCSParRRule = 
	getPossibleSteps: (parallel, copyOnPerform) ->
		if not parallel._CCSParRRule
			i = 0
			parallel._CCSParRRule = (new CCSStep(i++, parallel, step.action, @, copyOnPerform, null, step) for step in parallel.getRight()._getPossibleSteps(copyOnPerform).filterActVPSteps())
		parallel._CCSParRRule
	performStep: (step, info) -> 
		res = step._getMutableProcess()
		res._CCSSyncRule = undefined
		res._CCSParRRule = undefined
		res._CCSParLRule = undefined
		res.setRight(step.substeps[0].perform(info))
		res

# - SyncRule
CCSSyncRule =
	filterStepsSyncableWithStep: (step, steps) ->
		result = []
		(if s.action.isSyncableWithAction(step.action) then result.push(s)) for s in steps
		return result

	getPossibleSteps: (parallel, copyOnPerform) ->
		if not parallel._CCSSyncRule
			left = parallel.getLeft()._getPossibleSteps(copyOnPerform)
			right = parallel.getRight()._getPossibleSteps(copyOnPerform)
			result = []
			c = 0
			(
				_right = CCSSyncRule.filterStepsSyncableWithStep(l, right)
				(result.push(new CCSStep(c++, parallel, new CCSInternalActionCreate(CCSInternalChannel), @, copyOnPerform, "#{if l.action.isOutputAction() then l.action.transferDescription() else r.action.transferDescription()}", l, r))) for r in _right
			) for l in left
			parallel._CCSSyncRule = result
		parallel._CCSSyncRule
	performStep: (step, info) -> 
		res = step._getMutableProcess()
		res._CCSSyncRule = undefined
		res._CCSParRRule = undefined
		res._CCSParLRule = undefined
		inp = null
		out = null
		left = null
		right = null
		prefix = step.substeps[0].getLeafProcesses()[0]		# This method is also called by ExitSync, so "prefix" might also be an exit process
		if prefix.action and prefix.action.supportsValuePassing()
			if prefix.action.isInputAction()
				inp = prefix
				out = step.substeps[1].getLeafProcesses()[0]
				info["inputValue"] = out.action.expression.evaluate()
				left = step.substeps[0].perform(info)
				right = step.substeps[1].perform(info)
			else
				out = prefix
				inp = step.substeps[1].getLeafProcesses()[0]
				info["inputValue"] = out.action.expression.evaluate()
				left = step.substeps[0].perform(info)
				right = step.substeps[1].perform(info)
			#inp.action.incommingValue = out.action.expression.evaluate()
		else
			left = step.substeps[0].perform(info)
			right = step.substeps[1].perform(info)
		res.setLeft(left)
		res.setRight(right)
		res


# - ResRule
CCSResRule =
	shouldRestrictChannel: (chan, restr) ->
		return false if chan == CCSInternalChannel or chan == CCSExitChannel
		return false if restr.length == 0
		if restr[0] == "*" then restr.indexOf(chan) == -1 else restr.indexOf(chan) != -1
	getPossibleSteps: (restriction, copyOnPerform) ->
		steps = restriction.getProcess()._getPossibleSteps(copyOnPerform).filterActVPPlusSteps()
		result = []
		c = 0
		(result.push(new CCSStep(c++, restriction, step.action, @, copyOnPerform, null, step)) if  !@shouldRestrictChannel(step.action.channel.name, restriction.restrictedChannels)) for step in steps
		return result
	performStep: (step, info) -> 
		res = step._getMutableProcess()
		res.setProcess(step.substeps[0].perform(info))
		res


# - CondRule
CCSCondRule =
	getPossibleSteps: (condition, copyOnPerform) ->
		debugger if CCSCondRule.DEBUGGER
		if condition.expression.evaluate() == "1"
		then condition.getProcess()._getPossibleSteps(copyOnPerform).filterActVPPlusSteps() 
		else []
	performStep: (step, info) -> step.substeps[0].perform(info)


# - ExitRule
CCSExitRule = 
	getPossibleSteps: (exit, copyOnPerform) -> [new CCSStep(0, exit, new CCSInternalActionCreate(CCSExitChannel), @, copyOnPerform)]
	performStep: (step, info) -> new CCSStop()


# - SyncExitRule
CCSSyncExitRule =
	getPossibleSteps: (parallel, copyOnPerform) ->
		filter = (step) -> step.action.channel.name == CCSExitChannel
		left = parallel.getLeft()._getPossibleSteps(copyOnPerform).filter(filter)
		right = parallel.getRight()._getPossibleSteps(copyOnPerform).filter(filter)
		c = 0
		result = []
		(
			#(result.push(new CCSStep(c++, parallel, CCSInternalActionCreate(CCSExitChannel), @, copyOnPerform, "#{if l.action.isOutputAction() then l.action.transferDescription() else r.action.transferDescription()}", l, r))) for r in right
			(result.push(new CCSStep(c++, parallel, CCSInternalActionCreate(CCSExitChannel), @, copyOnPerform, null, l, r))) for r in right
		) for l in left
		return result
	performStep: (step, info) -> CCSSyncRule.performStep step, info


# - Seq1Rule
CCSSeq1Rule = 
	getPossibleSteps: (sequence, copyOnPerform) -> 
		c = 0
		(new CCSStep(c++, sequence, step.action, @, copyOnPerform, null, step)) for step in sequence.getLeft()._getPossibleSteps(copyOnPerform).filterActVPSteps()
	performStep: (step, info) -> 
		res = step._getMutableProcess()
		res.setLeft(step.substeps[0].perform(info))
		res


# - Seq2Rule
CCSSeq2Rule =
	getPossibleSteps: (sequence, copyOnPerform) ->
		filter = (step) -> step.action.channel.name == CCSExitChannel
		rhos = sequence.getLeft()._getPossibleSteps(copyOnPerform).filter(filter)
		result = []
		c = 0
		(result.push(new CCSStep(c++, sequence, new CCSInternalActionCreate(CCSInternalChannel), @, copyOnPerform, "#{CCSExitChannel}", rho))) for rho in rhos
		return result
	performStep: (step, info) -> step.process.getRight()


# - RecRule
CCSRecRule = 
	getPossibleSteps: (application, copyOnPerform) ->
		steps = application.getProcess()._getPossibleSteps(copyOnPerform)
		c = 0 
		new CCSStep(c++, application, step.action, @, copyOnPerform, null, step) for step in steps
	performStep: (step, info) -> 
		step.substeps[0].perform(info)















