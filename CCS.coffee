
CCSInternalChannel = "\u03c4"	# tau
CCSExitChannel = "\u03b4"		# rho

class Environment
	constructor: (parent) ->
		@env = {}
		if parent
			@env[key] = value for key, value of parent.env
	getValueForIdentifier: (identifier) -> 
		if @env[identifier] then @env[identifier] else throw 'Unbound identifier "' + identifier + '"!'
	setValueForIdentifier: (identifier, value) -> @env[identifier] = value
	

class CCS
	constructor: (@processDefinitions, @system) ->		# System must be an applied (anonymous) process definition
	
	#Properties
	getProcessDefinitionAtIndex: (i) -> @processDefinitions[i]
	getProcessDefinitionCount: -> @processDefinitions.length
	getSystem: -> @system
	getPossibleSteps: (env) -> @system.getPossibleSteps(env)
	
	toString: -> "#{ (process.toString() for name, process of @processDefinitions).join("") }\n#{ @system.toString() }";





class ProcessDefinition
	constructor: (@name, @process, @params) ->					# string x Process x string*
	
	#Properties
	getName: -> @name
	getProcess: ->@process
	
	toString: -> 
		result = @name
		result += "[#{@params.join ", "}]" if @params?
		result +=" := #{@process.toString()}\n"
		return result;


# NOT IN USE
class AppliedProcessDefinition extends Process
	constructor: (@process, @environment, @processApplication, @applicationEnvironment) ->		# Sets up a new environment
	
	getPossibleSteps: -> @process.getPossibleSteps(@environment)
	getApplicapleRules: -> @process.getApplicapleRules()
	toString: -> @process.toString()
# NOT IN USE

class Process
	constructor: (@subprocesses...) ->								# Process*
		
	replaceVariableWithValue: (varName, value) -> 
		p.replaceVariableWithValue(varName, value) for p in @subprocesses
	stringForSubprocess: (process) ->
		if @getPrecedence? and process.getPrecedence? and process.getPrecedence() < @getPrecedence()
			"(#{process.toString()})"
		else
			"#{process.toString()}"
	getApplicapleRules: -> []
	getPossibleSteps: (env) -> (rule.getPossibleSteps(this, env) for rule in @getApplicapleRules()).concatChildren()
	performStep: (step) -> throw "Not implemented!"
			

class Restriction extends Process
	constructor: (@process, @restrictedActions) -> super @process	# Process x SimpleAction
	
	#Properties
	getProcess: -> @process
	getRestrictedActions: -> @restrictedActions
	getPrecedence: -> 1
	getApplicapleRules: -> [ResRule]
	
	toString: -> "#{@stringForSubprocess @process} \\ {#{(a.toString() for a in @restrictedActions).join ", "}}"
	copy: -> new Restriction(@process.copy(), @restrictedActions)

class Sequence extends Process
	constructor: (@left, @right) -> super @left, @right		# Process x Process
	
	#Properties
	getLeft: -> @left
	getRight: -> @right
	getPrecedence: -> 3
	getApplicapleRules: -> [Seq1Rule, Seq2Rule]
	
	toString: -> "#{@stringForSubprocess @left} ; #{@stringForSubprocess @right}"
	copy: -> new Sequence (@left.copy(), @right.copy())
	
	
	
class Parallel extends Process
	constructor: (@left, @right) -> super @left, @right		# Process x Process
	
	#Properties
	getLeft: -> @left
	getRight: -> @right
	getPrecedence: -> 6
	getApplicapleRules: -> [ParLRule, ParRRule, SyncRule, SyncExitRule]
	
	toString: -> "#{@stringForSubprocess @left} | #{@stringForSubprocess @right}"
	copy: -> new Sequence (@left.copy(), @right.copy())
	



class Choice extends Process
	constructor: (@left, @right) -> super @left, @right		# Process x Process
	
	#Properties
	getLeft: -> @left
	getRight: -> @right
	getPrecedence: -> 9
	getApplicapleRules: -> [ChoiceLRule, ChoiceRRule]
	
	toString: -> "#{@stringForSubprocess @left} + #{@stringForSubprocess @right}"
	copy: -> new Sequence (@left.copy(), @right.copy())
	



class Prefix extends Process
	constructor: (@action, @process) -> super @process		# Action x Process
	
	#Properties
	getAction: -> @action
	getProcess: -> @process
	getPrecedence: -> 12
	getApplicapleRules: -> [PrefixRule, OutputRule, InputRule, MatchRule]
	
	toString: -> "#{@action}.#{@stringForSubprocess @process}"
	copy: -> new Prefix (@action.copy(), @process.copy())
	

class Condition extends Process
	constructor: (@expression, @process) -> super @process		# Expression x Process
	
	#Properties
	getExpression: -> @expression
	getProcess: -> @process
	getPrecedence: -> 12
	getApplicapleRules: -> [CondRule]
	
	toString: -> "when (#{@expression()}) #{@stringForSubprocess @process}"
	copy: -> new Condition (@expression.copy(), @process.copy())


class Action
	constructor: (@channel) ->		# string
		if @channel == "i"
			if !@isSimpleAction() then throw "Internal channel i is only allowed as simple action!"
			@channel = CCSInternalChannel
		else if @channel == "e"
			if !@isSimpleAction() then throw "Exit channel e is only allowed as simple action!"
			@channel = CCSExitChannel
	
	#Properties
	getChannel: -> @channel
	isSimpleAction: -> false
	isInputAction: -> false
	isMatchAction: -> false
	isOutputAction: ->false
	
	toString: -> @channel
	isSyncableWithAction: (action) -> false


class SimpleAction extends Action
	isSimpleAction: -> true
	copy: -> new SimpleAction(@channel)


class Input extends Action
	constructor: (channel, @variable, @range) -> super channel		# string x string x {int x int) ; range must be copy in!
	
	#Properties
	getVariable: -> @variable
	isInputAction: -> true
	supportsValuePassing: -> typeof @variable == "string" and @variable.length > 0
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel == this.channel and action.supportsValuePassing() == this.supportsValuePassing()
	
	toString: -> "#{super}?#{@variable}"
	copy: -> new Input(@channel, @variable, @range)


class Match extends Action
	constructor: (channel, @expression) -> super channel	# string x Expression
	
	#Properties
	getExpression: -> @expression
	isMatchAction: -> true
	supportsValuePassing: -> true
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel == this.channel and action.supportsValuePassing() and action.expression.evaluate() == this.expression.evaluate()
	
	toString: -> "#{super}?=#{@expression.toString()}"
	copy: -> new Match(@channel, @expression.copy())
	
	
class Output extends Action
	constructor: (channel, @expression) -> super channel	# string x Expression
	
	#Properties
	getExpression: -> @expression
	isOutputAction: ->true
	supportsValuePassing: -> typeof @expression == "string" and @expression.length > 0
	isSyncableWithAction: (action) -> 
		if action?.isInputAction() or action.isMatchAction()
			action.isSyncableWithAction(this)
		else
			false
			
	toString: -> "#{super}!#{@expression.toString()}"
	copy: -> new Output(@channel, @expression.copy())
	

class Expression
	constructor: (@evaluationCode, @userCode) ->			# javascript x javascript	ToDo: Environment!?
	
	#Properties
	evaluateCodeInEnvironment:(code, env) -> `(function(__env,__code){return eval(__code)})(env,code)`
	getExpressionString: (env) -> @evaluateCodeInEnvironment(@userCode, env)
	
	evaluate: -> @evaluateCodeInEnvironment(@evaluationCode, env)
	
	toString: -> @getExpressionString((a)->a)
	copy: -> new Expression(@evaluationCode, @userCode)


class ProcessApplication extends Process
	constructor: (@process, @valuesToPass=null) ->		# string x Expression list
	
	#Properties
	getProcess: -> @process
	getValuesToPass: -> @valuesToPass
	getPrecedence: -> 12
	
	toString: -> 
		result = @process
		result += "[#{(e.toString() for e in @valuesToPass).join ", "}]" if @valuesToPass
		return result
	copy: -> new ProcessApplication(@process, @valuesToPass)
	
	
class Stop extends Process
	getPrecedence: -> 12
	toString: -> "0"
	copy: -> new Stop()
	
class Exit extends Process
	getPrecedence: -> 12
	toString: -> "1"
	copy: -> new Exit()
	getApplicapleRules: -> [ExitRule]
	
	
	
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
	