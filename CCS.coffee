
# - Constants
CCSInternalChannel = "\u03c4"	# tau
CCSExitChannel = "\u03b4"		# rho	
CCSUIChannel = "\u03c8"			# psi	
ObjID = 1
_DEBUG = []


# - CCS
class CCS
	constructor: (@processDefinitions, @system) ->
		@system.setCCS @
		pd.setCCS @ for pd in @processDefinitions
	
	getProcessDefinition: (name, argCount) -> 
		result = null
		(result = pd if pd.name == name and argCount == pd.getArgCount()) for pd in @processDefinitions
		return result
	getPossibleSteps: (env) -> @system.getPossibleSteps(env)
	
	toString: -> "#{ (process.toString() for process in @processDefinitions).join("") }\n#{ @system.toString() }";


# - ProcessDefinition
class ProcessDefinition
	constructor: (@name, @process, @params) ->					# string x Process x string*
	
	getArgCount: -> if @params then @params.length else 0
	setCCS: (ccs) -> @process.setCCS ccs
	
	toString: -> 
		result = @name
		result += "[#{@params.join ", "}]" if @params?
		result +=" := #{@process.toString()}\n"
		return result;


# - Process (abstract class)
class Process
	constructor: (@subprocesses...) ->								# Process*
		@__id = ObjID++
		
	setCCS: (@ccs) -> p.setCCS(@ccs) for p in @subprocesses
	_setCCS: (@ccs) -> throw "no ccs" if !@ccs; @
	
	replaceIdentifierWithValue: (identifier, value) -> 
		p.replaceIdentifierWithValue(identifier, value) for p in @subprocesses
	getApplicapleRules: -> []
	getPossibleSteps: () -> (rule.getPossibleSteps(this) for rule in @getApplicapleRules()).concatChildren()
		
	needsBracketsForSubprocess: (process) -> 
		@getPrecedence? and process.getPrecedence? and process.getPrecedence() < @getPrecedence()
	stringForSubprocess: (process) ->
		if @needsBracketsForSubprocess process
			"(#{process.toString()})"
		else
			"#{process.toString()}"
	getPrefixes: -> (p.getPrefixes() for p in @subprocesses).concatChildren()
	
	

# - Stop
class Stop extends Process
	getPrecedence: -> 12
	toString: -> "0"
	copy: -> (new Stop())._setCCS(@ccs)
	

# - Exit
class Exit extends Process
	getPrecedence: -> 12
	getApplicapleRules: -> [ExitRule]
	toString: -> "1"
	copy: -> (new Exit())._setCCS(@ccs)
	
	
	
# - ProcessApplication
class ProcessApplication extends Process
	constructor: (@processName, @valuesToPass=[]) -> super()		# string x Expression list
	
	getArgCount: -> @valuesToPass.length
	getProcess: -> 
		return @process if @process
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		@process = pd.process.copy()
		((
			id = pd.params[i]
			val = @valuesToPass[i].evaluate()
			@process.replaceIdentifierWithValue(id, val)
		) for i in [0..pd.params.length-1] ) if pd.params
		@process
	getPrecedence: -> 12
	getApplicapleRules: -> [RecRule]
	getPrefixes : -> @getProcess().getPrefixes()
	replaceIdentifierWithValue: (identifier, value) -> 
		e.replaceIdentifierWithValue(identifier, value) for e in @valuesToPass
	###getProxy: -> 	# ToDo: cache result
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		new ProcessApplicationProxy(@, pd.process.copy())###
	
	toString: -> 
		result = @processName
		result += "[#{(e.toString() for e in @valuesToPass).join ", "}]" if @getArgCount()>0
		return result
	copy: -> (new ProcessApplication(@processName, v.copy() for v in @valuesToPass))._setCCS(@ccs)



### - ProcessApplicationProxy			
# (Required to support moving back and forth between process name and definition in step view)
class ProcessApplicationProxy extends Process
	constructor: (@processApplication, @subprocess) -> super @subprocess
	
	getPrecedence: -> @subprocess.getPrecedence()
	getApplicapleRules: -> [ProxyForwardRule, CollapseRule]
	
	toString: -> @subprocess.toString()
	copy: -> (new ProcessApplicationProxy(@processApplication, @subprocess))._setCCS(@ccs)
	###

# - Prefix
class Prefix extends Process
	constructor: (@action, @process) -> super @process		# Action x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [PrefixRule, OutputRule, InputRule, MatchRule]
	
	replaceIdentifierWithValue: (identifier, value) ->
		super identifier, value if @action.replaceIdentifierWithValue(identifier, value) 
	getPrefixes: -> return [@]
	
	toString: -> "#{@action}.#{@stringForSubprocess @process}"
	copy: -> (new Prefix(@action.copy(), @process.copy()))._setCCS(@ccs)


# - Condition
class Condition extends Process
	constructor: (@expression, @process) -> super @process		# Expression x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [CondRule]
	
	toString: -> "when (#{@expression.toString()}) #{@stringForSubprocess @process}"
	copy: -> (new Condition(@expression.copy(), @process.copy()))._setCCS(@ccs)


# - Choice
class Choice extends Process
	constructor: (@left, @right) -> super @left, @right		# Process x Process
	
	getPrecedence: -> 9
	getApplicapleRules: -> [ChoiceLRule, ChoiceRRule]
	
	toString: -> "#{@stringForSubprocess @left} + #{@stringForSubprocess @right}"
	copy: -> (new Choice(@left.copy(), @right.copy()))._setCCS(@ccs)


# - Parallel
class Parallel extends Process
	constructor: (@left, @right) -> super @left, @right		# Process x Process
	
	getPrecedence: -> 6
	getApplicapleRules: -> [ParLRule, ParRRule, SyncRule, SyncExitRule]
	
	toString: -> "#{@stringForSubprocess @left} | #{@stringForSubprocess @right}"
	copy: -> (new Parallel(@left.copy(), @right.copy()))._setCCS(@ccs)


# - Sequence
class Sequence extends Process
	constructor: (@left, @right) -> super @left, @right		# Process x Process
	
	getPrecedence: -> 3
	getApplicapleRules: -> [Seq1Rule, Seq2Rule]
	
	toString: -> "#{@stringForSubprocess @left} ; #{@stringForSubprocess @right}"
	copy: -> (new Sequence(@left.copy(), @right.copy()))._setCCS(@ccs)


# - Restriction		
class Restriction extends Process
	constructor: (@process, @restrictedActions) -> super @process	# Process x SimpleAction
	
	getPrecedence: -> 1
	getApplicapleRules: -> [ResRule]
	
	toString: -> "#{@stringForSubprocess @process} \\ {#{(a.toString() for a in @restrictedActions).join ", "}}"
	copy: -> (new Restriction(@process.copy(), @restrictedActions))._setCCS(@ccs)
	


	

# --------------------

# -- Action (abstract class)
class Action
	constructor: (@channel) ->		# string
		if @channel == "i"
			if !@isSimpleAction() then throw "Internal channel i is only allowed as simple action!"
			@channel = CCSInternalChannel
		else if @channel == "e"
			if !@isSimpleAction() then throw "Exit channel e is only allowed as simple action!"
			@channel = CCSExitChannel
	
	isSimpleAction: -> false
	isInputAction: -> false
	isMatchAction: -> false
	isOutputAction: ->false
	
	toString: -> @channel
	isSyncableWithAction: (action) -> false
	replaceIdentifierWithValue: (identifier, value) -> true		# returns true if prefix should continue replacing the variable in its subprocess


# - Simple Action
class SimpleAction extends Action
	isSimpleAction: -> true
	copy: -> new SimpleAction(@channel)


# - Input
class Input extends Action
	constructor: (channel, @variable, @range) -> 		# string x string x {int x int) ; range must be copy in!
		super channel
		@incommingValue = null
	
	isInputAction: -> true
	supportsValuePassing: -> typeof @variable == "string" and @variable.length > 0
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel == this.channel and action.supportsValuePassing() == this.supportsValuePassing()
	replaceIdentifierWithValue: (identifier, value) -> @variable != identifier	# stop replacing if identifier is equal to its own variable name
	
	toString: -> "#{super}?#{@variable}"
	copy: -> new Input(@channel, @variable, @range)


# - Match
class Match extends Action
	constructor: (channel, @expression) -> super channel	# string x Expression
	
	isMatchAction: -> true
	supportsValuePassing: -> true
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel == this.channel and action.supportsValuePassing() and action.expression.evaluate() == this.expression.evaluate()
	replaceIdentifierWithValue: (identifier, value) -> 
		@expression.replaceIdentifierWithValue(identifier, value)
		true
	
	toString: -> "#{super}?=#{if @expression then @expression.toString() else ""}"
	copy: -> new Match(@channel, @expression?.copy())
	

# - Output
class Output extends Action
	constructor: (channel, @expression) -> super channel	# string x Expression
	
	isOutputAction: -> true
	supportsValuePassing: -> @expression instanceof Expression
	isSyncableWithAction: (action) -> 
		if action?.isInputAction() or action.isMatchAction()
			action.isSyncableWithAction(this)
		else
			false
	replaceIdentifierWithValue: (identifier, value) -> 
		@expression?.replaceIdentifierWithValue(identifier, value)
		true
			
	toString: -> "#{super}!#{if @expression then @expression.toString() else ""}"
	copy: -> new Output(@channel, (@expression?.copy()))
	

# -- Expression
class Expression
	constructor: (@evaluationCode, @userCode) ->			# javascript x javascript
	
	replaceIdentifierWithValue: (identifier, value) -> 
		@evaluationCode = @evaluationCode.replaceAll('__env("' + identifier + '")', value)
		@userCode = @userCode.replaceAll('__env("' + identifier + '")', value)
		
	evaluateCodeInEnvironment:(code, env) -> `(function(__env,__code){return eval(__code)})(env,code)`
	getExpressionString: -> @evaluateCodeInEnvironment(@userCode, (a)->a)
	evaluate: -> @evaluateCodeInEnvironment(@evaluationCode,((v)->throw 'Unknown identifier "#{v}"'))
	
	toString: -> @getExpressionString()
	copy: -> new Expression(@evaluationCode, @userCode)



	
	
	
ActionSets =
	isActionInK: (action) -> ActionSets.isActionInCom(action) and action.isSimpleAction()
	isActionInCom: (action) -> ActionSets.isActionInAct(action) and action.channel != CCSInternalChannel
	isActionInAct: (action) -> ActionSets.isActionInActPlus(action) and action.channel != CCSExitChannel
	isActionInActPlus: (action) -> !action.supportsValuePassing()
	isActionInComVP: (action) -> ActionSets.isActionInActVP(action) and action.channel != CCSInternalChannel
	isActionInActVP: (action) -> action.channel != CCSExitChannel
	isActionInActVPPlus: (action) -> true	# We don't have more
	
Array::filterKSteps = ->
	filter = (step) -> ActionSets.isActionInK(step.action)
	this.filter(filter)
Array::filterComSteps = ->
	filter = (step) -> ActionSets.isActionInCom(step.action)
	this.filter(filter)
Array::filterActSteps = ->
	filter = (step) -> ActionSets.isActionInAct(step.action)
	this.filter(filter)
Array::filterActPlusSteps = ->
	filter = (step) -> ActionSets.isActionInActPlus(step.action)
	this.filter(filter)
Array::filterComVPSteps = ->
	filter = (step) -> ActionSets.isActionInComVP(step.action)
	this.filter(filter)
Array::filterActVPSteps = ->
	filter = (step) -> ActionSets.isActionInActVP(step.action)
	this.filter(filter)
Array::filterActVPPlusSteps = -> this
	









# Workaround (replace all without reg exp)
`String.prototype.replaceAll = function(needle, replacement) {
	var t = this
	var tt = this
	do {
		t = tt;
		tt = t.replace(needle, replacement);
	} while (t != tt);
	return t;
}

Array.prototype.concatChildren = function() {
	if (this.length == 0)
		return [];
	var result = this.shift().concat([]);	// Result should always be a copy
	while (this.length > 0) {
		result = result.concat(this.shift());
	}
	return result;
}

Array.prototype.joinChildren = function(separator) {
	var result = [];
	var i = 0;
	while(true) {
		var joinTarget = [];
		for (var c = 0; c < this.length; c++) {
			if (this[c][i]) joinTarget.push(this[c][i]);
		}
		if (joinTarget.length == 0)
			break;
		result[i++] = joinTarget.join(separator);
	}
	return result;
}`
	