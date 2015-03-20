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
	ToDo
###

PCTEnvironmentControllerInternalMainAgentName = "$mainAgent"

class PCTEnvironmentController
	constructor: ->
		@root = new PCTEnvironmentNode(null, "")		# global
		@classes = {}
		@_envStack = @root
		@blockCounter = 1
	
	getGlobal: -> @root

	openEnvironment: (node) ->
		node.__id = @blockCounter++
		child = new PCTEnvironmentNode(node, "##{node.__id}")
		child.__id = node.__id
		@_envStack.addChild(child)
		@_envStack = child
		child

	getEnvironment: (node, id) ->
		node = @_envStack.getBlockWithId(id)
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "BlockNotFound", "message" : "Block not found!"}) if not node
		@_envStack = node
		node

	closeEnvironment: ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "MissingEnvironment", "message" : "No open environment!"}) if not @_envStack instanceof PCTEnvironmentNode
		@_envStack.node.isReturnExhaustive = @_envStack.isReturnExhaustive()
		@_envStack = @_envStack.parent
	
	getClassWithName: (name) ->
		result = @classes[name]
		throw ({"line" : 0, "column" : 0, "wholeFile" : false, "name" : "UnknownClass", "message" : "Unknown class '#{name}'"}) if result == undefined
		result
	
	getAllClasses: -> @root.getAllClasses()
	
	getVariableWithName: (name, line, column) ->
		@_envStack.getVariableWithName(name, line, column)
	
	getProcedureWithName: (name, line, column) ->
		@_envStack.getProcedureWithName(name, line, column)

	getMainAgent: (line, column) ->
		@getProcedureWithName(PCTEnvironmentControllerInternalMainAgentName, line, column)
	
	getExpectedReturnValue: ->
		@_envStack.getExpectedReturnValue()

	isReturnExhaustive: -> @_envStack.isReturnExhaustive()

	setReturnExhaustive: -> @_envStack.setReturnExhaustive()

	unsetReturnExhaustive: -> @_envStack.unsetReturnExhaustive()
	
	
	processNewClass: (node, classType) ->
		tnode = new PCTClass(node, classType)
		@_processNewClass tnode
	
	_processNewClass: (node) ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : false, "name" : "Redeclaration", "message" : "Class #{node.getName()} already declared!"}) if @classes[node.getName()]
		@_envStack.addChild(node)
		@classes[node.getName()] = node
	
	beginClass: (className) ->
		try
			node = @getClassWithName(className)
		catch e
			e.line = @line
			e.column = @column
			throw e
		# throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "Error", "message" : "Node must not be null!"}) if not node
		@_envStack = node
		node
		
	endClass: ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "ClassError", "message" : "No class did begin!"}) if not @_envStack instanceof PCTClass
		@_envStack.node.isReturnExhaustive = @_envStack.isReturnExhaustive()
		@_envStack = @_envStack.parent
	
	
	
	beginNewProcedure: (node, procedureName, returnType, args) ->
		tnode = new PCTProcedure(node, procedureName, returnType, args)
		@_beginNewProcedure(tnode)
	
	_beginNewProcedure: (node) ->
		try
			@_envStack.getProcedureWithName(node.getName())
		catch
			@_envStack.addChild(node)
			@beginProcedure(node.getName())
			return
		throw ({"line" : 0, "column" : 0, "wholeFile" : false, "name" : "Redeclaration", "message" : "Procedure #{node.getName()} already declared!"})
	
	beginProcedure: (procedureName) ->
		try
			node = @_envStack.getProcedureWithName(procedureName)
			@_envStack = node
			node
		catch
			throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "Error", "message" : "Node must not be null!"}) if not node
	
	endProcedure: ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "ProcedureError", "message" : "No procedure did begin!"}) if not @_envStack instanceof PCTProcedure
		@_envStack.node.isReturnExhaustive = @_envStack.isReturnExhaustive()
		@_envStack = @_envStack.parent
	
	beginMainAgent: (node) ->
		try
			@_envStack.getProcedureWithName(PCTEnvironmentControllerInternalMainAgentName)
		catch
			@beginNewProcedure(node, PCTEnvironmentControllerInternalMainAgentName, new PCTType(PCTType.VOID), [])
			return
		@beginProcedure(PCTEnvironmentControllerInternalMainAgentName)

	_beginMainAgent: (node) ->
		try
			@_envStack.getProcedureWithName(PCTEnvironmentControllerInternalMainAgentName)
		catch
			@beginNewProcedure(node, PCTEnvironmentControllerInternalMainAgentName, new PCTType(PCTType.VOID), [])
			return
		throw ({"line" : node.line, "column" : node.column, "wholeFile" : false, "name" : "DuplicateMainAgent", "message" : "Main agent can't be declared twice!"})
	
	endMainAgent: ->
		@endProcedure()
	
	
	
	processNewVariable: (variable) ->
		@_processNewVariable(variable)
	
	_processNewVariable: (node) ->
		try
			@_envStack.getVariableWithName(node.getName())
		catch
			@_envStack.addChild(node)
			node
			return
		throw ({"line" : 0, "column" : 0, "wholeFile" : false, "name" : "Redeclaration", "message" : "Variable #{node.getName()} already declared!"})







class PCTEnvironmentNode
	constructor: (@node, @label) ->
		@parent = null
		@children = []
		@variables = {}
		@procedures = {}
		@blocks = {}
		@isRetExhaust = false
	
	addChild: (child) ->
		@children.push(child)
		child.parent = @
		child.isRetExhaust = @isRetExhaust
		if child instanceof PCTProcedure
			@procedures[child.getName()] = child
		else if child instanceof PCTVariable
			@variables[child.getIdentifier()] = child
		else if child instanceof PCTEnvironmentNode
			@blocks[child.__id] = child
		child
	getVariableWithName: (name, line, column) ->
		if not @variables[name]?
			throw ({"line" : line, "column" : column, "wholeFile" : false, "name" : "UndefinedVariable", "message" : "Variable '#{name}' wasn't declared."}) if not @parent?
			@parent.getVariableWithName(name, line, column)
		else
			@variables[name]
	getProcedureWithName: (name, line, column) ->
		if not @procedures[name]?
			throw ({"line" : line, "column" : column, "wholeFile" : false, "name" : "UndefinedProcedure", "message" : "Procedure '#{name}' wasn't declared."}) if not @parent?
			@parent.getProcedureWithName(name, line, column)
		else
			@procedures[name]
	getBlockWithId: (id) -> @blocks[id]
	getComposedLabel: -> "#{if @parent?.getComposedLabel?().length > 0 then "#{@parent.getComposedLabel()}_$" else ""}#{@label}"
	getAllClasses: ->
		result = []
		for c in @children
			result.push(c) if c instanceof PCTClass
		result
	getExpectedReturnValue: ->
		if @ instanceof PCTProcedure
			@returnType
		else
			if @parent?
				@parent.getExpectedReturnValue()
			else
				throw ({"line" : 0, "column" : 0, "wholeFile" : false, "name" : "InvalidLocation", "message" : "Return statements are only allowed inside procedures!"})
	isReturnExhaustive: -> @isRetExhaust
	setReturnExhaustive: -> @isRetExhaust = true
	unsetReturnExhaustive: -> @isRetExhaust = false


class PCTClass extends PCTEnvironmentNode
	constructor: (node, @type) ->
		@usedClassTypes = []
		super node, @type.identifier
	getName: -> @label
	isMonitor: -> @type.isMonitor()
	addUseOfClassType: (type) -> @usedClassTypes.push(type)
	getUsedClassTypes: ->
		result = []
		result.push(type) for type in @usedClassTypes
		result

class PCTProcedure extends PCTEnvironmentNode
	constructor: (node, name, @returnType, @arguments) ->
		super node, name		# string x PCType x PCTVariable*
		@variables[arg.getName()] = arg for arg in @arguments
	getName: -> @label
	#isStructProcedure: -> @parent instanceof PCStruct
	#isMonitorProcedure: -> @parent instanceof PCMonitor
	isClassProcedure: -> @parent instanceof PCTClass
	isMonitorProcedure: -> @parent instanceof PCTClass and @parent.isMonitor()





class PCTVariable
	constructor: (@node, name, @type) ->
		debugger if typeof @node == "string"
		@label = name
		@parent = null
	getName: -> @label
	getIdentifier: -> @label
	getComposedLabel: -> "#{if @parent then "#{@parent.getComposedLabel()}_$" else ""}#{@label}"

# TODO comment
class PCTCycleChecker
	constructor: (classTypes) ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "Error", "message" : "List of class types must not be empty!"}) if not classTypes?
		@classTypes = {}
		@classTypes[type.getName()] = type for type in classTypes
	cycleTraceForTypes: ->
		while Object.keys(@classTypes).length > 0
			for name, type of @classTypes
				trace = @cycleTraceForType(type, {}, new PCTTrace(null))
				return trace.toString() if trace
		null
	cycleTraceForType: (type, alreadyReachable, trace) ->
		trace.add(type)
		return trace if alreadyReachable[type.getName()]?
		alreadyReachable[type.getName()] = type
		if @classTypes[type.getName()]?
			delete @classTypes[type.getName()]
		else
			return null
		for t in type.getUsedClassTypes()
			innerAlreadyReachable = {}
			innerAlreadyReachable[name] = type for name, type of alreadyReachable
			result = @cycleTraceForType(t, innerAlreadyReachable, new PCTTrace(trace))
			return result if result?
		null

# TODO comment
class PCTTrace
	constructor: (trace) ->
		@elements = []
		if trace?
			@elements.push(elem) for elem in trace.elements
	add: (element) -> @elements.push(element)
	toString: ->
		result = "#{@elements[0].getName() if @elements.length > 0}"
		"#{result += " -> " + element.getName() for element in @elements[1..] by 1}"
		result

