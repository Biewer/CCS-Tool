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


class PCCGlobal extends PCEnvironmentNode
	constructor: (program) -> super program, ""
	getVariableClass: -> PCCGlobalVariable
	
	compilerGetVariable: (compiler, identifier) -> @getVariableWithName(identifier)
	compilerGetProcedure: (compiler, identifier) -> @getProcedureWithName(identifier)
	compilerHandleNewVariableWithDefaultValueCallback: (compiler, variable) -> 
		variable = @getVariableWithName(variable.getName())
		throw new Error("Unexpected new identifier found!") if variable == undefined
		variable.emitConstructor(compiler)
		variable
		


class PCCClass extends PCClass
	constructor: ->
		super
		@addChild(new PCCInternalReadOnlyField(null, "guard", new PCTType(PCTType.MUTEX), true))
	getAllConditions: ->
		result = []
		for n, v of @variables
			result.push(v) if v.type and v.type.kind == PCTType.CONDITION
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
		
class PCCProcedure extends PCProcedure
	getProcessName: -> "Proc#{@getComposedLabel()}"
	getAgentStarterChannel: -> "start#{@getComposedLabel()}"
	getAgentProcessName: -> "Agent#{@getComposedLabel()}"
	getVariableClass: -> PCCLocalVariable
	getAllArgumentContainers: (compiler, explicitArgumentContainers, instanceContainer) ->
		argumentContainers = explicitArgumentContainers[..]
		if @isClassProcedure()
			#argumentContainers.unshift(compiler.getVariable("i_g").getContainer(compiler)) if @isMonitorProcedure()
			if not instanceContainer
				instanceContainer = compiler.getVariableWithName("i", null, true).getContainer(compiler) 
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
			guard = compiler.getVariableWithName("guard", null, true)
			compiler.emitOutput("unlock", guard.getContainer(compiler))
		compiler.emitExit()
			
		
		
		



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

PCTType::getCCSType = ->
	switch @kind
		when PCTType.INT then PCCType.INT
		when PCTType.BOOL then PCCType.BOOL
		when PCTType.STRING then PCCType.STRING
		when PCTType.CHANNEL then throw new Error("Unexpected type kind!")
		when PCTType.ARRAY then throw new Error("Unexpected type kind!")
		when PCTType.MONITOR then PCCType.INT
		when PCTType.STRUCTURE then PCCType.INT
		when PCTType.MUTEX then PCCType.INT
		when PCTType.CONDITION then PCCType.INT
		when PCTType.PROCEDURE then throw new Error("Unexpected type kind!")
		when PCTType.TYPE then throw new Error("Unexpected type kind!")
		when PCTType.MAINAGENT then throw new Error("Unexpected type kind!")
		when PCTType.AGENT then PCCType.INT
		when PCTType.WILDCARD then throw new Error("Unexpected type kind!")
		else PCCType.VOID

PCTArrayType::getCCSType = -> new PCCType(@elementsType.getCCSType())
PCTChannelType::getCCSType = -> new PCCType(@channelledType.getCCSType())
PCTProcedureType::getCCSType = -> @returnType.getCCSType()
PCTProcedureType::getCCSArgumentTypes = -> t.getCCSType() for t in @argumentTypes

###
PCTArrayType::fulfillAssignment = (compiler, container) ->
	result = compiler.getFreshContainer(container.ccsType)
	compiler.emitInput("array_copy", container, result)
	result
###
PCTArrayType::createContainer = (compiler, containers=[]) ->
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
PCTType::requiresCustomDefaultContainer = -> 
	@kind != PCTType.INT and @kind != PCTType.BOOL and @kind != PCTType.STRING
PCTType::createContainer = (compiler, container) ->
	return container if container
	throw new Error("No default value for agents available") if @kind == PCTType.AGENT
	throw new Error("No default value for void available") if @kind == PCTType.VOID
	if @kind == PCTType.MUTEX
		result = compiler.getFreshContainer(PCCType.INT)
		compiler.emitInput("mutex_create", null, result)
		result
	else if @kind == PCTType.STRING
		new PCCConstantContainer("")
	else
		new PCCConstantContainer(0)
PCTChannelType::createContainer = (compiler, container) ->
	return container if container
	res = compiler.getFreshContainer(@getCCSType())
	buffered = @capacity != PCChannelType.CAPACITY_UNKNOWN and @capacity != 0
	channel = "channel#{if buffered then @capacity else ""}_create"
	compiler.emitInput(channel, null, res)
	#if buffered
		#compiler.emitOutput("channel_setDefault", res, @channelledType.getCCSType().getDefaultContainer())
	res
PCTClassType::createContainer = (compiler, container) ->
	return container if container
	result = compiler.getFreshContainer(PCCType.INT)
	compiler.emitInput("class_#{@identifier}_create", null, result)
	result


	



# Variables

class PCCVariableInfo extends PCVariable
	constructor: (node, name, type, @isInternal=false) -> super node, name, type
	getIdentifier: -> "#{if @isInternal then "#" else ""}#{@getName()}"	# default: x; internal: #x
	getSuggestedContainerName: -> @getName() + (if @isInternal then "H" else "L")
	 
PCCVariableInfo.getNameForInternalVariableWithName = (name) -> "#"+name

PCVariable::getSuggestedContainerName = -> @getName() + "L"
PCVariable::getCCSType = -> @type.getCCSType()
PCVariable::compileDefaultValue = (compiler) -> 
	if @node then @node.compileDefaultValue(compiler) else @type.createContainer(compiler)
PCCVariableInfo::getCCSType = -> if @type or not @isInternal then super else PCCType.INT
	
	

class PCCVariable extends PCCVariableInfo
	getContainer: (compiler) -> throw new Error("Not implemented!")
	setContainer: (compiler, container) -> throw new Error("Not implemented")

class PCCGlobalVariable extends PCCVariable
	accessorChannel: (set) -> "env_global_#{if set then "set" else "get"}_#{@getName()}"
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
		compiler.emitProcessApplication(@getEnvProcessName(), containers)
		control.setBranchFinished()
	emitConstructor: (compiler) ->
		compiler.beginProcessGroup(new PCCGroupable(@getEnvProcessName()), [@])
		@emitAccessors(compiler, [compiler.getVariableWithName(@getName())])
		compiler.endProcessGroup()
		compiler.beginProcessGroup(@)
		container = @compileDefaultValue(compiler)
		compiler.emitProcessApplication(@getEnvProcessName(), [container])
		compiler.endProcessGroup()
		compiler.emitSystemProcessApplication(@getProcessName(), [])
		
	getProcessName: -> "Env_global_#{@getName()}_cons"
	getEnvProcessName: -> "Env_global_#{@getName()}"

class PCCField extends PCCGlobalVariable
	accessorChannel: (set) -> "env_class_#{@parent.getName()}_#{if set then "set" else "get"}_#{@getName()}"
	getContainer: (compiler) ->
		if @getIdentifier() == "#guard"
			result = compiler.getFreshContainer(PCCType.INT)
			compiler.emitInput("env_class_get_guard", compiler.getVariableWithName("i", null, true).getContainer(compiler), result)
		else
			result = compiler.getFreshContainer(@type.getCCSType())
			compiler.emitInput(@accessorChannel(false), compiler.getVariableWithName("i", null, true).getContainer(compiler), result)
		result
	setContainer: (compiler, container) ->
		compiler.emitOutput(@accessorChannel(true), compiler.getVariableWithName("i", null, true).getContainer(compiler), container)
		null
	getEnvProcessName: -> "Env_class_#{@parent.getName()}"

class PCCInternalReadOnlyField extends PCCField
	emitAccessors: (compiler, variables, instance) ->
		local = compiler.getVariableWithName(@getIdentifier())
		containers = (v.getContainer(compiler) for v in variables)
		c = local.getContainer(compiler)
		compiler.emitOutput("env_class_guard", instance, c)
		compiler.emitProcessApplication(@getEnvProcessName(), containers)
	getContainer: (compiler) -> 
		result = compiler.getFreshContainer(PCCType.INT)
		compiler.emitInput("env_class_guard", compiler.getVariableWithName("i", null, true).getContainer(compiler), result)
		result
	setContainer: -> throw new Error("Setting container for read only variable!")
	

class PCCCondition extends PCCField
	constructor: (name, @expressionNode) -> super name, new PCTType(PCTType.CONDITION)

class PCCLocalVariable extends PCCVariable
	getContainer: (compiler) -> compiler.getProcessFrame().getContainerForVariable(@getIdentifier())
	setContainer: (compiler, container) -> compiler.getProcessFrame().assignContainerToVariable(@getIdentifier(), container)








class PCCProgramController extends PCEnvironmentController
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
			res.push(proc) if proc instanceof PCProcedure
		res
	
	getUsedTypes: ->
		res = 
			arrays: {}
			channels: {}
		@root.getUsedTypes(res)
		res
	
	

PCEnvironmentNode::getUsedTypes = (res) ->
	c.getUsedTypes(res) for c in @children
	null
PCVariable::getUsedTypes = (res) ->
	@type.getUsedTypes(res)
PCTType::getUsedTypes = -> null
PCTArrayType::getUsedTypes = (res) ->
	res.arrays[@capacity] = true
	@elementsType.getUsedTypes(res)
	null
PCTChannelType::getUsedTypes = (res) ->
	res.channels[@getApplicableCapacity()] = true
	null
		

PCNode::collectAgents = (env) -> c.collectAgents(env) for c in @children
PCMonitor::collectAgents = (env) -> 
	env.beginClass(@name)
	super
	env.endClass()
PCStruct::collectAgents = (env) -> 
	env.beginClass(@name)
	super
	env.endClass()
PCProcedure::collectAgents = (env) -> 
	env.beginProcedure(@name)
	super
	env.endProcedure()

PCStartExpression::collectAgents = (env) -> env.processProcedureAsAgent(@children[0].getProcedure(env))




