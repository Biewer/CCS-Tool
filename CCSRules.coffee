
# - CCSStep
class CCSStep
	constructor: (@index, @process, @action, @rule, @actionDetails, @substeps...) ->		# int x Action
		(if s == undefined or s == null then throw "substep must not be nil!") for s in @substeps
		if !@actionDetails
			@actionDetails = if @substeps.length == 1 then @substeps[0].actionDetails else ""
	
	getLeaveProcesses: ->
		if @substeps.length == 0 then [@process]
		else (step.getLeaveProcesses() for step in @substeps).concatChildren()
	perform : -> @rule.performStep @
	toString: -> @action.toString() + (if @actionDetails.length>0 then " #{@actionDetails}" else "")


# - CCSBaseStep  -> Der Ur-Schritt :D, also das was prefix, input, output, match oder exit liefert
class CCSBaseStep extends CCSStep		
	constructor: (prefix, rule) -> super 0, prefix, prefix.action, rule
	


# - PrefixRule
PrefixRule =
	getPossibleSteps: (prefix) -> 
		if prefix?.action.isSimpleAction() or !prefix.action.supportsValuePassing() 
		then [(new CCSBaseStep(prefix, @))] 
		else []
	performStep: (step) -> step.process.process

# - OutputRule
OutputRule = 
	getPossibleSteps: (prefix) -> # ToDo: Check if evaluatable!
		if prefix?.action.isOutputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @)]
		else []
	performStep: (step) -> step.process.process

# - InputRule
InputRule = 
	getPossibleSteps: (prefix) ->
		if prefix?.action.isInputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @)]
		else []
	performStep: (step) ->
		throw new Error("Not implemented")
		step.process.process

# - MatchRule
MatchRule = 
	getPossibleSteps: (prefix) -> # ToDo: Check if evaluatable!
		if prefix?.action.isMatchAction() then [new CCSBaseStep(prefix, @)] else []
	performStep: (step) -> step.process.process


# - ChoiceLRule
ChoiceLRule = 
	getPossibleSteps: (choice) -> 
		i = 0
		new CCSStep(i++, choice, step.action, @, null, step) for step in choice.left.getPossibleSteps().filterActVPPlusSteps()
	performStep: (step) -> step.substeps[0].perform()

# - ChoiceRRule
ChoiceRRule = 
	getPossibleSteps: (choice) ->
		i = 0
		new CCSStep(i++, choice, step.action, @, null, step) for step in choice.right.getPossibleSteps().filterActVPPlusSteps()
	performStep: (step) -> step.substeps[0].perform()


# - ParLRule
ParLRule = 
	getPossibleSteps: (parallel) ->
		i = 0
		new CCSStep(i++, parallel, step.action, @, null, step) for step in parallel.left.getPossibleSteps().filterActVPSteps()
	performStep: (step) -> 
		step.process.left = step.substeps[0].perform()
		step.process

# - ParRRule
ParRRule = 
	getPossibleSteps: (parallel) ->
		i = 0
		new CCSStep(i++, parallel, step.action, @, null, step) for step in parallel.right.getPossibleSteps().filterActVPSteps()
	performStep: (step) -> 
		step.process.right = step.substeps[0].perform()
		step.process

# - SyncRule
SyncRule =
	filterStepsSyncableWithStep: (step, steps) ->
		result = []
		(if s.action.isSyncableWithAction(step.action) then result.push(s)) for s in steps
		return result

	getPossibleSteps: (parallel) ->
		left = parallel.left.getPossibleSteps()
		right = parallel.right.getPossibleSteps()
		result = []
		c = 0
		(
			_right = SyncRule.filterStepsSyncableWithStep(l, right)
			(result.push(new CCSStep(c++, parallel, new SimpleAction(CCSInternalChannel), @, "[#{l.toString()}, #{r.toString()}]", l, r))) for r in _right
		) for l in left
		return result
	performStep: (step) -> 
		step.process.left = step.substeps[0].perform()
		step.process.right = step.substeps[1].perform()
		step.process


# - ResRule
ResRule =
	getPossibleSteps: (restriction) ->
		steps = restriction.process.getPossibleSteps().filterActVPPlusSteps()
		result = []
		c = 0
		restr = (a.channel for a in restriction.restrictedActions) 
		(result.push(new CCSStep(c++, restriction, step.action, @, null, step)) if restr.indexOf(step.action.channel) == -1) for step in steps
		return result
	performStep: (step) -> 
		step.process.process = step.substeps[0].perform()
		step.process


# - CondRule
CondRule =
	getPossibleSteps: (condition) ->
		if condition.expression.evaluate() 
		then condition.process.getPossibleSteps().filterActVPPlusSteps() 
		else []
	performStep: (step) -> step.substeps[0].perform()


# - ExitRule
ExitRule = 
	getPossibleSteps: (exit) -> [new CCSStep(0, exit, new SimpleAction(CCSExitChannel), @)]
	performStep: (step) -> new Stop()


# - SyncExitRule
SyncExitRule =
	getPossibleSteps: (parallel) ->
		filter = (step) -> step.action.channel == CCSExitChannel
		left = parallel.left.getPossibleSteps().filter(filter)
		right = parallel.right.getPossibleSteps().filter(filter)
		c = 0
		result = []
		(
			(result.push(new CCSStep(c++, parallel, new SimpleAction(CCSExitChannel), @, "[#{l.toString()}, #{r.toString()}]", l, r))) for r in right
		) for l in left
		return result
	performStep: (step) -> SyncRule.performStep step


# - Seq1Rule
Seq1Rule = 
	getPossibleSteps: (sequence) -> 
		c = 0
		(new CCSStep(c++, sequence, step.action, @, null, step)) for step in sequence.left.getPossibleSteps().filterActVPSteps()
	performStep: (step) -> step.process.left = step.substeps[0].perform()


# - Seq2Rule
Seq2Rule =
	getPossibleSteps: (sequence) ->
		filter = (step) -> step.action.channel == CCSExitChannel
		rhos = sequence.left.getPossibleSteps().filter(filter)
		result = []
		c = 0
		(result.push(new CCSStep(c++, sequence, new SimpleAction(CCSInternalChannel), @, "[#{CCSExitChannel}]", rho))) for rho in rhos
		return result
	performStep: (step) -> step.process.right


# - RecRule
RecRule = 
	getPossibleSteps: (application) ->
		




###
# - ExtendRule
ExtendRule = 
	getPossibleSteps: (application) ->
		pd = application.ccs.getProcessDefinition(application.processName, application.getArgCount())
		if pd 
		then [new CCSStep(0, application, new SimpleAction(CCSUIChannel), @, "[#{application.processName}]")]
		else []
	performStep: (step) ->
		pd = step.process.ccs.getProcessDefinition(step.process.processName, step.process.getArgCount())
		p = step.process.getProxy()
		((
			id = pd.params[i]
			val = step.process.valuesToPass[i].evaluate()
			p.replaceIdentifierWithValue(id, val)
		) for i in [0..pd.params.length-1] ) if pd.params
		return p


# - CollapseRule
CollapseRule = 
	getPossibleSteps: (proxy) ->
		[new CCSStep(0, proxy, new SimpleAction(CCSUIChannel), @, "[\u21aa #{proxy.processApplication.processName}]")]
	performStep: (step) -> step.process.processApplication


# - ProxyForwardRule
ProxyForwardRule =
	getPossibleSteps: (proxy) ->
		steps = proxy.subprocess.getPossibleSteps().filterActVPPlusSteps()
		c = 0 
		new CCSStep(c++, proxy, step.action, @, null, step) for step in steps
	performStep: (step) -> 
		step.substeps[0].perform()
		
###












