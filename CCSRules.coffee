
# - CCSStep
class CCSStep
	constructor: (@index, @process, @action, @rule, @actionDetails, @substeps...) ->		# int x Action
		(if s == undefined or s == null then throw "substep must not be nil!") for s in @substeps
		if !@actionDetails
			@actionDetails = if @substeps.length == 1 then @substeps[0].actionDetails else ""
	
	getLeafProcesses: ->
		if @substeps.length == 0 then [@process]
		else (step.getLeafProcesses() for step in @substeps).concatChildren()
	perform : -> @rule.performStep @
	toString: -> @action.toString() + (if @actionDetails.length>0 then " #{@actionDetails}" else "")


# - CCSBaseStep  -> Der Ur-Schritt :D, also das was prefix, input, output, match oder exit liefert
class CCSBaseStep extends CCSStep		
	constructor: (prefix, rule) -> super 0, prefix, prefix.action, rule
	


# - PrefixRule
CCSPrefixRule =
	getPossibleSteps: (prefix) -> 
		if prefix?.action.isSimpleAction() or !prefix.action.supportsValuePassing() 
		then [(new CCSBaseStep(prefix, @))] 
		else []
	performStep: (step) -> step.process.getProcess()

# - OutputRule
CCSOutputRule = 
	getPossibleSteps: (prefix) -> # ToDo: Check if evaluatable!
		if prefix?.action.isOutputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @)]
		else []
	performStep: (step) -> step.process.getProcess()

# - InputRule
CCSInputRule = 
	getPossibleSteps: (prefix) ->
		if prefix?.action.isInputAction() and prefix.action.supportsValuePassing()
		then [new CCSBaseStep(prefix, @)]
		else []
	performStep: (step) ->
		if step.process.action.incommingValue == undefined
			throw new Error("Input action's incomming value was not set!")
		result = step.process.getProcess()
		result.replaceIdentifierWithValue(step.process.action.variable, step.process.action.incommingValue)
		result

# - MatchRule
CCSMatchRule = 
	getPossibleSteps: (prefix) -> # ToDo: Check if evaluatable!
		if prefix?.action.isMatchAction() then [new CCSBaseStep(prefix, @)] else []
	performStep: (step) -> step.process.getProcess()


# - ChoiceLRule
CCSChoiceLRule = 
	getPossibleSteps: (choice) -> 
		i = 0
		new CCSStep(i++, choice, step.action, @, null, step) for step in choice.getLeft().getPossibleSteps().filterActVPPlusSteps()
	performStep: (step) -> step.substeps[0].perform()

# - ChoiceRRule
CCSChoiceRRule = 
	getPossibleSteps: (choice) ->
		i = 0
		new CCSStep(i++, choice, step.action, @, null, step) for step in choice.getRight().getPossibleSteps().filterActVPPlusSteps()
	performStep: (step) -> step.substeps[0].perform()


# - ParLRule
CCSParLRule = 
	getPossibleSteps: (parallel) ->
		i = 0
		new CCSStep(i++, parallel, step.action, @, null, step) for step in parallel.getLeft().getPossibleSteps().filterActVPSteps()
	performStep: (step) -> 
		step.process.setLeft(step.substeps[0].perform())
		step.process

# - ParRRule
CCSParRRule = 
	getPossibleSteps: (parallel) ->
		i = 0
		new CCSStep(i++, parallel, step.action, @, null, step) for step in parallel.getRight().getPossibleSteps().filterActVPSteps()
	performStep: (step) -> 
		step.process.setRight(step.substeps[0].perform())
		step.process

# - SyncRule
CCSSyncRule =
	filterStepsSyncableWithStep: (step, steps) ->
		result = []
		(if s.action.isSyncableWithAction(step.action) then result.push(s)) for s in steps
		return result

	getPossibleSteps: (parallel) ->
		left = parallel.getLeft().getPossibleSteps()
		right = parallel.getRight().getPossibleSteps()
		result = []
		c = 0
		(
			_right = CCSSyncRule.filterStepsSyncableWithStep(l, right)
			(result.push(new CCSStep(c++, parallel, new CCSInternalActionCreate(CCSInternalChannel), @, "[#{l.toString()}, #{r.toString()}]", l, r))) for r in _right
		) for l in left
		return result
	performStep: (step) -> 
		inp = null
		out = null
		prefix = step.substeps[0].getLeaveProcesses()[0]
		if prefix.action.supportsValuePassing()
			if prefix.action.isInputAction()
				inp = prefix
				out = step.substeps[1].getLeaveProcesses()[0]
			else
				out = prefix
				inp = step.substeps[1].getLeaveProcesses()[0]
			inp.action.incommingValue = out.action.expression.evaluate()
		step.process.setLeft(step.substeps[0].perform())
		step.process.setRight(step.substeps[1].perform())
		step.process


# - ResRule
CCSResRule =
	shouldRestrictChannel: (chan, restr) ->
		return false if chan == CCSInternalChannel or chan == CCSExitChannel
		return false if restr.length == 0
		if restr[0] == "*" then restr.indexOf(chan) == -1 else restr.indexOf(chan) != -1
	getPossibleSteps: (restriction) ->
		steps = restriction.getProcess().getPossibleSteps().filterActVPPlusSteps()
		result = []
		c = 0
		(result.push(new CCSStep(c++, restriction, step.action, @, null, step)) if  !@shouldRestrictChannel(step.action.channel.name, restriction.restrictedChannels)) for step in steps
		return result
	performStep: (step) -> 
		step.process.setProcess(step.substeps[0].perform())
		step.process


# - CondRule
CCSCondRule =
	getPossibleSteps: (condition) ->
		if condition.expression.evaluate() 
		then condition.process.getPossibleSteps().filterActVPPlusSteps() 
		else []
	performStep: (step) -> step.substeps[0].perform()


# - ExitRule
CCSExitRule = 
	getPossibleSteps: (exit) -> [new CCSStep(0, exit, new CCSInternalActionCreate(CCSExitChannel), @)]
	performStep: (step) -> new Stop()


# - SyncExitRule
CCSSyncExitRule =
	getPossibleSteps: (parallel) ->
		filter = (step) -> step.action.channel.name == CCSExitChannel
		left = parallel.getLeft().getPossibleSteps().filter(filter)
		right = parallel.getRight().getPossibleSteps().filter(filter)
		c = 0
		result = []
		(
			(result.push(new CCSStep(c++, parallel, CCSInternalActionCreate(CCSExitChannel), @, "[#{l.toString()}, #{r.toString()}]", l, r))) for r in right
		) for l in left
		return result
	performStep: (step) -> SyncRule.performStep step


# - Seq1Rule
CCSSeq1Rule = 
	getPossibleSteps: (sequence) -> 
		c = 0
		(new CCSStep(c++, sequence, step.action, @, null, step)) for step in sequence.getLeft().getPossibleSteps().filterActVPSteps()
	performStep: (step) -> 
		step.process.setLeft(step.substeps[0].perform())
		step.process


# - Seq2Rule
CCSSeq2Rule =
	getPossibleSteps: (sequence) ->
		filter = (step) -> step.action.channel.name == CCSExitChannel
		rhos = sequence.getLeft().getPossibleSteps().filter(filter)
		result = []
		c = 0
		(result.push(new CCSStep(c++, sequence, new CCSInternalActionCreate(CCSInternalChannel), @, "[#{CCSExitChannel}]", rho))) for rho in rhos
		return result
	performStep: (step) -> step.process.getRight()


# - RecRule
CCSRecRule = 
	getPossibleSteps: (application) ->
		steps = application.getProcess().getPossibleSteps()
		c = 0 
		new CCSStep(c++, application, step.action, @, null, step) for step in steps
	performStep: (step) -> 
		step.substeps[0].perform()















