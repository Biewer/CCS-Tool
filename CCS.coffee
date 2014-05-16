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
CCSUIChannel = "\u03c8"			# psi		# remove?
ObjID = 1
_DEBUG = []

DSteps = []
DS = ->			# remove?
	console.log ccs.system.toString()
	DSteps = ccs.getPossibleSteps()
	console.log("\"#{i}\": #{s.toString()}") for s, i in DSteps
	null
DP = (i) -> 		# remove?
	ccs.performStep(DSteps[i])
	DS()


class Environment
	constructor: -> @env = {}
	getValue: (id) ->
		res = @env[id]
		throw new Error("Unbound identifier \"#{id}\"!") if ! res
		res
	setValue: (id, type) ->
		@env[id] = type
	hasValue: (id) -> if @env[id] then true else false

CCSTypeUnknown = 3
CCSTypeChannel = 1
CCSTypeValue = 2
CCSTypeProcess = 10
CCSGetMostGeneralType = (t1, t2) ->
	return t1 if t2 == CCSTypeUnknown
	return t2 if t1 == CCSTypeUnknown
	return t1 if t1 == t2
	throw new Error("Incompatible Types: #{CCSTypeToString t1} and #{CCSTypeToString t2}!");

CCSTypeToString = (t) ->
	if t == CCSTypeChannel
		"Channel"
	else if t == CCSTypeValue
		"Value"
	else if t == CCSTypeProcess
		"Process"
	else
		"Unknown"

class CCSEnvironment extends Environment
	constructor: (@ccs, @pd) -> super()
	getType: (id) -> @getValue id
	setType: (id, type) ->
		now = @env[id]
		if now
			throw new Error("Duplicate process variable \"#{id}\"") if type == CCSTypeProcess
			@env[id] = CCSGetMostGeneralType(now, type)
		else
			@env[id] = type
	hasType: (id) -> @hasValue id
	allowsUnboundedInputOnChannelName: (name) ->
		if @pd and @pd.usesParameterName(name)
			false
		else
			@ccs.allowsUnboundedInputOnChannelName(name)
			


# - CCS
class CCS
	constructor: (@processDefinitions, @system, @allowUnguardedRecursion=true) ->
		@warnings = []
		if @system instanceof CCSRestriction
			@rootRestriction = @system
		else
			@rootRestriction = null
		@system.setCCS @
		penv = new CCSEnvironment(@)
		(pd.setCCS @) for pd in @processDefinitions
		(pd.computeTypes(penv)) for pd in @processDefinitions
		try
			@system.computeTypes(new CCSEnvironment(@))
		catch e
			e = new Error(e.message)
			e.line = @system.line
			e.column = 1
			e.name = "TypeError"
			e.code = @toString()
			throw e
	
	allowsUnboundedInputOnChannelName: (name) ->
		if @rootRestriction then @rootRestriction.restrictsChannelName(name) else false
	
	getProcessDefinition: (name, argCount) -> 
		result = null
		(result = pd if pd.name == name and argCount == pd.getArgCount()) for pd in @processDefinitions
		return result
	getPossibleSteps: (copyOnPerform) -> @system.getPossibleSteps(copyOnPerform)
	#performStep: (step) -> @system = step.perform()
	
	toString: -> "#{ (process.toString() for process in @processDefinitions).join("") }\n#{ @system.toString() }";


# - ProcessDefinition
class CCSProcessDefinition
	constructor: (@name, @process, @params, @line=0) ->					# string x Process x CCSVariable*
	
	getArgCount: -> if @params then @params.length else 0
	usesParameterName: (name) ->
		return false if not @params
		(return true if name == p.name) for p in @params
		false
	setCCS: (@ccs) -> 
		@process.setCCS @ccs
		@env = new CCSEnvironment(@ccs, @)
		if @params
			for x in @params
				@env.setType(x.name, CCSTypeUnknown)
	computeTypes: (penv) -> 
		if @process.isUnguardedRecursion()
			e = new Error("You are using unguarded recursion") 
			e.line = @line
			e.column = 1
			e.name = "TypeError"
			e.code = @ccs.toString()
			if @ccs.allowUnguardedRecursion
				@ccs.warnings.push(e)
			else
				throw e	
		try
			penv.setType(@name, CCSTypeProcess)
			@process.computeTypes(@env)
		catch e
			e = new Error(e.message)
			e.line = @line
			e.column = 1
			e.name = "TypeError"
			e.code = @ccs.toString()
			throw e
	
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
	###getTypeOfIdentifier: (identifier, type) ->
		for t in (p.getTypeOfIdentifier(identifier, type) for p in @subprocesses)
			type = CCSGetMostGeneralType(type, t)
		type###
	computeTypes: (env) ->
		p.computeTypes(env) for p in @subprocesses
		null
	isUnguardedRecursion: ->
		(return true if p.isUnguardedRecursion()) for p in @subprocesses
		false
	
	getApplicapleRules: -> []
	_getPossibleSteps: (info, copyOnPerform) -> 
		copyOnPerform = false if not copyOnPerform
		res = SBArrayConcatChildren(rule.getPossibleSteps(this, info, copyOnPerform) for rule in @getApplicapleRules())
	getPossibleSteps: (copyOnPerform) -> CCSExpandInput(@_getPossibleSteps({}, copyOnPerform))
		
	needsBracketsForSubprocess: (process) -> 
		@getPrecedence? and process.getPrecedence? and process.getPrecedence() < @getPrecedence()
	stringForSubprocess: (process, mini) ->
		if @needsBracketsForSubprocess process
			"(#{process.toString(mini)})"
		else
			"#{process.toString(mini)}"
	getPrefixes: -> SBArrayConcatChildren(p.getPrefixes() for p in @subprocesses)
	getExits: -> SBArrayConcatChildren(p.getExits() for p in @subprocesses)

	

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
	getProcessDefinition: -> @ccs.getProcessDefinition(@processName, @getArgCount())
	getProcess: -> 
		return @process if @process
		pd = @getProcessDefinition()
		@process = pd.process.copy()
		if pd.params
			for i in [0..pd.params.length-1] by 1
				id = pd.params[i].name
				if pd.env.getType(id) == CCSTypeChannel
					@process.replaceChannelName(id, @valuesToPass[i].variableName)
				else
					if !(pd.params[i].allowsValue(@valuesToPass[i].evaluate()))
						@process = null
						return null
					@process.replaceVariable(id, @valuesToPass[i])	
		@process
	getPrecedence: -> 12
	###getTypeOfIdentifier: (identifier, type) ->
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		if pd.params
			for i in [0..pd.params.length-1] by 1
				type = @valuesToPass[i].getTypeOfIdentifier(identifier, type)
				type = CCSGetMostGeneralType(type, pd.types[i])
		type###
	computeTypes: (env) ->
		pd = @ccs.getProcessDefinition(@processName, @getArgCount())
		throw new Error("Unknown process variable \"#{@processName}\" (with #{@getArgCount()} arguments)!") if not pd
		if pd.params
			for i in [0..pd.params.length-1] by 1
				type = @valuesToPass[i].computeTypes(env, true)
				pd.env.setType(pd.params[i].name, type)
		super
	isUnguardedRecursion: -> true
	
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
	
	toString: (mini) -> 
		result = @processName
		result += "[#{(e.toString(mini) for e in @valuesToPass).join ", "}]" if @getArgCount()>0
		return result
		
	copy: -> (new CCSProcessApplication(@processName, v.copy() for v in @valuesToPass))._setCCS(@ccs)



# - Prefix
class CCSPrefix extends CCSProcess
	constructor: (@action, process) -> super process		# Action x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [CCSPrefixRule, CCSOutputRule, CCSInputRule, CCSMatchRule]
	getProcess: -> @subprocesses[0]
	
	replaceVariable: (varName, exp) ->
		super varName, exp if @action.replaceVariable(varName, exp)
	replaceChannelName: (old, newID) ->
		@action.replaceChannelName(old, newID)
		super old, newID #if @action.replaceChannelName(old, newID)
	getPrefixes: -> return [@]
	###getTypeOfIdentifier: (identifier, type) ->
		type = @action.getTypeOfIdentifier(identifier, type)
		if @action.isInputAction() and @action.variable == identifier	# new var starts with type "value"
			super identifier, CCSTypeValue
			type		# Was macht das da?
		else
			super identifier, type###
	computeTypes: (env) ->
		@action.computeTypes(env)
		super
	isUnguardedRecursion: -> false
			
		
	toString: (mini) -> "#{@action.toString(mini)}.#{@stringForSubprocess(@getProcess(), mini)}"
	copy: -> (new CCSPrefix(@action.copy(), @getProcess().copy()))._setCCS(@ccs)


# - Condition
class CCSCondition extends CCSProcess
	constructor: (@expression, process) -> super process		# Expression x Process
	
	getPrecedence: -> 12
	getApplicapleRules: -> [CCSCondRule]
	getProcess: -> @subprocesses[0]
	###getTypeOfIdentifier: (identifier, type) ->
		type = @expression.getTypeOfIdentifier(identifier, type)
		super identifier, type###
	computeTypes: (env) ->
		type = @expression.computeTypes(env, false)
		throw new Error("Conditions can only check values, channel names are not supported!") if type == CCSTypeChannel
		super
	replaceVariable: (varName, exp) ->
		@expression = @expression.replaceVariable(varName, exp)
		super varName, exp
	
	toString: (mini) -> "when (#{@expression.toString(mini)}) #{@stringForSubprocess(@getProcess(), mini)}"
	copy: -> (new CCSCondition(@expression.copy(), @getProcess().copy()))._setCCS(@ccs)


# - Choice
class CCSChoice extends CCSProcess
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 9
	getApplicapleRules: -> [CCSChoiceLRule, CCSChoiceRRule]
	
	toString: (mini) -> "#{@stringForSubprocess(@getLeft(), mini)} + #{@stringForSubprocess(@getRight(), mini)}"
	copy: -> (new CCSChoice(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Parallel
class CCSParallel extends CCSProcess
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 6
	getApplicapleRules: -> [CCSParLRule, CCSParRRule, CCSSyncRule, CCSSyncExitRule]
	
	toString: (mini) -> "#{@stringForSubprocess(@getLeft(), mini)} | #{@stringForSubprocess(@getRight(), mini)}"
	copy: -> (new CCSParallel(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Sequence
class CCSSequence extends CCSProcess
	constructor: (left, right) -> super left, right		# Process x Process
	
	getPrecedence: -> 3
	getApplicapleRules: -> [CCSSeq1Rule, CCSSeq2Rule]
	getPrefixes: -> @getLeft().getPrefixes()
	getExits: -> @getLeft().getExits()
	
	toString: (mini) -> "#{@stringForSubprocess(@getLeft(), mini)} ; #{@stringForSubprocess(@getRight(), mini)}"
	copy: -> (new CCSSequence(@getLeft().copy(), @getRight().copy()))._setCCS(@ccs)


# - Restriction		
class CCSRestriction extends CCSProcess
	constructor: (process, @restrictedChannels) -> super process	# Process x string*
	
	getPrecedence: -> 1
	getApplicapleRules: -> [CCSResRule]
	getProcess: -> @subprocesses[0]
	setProcess: (process) -> @subprocesses[0] = process 
	restrictsChannelName: (name) ->
		return false if name == CCSInternalChannel or name == CCSExitChannel
		return false if @restrictedChannels.length == 0
		if @restrictedChannels[0] == "*" then @restrictedChannels.indexOf(name) == -1 else @restrictedChannels.indexOf(name) != -1
	
	toString: (mini) -> "#{@stringForSubprocess(@getProcess(), mini)} \\ {#{@restrictedChannels.join ", "}}"
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
	###getTypeOfIdentifier: (identifier, type) ->
		type = CCSGetMostGeneralType(type, CCSTypeChannel) if @name == identifier
		type = @expression.getTypeOfIdentifier(identifier, type) if @expression
		type###
	computeTypes: (env) ->
		env.setType(@name, CCSTypeChannel)
		if @expression
			type = @expression.computeTypes(env, false)
			throw new Error("Channel variables are not allowed in channel specifier expression!") if type == CCSTypeChannel
		null
	toString: (mini) ->
		result = "" + @name
		if @expression
				#if @expression.isEvaluatable()
				#	result += "(#{@expression.evaluate()})"
				#else
				result += "(#{@expression.toString(mini)})"
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
		if @channel.name == "i"		# ??? TODO @channel is not a string?
			if !@isSimpleAction() then throw new Error("Internal channel i is only allowed as simple action!")
			@channel.name = CCSInternalChannel
		else if @channel.name == "e"
			if !@isSimpleAction() then throw new Error("Exit channel e is only allowed as simple action!")
			@channel.name = CCSExitChannel
	
	isSimpleAction: -> false
	isInputAction: -> false
	isMatchAction: -> false
	isOutputAction: ->false
	
	isInternalAction: -> @channel.name == CCSInternalChannel or @channel.name == CCSExitChannel
	
	
	toString: (mini) -> @channel.toString(mini)
	transferDescription: -> @channel.toString(true)
	isSyncableWithAction: (action) -> false
	replaceVariable: (varName, exp) ->		# returns true if prefix should continue replacing the variable in its subprocess
		@channel.replaceVariable(varName, exp)
		true
	replaceChannelName: (old, newID) -> @channel.replaceChannelName old, newID
	#getTypeOfIdentifier: (identifier, type) -> @channel.getTypeOfIdentifier(identifier, type)
	computeTypes: (env) -> @channel.computeTypes(env)


# - Simple Action
class CCSSimpleAction extends CCSAction
	isSimpleAction: -> true
	supportsValuePassing: -> false
	copy: -> new CCSSimpleAction(@channel.copy())

CCSInternalActionCreate = (name) -> 
	if name != CCSInternalChannel and name != CCSExitChannel
		throw new Error("Only internal channel names are allowed!")
	new CCSSimpleAction(new CCSChannel(name, null))



class CCSVariable
	constructor: (@name, @set) -> throw new Error("Illegal variable name") if typeof @name != "string" or @name.length == 0
	allowsValue: (value) -> if @set then @set.allowsValue value else true
	possibleValues: ->
		throw new Error("Cannot generate infinite values for unrestricted variables!") if not @set
		@set.possibleValues()
	toString: -> "#{@name}#{if @set then ":"+@set.toString() else ""}"


class CCSValueSet
	constructor: (@type, @min, @max) ->
		throw new Error("Unknown Type") if @type != "string" and @type != "number"
	allowsValue: (value) ->
		value = CCSStringDataForValue(value)
		if @type == "string"
			len = ("" + value).length
			len >= @min and len <= @max
		else
			if CCSValueIsInt(value)
				val = parseInt(value)
				val >= @min and val <= @max
			else
				false
	possibleValues: ->
		if @type == "string"
			res = [""]
			t = []
			for i in [0...@min] by 1
				for s in res
					for c in CCSValueSet.allowedChars
						t.push(s+c)
				res = t
				t = []
			for i in [@min...@max] by 1
				for s in res
					for c in CCSValueSet.allowedChars
						t.push(s+c)
				res = res.concat(t)
			res
		else
			[@min..@max]
	toString: ->
		if @type == "string"
			res = ""
			for i in [0...@min] by 1
				res += "$"
			res += ".."
			for i in [0...@max] by 1
				res += "$"
			res
		else
			"#{@min}..#{@max}"


CCSValueSet.allowedChars = (->
	res = []
	for i in [65..90] by 1
		res.push(String.fromCharCode(i))
	for i in [97..122] by 1
		res.push(String.fromCharCode(i))
	res.push("-")
	res
)()
	

# - Input
class CCSInput extends CCSAction
	constructor: (channel, @variable) -> 		# CCSChannel x CCSVariable
		super channel
	
	isInputAction: -> true
	supportsValuePassing: -> if @variable then true else false
	isSyncableWithAction: (action) -> action?.isOutputAction() and action.channel.isEqual(@channel) and (if action.supportsValuePassing() then @supportsValuePassing() and @variable.allowsValue(action.expression.evaluate()) else not @supportsValuePassing())
	replaceVariable: (varName, exp) -> 
		super varName, exp
		not @variable or @variable.name != varName	# stop replacing if identifier is equal to its own variable name
	allowsValueAsInput: (value) -> @variable.allowsValue(value)
	
	computeTypes: (env) ->
		if @supportsValuePassing()
			env.setType(@variable.name, CCSTypeValue) 
			if not env.allowsUnboundedInputOnChannelName(@channel.name)
				throw new Error("Unbounded input variable \"#{@variable}\"") if not @variable.set
		super
	
	toString: (mini, inputValue) -> 
		inputValue = null if inputValue == undefined
		"#{super}?#{ if @supportsValuePassing() then (if inputValue != null then CCSBestStringForValue inputValue else @variable.toString()) else ""}"
	transferDescription: (inputValue) -> 
		if @supportsValuePassing() and (inputValue == null or inputValue == undefined)
			throw new Error("CCSInput.transferDescription needs an input value as argument if it supports value passing!") 
		"#{super}#{ if @supportsValuePassing() then ": " + inputValue else ""}"
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
	###getTypeOfIdentifier: (identifier, type) -> 
		type = @expression.getTypeOfIdentifier(identifier, type) if @expression
		super identifier, type###
	computeTypes: (env) ->
		type = @expression.computeTypes(env, false)
		throw new Error("Channels can not be sent over channels!") if type == CCSTypeChannel
		super
	
	toString: (mini) -> "#{super}?(#{if @expression then @expression.toString(mini) else ""})"
	transferDescription: -> "#{super}:#{@expression.evaluate()}"
	copy: -> new CCSMatch(@channel.copy(), @expression.copy())

	

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
	###getTypeOfIdentifier: (identifier, type) -> 
		type = @expression.getTypeOfIdentifier(identifier, type) if @expression
		super identifier, type###
	computeTypes: (env) ->
		if @expression
			type = @expression.computeTypes(env, false)
			throw new Error("Channels can not be sent over channels!") if type == CCSTypeChannel
		super
			
	toString: (mini) -> "#{super}!#{if @expression then @expression.toString(mini) else ""}"
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
	
	###usesIdentifier: (identifier) ->
		@_childrenUseIdentifier identifier
	_childrenUseIdentifier: (identifier) ->
		result = false;
		(result || e.usesIdentifier()) for e in @subExps
		result###
	computeTypes: (env, allowsChannel) ->
		e.computeTypes(env, false) for e in @subExps
		CCSTypeValue
	###getTypeOfIdentifier: (identifier, type) ->
		type = CCSGetMostGeneralType(type, CCSTypeValue) if @_childrenUseIdentifier(identifier)
		type###
	evaluate: -> throw new Error("Abstract method!")
	isEvaluatable: -> false
	typeOfEvaluation: -> throw new Error("Abstract method!")
		
	needsBracketsForSubExp: (exp) -> 
		@getPrecedence? and exp.getPrecedence? and exp.getPrecedence() < @getPrecedence()
	stringForSubExp: (exp, mini) ->
		if @needsBracketsForSubExp exp
			"(#{exp.toString(mini)})"
		else
			"#{exp.toString(mini)}"
	toString: -> throw new Error("Abstract method not implemented!")
	copy: -> throw new Error("Abstract method not implemented!")


# - ConstantExpression
class CCSConstantExpression extends CCSExpression
	constructor: (@value) -> 
		super()
	
	getPrecedence: -> 18
	evaluate: -> CCSStringDataForValue @value
		#if typeof @value == "boolean" then (if @value == true then 1 else 0) else @value
	isEvaluatable: -> true
	typeOfEvaluation: -> typeof @value
	toString: -> CCSBestStringForValue @value #if typeof @value == "string" then '"'+@value+'"' else "" + @value
	copy: -> new CCSConstantExpression(@value)
	

CCSStringDataForValue = (value) ->
	value = (if value == true then "1" else "0") if typeof value == "boolean"
	value = "" + value

CCSValueIsInt = (value) -> ("" + value).match(/^-?[0-9]+$/)

CCSBestStringForValue = (value) ->
	if CCSValueIsInt(value) then "" + value else if value == true then "1" else if value == false then "0" else "\"#{value}\""

CCSBooleanForString = (string) -> if string == "0" then false else if string == "1" then true else throw new Error("Value #{CCSBestStringForValue string} is not a boolean value!")
	

# - VariableExpression
class CCSVariableExpression extends CCSExpression
	constructor: (@variableName) -> 
		super()
	
	getPrecedence: -> 18
	computeTypes: (env, allowsChannel) -> 
		if allowsChannel
			env.setType(@variableName, CCSTypeUnknown)
			env.getType(@variableName)
		else	
			env.getType(@variableName)	# Ensure that the variable is bound
			env.setType(@variableName, CCSTypeValue)	# We have to force type "value"
			super
	#usesIdentifier: (identifier) -> identifier == @variableName
	replaceVariable: (varName, exp) -> 
		if varName == @variableName then exp else @
	replaceChannelName: (old, newID) ->
		@variableName = newID if @variableName == old
	evaluate: -> throw new Error('Unbound identifier!')
	typeOfEvaluation: -> throw new Error('Unbound identifier!')
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
	typeOfEvaluation: -> "number"
	toString: (mini) -> 
		if mini and @isEvaluatable()
			CCSBestStringForValue(@evaluate())
		else
			@stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new CCSAdditiveExpression(@getLeft().copy(), @getRight().copy(), @op)


# - MultiplicativeExpression
class CCSMultiplicativeExpression extends CCSExpression
	constructor: (left, right, @op) -> super left, right
	
	getPrecedence: -> 12
	evaluate: ->
		l = parseInt(@getLeft().evaluate())
		r = parseInt(@getRight().evaluate())
		if @op == "*" then l * r else if @op == "/" then Math.floor(l/r) else if @op == "%" then l % r 
		else throw new Error("Invalid operator \"#{@op}\"!")
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	typeOfEvaluation: -> "number"
	toString: (mini) -> 
		if mini and @isEvaluatable()
			CCSBestStringForValue(@evaluate())
		else
			@stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new CCSMultiplicativeExpression(@getLeft().copy(), @getRight().copy(), @op)
	

# - ConcatenatingExpression
class CCSConcatenatingExpression extends CCSExpression
	constructor: (left, right) -> super left, right
	
	getPrecedence: -> 9
	evaluate: -> "" + @getLeft().evaluate() + @getRight().evaluate()
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	typeOfEvaluation: -> "string"
	toString: (mini) -> 
		if mini and @isEvaluatable()
			CCSBestStringForValue(@evaluate())
		else
			@stringForSubExp(@getLeft()) + "^" + @stringForSubExp(@getRight())
	
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
		CCSStringDataForValue res
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	typeOfEvaluation: -> "boolean"
	toString: (mini) -> 
		if mini and @isEvaluatable()
			CCSBestStringForValue(@evaluate())
		else
			@stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
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
		CCSStringDataForValue res
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	typeOfEvaluation: -> "boolean"
	toString: (mini) -> 
		if mini and @isEvaluatable()
			CCSBestStringForValue(@evaluate())
		else
			@stringForSubExp(@getLeft()) + @op + @stringForSubExp(@getRight())
	
	copy: -> new CCSEqualityExpression(@getLeft().copy(), @getRight().copy(), @op)


# - CCSAndExpression
class CCSAndExpression extends CCSExpression
	constructor: (left, right) -> super left, right
	
	getPrecedence: -> 0
	evaluate: -> 
		res = CCSBooleanForString(@getLeft().evaluate()) && CCSBooleanForString(@getRight().evaluate())
		CCSStringDataForValue res
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	typeOfEvaluation: -> "boolean"
	toString: (mini) -> 
		if mini and @isEvaluatable()
			CCSBestStringForValue(@evaluate())
		else
			@stringForSubExp(@getLeft()) + "&&" + @stringForSubExp(@getRight())
	
	copy: -> new CCSConcatenatingExpression(@getLeft().copy(), @getRight().copy())

# - CCSOrExpression
class CCSOrExpression extends CCSExpression
	constructor: (left, right) -> super left, right
	
	getPrecedence: -> -3
	evaluate: -> 
		res = CCSBooleanForString(@getLeft().evaluate()) || CCSBooleanForString(@getRight().evaluate())
		CCSStringDataForValue res
	isEvaluatable: -> @getLeft().isEvaluatable() and @getRight().isEvaluatable()
	typeOfEvaluation: -> "boolean"
	toString: (mini) -> 
		if mini and @isEvaluatable()
			CCSBestStringForValue(@evaluate())
		else
			@stringForSubExp(@getLeft()) + "||" + @stringForSubExp(@getRight())
	
	copy: -> new CCSConcatenatingExpression(@getLeft().copy(), @getRight().copy())
	

	
	
	
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
	








SBStringReplaceAll = (text, needle, replacement) ->
	t = text
	tt = text
	loop
		t = tt;
		tt = t.replace(needle, replacement)
		break if t == tt
	t

SBArrayConcatChildren = (array) ->
	return [] if array.length == 0
	target = array[..]
	result = target.shift()[..]	# Result should always be a copy
	while target.length > 0
		result = result.concat(target.shift())
	result

SBArrayJoinChildren = (array, separator) ->
	result = [];
	i = 0;
	loop
		joinTarget = [];
		for c in [0..array.length] by 1
			joinTarget.push(this[c][i]) if array[c][i]
		break if joinTarget.length == 0
		result[i++] = joinTarget.join(separator)
	result

SBArrayAssertNonNull = (array) ->
	(throw new Error("Null element found!") if typeof e == "undefined" or e == null) for e in array

### Workaround (replace all without reg exp)
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
###
	

CCSProcess::findApp = (name) ->
	SBArrayJoinChildren(c.findApp name for c in @subprocesses)
CCSProcessApplication::findApp = (name) ->
	if name == @processName then [@] else []
CCSPrefix::findApp = -> []
	