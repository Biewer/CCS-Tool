###
	This class manages all variables, classes, procedures and the relationships between each other that occur in a PseuCo program.
###

class PCCProgramController extends PCCControlElement
	constructor: (@program) ->
		@nodeStack = [@]
		@classes = {}
		
		@addChild(new PCCGlobal())
		super ""
	
	
	_getCurrentTarget: -> @nodeStack[@nodeStack.length-1]
	
	
	# Accessing information
	
	getClassWithName: (name) ->
		result = @classes[name]
		throw new Error("Unknown class") if result == undefined
		result
	
	getGlobal: ->
		@children[0]
	
	
	
	# Collecting information
	
	beginClass: (className, isMonitor) ->
		node = if isMonitor then new PCCMonitor(className) else new PCCStruct(className)
		@_getCurrentTarget.addChild(node)
		@nodeStack.push(node)
		@classes[className] = node
		node
		
	endClass: ->
		node = @_getCurrentTarget()
		throw new Error("No class did begin!") if not (node instanceof PCCMonitor or node instanceof PCCStruct)
		@nodeStack.pop()
	
	beginProcedure: (procedureName, argumentNames) ->
		node = new PCCProcedure(procedureName, argumentNames)
		@_getCurrentTarget.addChild(node)
		@nodeStack.push(node)
		node
	
	endProcedure: ->
		node = @_getCurrentTarget()
		throw new Error("No procedure did begin!") if not node instanceof PCCProcedure
		@nodeStack.pop()
	
	processNewIdentifier: (identifier) ->					# Different behaviour depending on context (global, class, local variable)
		varClass = @_getCurrentTarget.getVariableClass()
		node = new varClass(identifier)
		@_getCurrentTarget.addChild(node)
		node







class PCCControlElement
	constructor: (@label) ->
		@parent = null
		@children = []
		@variables = {}
		@procedures = {}
	addChild: (child) -> 
		@children.push(child)
		child.parent = @
		if child instanceof PCCProcedure
			@procedures[child.getName()] = child
		else if child instanceof PCCVariable
			@variables[child.getName()] = child
		child
	getVariableWithName: (name) -> @variables[name]
	getProcedureWithName: (name) -> @procedures[name]
	getComposedLabel: -> "#{if @parent then "#{@parent.getComposedLabel()}_" else ""}#{@label}"
	getVariableClass: -> throw new Error("Variables are not supported at this level")

class PCCGlobal extends PCCControlElement
	constructor: -> super "global"
	getVariableClass: -> PCCGlobalVariable
	
	compilerGetVariable: (compiler, identifier) -> @getVariableWithName(identifier)
	compilerGetProcedure: (compiler, identifier) -> @getProcedureWithName(identifier)
	compilerHandleNewIdentifierWithDefaultValueCallback: (compiler, identifier, callback, context) -> 
		variable = @getVariableWithName(identifier)
		throw new Error("Unexpected new identifier found!") if variable == undefined
		variable.emitConstructor(compiler, callback, context)
		

class PCCClass extends PCCControlElement	#abstract
	constructor: (name) -> super name
	getName: -> @label
	getVariableClass: -> PCCField
	
	compilerGetVariable: (compiler, identifier) -> @getVariableWithName(identifier)
	compilerGetProcedure: (compiler, identifier) -> @getProcedureWithName(identifier)
	compilerHandleNewIdentifierWithDefaultValueCallback: (compiler, identifier, callback, context) ->  # ignore
	
	emitConstructor: ->
	
	emitEnvironment: ->
		

class PCCMonitor extends PCCClass

class PCCStruct extends PCCClass
		
class PCCProcedure extends PCCControlElement
	constructor: (name, @arguments) -> super name		# string x string[]
	getName: -> @label
	getProcessName: -> "Proc_#{@getComposedLabel()}"
	getVariableClass: -> PCCLocalVariable
	isStructProcedure: -> @parent instanceof PCCStruct
	isMonitorProcedure: -> @parent instanceof PCCMonitor
	isClassProcedure: -> @isStructProcedure() or @isMonitorProcedure()
	createCallProcess: (argumentContainers, instanceContainer) ->		# return[, instance[, guard]], ...
		argumentContainers = argumentContainers[..]
		if @isClassProcedure()
			argumentContainers.unshift(PCCContainer.GUARD()) if @isMonitorProcedure()
			instanceContainer = PCCContainer.INSTANCE() if instanceContainer == null
			argumentContainers.unshift(instanceContainer)
		else
			throw new Error("Illegal instance value") if instance isnt null
		argumentContainers.unshift(PCCContainer.RETURN())
		new CCSProcessApplication(@getName(), argumentContainers)
		
		




# Variables (only leaves of PCCControlElement objects)

class PCCVariable
	constructor: (@identifier) ->
		@parent = null
	getContainer: (compiler) -> throw new Error("Not implemented!")
	setContainer: (compiler, container) -> throw new Error("Not implemented")

class PCCGlobalVariable extends PCCVariable
	accessorChannel: (set) -> "env_global_#{if set then "set" else "get"}_#{@identifier}"
	getContainer: (compiler) ->
		result = compiler.getFreshContainer()
		getter = new CCSPrefix(new CCSInput(@accessorChannel(false), result.identifier), new CCSStop())
		compiler.emitCCSProcess(getter)
		result
	setContainer: (compiler, container) ->
		setter = new CCSPrefix(new CCSOutput(@accessorChannel(true), container.ccsTree()), new CCSStop())
		compiler.emitCCSProcess(setter)
	emitAccessors: (compiler) ->
		channel = new CCSChannel(@accessorChannel(false))
		action = new CCSOutput(channel, new CCSVariableExpression(@identifier))
		rec = new CCSProcessApplication(@getEnvProcessName(), [new CCSVariableExpression(@identifier)])
		getter = new CCSPrefix(action, rec)
		channel = new CCSChannel(@accessorChannel(true))
		action = new CCSInput(channel, "t")
		rec = new CCSProcessApplication(@getEnvProcessName(), [new CCSVariableExpression("t")])
		setter = new CCSPrefix(action, rec)
		choice = new CCSChoice(getter, setter)
		compiler.emitCCSProcess(choice)
	emitConstructor: (compiler, callback, context) ->
		f = new PCCProcessFrame(@)		# set up frame for callback
		compiler.pushProcessFrame(f)
		container = callback(context)
		env = new CCSProcessDefinition(@getEnvProcessName(), new CCSStop(), [@identifier])
		compiler.pushCCSProcessDefinition(env)
		@emitAccessors()
		compiler.popCCSProcessDefinition()
		compiler.emitCCSProcess(new CCSProcessApplication(@getEnvProcessName(), container))
		compiler.popProcessFrame()
		
	getProcessName: -> "Env_global_#{@identifier}_cons"
	getEnvProcessName: -> "Env_global_#{@identifier}"

class PCCField extends PCCGlobalVariable
	accessorChannel: (set) -> "env_class_#{@parent.getName()}_#{if set then "set" else "get"}_#{@identifier}"

class PCCLocalVariable extends PCCVariable
	getContainer: (compiler) -> compiler.getProcessFrame().getContainerForVariable(@identifier)
	setContainer: (compiler, container) -> compiler.getProcessFrame().assignContainerToVariable(@identifier, container)




