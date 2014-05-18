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



###
	PCCProgramController manages all variables, classes, procedures and the relationships between each other that occur in a PseuCo program.
###


class PCCGlobal extends PC.EnvironmentNode
	constructor: (program) -> super program, ""
	getVariableClass: -> PCCGlobalVariable
	
	compilerGetVariable: (compiler, identifier) -> @getVariableWithName(identifier)
	compilerGetProcedure: (compiler, identifier) -> @getProcedureWithName(identifier)
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable) -> 
		variable = @getVariableWithName(variable.getName())
		throw new Error("Unexpected new identifier found!") if variable == undefined
		variable.emitConstructor(compiler)
		variable
		


class PCCClass extends PC.Class
	constructor: ->
		super
		@addChild(new PCCInternalReadOnlyField(null, "guard", new PC.Type(PC.Type.MUTEX), true))	# ToDo: guard only in monitor?
	getAllConditions: ->
		result = []
		for n, v of @variables
			result.push(v) if v.type and v.type.kind == PC.Type.CONDITION
		result
	getVariableClass: -> PCCField
	
	compilerGetVariable: (compiler, identifier) -> 
		@getVariableWithName(identifier)
	compilerGetProcedure: (compiler, identifier) -> @getProcedureWithName(identifier)
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable) ->  
		@getVariableWithName(variable.getName())
	
	emitEnvironment: (compiler) ->
		variables = (v for n,v of @variables)
		instance = new PCCVariableInfo(null, "i", @type, true)
		variables.unshift(instance)
		compiler.beginProcessGroup(new PCCGroupable(@getEnvProcessName()), variables)
		variables = (compiler.getVariableWithName(v.getIdentifier()) for v in variables)	# as local variables
		names = (n for n of @variables)
		for i in [0...names.length-1]
			control = compiler.emitChoice()
			@variables[names[i]].emitAccessors(compiler, variables, variables[0].getContainer(compiler))
			control.setBranchFinished()
		@variables[names[names.length-1]].emitAccessors(compiler, variables, variables[0].getContainer(compiler))
		compiler.endProcessGroup()
	emitConstructor: (compiler) ->
		hasVariables = false
		(hasVariables = true; break) for n of @variables
		return if not hasVariables
		@emitEnvironment(compiler)
		PCCConstructor.emitConstructor(compiler, @)
		compiler.emitSystemProcessApplication(@getProcessName(), [new PCCConstantContainer(1)])
		
	constructorGetName: -> @getEnvProcessName()
	constructorGetArguments: -> [new PCCVariableInfo(null, "next_i", @type, true)]
	constructorProtectEnvironmentArguments: (cons, compiler, variables) ->
		instance = variables[0]
		compiler.emitOutput("class_#{@getName()}_create", null, instance.getContainer(compiler))
		compiler.protectContainer(instance.getContainer(compiler))
		res = 1
		for n,v of @variables
			c = v.compileDefaultValue(compiler)
			compiler.protectContainer(c)
			res++
		res
	constructorShouldCallRecursively: -> true
	constructorUpdateVariablesForRecursiveCall: (cons, compiler, entry, variables) ->
		instance = variables[0]
		new_i = new PCCBinaryContainer(instance.getContainer(compiler), new PCCConstantContainer(1), "+")
		instance.setContainer(compiler, new_i)
		
	
	getProcessName: -> "Env_class_#{@getName()}_cons"
	getEnvProcessName: -> "Env_class_#{@getName()}"
		
	

#class PCCMonitor extends PCCClass

#class PCCStruct extends PCCClass
		
class PCCProcedure extends PC.Procedure
	getProcessName: -> "Proc#{@getComposedLabel()}"
	getAgentStarterChannel: -> "start#{@getComposedLabel()}"
	getAgentProcessName: -> "Agent#{@getComposedLabel()}"
	getVariableClass: -> PCCLocalVariable
	getAllArgumentContainers: (compiler, explicitArgumentContainers, instanceContainer) ->
		argumentContainers = explicitArgumentContainers[..]
		if @isClassProcedure()
			#argumentContainers.unshift(compiler.getVariable("i_g").getContainer(compiler)) if @isMonitorProcedure()
			if not instanceContainer
				instanceContainer = compiler.getVariableWithNameOfClass("i", null, true).getContainer(compiler) 
			argumentContainers.unshift(instanceContainer)
		else
			throw new Error("Illegal instance value") if instanceContainer
		#argumentContainers.unshift(compiler.getVariableWithName("r", null, true).getContainer(compiler))
		argumentContainers
	getImplicitAndExplicitArgumentCount: ->
		res = @arguments.length #+ 1
		res++ if @isClassProcedure()
		res
	emitAgentConstructor: (compiler) ->
		definitionName = @getAgentProcessName()
		compiler.beginProcessDefinition(definitionName, [])
		i = new PCCVariableContainer("i", PCCType.INT)
		compiler.emitInput("agent_new", null, i)
		compiler.emitOutput(@getAgentStarterChannel(), null, i)
		args = []
		for j in [0...@getImplicitAndExplicitArgumentCount()]
			a = new PCCVariableContainer("a#{j}", PCCType.VOID)		# Type is unimportant here
			compiler.emitInput("start_set_arg", i, a)
			args.push(a)
		control1 = compiler.emitParallel()
		compiler.emitProcessApplication(definitionName, [])
		control1.setBranchFinished()
		control2 = compiler.emitParallel()
		control3 = compiler.emitSequence()
		compiler.emitProcessApplication(@getProcessName(), args)
		control3.setBranchFinished()
		compiler.emitOutput("agent_terminate", i, null)
		compiler.emitStop()
		control3.setBranchFinished()
		control2.setBranchFinished()
		compiler.emitProcessApplication("AgentJoiner", [i, new PCCConstantContainer(0)])
		control2.setBranchFinished()
		control1.setBranchFinished()
		compiler.endProcessDefinition()
	emitExit : (compiler) ->
		if @isMonitorProcedure()
			guard = compiler.getVariableWithNameOfClass("guard", null, true)
			compiler.emitOutput("unlock", guard.getContainer(compiler))
		compiler.emitExit()
			
		
		
		


###
	PCCType represents CCS types, and - if an integer is used as a reference - the referenced CCS type.
###

class PCCType
	constructor: (@_type, @_className) ->
		@_type = 1 if not @_type and @_className
	isVoid: -> @_type == -1
	isBool: -> @_type == 0
	isInt: -> @_type == 1
	isString: -> @_type == 2
	isArray: -> @_type instanceof PCCType
	isClass: -> if @_className then true else false
	getClassName: -> 
		throw new Error("Can't get class name for non-class type!") if not @_className
		@_className
	isEqual: (type) -> if @isArray() then type.isArray() && @_type.isEqual(type._type) else @_type == type._type
	getSubtype: ->
		throw new Error("Cannot get subtype for non-array type!") if !@isArray()
		@_type._type
	getDefaultContainer: -> 
		return new PCCConstantContainer(0) if @isArray() or @isClass()
		new PCCConstantContainer(switch @_type
			when 0 then false
			when 1 then 0
			when 2 then ""
			else throw new Error("Void does not have a default value")
		)

PCCType.VOID = new PCCType(-1)
PCCType.BOOL = new PCCType(0)
PCCType.INT = new PCCType(1)
PCCType.STRING = new PCCType(2)

PC.Type::getCCSType = ->
	switch @kind
		when PC.Type.INT then PCCType.INT
		when PC.Type.BOOL then PCCType.BOOL
		when PC.Type.STRING then PCCType.STRING
		when PC.Type.CHANNEL then throw new Error("Unexpected type kind!")
		when PC.Type.ARRAY then throw new Error("Unexpected type kind!")
		when PC.Type.MONITOR then PCCType.INT
		when PC.Type.STRUCTURE then PCCType.INT
		when PC.Type.MUTEX then PCCType.INT
		when PC.Type.CONDITION then PCCType.INT
		when PC.Type.PROCEDURE then throw new Error("Unexpected type kind!")
		when PC.Type.TYPE then throw new Error("Unexpected type kind!")
		when PC.Type.MAINAGENT then throw new Error("Unexpected type kind!")
		when PC.Type.AGENT then PCCType.INT
		when PC.Type.WILDCARD then throw new Error("Unexpected type kind!")
		else PCCType.VOID

PC.ArrayType::getCCSType = -> new PCCType(@elementsType.getCCSType())
PC.ChannelType::getCCSType = -> new PCCType(@channelledType.getCCSType())
PC.ProcedureType::getCCSType = -> @returnType.getCCSType()
PC.ProcedureType::getCCSArgumentTypes = -> t.getCCSType() for t in @argumentTypes

###
PCTArrayType::fulfillAssignment = (compiler, container) ->
	result = compiler.getFreshContainer(container.ccsType)
	compiler.emitInput("array_copy", container, result)
	result
###
PC.ArrayType::createContainer = (compiler, containers=[]) ->
	result = compiler.getFreshContainer(@getCCSType())
	compiler.emitInput("array#{@capacity}_create", null, result)
	compiler.emitOutput("array_setDefault", result, @elementsType.getCCSType().getDefaultContainer())
	if @elementsType.requiresCustomDefaultContainer()
		for i in [containers.length...@capacity] by 1
			containers.push(@elementsType.createContainer(compiler))
	for c, i in containers
		compiler.emitOutput("array_access", result, new PCCConstantContainer(i))
		compiler.emitOutput("array_set", result, c)
	result
PC.Type::requiresCustomDefaultContainer = -> 
	@kind != PC.Type.INT and @kind != PC.Type.BOOL and @kind != PC.Type.STRING
PC.Type::createContainer = (compiler, container) ->
	return container if container
	throw new Error("No default value for agents available") if @kind == PC.Type.AGENT
	throw new Error("No default value for void available") if @kind == PC.Type.VOID
	if @kind == PC.Type.MUTEX
		result = compiler.getFreshContainer(PCCType.INT)
		compiler.emitInput("mutex_create", null, result)
		result
	else if @kind == PC.Type.STRING
		new PCCConstantContainer("")
	else
		new PCCConstantContainer(0)
PC.ChannelType::createContainer = (compiler, container) ->
	return container if container
	res = compiler.getFreshContainer(@getCCSType())
	buffered = @capacity != PC.ChannelTypeNode.CAPACITY_UNKNOWN and @capacity != 0
	channel = "channel#{if buffered then @capacity else ""}_create"
	compiler.emitInput(channel, null, res)
	#if buffered
		#compiler.emitOutput("channel_setDefault", res, @channelledType.getCCSType().getDefaultContainer())
	res
PC.ClassType::createContainer = (compiler, container) ->
	return container if container
	result = compiler.getFreshContainer(PCCType.INT)
	compiler.emitInput("class_#{@identifier}_create", null, result)
	result


	



# Variables

class PCCVariableInfo extends PC.Variable
	constructor: (node, name, type, @isInternal=false) -> super node, name, type
	getIdentifier: -> "#{if @isInternal then "#" else ""}#{@getName()}"	# default: x; internal: #x
	#getSuggestedContainerName: -> @getName() + (if @isInternal then "H" else "L")
	getSuggestedContainerName: -> 
		if @isInternal
			PCCVarNameForInternalVar @getName()
		else
			PCCVarNameForPseucoVar @getName()
	#(if @isInternal then "" else "$") + @getName()
	 
PCCVariableInfo.getNameForInternalVariableWithName = (name) -> "#"+name

PC.Variable::getSuggestedContainerName = -> PCCVarNameForPseucoVar @getName()
PC.Variable::getCCSType = -> @type.getCCSType()
PC.Variable::compileDefaultValue = (compiler) -> 
	if @node then @node.compileDefaultValue(compiler) else @type.createContainer(compiler)
PCCVariableInfo::getCCSType = -> if @type or not @isInternal then super else PCCType.INT
	
	

class PCCVariable extends PCCVariableInfo
	getContainer: (compiler) -> throw new Error("Not implemented!")
	setContainer: (compiler, container) -> throw new Error("Not implemented")

class PCCGlobalVariable extends PCCVariable
	accessorChannel: (set) -> "env_global_#{if set then "set" else "get"}_#{@getName()}"
	trackValue: (compiler) -> compiler.trackGlobalVars()
	getContainer: (compiler) ->
		result = compiler.getFreshContainer(@type.getCCSType())
		compiler.emitInput(@accessorChannel(false), null, result)
		result
	setContainer: (compiler, container) ->
		compiler.emitOutput(@accessorChannel(true), null, container)
		null
	emitAccessors: (compiler, variables, instance=null) ->
		local = compiler.getVariableWithName(@getIdentifier())
		containers = (v.getContainer(compiler) for v in variables)
		control = compiler.emitChoice()
		c = local.getContainer(compiler)
		compiler.emitOutput(@accessorChannel(false), instance, c)
		compiler.emitProcessApplication(@getEnvProcessName(), containers)
		control.setBranchFinished()
		compiler.emitInput(@accessorChannel(true), instance, c)
		if @trackValue(compiler)
			cid = new PCCConstantContainer(@getName())
			cid = new PCCBinaryContainer(instance, cid, "^") if instance
			compiler.emitOutput("sys_var", cid, c)
		compiler.emitProcessApplication(@getEnvProcessName(), containers)
		control.setBranchFinished()
	emitConstructor: (compiler) ->
		compiler.beginProcessGroup(new PCCGroupable(@getEnvProcessName()), [@])
		@emitAccessors(compiler, [compiler.getVariableWithName(@getName())])
		compiler.endProcessGroup()
		compiler.beginProcessGroup(@)
		container = @compileDefaultValue(compiler)
		if @trackValue(compiler)
			cid = new PCCConstantContainer(@getName())
			compiler.emitOutput("sys_var", cid, container)
		compiler.emitProcessApplication(@getEnvProcessName(), [container])
		compiler.endProcessGroup()
		compiler.emitSystemProcessApplication(@getProcessName(), [])
		
	getProcessName: -> "Env_global_#{@getName()}_cons"
	getEnvProcessName: -> "Env_global_#{@getName()}"

class PCCField extends PCCGlobalVariable
	accessorChannel: (set) -> "env_class_#{@parent.getName()}_#{if set then "set" else "get"}_#{@getName()}"
	trackValue: (compiler) -> compiler.trackClassVars()
	getContainer: (compiler) ->
		if @getIdentifier() == "#guard"
			result = compiler.getFreshContainer(PCCType.INT)
			compiler.emitInput("env_class_get_guard", compiler.getVariableWithNameOfClass("i", null, true).getContainer(compiler), result)
		else
			result = compiler.getFreshContainer(@type.getCCSType())
			compiler.emitInput(@accessorChannel(false), compiler.getVariableWithNameOfClass("i", null, true).getContainer(compiler), result)
		result
	setContainer: (compiler, container) ->
		compiler.emitOutput(@accessorChannel(true), compiler.getVariableWithNameOfClass("i", null, true).getContainer(compiler), container)
		null
	getEnvProcessName: -> "Env_class_#{@parent.getName()}"

class PCCInternalReadOnlyField extends PCCField
	emitAccessors: (compiler, variables, instance) ->
		local = compiler.getVariableWithName(@getIdentifier())
		containers = (v.getContainer(compiler) for v in variables)
		c = local.getContainer(compiler)
		compiler.emitOutput("env_class_guard", instance, c)						# too much hard coded?
		compiler.emitProcessApplication(@getEnvProcessName(), containers)
	getContainer: (compiler) -> 
		result = compiler.getFreshContainer(PCCType.INT)
		compiler.emitInput("env_class_guard", compiler.getVariableWithNameOfClass("i", null, true).getContainer(compiler), result)
		result
	setContainer: -> throw new Error("Setting container for read only variable!")
	

class PCCCondition extends PCCField
	constructor: (name, @expressionNode) -> super name, new PC.Type(PC.Type.CONDITION)

class PCCLocalVariable extends PCCVariable
	trackValue: (compiler) -> compiler.trackLocalVars()
	getContainer: (compiler) -> compiler.getProcessFrame().getContainerForVariable(@getIdentifier())
	setContainer: (compiler, container) -> 
		if @trackValue(compiler)
			cid = new PCCConstantContainer(@getName())
			compiler.emitOutput("sys_var", cid, container)
		compiler.getProcessFrame().assignContainerToVariable(@getIdentifier(), container)








class PCCProgramController extends PC.EnvironmentController
	constructor: ->
		super
		@root = new PCCGlobal()
		@agents = {}
		@_envStack = @root

	processNewClass: (node, classType) ->
		tnode = new PCCClass(node, classType)
		@_processNewClass(tnode)
	
	beginNewProcedure: (node, procedureName, returnType, args) ->
		tnode = new PCCProcedure(node, procedureName, returnType, args)
		@_beginNewProcedure(tnode)
	
	processNewVariable: (variable) ->		
		varClass = @_envStack.getVariableClass()
		tnode = new varClass(variable.node, variable.getName(), variable.type)
		@_processNewVariable(tnode)
	
	processProcedureAsAgent: (procedure) ->
		@agents[procedure.getName()] = procedure
	
	getAgents: ->
		res = []
		for p of @agents
			proc = @agents[p]
			res.push(proc) if proc instanceof PC.Procedure
		res
	
	getUsedTypes: ->
		res = 
			arrays: {}
			channels: {}
		@root.getUsedTypes(res)
		res
	
	

PC.EnvironmentNode::getUsedTypes = (res) ->
	c.getUsedTypes(res) for c in @children
	null
PC.Variable::getUsedTypes = (res) ->
	@type.getUsedTypes(res)
PC.Type::getUsedTypes = -> null
PC.ArrayType::getUsedTypes = (res) ->
	res.arrays[@capacity] = true
	@elementsType.getUsedTypes(res)
	null
PC.ChannelType::getUsedTypes = (res) ->
	res.channels[@getApplicableCapacity()] = true
	null
		

PC.Node::collectAgents = (env) -> c.collectAgents(env) for c in @children
_t = PC.Monitor		# CoffeeScript bug? Can't call super in PC.Monitor::...
_t::collectAgents = (env) -> 
	env.beginClass(@name)
	super
	env.endClass()
_t = PC.Struct
_t::collectAgents = (env) -> 
	env.beginClass(@name)
	super
	env.endClass()
_t = PC.ProcedureDecl
_t::collectAgents = (env) -> 		# ToDo: PCProcedure should be renamed to PCTProcedure. But shouldn't it be PCProcedureDecl?
	env.beginProcedure(@name)
	super
	env.endProcedure()

PC.StartExpression::collectAgents = (env) -> env.processProcedureAsAgent(@children[0].getProcedure(env))




