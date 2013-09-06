
# - Constants
CCSInternalChannel = "\u03c4"	# tau
CCSExitChannel = "\u03b4"		# rho	
CCSUIChannel = "\u03c8"			# psi	
ObjID = 1
_DEBUG = []

CCSTypeUnknown = 0
CCSTypeChannel = 1
CCSTypeValue = 2
CCSGetMostGeneralType = (t1, t2) ->
	return t1 if t2 == CCSTypeUnknown
	return t2 if t1 == CCSTypeUnknown
	return t1 if t1 == t2
	throw new Error("Incopatible Types: #{t1} and #{t2}!");


# - CCS
class CCS
	constructor: (@processDefinitions, @system) ->
		@system.setCCS @
		(pd.setCCS @; pd.getArgTypes()) for pd in @processDefinitions
	
	getProcessDefinition: (name, argCount) -> 
		result = null
		(result = pd if pd.name == name and argCount == pd.getArgCount()) for pd in @processDefinitions
		return result
	getPossibleSteps: (env) -> @system.getPossibleSteps(env)
	
	toString: -> "#{ (process.toString() for process in @processDefinitions).join("") }\n#{ @system.toString() }";


# - ProcessDefinition
class ProcessDefinition
	constructor: (@name, @process, @params) ->					# string x Process x string*
		(@types = (CCSTypeUnknown for p in @params)) if @params	# init with default value
	
	getArgCount: -> if @params then @params.length else 0
	setCCS: (ccs) -> @process.setCCS ccs
	getArgTypes: ->
		return null if !@params
		@types = ((								# ToDo: Repeat until types won't change anymore
			@process.getTypeOfIdentifier x, CCSTypeUnknown
		) for x in @params)
	
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
	getLeft: -> @subprocesses[0]
	getRight: -> @subprocesses[1]
	setLeft: (left) -> @subprocesses[0] = left
	setRight: (right) -> @subprocesses[1] = right
	
	replaceIdentifierWithValue: (identifier, value) -> 
		p.replaceIdentifierWithValue(identifier, value) for p in @subprocesses
	replaceIdentifier: (old, newID) ->
		p.replaceIdentifier(old, newID) for p in @subprocesses
	getTypeOfIdentifier: (identifier, type) ->
		(
			type = CCSGetMostGeneralType(type, t)
		) for t in (p.getTypeOfIdentifier(identifier, type) for p in @subprocesses)
		type
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
	getExits: -> (p.getExits() for p in @subprocesses).concatChildren()

	

# - Stop
class Stop extends Process
	getPrecedence: -> 12
	toString: -> "0"
	copy: -> (new Stop())._setCCS(@ccs)
	

# - Exit
class Exit extends Process
	getPrecedence: -> 12
	getApplicapleRules: -> [ExitRule]
	getExits: -> [@]
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
			if pd.types[i] == CCSTypeChannel
				@process.replaceIdentifier(id, @valuesToPass[i].variableName)
			else
				@process.replaceIdentifierWithValue(id, @valuesToPass[i].evaluate())			
		) for i in [0..pd.params.length-1] ) if pd.params
		@process
	getPrecedence: -> 12
	getTypeOfIdentifier: (identifier, type) ->
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		((
			type = CCSGetMostGeneralType(type, @valuesToPass[i].getType(identifier))
			type = CCSGetMostGeneralType(type, pd.types[i])
		) for i in [0..pd.params.length-1] ) if pd.params
		type
	getApplicapleRules: -> [RecRule]
	getPrefixes : -> @getProcess().getPrefixes() #if @process then @process.getPrefixes() else []
	getExits: -> if @process then @process.getExits() else []
	replaceIdentifierWithValue: (identifier, value) -> 
		@valuesToPass = (e.replaceIdentifierWithValue(identifier, value) for e in @valuesToPass)
	replaceIdentifier: (old, newID) -> 
		e.replaceIdentifier(old, newID) for e in @valuesToPass
	###getProxy: -> 	# ToDo: cache result
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		new ProcessApplicationProxy(@, pd.process.copy())###
	
	toString: -> 
		result = @processName
		result += "[#{(e.toString() for e in @valuesToPass).join ", "}]" if @getArgCount()>0
		return result
	copy: -> (new ProcessApplication(@processName, v.copy() for v in @valuesToPass))._setCCS(@ccs)



# - Prefix
class Prefix extends Process
	constructor: (@action, process) -> super process		# Action x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [PrefixRule, OutputRule, InputRule]
	getProcess: -> @subprocesses[0]
	
	replaceIdentifierWithValue: (identifier, value) ->
		@action.replaceIdentifierWithValue(identifier, value)
		super identifier, value if @action.replaceIdentifierWithValue(identifier, value)
	replaceIdentifier: (old, newID) ->
		@action.replaceIdentifier(old, newID)
		super old, newID if @action.replaceIdentifier(old, newID)
	getPrefixes: -> return [@]
	getTypeOfIdentifier: (identifier, type) ->
		type = CCSGetMostGeneralType(type, @action.getTypeOfIdentifier(identifier, type))
		return type if @action.isInputAction() and @action.variable == "identifier"
		super identifier, type
	toString: -> "#{@action.toString()}.#{@stringForSubprocess @getProcess()}"
	copy: -> (new Prefix(@action.copy(), @getProcess().copy()))._setCCS(@ccs)


# - Condition
class Condition extends Process
	constructor: (@expression, @process) -> super @process		# Expression x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [CondRule]
	
	toString: -> "when (#{@expression.toString()}) #{@stringForSubprocess @process}"
	copy: -> (new Condition(@expression.copy(), @process.copy()))._setCCS(@ccs)


# - Choice
class Choice extends Process
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 9
	getApplicapleRules: -> [ChoiceLRule, ChoiceRRule]
	
	toString: -> "#{@stringForSubprocess @getLeft()} + #{@stringForSubprocess @getRight()}"
	copy: -> (new Choice(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Parallel
class Parallel extends Process
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 6
	getApplicapleRules: -> [ParLRule, ParRRule, SyncRule, SyncExitRule]
	
	toString: -> "#{@stringForSubprocess @getLeft()} | #{@stringForSubprocess @getRight()}"
	copy: -> (new Parallel(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Sequence
class Sequence extends Process
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 3
	getApplicapleRules: -> [Seq1Rule, Seq2Rule]
	getPrefixes: -> @getLeft().getPrefixes()
	getExits: -> @getLeft().getExits()
	
	toString: -> "#{@stringForSubprocess @getLeft()} ; #{@stringForSubprocess @getRight()}"
	copy: -> (new Sequence(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Restriction		
class Restriction extends Process
	constructor: (process, @restrictedActions) -> super process	# Process x SimpleAction
	
	getPrecedence: -> 1
	getApplicapleRules: -> [ResRule]
	getProcess: -> @subprocesses[0]
	setProcess: (process) -> @subprocesses[0] = process 
	
	toString: -> "#{@stringForSubprocess @getProcess()} \\ {#{(a.toString() for a in @restrictedActions).join ", "}}"
	copy: -> (new Restriction(@getProcess().copy(), @restrictedActions))._setCCS(@ccs)
	


	

# --------------------
# - Channel

class Channel
	constructor: (@name, @expression) ->
	
	isEqual: (channel) ->
		return false if channel.name != @name
		return true if channel.expression == null and @expression == null
		return false if channel.expression == null or @expression == null
		return channel.expression.evaluate() == @expression.evaluate()
	replaceIdentifierWithValue: (identifier, value) ->
		@expression = @expression.replaceIdentifierWithValue(identifier, value) if @expression
	replaceIdentifier: (old, newID) ->
		@name = newID if @name == old
	getTypeOfIdentifier: (identifier, type) ->
		type = CCSGetMostGeneralType(type, CCSTypeChannel) if @name == identifier
		type = CCSGetMostGeneralType(type, @expression.getType()) if @expression
		type
	toString: ->
		result = "" + @name
		if @expression
				if @expression.isEvaluatable()
					result += "(#{@expression.evaluate();})"
				else
					result += "(#{@expression.toString();})"
		result

# -- Action (abstract class)
class Action
	constructor: (@channel) ->		# string x Expression
		if @channel == "i"
			if !@isSimpleAction() then throw new Error("Internal channel i is only allowed as simple action!")
			@channel = CCSInternalChannel
		else if @channel == "e"
			if !@isSimpleAction() then throw new Error("Exit channel e is only allowed as simple action!")
			@channel = CCSExitChannel
	
	isSimpleAction: -> false
	isInputAction: -> false
	isMatchAction: -> false
	isOutputAction: ->false
	
	
	toString: -> @channel.toString()
	isSyncableWithAction: (action) -> false
	replaceIdentifierWithValue: (identifier, value) ->		# returns true if prefix should continue replacing the variable in its subprocess
		@channel.replaceIdentifierWithValue(identifier, value)
		true
	replaceIdentifier: (old, newID) -> @channel.replaceIdentifier old, newID
	getTypeOfIdentifier: (identifier, type) -> @channel.getTypeOfIdentifier(identifier, type)


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
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel.isEqual(@channel) and action.supportsValuePassing() == this.supportsValuePassing()
	replaceIdentifierWithValue: (identifier, value) -> 
		super identifier, value
		@variable != identifier	# stop replacing if identifier is equal to its own variable name
	replaceIdentifier: (old, newID) -> 
		super old, newID
		@variable != old
	getTypeOfIdentifier: (identifier, type) -> 
		type = CCSGetMostGeneralType(type, CCSTypeValue) if @variable == identifier
		super identifier, type
	
	toString: -> "#{super}?#{@variable}"
	copy: -> new Input(@channel, @variable, @range)


# - Match
class Match extends Action
	constructor: (channel, @expression) -> super channel	# string x Expression
	
	isMatchAction: -> true
	supportsValuePassing: -> true
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel.isEqual(@channel) and action.supportsValuePassing() and action.expression.evaluate() == this.expression.evaluate()
	replaceIdentifierWithValue: (identifier, value) -> 
		super identifier, value
		@expression = @expression.replaceIdentifierWithValue(identifier, value)
		true
	replaceIdentifier: (old, newID) -> 
		super old, newID
		@expression.replaceIdentifier(old, newID)
		true
	getTypeOfIdentifier: (identifier, type) -> 
		type = CCSGetMostGeneralType(type, @expression.getType(identifier)) if @expression
		super identifier, type
	
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
		super identifier, value
		@expression = @expression.replaceIdentifierWithValue(identifier, value) if @expression
		true
	replaceIdentifier: (old, newID) -> 
		super old, newID
		@expression?.replaceIdentifier(old, newID)
		true
	getTypeOfIdentifier: (identifier, type) -> 
		type = CCSGetMostGeneralType(type, @expression.getType(identifier)) if @expression
		super identifier, type
			
	toString: -> "#{super}!#{if @expression then @expression.toString() else ""}"
	copy: -> new Output(@channel, (@expression?.copy()))
	

# -- Expression
class Expression
	constructor: (@subExps...) ->			# Expression*
	
	getLeft: -> @subExps[0]
	getRight: -> @subExps[1]
	replaceIdentifierWithValue: (identifier, value) -> 
		@subExps = ((
			exp.replaceIdentifierWithValue(identifier, value)
		) for exp in @subExps)
		@
	replaceIdentifier: (old, newID) -> 
		exp.replaceIdentifier(old, newID) for exp in @subExps
	
	usesIdentifier: (identifier) ->
		result = false;
		(result || e.usesIdentifier()) for e in @subExps	# Returns false if root is the requested identifier: then its type is unknown
		result
	getType: (identifier) ->
		CCSTypeValue if @usesIdentifier(identifier)
		CCSTypeUnknown
	evaluate: -> throw new Error("Abstract method!")
	isEvaluatable: -> false
		
	needsBracketsForSubExp: (exp) -> 
		@getPrecedence? and exp.getPrecedence? and exp.getPrecedence() < @getPrecedence()
	stringForSubExp: (exp) ->
		if @needsBracketsForSubExp exp
			"(#{exp.toString()})"
		else
			"#{exp.toString()}"
	toString: -> throw new Error("Abstract method not implemented!")
	copy: -> throw new Error("Abstract method not implemented!")


# - ConstantExpression
class ConstantExpression extends Expression
	constructor: (@value) -> super()
	
	getPrecedence: -> 18
	evaluate: -> 
		if typeof @value == "boolean" then (if @value == true then 1 else 0) else @value
	isEvaluatable: -> true
	toString: -> if typeof @value == "string" then '"'+@value+'"' else "" + @value
	copy: -> new ConstantExpression(@value)
	

# - VariableExpression
class VariableExpression extends Expression
	constructor: (@variableName) -> 
		super()
	
	getPrecedence: -> 18
	replaceIdentifierWithValue: (identifier, value) -> 
		if identifier == @variableName then new ConstantExpression(value) else @
	replaceIdentifier: (old, newID) ->
		@variableName = newID if @variableName == old
	evaluate: -> throw new Error('Unbound identifier!')
	isEvaluatable: -> false
	toString: -> @variableName
	
	copy: -> new VariableExpression(@variableName)


# - AdditiveExpression
class AdditiveExpression extends Expression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 15
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		if @op == "+" then l + r else if @op == "-" then l-r else throw new Error("Invalid operator!")
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new AdditiveExpression(@getLeft().copy(), @getRight().copy(), @op)


# - MultiplicativeExpression
class MultiplicativeExpression extends Expression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 12
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		if @op == "*" then l * r else if @op == "/" then Math.floor(l/r) 
		else throw new Error("Invalid operator!")
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new MultiplicativeExpression(@getLeft().copy(), @getRight().copy(), @op)
	

# - ConcatenatingExpression
class ConcatenatingExpression extends Expression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 9
	evaluate: -> "" + @getLeft().evaluate() + @getRight().evaluate()
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + "^" + @stringForSubExp(@getRight())
	
	copy: -> new ConcatenatingExpression(@getLeft().copy(), @getRight().copy())


# - RelationalExpression
class RelationalExpression extends Expression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 6
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		if @op == "<" then l < r else if @op == "<=" then l <= r
		else if @op == ">" then l > r else if @op == ">=" then l >= r
		else throw new Error("Invalid operator!")
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new RelationalExpression(@getLeft().copy(), @getRight().copy(), @op)
	

# - EqualityExpression
class EqualityExpression extends Expression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 3
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		if @op == "==" then l == r else if @op == "!=" then l != r 
		else throw new Error("Invalid operator!")
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new EqualityExpression(@getLeft().copy(), @getRight().copy(), @op)
	

	
	
	
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
	