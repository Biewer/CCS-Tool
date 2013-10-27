###
	ToDo
###

class PCEnvironmentController
	constructor: ->
		@root = new PCEnvironmentNode(null, "")		# global
		@classes = {}
		@_envStack = @root
	
	getGlobal: -> @root
	
	getClassWithName: (name) ->
		result = @classes[name]
		throw new Error("Unknown class") if result == undefined
		result
	
	getAllClasses: -> @root.getAllClasses()
	
	getVariableWithName: (name) ->
		@_envStack.getVariableWithName(name)
	
	getProcedureWithName: (name) ->
		@_envStack.getProcedureWithName(name)
	
	
	processNewClass: (node, classType) ->
		tnode = new PCClass(node, classType)
		@_processNewClass tnode
	
	_processNewClass: (node) ->
		throw new Error("Class already registered!") if @classes[node.getName()]
		@_envStack.addChild(node)
		@classes[node.getName()] = node
	
	beginClass: (className) ->
		node = @getClassWithName(className)
		throw new Error("Node must not be null!") if not node
		@_envStack = node
		node
		
	endClass: ->
		throw new Error("No class did begin!") if not @_envStack instanceof PCClass
		@_envStack = @_envStack.parent
	
	
	
	beginNewProcedure: (node, procedureName, returnType, args) ->
		tnode = new PCProcedure(node, procedureName, returnType, args)
		@_processNewProcedure(tnode)
	
	_beginNewProcedure: (node) ->
		@_envStack.addChild(node)
		@beginProcedure(node.getName())
	
	beginProcedure: (procedureName) ->
		node = @_envStack.getProcedureWithName(procedureName)
		throw new Error("Node must not be null!") if not node
		@_envStack = node
		node
	
	endProcedure: ->
		throw new Error("No procedure did begin!") if not @_envStack instanceof PCProcedure
		@_envStack = @_envStack.parent
	
	beginMainAgent: (node) -> 
		if @_envStack.getProcedureWithName("#mainAgent")
			@beginProcedure("#mainAgent")
		else
			@beginNewProcedure(node, "#mainAgent", new PCTType(PCTType.VOID), [])
	
	endMainAgent: ->
		@endProcedure()
	
	
	
	processNewVariable: (variable) ->			
		@_processNewVariable(variable)
	
	_processNewVariable: (node) ->
		@_envStack.addChild(node)
		node







class PCEnvironmentNode
	constructor: (@node, @label) ->
		@parent = null
		@children = []
		@variables = {}
		@procedures = {}
	
	addChild: (child) -> 
		@children.push(child)
		child.parent = @
		if child instanceof PCProcedure
			@procedures[child.getName()] = child
		else if child instanceof PCVariable
			@variables[child.getIdentifier()] = child
		child
	getVariableWithName: (name) -> @variables[name]
	getProcedureWithName: (name) -> @procedures[name]
	getComposedLabel: -> "#{if @parent then "#{@parent.getComposedLabel()}_" else ""}#{@label}"
	getAllClasses: -> 
		result = []
		for c in @children
			result.push(c) if c instanceof PCClass
		result


class PCClass extends PCEnvironmentNode
	constructor: (node, @type) -> super node, @type.identifier
	getName: -> @label
	isMonitor: -> @type.isMonitor()


class PCProcedure extends PCEnvironmentNode
	constructor: (node, name, @returnType, @arguments) -> super node, name		# string x PCType x PCVariable*
	getName: -> @label
	#isStructProcedure: -> @parent instanceof PCStruct
	#isMonitorProcedure: -> @parent instanceof PCMonitor
	isClassProcedure: -> @parent instanceof PCClass
	isMonitorProcedure: -> @parent instanceof PCClass and @parent.isMonitor()





class PCVariable
	constructor: (@node, name, @type) ->
		debugger if typeof @node == "string"
		@label = name
		@parent = null
	getName: -> @label
	getIdentifier: -> @label
	getComposedLabel: -> "#{if @parent then "#{@parent.getComposedLabel()}_" else ""}#{@label}"

	












		
		