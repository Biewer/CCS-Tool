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

# - Constants
CCSInternalChannel = "\u03c4"	# tau
CCSExitChannel = "\u03b4"		# rho	
CCSUIChannel = "\u03c8"			# psi	
ObjID = 1
_DEBUG = []

DSteps = []
DS = ->
	console.log ccs.system.toString()
	DSteps = ccs.getPossibleSteps()
	console.log("\"#{i}\": #{s.toString()}") for s, i in DSteps
	null
DP = (i) -> 
	ccs.performStep(DSteps[i])
	DS()

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
		(pd.setCCS @; pd.computeArgTypes()) for pd in @processDefinitions
	
	getProcessDefinition: (name, argCount) -> 
		result = null
		(result = pd if pd.name == name and argCount == pd.getArgCount()) for pd in @processDefinitions
		return result
	getPossibleSteps: (env) -> @system.getPossibleSteps(env)
	performStep: (step) -> @system = step.perform()
	
	toString: -> "#{ (process.toString() for process in @processDefinitions).join("") }\n#{ @system.toString() }";


# - ProcessDefinition
class CCSProcessDefinition
	constructor: (@name, @process, @params) ->					# string x Process x string*
		(@types = (CCSTypeUnknown for p in @params)) if @params	# init with default value
	
	getArgCount: -> if @params then @params.length else 0
	setCCS: (ccs) -> @process.setCCS ccs
	computeArgTypes: ->
		return null if !@params
		@types = ((								# ToDo: Repeat until types won't change anymore
			@process.getTypeOfIdentifier x, CCSTypeUnknown
		) for x in @params)
	
	toString: -> 
		result = @name
		result += "[#{@params.join ", "}]" if @params?.length > 0
		result +=" := #{@process.toString()}\n"
		return result;


# - Process (abstract class)
class CCSProcess
	constructor: (@subprocesses...) ->								# Process*
		@__id = ObjID++
		
	setCCS: (@ccs) -> p.setCCS(@ccs) for p in @subprocesses
	_setCCS: (@ccs) -> throw "no ccs" if !@ccs; @
	getLeft: -> @subprocesses[0]
	getRight: -> @subprocesses[1]
	setLeft: (left) -> @subprocesses[0] = left
	setRight: (right) -> @subprocesses[1] = right
	
	replaceVariable: (varName, exp) -> 
		p.replaceVariable(varName, exp) for p in @subprocesses
	replaceVariableWithValue: (varName, val) -> 
		@replaceVariable varName, new CCSConstantExpression(val)
	replaceChannelName: (old, newID) ->
		p.replaceChannelName(old, newID) for p in @subprocesses
	getTypeOfIdentifier: (identifier, type) ->
		for t in (p.getTypeOfIdentifier(identifier, type) for p in @subprocesses)
			type = CCSGetMostGeneralType(type, t)
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
class CCSStop extends CCSProcess
	getPrecedence: -> 12
	toString: -> "0"
	copy: -> (new CCSStop())._setCCS(@ccs)
	

# - Exit
class CCSExit extends CCSProcess
	getPrecedence: -> 12
	getApplicapleRules: -> [CCSExitRule]
	getExits: -> [@]
	toString: -> "1"
	copy: -> (new CCSExit())._setCCS(@ccs)
	
	
	
# - ProcessApplication
class CCSProcessApplication extends CCSProcess
	constructor: (@processName, @valuesToPass=[]) -> super()		# string x Expression list
	
	getArgCount: -> @valuesToPass.length
	getProcess: -> 
		return @process if @process
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		@process = pd.process.copy()
		if pd.params
			for i in [0..pd.params.length-1]
				id = pd.params[i]
				if pd.types[i] == CCSTypeChannel
					@process.replaceChannelName(id, @valuesToPass[i].variableName)
				else
					@process.replaceVariable(id, @valuesToPass[i])	
		@process
	getPrecedence: -> 12
	getTypeOfIdentifier: (identifier, type) ->
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		if pd.params
			for i in [0..pd.params.length-1] by 1
				type = @valuesToPass[i].getTypeOfIdentifier(identifier, type)
				type = CCSGetMostGeneralType(type, pd.types[i])
		type
	getApplicapleRules: -> [CCSRecRule]
	getPrefixes : -> @getProcess().getPrefixes() #if @process then @process.getPrefixes() else []
	getExits: -> if @process then @process.getExits() else []
	replaceVariable: (varName, exp) -> 
		@valuesToPass = (e.replaceVariable(varName, exp) for e in @valuesToPass)
	replaceChannelName: (old, newID) -> 
		e.replaceChannelName(old, newID) for e in @valuesToPass
	###getProxy: -> 	# ToDo: cache result
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		new ProcessApplicationProxy(@, pd.process.copy())###
	
	toString: -> 
		result = @processName
		result += "[#{(e.toString() for e in @valuesToPass).join ", "}]" if @getArgCount()>0
		return result
	copy: -> (new CCSProcessApplication(@processName, v.copy() for v in @valuesToPass))._setCCS(@ccs)



# - Prefix
class CCSPrefix extends CCSProcess
	constructor: (@action, process) -> super process		# Action x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [CCSPrefixRule, CCSOutputRule, CCSInputRule]
	getProcess: -> @subprocesses[0]
	
	replaceVariable: (varName, exp) ->
		super varName, exp if @action.replaceVariable(varName, exp)
	replaceChannelName: (old, newID) ->
		super old, newID if @action.replaceChannelName(old, newID)
	getPrefixes: -> return [@]
	getTypeOfIdentifier: (identifier, type) ->
		type = @action.getTypeOfIdentifier(identifier, type)
		if @action.isInputAction() and @action.variable == identifier	# new var starts with type "value"
			super identifier, CCSTypeValue
			type
		else
			super identifier, type
		
	toString: -> "#{@action.toString()}.#{@stringForSubprocess @getProcess()}"
	copy: -> (new CCSPrefix(@action.copy(), @getProcess().copy()))._setCCS(@ccs)


# - Condition
class CCSCondition extends CCSProcess
	constructor: (@expression, process) -> super process		# Expression x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [CCSCondRule]
	getProcess: -> @subprocesses[0]
	getTypeOfIdentifier: (identifier, type) ->
		type = @expression.getTypeOfIdentifier(identifier, type)
		super identifier, type
	replaceVariable: (varName, exp) ->
		@expression = @expression.replaceVariable(varName, exp)
		super varName, exp
	
	toString: -> "when (#{@expression.toString()}) #{@stringForSubprocess @getProcess()}"
	copy: -> (new CCSCondition(@expression.copy(), @getProcess().copy()))._setCCS(@ccs)


# - Choice
class CCSChoice extends CCSProcess
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 9
	getApplicapleRules: -> [CCSChoiceLRule, CCSChoiceRRule]
	
	toString: -> "#{@stringForSubprocess @getLeft()} + #{@stringForSubprocess @getRight()}"
	copy: -> (new CCSChoice(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Parallel
class CCSParallel extends CCSProcess
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 6
	getApplicapleRules: -> [CCSParLRule, CCSParRRule, CCSSyncRule, CCSSyncExitRule]
	
	toString: -> "#{@stringForSubprocess @getLeft()} | #{@stringForSubprocess @getRight()}"
	copy: -> (new CCSParallel(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Sequence
class CCSSequence extends CCSProcess
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 3
	getApplicapleRules: -> [CCSSeq1Rule, CCSSeq2Rule]
	getPrefixes: -> @getLeft().getPrefixes()
	getExits: -> @getLeft().getExits()
	
	toString: -> "#{@stringForSubprocess @getLeft()} ; #{@stringForSubprocess @getRight()}"
	copy: -> (new CCSSequence(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Restriction		
class CCSRestriction extends CCSProcess
	constructor: (process, @restrictedChannels) -> super process	# Process x string*
	
	getPrecedence: -> 1
	getApplicapleRules: -> [CCSResRule]
	getProcess: -> @subprocesses[0]
	setProcess: (process) -> @subprocesses[0] = process 
	
	toString: -> "#{@stringForSubprocess @getProcess()} \\ {#{@restrictedChannels.join ", "}}"
	copy: -> (new CCSRestriction(@getProcess().copy(), @restrictedChannels))._setCCS(@ccs)
	


	

# --------------------
# - Channel

class CCSChannel
	constructor: (@name, @expression=null) ->	# string x Expression
	
	isEqual: (channel) ->
		return false if channel.name != @name
		return true if not channel.expression and not @expression
		return false if not channel.expression or not @expression
		return channel.expression.evaluate() == @expression.evaluate()
	replaceVariable: (varName, exp) ->
		@expression = @expression.replaceVariable(varName, exp) if @expression
		null
	replaceChannelName: (old, newID) ->
		@name = newID if @name == old
		null
	getTypeOfIdentifier: (identifier, type) ->
		type = CCSGetMostGeneralType(type, CCSTypeChannel) if @name == identifier
		type = @expression.getTypeOfIdentifier(identifier, type) if @expression
		type
	toString: ->
		result = "" + @name
		if @expression
				if @expression.isEvaluatable()
					result += "(#{@expression.evaluate()})"
				else
					result += "(#{@expression.toString()})"
		result
	copy: -> new CCSChannel(@name, @expression?.copy())

###
class CCSInternalChannel extends CCSChannel
	constructor: (name) ->
		if name != CCSInternalChannel or name != CCSExitChannel
			throw new Error("Only internal channel names are allowed!")
		super name, null
	isEqual: (channel) -> channel.name == @name and channel.expression == null
	replaceVariable: (varName, exp) -> null
	replaceChannelName: (old, newID) -> null
	getTypeOfIdentifier: (identifier, type) -> type
	toString: -> @name
	###
	
	

# -- Action (abstract class)
class CCSAction
	constructor: (@channel) ->		# CCSChannel
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
	transferDescription: -> @channel.toString()
	isSyncableWithAction: (action) -> false
	replaceVariable: (varName, exp) ->		# returns true if prefix should continue replacing the variable in its subprocess
		@channel.replaceVariable(varName, exp)
		true
	replaceChannelName: (old, newID) -> @channel.replaceChannelName old, newID
	getTypeOfIdentifier: (identifier, type) -> @channel.getTypeOfIdentifier(identifier, type)


# - Simple Action
class CCSSimpleAction extends CCSAction
	isSimpleAction: -> true
	supportsValuePassing: -> false
	copy: -> new CCSSimpleAction(@channel.copy())

CCSInternalActionCreate = (name) -> 
	if name != CCSInternalChannel and name != CCSExitChannel
		throw new Error("Only internal channel names are allowed!")
	new CCSSimpleAction(new CCSChannel(name, null))


# - Input
class CCSInput extends CCSAction
	constructor: (channel, @variable, @range) -> 		# CCSChannel x string x {int x int) ; range must be copy in!
		super channel
		@incommingValue = null
	
	isInputAction: -> true
	supportsValuePassing: -> typeof @variable == "string" and @variable.length > 0
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel.isEqual(@channel) and action.supportsValuePassing() == this.supportsValuePassing()
	replaceVariable: (varName, exp) -> 
		super varName, exp
		@variable != varName	# stop replacing if identifier is equal to its own variable name
	
	toString: -> "#{super}?#{ if @supportsValuePassing() then @variable else ""}"
	transferDescription: -> "#{super}#{ if @supportsValuePassing() then ": " + @incommingValue else ""}"
	copy: -> new CCSInput(@channel.copy(), @variable, @range)


# - Match
class CCSMatch extends CCSAction
	constructor: (channel, @expression) -> super channel	# CCSChannel x Expression
	
	isMatchAction: -> true
	supportsValuePassing: -> true
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel.isEqual(@channel) and action.supportsValuePassing() and action.expression.evaluate() == this.expression.evaluate()
	replaceVariable: (varName, exp) -> 
		super varName, exp
		@expression = @expression.replaceVariable(varName, exp)
		true
	getTypeOfIdentifier: (identifier, type) -> 
		type = @expression.getTypeOfIdentifier(identifier, type) if @expression
		super identifier, type
	
	toString: -> "#{super}?=#{if @expression then @expression.toString() else ""}"
	transferDescription: -> throw new Error("Currently unsupported action")
	copy: -> new CCSMatch(@channel.copy(), @expression?.copy())
	

# - Output
class CCSOutput extends CCSAction
	constructor: (channel, @expression) -> super channel	# CCSChannel x Expression
	
	isOutputAction: -> true
	supportsValuePassing: -> @expression instanceof CCSExpression
	isSyncableWithAction: (action) -> 
		if action?.isInputAction() or action.isMatchAction()
			action.isSyncableWithAction(this)
		else
			false
	replaceVariable: (varName, exp) -> 
		super varName, exp
		@expression = @expression.replaceVariable(varName, exp) if @expression
		true
	getTypeOfIdentifier: (identifier, type) -> 
		type = @expression.getTypeOfIdentifier(identifier, type) if @expression
		super identifier, type
			
	toString: -> "#{super}!#{if @expression then @expression.toString() else ""}"
	transferDescription: -> "#{super}#{if @expression then ": " + @expression.evaluate() else ""}"
	copy: -> new CCSOutput(@channel.copy(), (@expression?.copy()))
	

# -- Expression
class CCSExpression
	constructor: (@subExps...) ->			# Expression*
	
	getLeft: -> @subExps[0]
	getRight: -> @subExps[1]
	replaceVariable: (varName, exp) -> 
		@subExps = ((
			e.replaceVariable(varName, exp)
		) for e in @subExps)
		@
	replaceChannelName: (old, newID) -> null
	
	usesIdentifier: (identifier) ->
		@_childrenUseIdentifier identifier
	_childrenUseIdentifier: (identifier) ->
		result = false;
		(result || e.usesIdentifier()) for e in @subExps
		result
	getTypeOfIdentifier: (identifier, type) ->
		type = CCSGetMostGeneralType(type, CCSTypeValue) if @_childrenUseIdentifier(identifier)
		type
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
class CCSConstantExpression extends CCSExpression
	constructor: (@value) -> 
		super()
	
	getPrecedence: -> 18
	evaluate: -> CCSConstantExpression.valueToString @value
		#if typeof @value == "boolean" then (if @value == true then 1 else 0) else @value
	isEvaluatable: -> true
	toString: -> if typeof @value == "string" then '"'+@value+'"' else "" + @value
	copy: -> new CCSConstantExpression(@value)

CCSConstantExpression.valueToString = (value) ->
	value = (if value == true then "1" else "0") if typeof value == "boolean"
	value = "" + value
	

# - VariableExpression
class CCSVariableExpression extends CCSExpression
	constructor: (@variableName) -> 
		super()
	
	getPrecedence: -> 18
	usesIdentifier: (identifier) -> identifier == @variableName
	replaceVariable: (varName, exp) -> 
		if varName == @variableName then exp else @
	replaceChannelName: (old, newID) ->
		@variableName = newID if @variableName == old
	evaluate: -> throw new Error('Unbound identifier!')
	isEvaluatable: -> false
	toString: -> @variableName
	
	copy: -> new CCSVariableExpression(@variableName)


# - AdditiveExpression
class CCSAdditiveExpression extends CCSExpression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 15
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		"" + (if @op == "+" then l + r else if @op == "-" then l-r else throw new Error("Invalid operator!"))
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new CCSAdditiveExpression(@getLeft().copy(), @getRight().copy(), @op)


# - MultiplicativeExpression
class CCSMultiplicativeExpression extends CCSExpression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 12
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		if @op == "*" then l * r else if @op == "/" then Math.floor(l/r) 
		else throw new Error("Invalid operator!")
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new CCSMultiplicativeExpression(@getLeft().copy(), @getRight().copy(), @op)
	

# - ConcatenatingExpression
class CCSConcatenatingExpression extends CCSExpression
	constructor: (left, right) -> super left, right
	
	getPrecedence: -> 9
	evaluate: -> "" + @getLeft().evaluate() + @getRight().evaluate()
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + "^" + @stringForSubExp(@getRight())
	
	copy: -> new CCSConcatenatingExpression(@getLeft().copy(), @getRight().copy())


# - RelationalExpression
class CCSRelationalExpression extends CCSExpression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 6
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		res = if @op == "<" then l < r else if @op == "<=" then l <= r
		else if @op == ">" then l > r else if @op == ">=" then l >= r
		else throw new Error("Invalid operator!")
		CCSConstantExpression.valueToString res
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new CCSRelationalExpression(@getLeft().copy(), @getRight().copy(), @op)
	

# - EqualityExpression
class CCSEqualityExpression extends CCSExpression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 3
	evaluate: ->
		l = @getLeft().evaluate()
		r = @getRight().evaluate()
		res = if @op == "==" then l == r else if @op == "!=" then l != r 
		else throw new Error("Invalid operator!")
		CCSConstantExpression.valueToString res
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	toString: -> @stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new CCSEqualityExpression(@getLeft().copy(), @getRight().copy(), @op)
	

	
	
	
ActionSets =
	isActionInK: (action) -> ActionSets.isActionInCom(action) and action.isSimpleAction()
	isActionInCom: (action) -> ActionSets.isActionInAct(action) and action.channel.name != CCSInternalChannel
	isActionInAct: (action) -> ActionSets.isActionInActPlus(action) and action.channel.name != CCSExitChannel
	isActionInActPlus: (action) -> !action.supportsValuePassing()
	isActionInComVP: (action) -> ActionSets.isActionInActVP(action) and action.channel.name != CCSInternalChannel
	isActionInActVP: (action) -> action.channel.name != CCSExitChannel
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
	var target = this.concat([]);	// Copy
	var result = target.shift().concat([]);	// Result should always be a copy
	while (target.length > 0) {
		result = result.concat(target.shift());
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
Array::assertNonNull = ->
	(throw new Error("Null element found!") if typeof e == "undefined" or e == null) for e in @
	

CCSProcess::findApp = (name) ->
	(c.findApp name for c in @subprocesses).joinChildren()
CCSProcessApplication::findApp = (name) ->
	debugger
	if name == @processName then [@] else []
CCSPrefix::findApp = -> []
	