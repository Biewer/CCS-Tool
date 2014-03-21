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
		@_envStack = @_envStack.parent
	
	
	
	beginNewProcedure: (node, procedureName, returnType, args) ->
		tnode = new PCTProcedure(node, procedureName, returnType, args)
		@_beginNewProcedure(tnode)
	
	_beginNewProcedure: (node) ->
		@_envStack.addChild(node)
		@beginProcedure(node.getName())
	
	beginProcedure: (procedureName) ->
		node = @_envStack.getProcedureWithName(procedureName)
		throw new Error("Node must not be null!") if not node
		@_envStack = node
		node
	
	endProcedure: ->
		throw new Error("No procedure did begin!") if not @_envStack instanceof PCTProcedure
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







class PCTEnvironmentNode
	constructor: (@node, @label) ->
		@parent = null
		@children = []
		@variables = {}
		@procedures = {}
	
	addChild: (child) -> 
		@children.push(child)
		child.parent = @
		if child instanceof PCTProcedure
			@procedures[child.getName()] = child
		else if child instanceof PCTVariable
			@variables[child.getIdentifier()] = child
		child
	getVariableWithName: (name) -> @variables[name]
	getProcedureWithName: (name) -> @procedures[name]
	getComposedLabel: -> "#{if @parent then "#{@parent.getComposedLabel()}_" else ""}#{@label}"
	getAllClasses: -> 
		result = []
		for c in @children
			result.push(c) if c instanceof PCTClass
		result


class PCTClass extends PCTEnvironmentNode
	constructor: (node, @type) -> super node, @type.identifier
	getName: -> @label
	isMonitor: -> @type.isMonitor()


class PCTProcedure extends PCTEnvironmentNode
	constructor: (node, name, @returnType, @arguments) -> super node, name		# string x PCType x PCTVariable*
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

	












		
		