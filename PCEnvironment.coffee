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
		throw new Error("Block not found!") if not node
		@_envStack = node
		node

	closeEnvironment: ->
		throw new Error("No open environment!") if not @_envStack instanceof PCTEnvironmentNode
		@_envStack.node.isReturnExhaustive = @_envStack.isReturnExhaustive()
		@_envStack = @_envStack.parent
	
	getClassWithName: (name) ->
		result = @classes[name]
		throw new Error("Unknown class '#{name}'") if result == undefined
		result
	
	getAllClasses: -> @root.getAllClasses()
	
	getVariableWithName: (name, line, column) ->
		@_envStack.getVariableWithName(name, line, column)
	
	getProcedureWithName: (name, line, column) ->
		@_envStack.getProcedureWithName(name, line, column)
	
	getExpectedReturnValue: ->
		@_envStack.getExpectedReturnValue()

	isReturnExhaustive: -> @_envStack.isReturnExhaustive()

	setReturnExhaustive: -> @_envStack.setReturnExhaustive()

	unsetReturnExhaustive: -> @_envStack.unsetReturnExhaustive()
	
	
	processNewClass: (node, classType) ->
		tnode = new PCTClass(node, classType)
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
		throw new Error("No class did begin!") if not @_envStack instanceof PCTClass
		@_envStack.node.isReturnExhaustive = @_envStack.isReturnExhaustive()
		@_envStack = @_envStack.parent
	
	
	
	beginNewProcedure: (node, procedureName, returnType, args) ->
		tnode = new PCTProcedure(node, procedureName, returnType, args)
		@_beginNewProcedure(tnode)
	
	_beginNewProcedure: (node) ->
		@_envStack.addChild(node)
		@beginProcedure(node.getName())
	
	beginProcedure: (procedureName) ->
		try
			node = @_envStack.getProcedureWithName(procedureName)
			@_envStack = node
			node
		catch
			throw new Error("Node must not be null!") if not node
	
	endProcedure: ->
		throw new Error("No procedure did begin!") if not @_envStack instanceof PCTProcedure
		@_envStack.node.isReturnExhaustive = @_envStack.isReturnExhaustive()
		@_envStack = @_envStack.parent
	
	beginMainAgent: (node) ->
		try
			@_envStack.getProcedureWithName("#mainAgent")
		catch
			@beginNewProcedure(node, "#mainAgent", new PCTType(PCTType.VOID), [])
			return
		@beginProcedure("#mainAgent")

	_beginMainAgent: (node) ->
		try
			@_envStack.getProcedureWithName("#mainAgent")
		catch
			@beginNewProcedure(node, "#mainAgent", new PCTType(PCTType.VOID), [])
			return
		throw ({"line" : node.line, "column" : node.column, "message" : "Main agent can't be declared twice!"})
	
	endMainAgent: ->
		@endProcedure()
	
	
	
	processNewVariable: (variable) ->
		@_processNewVariable(variable)
	
	_processNewVariable: (node) ->
		@_envStack.addChild(node)
		node







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
			throw ({"line" : line, "column" : column, "message" : "Variable '#{name}' wasn't declared."}) if not @parent?
			@parent.getVariableWithName(name, line, column)
		else
			@variables[name]
	getProcedureWithName: (name, line, column) ->
		if not @procedures[name]?
			throw ({"line" : line, "column" : column, "message" : "Procedure '#{name}' wasn't declared."}) if not @parent?
			@parent.getProcedureWithName(name, line, column)
		else
			@procedures[name]
	getBlockWithId: (id) -> @blocks[id]
	getComposedLabel: -> "#{if @parent then "#{@parent.getComposedLabel()}_" else ""}#{@label}"
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
				throw new Error("Return statements are only allowed inside procedures!")
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
	isClassProcedure: -> @parent instanceof PCClass
	isMonitorProcedure: -> @parent instanceof PCClass and @parent.isMonitor()





class PCTVariable
	constructor: (@node, name, @type) ->
		debugger if typeof @node == "string"
		@label = name
		@parent = null
	getName: -> @label
	getIdentifier: -> @label
	getComposedLabel: -> "#{if @parent then "#{@parent.getComposedLabel()}_" else ""}#{@label}"

# TODO comment
class PCTCycleChecker
	constructor: (classTypes) ->
		throw new Error("List of class types must not be empty!") if not classTypes?
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
		return null if not delete @classTypes[type.getName()]
		for t in type.getUsedClassTypes()
			result = @cycleTraceForType(t, alreadyReachable, new PCTTrace(trace))
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

