
class CCSStep
	constructor: (@index, @process, @action, @rule, @actionDetails, @substeps...) ->		# int x Action
		(if s == undefined or s == null then throw "substep must not be nil!") for s in @substeps
		if !@actionDetails
			@actionDetails = if @substeps.length == 1 then @substeps[0].actionDetails else ""
	
	getPrefixes: -> (step.getPrefixes() for step in @substeps).concatChildren()
	toString: -> @action.toString() + (if @actionDetails.length>0 then " #{@actionDetails}" else "")


# Der Ur-Schritt :D, also das was prefix, input, output, match oder exit liefert
class CCSBaseStep extends CCSStep		
	constructor: (prefix, rule) -> super 0, prefix, prefix.action, rule

	getPrefixes: -> [@process]
	


PrefixRule =
	getPossibleSteps: (prefix, env) -> 
		if prefix?.action.isSimpleAction() or !prefix.action.supportsValuePassing() 
		then [(new CCSBaseStep(prefix, @))] 
		else []
	performStep: (step, env) -> step.process.process

OutputRule = 
	getPossibleSteps: (prefix, env) -> # ToDo: Check if evaluatable!
		if prefix?.action.isOutputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @)]
		else []
	performStep: (step, env) -> step.process.process

InputRule = 
	getPossibleSteps: (prefix, env) ->
		if prefix?.action.isInputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @)]
		else []
	performStep: (step, env) ->
		if !step.inputValue
			throw "Input steps require "
		env.setValueForIdentifier(prefix.variable, step.inputValue)
		step.process.process

MatchRule = 
	getPossibleSteps: (prefix, env) -> # ToDo: Check if evaluatable!
		if prefix?.action.isMatchAction() then [new CCSBaseStep(prefix, @)] else []


ChoiceLRule = 
	getPossibleSteps: (choice, env) -> 
		i = 0
		new CCSStep(i++, choice, step.action, @, null, step) for step in choice.left.getPossibleSteps(env).filterActVPPlusSteps()

ChoiceRRule = 
	getPossibleSteps: (choice, env) ->
		i = 0
		new CCSStep(i++, choice, step.action, @, null, step) for step in choice.right.getPossibleSteps(env).filterActVPPlusSteps()

ParLRule = 
	getPossibleSteps: (parallel, env) ->
		i = 0
		new CCSStep(i++, parallel, step.action, @, null, step) for step in parallel.left.getPossibleSteps(env).filterActVPSteps()

ParRRule = 
	getPossibleSteps: (parallel, env) ->
		i = 0
		new CCSStep(i++, parallel, step.action, @, null, step) for step in parallel.right.getPossibleSteps(env).filterActVPSteps()

SyncRule =
	filterStepsSyncableWithStep: (step, steps, env) ->
		result = []
		(if s.action.isSyncableWithAction(step.action, env) then result.push(s)) for s in steps
		return result

	getPossibleSteps: (parallel, env) ->
		left = parallel.left.getPossibleSteps(env)
		right = parallel.right.getPossibleSteps(env)
		result = []
		c = 0
		(
			_right = SyncRule.filterStepsSyncableWithStep(l, right, env)
			(result.push(new CCSStep(c++, parallel, new SimpleAction(CCSInternalChannel), @, "[#{l.toString()}, #{r.toString()}]", l, r))) for r in _right
		) for l in left
		return result

ResRule =
	getPossibleSteps: (restriction, env) ->
		steps = restriction.process.getPossibleSteps(env).filterActVPPlusSteps()
		result = []
		c = 0
		restr = (a.channel for a in restriction.restrictedActions)
		(if restr.indexOf(step.action.channel) == -1 
			then result.push(new CCSStep(c++, restriction, step.action, @, null, step)) for step in steps
		return result

CondRule =
	getPossibleSteps: (condition, env) ->
		if condition.expression.evaluate(env) 
		then condition.process.getPossibleSteps(env).filterActVPPlusSteps() 
		else []

ExitRule = 
	getPossibleSteps: (exit, env) -> [new CCSStep(0, exit, new SimpleAction(CCSExitChannel), @)]

SyncExitRule =
	getPossibleSteps: (parallel, env) ->
		filter = (step) -> step.action.channel == CCSExitChannel
		left = parallel.left.getPossibleSteps(env).filter(filter)
		right = parallel.right.getPossibleSteps(env).filter(filter)
		c = 0
		result = []
		(
			(result.push(new CCSStep(c++, parallel, new SimpleAction(CCSExitChannel), @, "[#{l.toString()}, #{r.toString()}]", l, r))) for r in right
		) for l in left
		return result

Seq1Rule = 
	getPossibleSteps: (sequence, env) -> 
		c = 0
		(new CCSStep(c++, sequence, step.action, @, null, step)) for step in sequence.left.getPossibleSteps(env).filterActVPSteps()

Seq2Rule =
	getPossibleSteps: (sequence, env) ->
		filter = (step) -> step.action.channel == CCSExitChannel
		rhos = sequence.left.getPossibleSteps(env).filter(filter)
		result = []
		c = 0
		(result.push(new CCSStep(c++, sequence, new SimpleAction(CCSInternalChannel), @, "[#{CCSExitChannel}]", rho))) for rho in rhos
		return result
		













