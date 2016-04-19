`/* ###
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
### */`




###

	The following classes represent the PseuCo tree.

	toString returns the string representation of the tree with minimal brackets
	and correctly indented.

###


PCIndent = "   "
PCErrorList = []

###
# @brief Abstract class for nodes in the AST.
#
###
class PCNode
	constructor: (@line, @column, @children...) ->
		@parent = null
		c.parent = this for c in @children

	###
	# @ brief Recursive implementation for type checking.
	#
	###
	getType: (env) ->
		if not @_type
			@_type = @_getType(env)
			@_type = true if not @_type		# remember that we already checked type
		if @_type == true then null else @_type

	_collectEnvironment: (env) -> null

	###
	# @ brief Empty type check for abstract AST node.
	#
	###
	_getType: -> throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "Error", "message" : "Not implemented"})

	###
	# @ brief Is the node inside of a PCMonitor node?
	#
	###
	insideMonitor: ->
		if @parent
			@parent.insideMonitor()
		else
			false

	###
	# @ brief Is the node inside of a PCProcedure node?
	#
	###
	insideProcedure: ->
		if @parent
			@parent.insideProcedure()
		else
			false

	###
	# @ brief Is the node inside of a PCWhileStmt, PCDoStmt or PCForStmt node?
	#
	###
	insideLoop: ->
		if @parent
			@parent.insideLoop()
		else
			false

	###
	# @ brief Is the node inside of a PCSendExpression or PCReceiveExpression
	# node?
	#
	###
	usesSendOrReceiveOperator: ->
		for child in @children
			return true if child.usesSendOrReceiveOperator()
		false

###
# @brief Represents the entire pseuCo program.
#
# Children:
#   - PCMonitor
#   - PCStruct
#   - PCMainAgent
#   - PCDecl
#   - PCProcedure
#
###
class PCProgram extends PCNode
	globalDeclarations: (env) ->
		env.beginNewProcedure(@, "println", PCSimpleType.VOID, [])
		env.endProcedure()
		env.beginNewProcedure(@, "start", PCSimpleType.AGENT, [])
		env.endProcedure()
		env.beginNewProcedure(@, "join", PCSimpleType.VOID, [])
		env.endProcedure()
		env.beginNewProcedure(@, "lock", PCSimpleType.VOID, [])
		env.endProcedure()
		env.beginNewProcedure(@, "unlock", PCSimpleType.VOID, [])
		env.endProcedure()
		env.beginNewProcedure(@, "waitForCondition", PCSimpleType.VOID, [])
		env.endProcedure()
		env.beginNewProcedure(@, "signal", PCSimpleType.VOID, [])
		env.endProcedure()
		env.beginNewProcedure(@, "signalAll", PCSimpleType.VOID, [])
		env.endProcedure()

	collectClasses: (env) ->
		for c in @children
			try
				c.collectClasses(env)
			catch e
				if e and e.wholeFile?
					PCErrorList.push e

	collectEnvironment: (env) ->
		@globalDeclarations(env)
		for c in @children
			try
				c.collectEnvironment(env)
			catch e
				if e and e.wholeFile?
					PCErrorList.push e

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		@globalDeclarations(env)
		for child in @children
			try
				child._collectEnvironment(env)
			catch e
				if e and e.wholeFile?
					PCErrorList.push e

	toString: -> (o.toString("") for o in @children).join("\n")

	###
	# @brief Type checking.
	#
	# Collect all errors and initiate the type checking for the entire program.
	# A well typed pseuCo program must have a mainAgent. In addition no cyclic
	# dependencies for class types (monitor & struct) are allowed.
	#
	###
	_getType: (env) ->
		PCErrorList = []
		env = new PCTEnvironmentController() if not env
		@collectClasses(env)
		@_collectEnvironment(env)
		for declaration in @children
			try
				declaration.getType(env)
			catch e
				if e and e.wholeFile?
					PCErrorList.push e
		try
			env.getMainAgent()
		catch
			PCErrorList.push ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "UndefinedMainAgent", "message" : "You must define a main agent!"})
		cycleChecker = new PCTCycleChecker(env.getAllClasses())
		trace = cycleChecker.cycleTraceForTypes()
		if trace
			PCErrorList.push ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "ClassStructureCycle", "message" : "Monitor/structure cycle detected: #{trace}!"})
		if PCErrorList.length > 0
			throw ({"errorlist" : true, "data" : PCErrorList})

###
# @brief Representation of the main agent.
#
# Children:
#   - PCStatementBlock
#
# Code example:
#
# mainAgent{ ... }
#
###
class PCMainAgent extends PCNode
	collectClasses: (env) -> null

	collectEnvironment: (env) ->
		env.beginMainAgent(@)
		@children[0].collectEnvironment(env)
		env.endMainAgent()

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env._beginMainAgent(@)
		@children[0]._collectEnvironment(env)
		env.endMainAgent()

	toString: -> "mainAgent " + @children[0].toString("")

	###
	# @brief Type checking.
	#
	# Check recursively all statements inside the mainAgent's code block.
	#
	###
	_getType: (env) ->
		# env.beginProcedure("$mainAgent")
		env.beginMainAgent()
		@children[0].getType(env)
		env.endMainAgent()
		new PCTType(PCTType.MAINAGENT)

	insideProcedure: -> true

###
# @brief Representation of a procedure declaration and definition.
#
# Children:
#   - PCStatementBlock
#   - PCFormalParameter
#
# Code example:
#
# void example(int a, bool b, string c) {
#   // some code
# }
#
###
class PCProcedureDecl extends PCNode	# Children: PCFormalParameter objects
	constructor: (line, column, resultType, @name, body, parameters...) ->
		parameters.unshift(line, column, resultType, body)
		super parameters...

	getResultType: -> @children[0]

	getBody: -> @children[1]

	getArgumentCount: -> @children.length-2

	getArgumentAtIndex: (index) -> @children[index+2]

	collectClasses: (env) -> null

	collectEnvironment: (env) ->
		args = (p.getVariable(env) for p in @children[2...@children.length] by 1)
		env.beginNewProcedure(@, @name, @getResultType().getType(env).type, args)
		@getBody().collectEnvironment(env)
		env.endProcedure()

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		args = (parameter.getVariable(env) for parameter in @children[2..])
		try
			env.beginNewProcedure(@, @name, @getResultType().getType(env).type, args)
		catch e
			e.line = @line
			e.column = @column
			@redeclared = true
			throw e
		@getBody()._collectEnvironment(env)
		env.endProcedure()

	toString: (indent) -> "#{indent}#{@getResultType().toString()} #{@name}(#{((@getArgumentAtIndex(i).toString() for i in [0...@getArgumentCount()] by 1).join(", "))}) #{@getBody().toString(indent)}"

	###
	# @brief Type checking.
	#
	# Check recursively all children of a procedure node. A procedure
	# declaration must be return exhaustive i.e. every possible execution path
	# of the procedure contains a return statement.
	#
	###
	_getType: (env) ->
		if not @redeclared
			proc = env.beginProcedure(@name)
			child.getType(env) for child in @children
			env.setReturnExhaustive() if @getBody().isReturnExhaustive
			if not (@getResultType().type is PCSimpleType.VOID)
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "ReturnNotExhaustive", "message" : "In your procedure it might be possible that for some conditions no value gets returned."}) if not env.isReturnExhaustive()
			env.endProcedure()
			proc

	insideProcedure: -> true


###
# @brief Representation of a formal parameter.
#
# A formal parameter is the type and name of a parameter. In contrast an actual
# parameter is the value passed into a procedure.
#
# Children:
#   - PCSimpleType
#   - PCClassType
#   - PCArrayType
#   - PCChannelType
#
# Code example:
#
# See PCProcedureDecl.
#
###
class PCFormalParameter extends PCNode
	constructor: (line, column, type, @identifier) -> super line, column, type

	getVariable: (env) -> new PCTVariable(@, @identifier, @children[0].getType(env).type)

	toString: -> @children[0].toString() + " " + @identifier

	# Type checking
	_getType: (env) -> null # already done in `collectEnvironment` of `PCProcedureDecl`

###
# @brief Representation of the declaration of a monitor.
#
# Children:
#   - PCProcedureDecl
#   - PCConditionDecl
#   - PCDecl
#
# Code example:
#
# monitor Example {
#   int x;
#
#   condition gez with (x >= 0);
#
#   int getX() {
#     return x;
#   }
# }
#
###
class PCMonitor extends PCNode
	constructor: (@name, declarations...) -> super declarations...

	collectClasses: (env) ->
		try
			env.processNewClass(@, new PCTClassType(true, @name))
		catch e
			e.line = @line
			e.column = @column
			throw e

	collectEnvironment: (env) ->
		env.beginClass(@name)
		c.collectEnvironment(env) for c in @children
		env.endClass()

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.beginClass(@name)
		child._collectEnvironment(env) for child in @children
		env.endClass()

	toString: -> "monitor #{@name} {\n#{ (o.toString(PCIndent) for o in @children).join("\n") }\n}"

	###
	# @brief Type checking.
	#
	# Check recursively all children of a monitor node. Store the class names of
	# all used class types for later use in the cyclic class dependency
	# detection.
	#
	###
	_getType: (env) ->
		env.beginClass(@name)
		child.getType(env) for child in @children
		env.endClass()
		try
			monitor = env.getClassWithName(@name)
		catch e
			e.line = @line
			e.column = @column
			throw e
		for variable in monitor.children
			if variable.type instanceof PCTClassType
				try
					monitor.addUseOfClassType(env.getClassWithName(variable.type.identifier))
				catch e
					e.line = @line
					e.column = @column
					throw e
		new PCTType(PCTType.VOID)

	insideMonitor: -> true

###
# @brief Representation of the declaration of a record.
#
# Children:
#   - PCProcedureDecl
#   - PCConditionDecl
#   - PCDecl
#
# Code example:
#
# struct Example {
#   int x;
#
#   void setX(int value) {
#     x = value;
#   }
#
#   int getX() {
#     return x;
#   }
# }
#
###
class PCStruct extends PCNode
	constructor: (@name, declarations...) -> super declarations...

	collectClasses: (env) ->
		try
			env.processNewClass(@, new PCTClassType(false, @name))
		catch e
			e.line = @line
			e.column = @column
			throw e

	collectEnvironment: (env) ->
		env.beginClass(@name)
		c.collectEnvironment(env) for c in @children
		env.endClass()

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.beginClass(@name)
		child._collectEnvironment(env) for child in @children
		env.endClass()

	toString: -> "struct #{@name} {\n#{ (o.toString(PCIndent) for o in @children).join("\n") }\n}"

	###
	# @brief Type checking.
	#
	# Check recursively all children of a struct node. Store the class names of
	# all used class types for later use in the cyclic class dependency
	# detection.
	#
	###
	_getType: (env) ->
		env.beginClass(@name)
		child.getType(env) for child in @children
		env.endClass()
		try
			struct = env.getClassWithName(@name)
		catch e
			e.line = @line
			e.column = @column
			throw e
		for variable in struct.children
			if variable.type instanceof PCTClassType
				try
					struct.addUseOfClassType(env.getClassWithName(variable.type.identifier))
				catch e
					e.line = @line
					e.column = @column
					throw e
		new PCTType(PCTType.VOID)

###
# @brief Representation of the declaration of a condition.
#
# Children:
#   - PCExpression
#
# Code example:
#
# See PCMonitor.
#
###
class PCConditionDecl extends PCNode	# condition <id> with <boolean expression>
	constructor: (line, column, @name, expression) -> super line, column, expression

	getExpression: -> @children[0]

	collectEnvironment: (env) ->
		try
			env.processNewVariable(new PCTVariable(@, @name, new PCTType(PCTType.CONDITION)))
		catch e
			e.line = @line
			e.column = @column
			throw e

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> @collectEnvironment(env)

	toString: (indent) -> "#{indent}condition #{@name} with #{@children[0].toString()};"

	###
	# @brief Type checking.
	#
	# Declaration of conditions is only allowed inside a monitor. The condition
	# must be of boolean type.
	#
	###
	_getType: (env) ->
		type = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidLocation", "message" : "Conditions can only be declared inside monitors!"}) if not @insideMonitor()
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Expressions assigned to condition must be boolean, not #{type}"}) if not type.isEqual(new PCTType(PCTType.BOOL))
		null

###
# @brief Representation of a variable declaration.
#
# The variable can be of any type i.e. base type, array type or class type. In
# addition each variable can be initialized.
#
# Children:
#   - PCSimpleType
#   - PCClassType
#   - PCArrayType
#   - PCChannelType
#   - PCVariableDeclarator
#
# Code example:
#
# int x = 1, y = 2;
# bool z;
#
###
class PCDecl extends PCNode
	constructor: (@isStatement, children...) -> super children...

	getTypeNode: -> @children[0]

	getDeclarators: -> @children[1..]

	collectClasses: (env) -> null

	collectEnvironment: (env) ->
		@type = @children[0].getType(env).type

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> @collectEnvironment(env)

	toString: (indent) ->
		res = indent + @children[0].toString() + " " + @children[1].toString()	# ToDo: Multiple declarators
		res += ";" if @isStatement
		res

	###
	# @brief Type checking.
	#
	# In a definition of a variable (declaration + initialization) the
	# expression used for the initialization must match the type of the declared
	# variable.
	#
	# The declaration of an agent must be initialized.
	#
	###
	_getType: (env) ->
		@children[i].collectEnvironment(env, @type) for i in [1...@children.length] by 1
		if @type.isEqual(new PCTType(PCTType.MUTEX))
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "OldSyntax", "message" : "You have used an old syntax. The type named \"mutex\" was renamed to \"lock\". For a complete list of changes look <a href=\"#/help#pseuco-syntax-migration\">here</a>."})
		for child in @children[1..]
			type = child._getType(env, @type)
			if type? and not @type.isEqual(type)
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You can't initialize variable of type #{@type} with value of type #{type}"})
		if @type.getBaseType().isEqual(new PCTType(PCTType.AGENT))
			for child in @children[1..]
				init = child.getInitializer()
				if not init? or init.isUncompletedArray is true
					throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "UncompleteInitialization", "message" : "Agent declarations must be initialized (uncomplete initializations aren't allowed)."})
		null

###
# @brief TODO Fill in the documentation.
#
# PCDeclStmt is temporary available for convenience reasons!
#
###
class PCDeclStmt extends PCDecl
	constructor: (children...) -> super true, children...
#	toString: (indent) -> super + ";"

###
# @brief Representation of the declarations of a declaration statement.
#
# Children:
#   - PCVariableInitializer
#
# Code example:
#
# See PCDecl.
#
###
class PCVariableDeclarator extends PCNode
	constructor: (line, column, @name, initializer) -> (if initializer then super line, column, initializer else super line, column, []...)

	getInitializer: -> if @children.length > 0 then @children[0] else null

	getTypeNode: -> @parent.getTypeNode()

	collectEnvironment: (env, type) ->
		try
			env.processNewVariable(new PCTVariable(@, @name, type))
		catch e
			e.line = @line
			e.column = @column
			throw e

	toString: ->
		res = @name
		res += " = #{@children[0].toString()}" if @children.length > 0
		res

	###
	# @brief Type checking.
	#
	# Check recursively.
	#
	###
	_getType: (env, targetType) ->
		if @children.length > 0
			@children[0]._getType(env, targetType)
		else
			null

###
# @brief Representation of the initialization of a variable.
#
# Children:
#   - PCExpression
#
# Code example:
#
# See PCDecl.
#
###
class PCVariableInitializer extends PCNode
	constructor: (line, column, @isUncompletedArray=false, children...) -> super line, column, children...

	isArray: -> !(@children[0] instanceof PCExpression)

	getTypeNode: -> @parent.getTypeNode()

	toString: ->
		if @children[0] instanceof PCExpression
			"#{@children[0].toString()}"
		else
			"{#{ (o.toString() for o in @children).join(", ") }#{ if @isUncompletedArray then "," else "" }}"

	###
	# @brief Type checking.
	#
	# In pseuCo empty array initialization are not allowed. A valid
	# initialization may only contain elements of the same type, the base type
	# of the declared array.
	#
	###
	_getType: (env, targetType) ->
		if @children.length is 0
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "EmptyInitialization", "message" : "Empty array initializations aren't allowed!"})
			type = targetType
		else
			if @isArray()
				type = @children[0]._getType(env, targetType.elementsType)
				for child in @children[1..]
					childType = child._getType(env, targetType.elementsType)
					throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Types of elements of an array must be equal! Found #{type} and #{childType}"}) if not type.isEqual(childType)
				if @isUncompletedArray
					type = new PCTArrayType(type, targetType.capacity)
				else
					type = new PCTArrayType(type, @children.length)
			else
				type = @children[0].getType(env)
		type

# -- TYPES --

###
# @brief Representation of an array type.
#
# Children:
#   - PCArrayType
#   - PCSimpleType
#   - PCChannelType
#   - PCClassType
#
# Code example:
#
# int[10]
# bool[2][2][2]
#
###
class PCArrayType extends PCNode
	constructor: (line, column, baseType, @size) -> super line, column, baseType

	###
	# @brief Type checking.
	#
	# Construction of correct type.
	#
	###
	_getType: (env) -> new PCTTypeType(new PCTArrayType(@children[0].getType(env).type, @size))

	toString: ->
		front = "#{@children[0]}"
		pos = front.indexOf("[")
		if pos is -1
			return "#{front}[#{@size}]"
		else
			end = front.substring(pos)
			front = front.slice(0, pos)
			return "#{front}[#{@size}]#{end}"

# - Non-Array Type
###
# @brief TODO Fill in the documentation.
#
# Abstract node.
#
###
class PCBaseType extends PCNode
	constructor: (line, column) -> super line, column, []...

###
# @brief Representation of a base type.
#
# Children:
#   - none
#
# Code example:
#
# int
# bool
# void
# string
#
###
class PCSimpleType extends PCBaseType
	constructor: (line, column, @type) ->
		throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "InvalidType", "message" : "Unknown type"}) if @type < 0 or @type > 6
		super line, column, []...

	###
	# @brief Type checking.
	#
	# Construction of correct type.
	#
	###
	_getType: -> new PCTTypeType(new PCTType(PCSimpleType.typeToTypeKind(@type)))

	toString: -> PCSimpleType.typeToString(@type)

PCSimpleType.VOID = 0
PCSimpleType.BOOL = 1
PCSimpleType.INT = 2
PCSimpleType.STRING = 3
PCSimpleType.LOCK = 4
PCSimpleType.MUTEX = 5
PCSimpleType.AGENT = 6

PCSimpleType.typeToString = (type) ->
	switch type
		when PCSimpleType.VOID then "void"
		when PCSimpleType.BOOL then "bool"
		when PCSimpleType.INT then "int"
		when PCSimpleType.STRING then "string"
		when PCSimpleType.LOCK then "lock"
		when PCSimpleType.MUTEX then "mutex"
		when PCSimpleType.AGENT then "agent"
		else throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "InvalidType", "message" : "Unknown type!"})

PCSimpleType.typeToTypeKind = (type) ->
	switch type
		when PCSimpleType.MUTEX then PCTType.MUTEX
		when PCSimpleType.LOCK then PCTType.LOCK
		when PCSimpleType.AGENT then PCTType.AGENT
		when PCSimpleType.VOID then PCTType.VOID
		when PCSimpleType.BOOL then PCTType.BOOL
		when PCSimpleType.INT then PCTType.INT
		when PCSimpleType.STRING then PCTType.STRING
		else throw ({"line" : 0, "column" : 0, "wholeFile" : true, "name" : "InvalidType", "message" : "Unknown type!"})

###
# @brief Representation of a channel type.
#
# Children:
#   - none
#
# Code example:
#
# intchan
# boolchan100
#
###
class PCChannelType extends PCNode
	constructor:(line, column, @valueType, @capacity) -> super line, column, []...

	###
	# @brief Type checking.
	#
	# Construction of correct type.
	#
	###
	_getType: -> new PCTTypeType(new PCTChannelType(new PCTType(PCSimpleType.typeToTypeKind(@valueType)), @capacity))

	toString: -> "#{PCSimpleType.typeToString(@valueType)}chan#{ if @capacity != PCChannelType.CAPACITY_UNKNOWN then @capacity else "" }"

PCChannelType.CAPACITY_UNKNOWN = -1

###
# @brief Representation of a composed type.
#
# Children:
#   - none
#
# Code example:
#
# Test a;
#
# struct Test { ... }
#
###
class PCClassType extends PCBaseType
	constructor: (line, column, @className) -> super line, column, []...

	###
	# @brief Type checking.
	#
	# Construction of correct type.
	#
	###
	_getType: (env) ->
		try
			new PCTTypeType(env.getClassWithName(@className).type)
		catch e
			e.line = @line
			e.column = @column
			throw e

	toString: -> @className

# -- EXPRESSIONS --
###
# @brief TODO Fill in the documentation.
#
# Abstract node.
#
###
class PCExpression extends PCNode
	childToString: (i=0, diff=0) ->			# diff helps to consider implicit left or right breaks. e.g.: a + b -> diff(a)==0 (implicit left) and diff(b)==1
		res = @children[i].toString()
		res = "(#{res})" if @getPrecedence()+diff > @children[i].getPrecedence()
		res

###
# @brief Representation of an expression for an agent start.
#
# Children:
#   - PCExpression
#
# Code example:
#
# void test() { ... }
#
# mainAgent {
#   start test();
# }
#
###
class PCStartExpression extends PCExpression
	getPrecedence: -> 42

	toString: -> "start (#{@childToString(0)})"

	###
	# @brief Type checking.
	#
	# Starting agents in pseuCo is only possible inside a procedure.
	#
	###
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidLocation", "message" : "Start primitives are only allowed in procedures!"}) if not @insideProcedure()
		@children[0].getType(env)
		new PCTType(PCTType.AGENT)

###
# @brief Representation of an assignment expression.
#
# Children:
#   - PCExpression
#
# Code example:
#
# int x;
# x = 1;
# x += 4;
#
###
class PCAssignExpression extends PCExpression
	constructor: (line, column, destination, @operator, expression) -> super line, column, destination, expression

	getDestination: -> @children[0]

	getExpression: -> @children[1]

	getPrecedence: -> 39

	toString: -> "#{@getDestination().toString()} #{@operator} #{@childToString(1)}"

	###
	# @brief Type checking.
	#
	# Check whether or not the expression that will be assigned matches the type
	# of the variable that is assigned.
	#
	# The += assignment can only be applied to variables of type int or string.
	#
	# Any assignment operator other than = can only be applied to variables of
	# type int.
	#
	###
	_getType: (env) ->
		dest = @children[0].getType(env)
		exp = @children[1].getType(env)
		err = ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You tried to assign #{exp} to #{dest}"})
		if @operator is "+="
			if exp.isEqual(new PCTType(PCTType.STRING))
				throw err if not dest.isEqual(new PCTType(PCTType.STRING))
			else if exp.isEqual(new PCTType(PCTType.INT))
				throw err if not dest.isEqual(new PCTType(PCTType.INT)) and not dest.isEqual(new PCTType(PCTType.STRING))
			else
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operator '+=' is only allowed with integers and strings, but not #{exp}"})
			return dest
		else if @operator is not "="
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operator '#{op}' is only allowed with integers, but not #{dest}"}) if not dest.isEqual(new PCTType(PCTType.INT))
		throw err if not exp.isAssignableTo(dest)
		return dest

###
# @brief Representation of the destination of an assignment.
#
# Children:
#   - PCExpression
#
# Code example:
#
# See PCAssignExpression.
#
###
class PCAssignDestination extends PCNode	# Variable or array element
	constructor: (@identifier, arrayIndexExpressions...) -> super arrayIndexExpressions...

	toString: -> "#{@identifier}#{("[#{o.toString()}]" for o in @children.slice(0).reverse()).join("")}"

	###
	# @brief Type checking.
	#
	# If the destination of an assignment is an array expression check whether
	# the variable has array type and whether each expression inside the access
	# brackets is of type int.
	#
	###
	_getType: (env) ->
		type = env.getVariableWithName(@identifier, @line, @column).type
		for child in @children
			childType = child.getType(env)
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You use array access on a non-array: #{type}"}) if not (type instanceof PCTArrayType)
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Array index must be an integer value, not #{childType}"}) if not childType.isEqual(new PCTType(PCTType.INT))
			type = type.elementsType
		type

###
# @brief Representation of expression for sending data via a channel.
#
# Children:
#   - PCExpression
#
# Code example:
#
# chn <! 42;
#
###
class PCSendExpression extends PCExpression
	getPrecedence: -> 39

	toString: -> "#{@childToString(0, 1)} <! #{@childToString(1)}"

	###
	# @brief Type checking.
	#
	# The left hand side of a send expression must be of channel type. If it is
	# the expression of the right hand side needs to match the base type of the
	# channel.
	#
	###
	_getType: (env) ->
		left = @children[0].getType(env)
		right = @children[1].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Channel expected but found #{left}"}) if not (left instanceof PCTChannelType)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Values of type #{right} can't be sent over channels for #{left.channelledType}"}) if not left.channelledType.isEqual(right)
		right

	usesSendOrReceiveOperator: -> true

###
# @brief Representation of an expression containing a conditional expression.
#
# Children:
#   - PCExpression
#
# Code example:
#
# c > 0 ? x : y
#
###
class PCConditionalExpression extends PCExpression	# Three children
	getPrecedence: -> 45

	toString: -> "#{@childToString(0)} ? #{@children[1].toString()} : #{@children[2].toString()}"

	###
	# @brief Type checking.
	#
	# The type of the condition expression must be boolean and the types of the
	# consequence and alternative must match.
	#
	###
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type bool expected instead of #{@children[0].getType(env)} in conditional expression!"}) if not @children[0].getType(env).isEqual(new PCTType(PCTType.BOOL))
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of consequence and alternative must be the same! You have #{@children[1].getType(env)} and #{@children[2].getType(env)} instead."}) if not @children[1].getType(env).isEqual(@children[2].getType(env))
		@children[1].getType(env)

###
# @brief Representation of an expression containing a logical or.
#
# Children:
#   - PCExpression
#
# Code example:
#
# a || b
#
###
class PCOrExpression extends PCExpression # 2 children
	getPrecedence: -> 48

	toString: -> "#{@childToString(0)} || #{@childToString(1, 1)}"

	###
	# @brief Type checking.
	#
	# Left and right hand side of this expression must have boolean type.
	#
	###
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type bool expected instead of #{child.getType(env)} in 'or' expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.BOOL))
		new PCTType(PCTType.BOOL)

###
# @brief Representation of an expression containing a logical and.
#
# Children:
#   - PCExpression
#
# Code example:
#
# a && b
#
###
class PCAndExpression extends PCExpression # 2 children
	getPrecedence: -> 51

	toString: -> "#{@childToString(0)} && #{@childToString(1, 1)}"

	###
	# @brief Type checking.
	#
	# Left and right hand side of this expression must have boolean type.
	#
	###
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type bool expected instead of #{child.getType(env)} in 'and' expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.BOOL))
		new PCTType(PCTType.BOOL)

###
# @brief Representation of an expression containing a comparison.
#
# Children:
#   - PCExpression
#
# Code example:
#
# a == b
# a != b
#
###
class PCEqualityExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right

	getPrecedence: -> 54

	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	###
	# @brief Type checking.
	#
	# Left and right hand side of this expression must have the same type.
	#
	###
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Types in equality expression must be the same! You have #{@children[0].getType(env)} and #{@children[1].getType(env)} instead."}) if not @children[0].getType(env).isEqual(@children[1].getType(env))
		new PCTType(PCTType.BOOL)

###
# @brief Representation of an expression containing a comparison.
#
# Children:
#   - PCExpression
#
# Code example:
#
# a < b
# a <= b
# a > b
# a >= b
#
###
class PCRelationalExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right

	getPrecedence: (env) -> 57

	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	###
	# @brief Type checking.
	#
	# Left and right hand side of this expression must have the same type.
	#
	###
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type int expected instead of #{child.getType(env)} in relational expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.BOOL)

###
# @brief Representation of an expression containing an additive expression.
#
# Children:
#   - PCExpression
#
# Code example:
#
# x + y
# x - y
#
###
class PCAdditiveExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right

	getPrecedence: -> 60

	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	###
	# @brief Type checking.
	#
	# Left and right hand side of this expression must be of type int. There is
	# one exception: If the operator is + the left or right hand side could be
	# of type string.
	#
	###
	_getType: (env) ->
		isString = false
		for child in @children
			if not child.getType(env).isEqual(new PCTType(PCTType.INT))
				if child.getType(env).isEqual(new PCTType(PCTType.STRING))
					isString = true
				else
					throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Illegal type in additive expression #{child.getType(env)}!"})
		if isString
			new PCTType(PCTType.STRING)
		else
			new PCTType(PCTType.INT)

###
# @brief Representation of an expression containing an multiplicative
# expression.
#
# Children:
#   - PCExpression
#
# Code example:
#
# x * y
# x / y
# x % y
#
###
class PCMultiplicativeExpression extends PCExpression
	constructor: (line, column, left, @operator, right) -> super line, column, left, right

	getPrecedence: -> 63

	toString: -> "#{@childToString(0)} #{@operator} #{@childToString(1, 1)}"

	###
	# @brief Type checking.
	#
	# Left and right hand side of this expression must be of type int.
	#
	###
	_getType: (env) ->
		for child in @children
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Value of type int expected instead of #{child.getType(env)} in multiplicative expression!"}) if not child.getType(env).isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.INT)

###
# @brief Representation of an expression containing an unary expression.
#
# Children:
#   - PCExpression
#
# Code example:
#
# !b
# -x
# +y
#
###
class PCUnaryExpression extends PCExpression
	constructor: (line, column, @operator, expression) -> super line, column, expression

	getPrecedence: -> 66

	toString: -> "#{@operator}#{@childToString(0)}"

	###
	# @brief Type checking.
	#
	# For + and - the operand must have type int and for ! the type must be
	# boolean.
	#
	###
	_getType: (env) ->
		type = @children[0].getType(env)
		if @operator is "+" or @operator is "-"
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operators '+' and '-' can only be used with integers, not with #{type}!"}) if not type.isEqual(new PCTType(PCTType.INT))
		else if @operator is "!"
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Operator '!' can only be used with booleans, not with #{type}!"}) if not type.isEqual(new PCTType(PCTType.BOOL))
		type

###
# @brief Representation of an expression containing a post-increment or
# -decrement.
#
# Children:
#   - PCAssignDestination
#
# Code example:
#
# x++
# y--
#
###
class PCPostfixExpression extends PCExpression
	constructor: (line, column, assignDestination, @operator) -> super line, column, assignDestination

	getPrecedence: -> 69

	toString: -> "#{@children[0].toString()}#{@operator}"

	###
	# @brief Type checking.
	#
	# The type of the operand must be int.
	#
	###
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Increment and decrement can only be used with integers, not with #{@children[0].getType(env)}!"}) if not @children[0].getType(env).isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.INT)

###
# @brief Representation of an expression containing a receive operation on a
# channel.
#
# Children:
#   - PCExpression
#
# Code example:
#
# x = <? chn
#
###
class PCReceiveExpression extends PCExpression	# 1 child
	getPrecedence: -> 72

	toString: -> "<? #{@childToString(0)}"

	###
	# @brief Type checking.
	#
	# The operand of this expression must be of a channel type.
	#
	###
	_getType: (env) ->
		type = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Expression to receive from must have a channeled type, not #{type}"}) if not (type instanceof PCTChannelType)
		type.channelledType

	usesSendOrReceiveOperator: -> true

###
# @brief Representation of an expression containing an procedure call.
#
# Children:
#   - PCExpression
#
# Code example:
#
# x = testCall(arg1, arg2, ..., argn)
#
###
class PCProcedureCall extends PCExpression
	constructor: (@procedureName, args...) -> super args...	# arguments are expressions

	getProcedure: (env, className) ->
		try
			(if className then env.getClassWithName(className) else env).getProcedureWithName(@procedureName, @line, @column)
		catch e
			e.line = @line
			e.column = @column
			throw e

	getType: (env, className) -> if not className then super else @_getType(env, className)

	getPrecedence: -> 75

	toString: -> "#{@procedureName}(#{(o.toString() for o in @children).join(", ")})"

	###
	# @brief Type checking.
	#
	# Check whether the procedure call has the correct number of arguments and
	# whether each argument matches the expected type (stated during the
	# declaration).
	#
	###
	_getType: (env, className) ->
		proc = @getProcedure(env, className)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "No arguments for procedure that requires arguments!"}) if @children.length == 0 and proc.arguments.length > 0
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Arguments were passed to procedure without arguments!"}) if @children.length > 0 and proc.arguments.length == 0
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "More arguments than requiered were passed to procedure!"}) if @children.length > proc.arguments.length
		for arg, i in proc.arguments
			type = arg.type
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Procedure expected argument of type #{type}, but got none!"}) if i >= @children.length
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Argument number #{i + 1} should have type #{type}, but is #{@children[i].getType(env)}"}) if not type.isAssignableTo(@children[i].getType(env))
		proc.returnType

###
# @brief Representation of an expression containing a call to a class method.
#
# Children:
#   - PCExpression
#
# Code example:
#
# A.test()
#
###
class PCClassCall extends PCExpression	# 2 children: expression that returns class and procedure call on that class
	getProcedure: (env) -> @children[1].getProcedure(env, @children[0].getType(env).identifier)

	getPrecedence: -> 78

	toString: -> "#{@children[0].toString()}.#{@children[1].toString()}"

	###
	# @brief Type checking.
	#
	# The expression of the left hand side must be of class type. In addition
	# this class type must be known.
	#
	###
	_getType: (env) ->
		type = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Incorrect type left to '.' (point). Expected a monitor or struct object, but found #{type}"}) if not (type instanceof PCTClassType)
		@children[1].getType(env, @children[0].getType(env).identifier)

###
# @brief Representation of an expression containing an array access.
#
# Children:
#   - PCExpression
#
# Code example:
#
# x[0][1]
#
###
class PCArrayExpression extends PCExpression	# 2 children
	getPrecedence: -> 81

	toString: ->
		front = "#{@children[0]}"
		pos = front.indexOf("[")
		if pos is -1
			return "#{front}[#{@children[1]}]"
		else
			end = front.substring(pos)
			front = front.slice(0, pos)
			return "#{front}[#{@children[1]}]#{end}"

	###
	# @brief Type checking.
	#
	# Check whether the expression has array type and whether each expression
	# inside the access brackets is of type int.
	#
	###
	_getType: (env) ->
		type = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "You use array access on a non-array: #{type}"}) if not (type instanceof PCTArrayType)
		childType = @children[1].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Array index must be an integer value, not #{childType}"}) if not childType.isEqual(new PCTType(PCTType.INT))
		type = type.elementsType
		type

###
# @brief Representation of an expression containing a literal.
#
# Children:
#   - none
#
# Code example:
#
# 42
# true
# "test"
#
###
class PCLiteralExpression extends PCExpression
	constructor: (line, column, @value) -> super line, column, []...

	getPrecedence: -> 84

	toString: ->
		switch (typeof @value)
			when "boolean" then (if @value then "true" else "false")
			when "string" then "\"#{@value}\""
			else "#{@value}"

	###
	# @brief Type checking.
	#
	# Construction of the correct type.
	#
	###
	_getType: (env) ->
		switch (typeof @value)
			when "boolean" then new PCTType(PCTType.BOOL)
			when "string" then new PCTType(PCTType.STRING)
			else new PCTType(PCTType.INT)

###
# @brief Representation of an expression containing an identifier.
#
# Children:
#   - none
#
# Code example:
#
# x
# A
#
###
class PCIdentifierExpression extends PCExpression
	constructor: (line, column, @identifier) -> super line, column, []...

	getPrecedence: -> 84

	toString: -> @identifier

	###
	# @brief Type checking.
	#
	# Look up the corresponding class type.
	#
	###
	_getType: (env) ->
		env.getVariableWithName(@identifier, @line, @column).type


# -- STATEMENTS --

###
# @brief TODO Fill in the documentation.
#
# We need this for instanceof check, empty statement and to add semicolon to
# expression stmt.
###
class PCStatement extends PCNode
	collectEnvironment: (env) -> @children.length > 0 and @children[0].collectEnvironment(env)

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> @children.length > 0 and @children[0]._collectEnvironment(env)

	toString: (indent, expectsNewBlock) ->
		addIndent = expectsNewBlock == true && (@children.length == 0 || !(@children[0] instanceof PCStmtBlock))
		indent += PCIndent if addIndent
		if @children.length == 0
			res = indent + ";"
		else
			res = @children[0].toString(indent)
			res += ";" if @children[0] instanceof PCStmtExpression
		res = "\n" + res if addIndent
		res

	###
	# @brief Type checking.
	#
	# Check recursively.
	#
	###
	_getType: (env) ->
		@children[0].getType(env) if @children.length > 0
		new PCTType(PCTType.VOID)

###
# @brief Representation of a break statement.
#
# Children:
#   - none
#
# Code example:
#
# break;
#
###
class PCBreakStmt extends PCNode
	constructor: (line, column) -> super line, column, []...

	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> indent + "break"

	###
	# @brief Type checking.
	#
	# A break statement can only occur inside a loop.
	#
	###
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "break-Statements are only allowed within loops."}) if not @insideLoop()
		new PCTType(PCTType.VOID)

###
# @brief Representation of a continue statement.
#
# Children:
#   - none
#
# Code example:
#
# continue;
#
###
class PCContinueStmt extends PCNode
	constructor: (line, column) -> super line, column, []...

	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> indent + "continue"

	###
	# @brief Type checking.
	#
	# A continue statement can only occur inside a loop.
	#
	###
	_getType: (env) ->
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "continue-Statements are only allowed within loops."}) if not @insideLoop()
		new PCTType(PCTType.VOID)

###
# @brief Representation of statement block.
#
# Children:
#   - PCStatement
#   - PCProcedureDecl
#   - PCConditionDecl
#
# Code example:
#
# { ... }
#
###
class PCStmtBlock extends PCNode
	collectEnvironment: (env) -> c.collectEnvironment(env) for c in @children

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}{\n#{(o.toString(indent+PCIndent) for o in @children).join("\n")}\n#{indent}}"

	###
	# @brief Type checking.
	#
	# Check recursively all contained statements.
	#
	###
	_getType: (env) ->
		env.getEnvironment(@, @__id)
		for child in @children
			try
				child.getType(env)
			catch e
				if e and e.wholeFile?
					PCErrorList.push e
			if child instanceof PCStatement and child.children[0]? and child.children[0] instanceof PCStmtBlock
				env.setReturnExhaustive() if child.children[0].isReturnExhaustive
		env.closeEnvironment()
		new PCTType(PCTType.VOID)

###
# @brief Representation of a statement containing an expression.
#
# Children:
#   - PCExpression
#
# Code example:
#
# x = 42;
#
###
class PCStmtExpression extends PCNode	# We need this for instanceof check
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> indent + @children[0].toString()

	###
	# @brief Type checking.
	#
	# Check recursively.
	#
	###
	_getType: (env) ->
		@children[0].getType(env)

###
# @brief Representation of a select statement.
#
# Children:
#   - PCCase
#
# Code example:
#
# select {
#   case <? x: ;
#   default: ;
# }
#
###
class PCSelectStmt extends PCNode	# children are cases
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}select {\n#{(o.toString(indent+PCIndent) for o in @children).join("\n")}\n#{indent}}"

	###
	# @brief Type checking.
	#
	# Check recursively all case statements. Update whether all contained
	# statements are exhaustive with regard to return statements.
	#
	###
	_getType: (env) ->
		env.getEnvironment(@, @__id)
		retExhaust = true
		for child in @children
			child.getType(env)
			retExhaust &= child.isReturnExhaustive
		env.setReturnExhaustive() if retExhaust
		env.closeEnvironment()
		env.setReturnExhaustive() if retExhaust
		new PCTType(PCTType.VOID)

###
# @brief Representation of one case statment of a select statement.
#
# Children:
#   - PCStatementExpression
#   - PCStatement
#
# Code example:
#
# See PCSelectStmt.
#
###
class PCCase extends PCNode
	constructor: (line, column, execution, condition) -> if condition then super line, column, execution, condition else super line, column, execution

	getCondition: -> if @children.length == 2 then @children[1] else null

	getExecution: -> @children[0]

	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		child._collectEnvironment(env) for child in @children

	toString: (indent) -> "#{indent}#{if @children.length == 2 then "case #{@children[1].toString()}" else "default"}: #{@children[0].toString(indent, true)}"

	###
	# @brief Type checking.
	#
	# The condition of a case statement requires at least one send or receive
	# expression.
	#
	###
	_getType: (env) ->
		child.getType(env) for child in @children
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "case condition requires at least one send or receive operation."}) if @children.length > 1 and not @children[1].usesSendOrReceiveOperator()
		if @children[0] instanceof PCStatement and @children[0].children[0]? and @children[0].children[0] instanceof PCStmtBlock
			@isReturnExhaustive = @children[0].children[0].isReturnExhaustive
		new PCTType(PCTType.VOID)

###
# @brief Representation of a conditional statement.
#
# Children:
#   - PCExpression
#   - PCStatement
#
# Code example:
#
# if (b) { ... }
# if (b) { ... } else { ... }
#
###
class PCIfStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}if (#{@children[0].toString()}) #{@children[1].toString(indent, true)}#{if @children[2] then "\n#{indent}else #{@children[2].toString(indent, true)}" else ""}"

	###
	# @brief Type checking.
	#
	# Check for return exhaustiveness.
	#
	# The condition expression must have boolean type.
	#
	###
	_getType: (env) ->
		expType = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if not expType.isEqual(new PCTType(PCTType.BOOL))
		env.getEnvironment(@, @.__id)
		@children[1].getType(env)
		@children[2].getType(env) if @children.length > 2
		if @children[1] instanceof PCStatement and @children[1].children[0]? and @children[1].children[0] instanceof PCStmtBlock
			if @children[2]?
				if @children[2] instanceof PCStatement and @children[2].children[0]? and @children[2].children[0] instanceof PCStmtBlock
					env.setReturnExhaustive() if @children[1].children[0].isReturnExhaustive and @children[2].children[0].isReturnExhaustive
			else
				env.setReturnExhaustive() if @children[1].children[0].isReturnExhaustive
		env.closeEnvironment()
		env.setReturnExhaustive() if @isReturnExhaustive
		new PCTType(PCTType.VOID)

###
# @brief Representation of a while loop.
#
# Children:
#   - PCExpression
#   - PCStatement
#
# Code example:
#
# while (b) { ... }
#
###
class PCWhileStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}while (#{@children[0].toString()}) #{@children[1].toString(indent, true)}"

	###
	# @brief Type checking.
	#
	# The condition expression must have boolean type.
	#
	###
	_getType: (env) ->
		expType = @children[0].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if not expType.isEqual(new PCTType(PCTType.BOOL))
		env.getEnvironment(@, @.__id)
		@children[1].getType(env)
		env.closeEnvironment()
		new PCTType(PCTType.VOID)

	insideLoop: -> true

###
# @brief Representation of a do-while loop.
#
# Children:
#   - PCExpression
#   - PCStatement
#
# Code example:
#
# do { ... } while (b);
#
###
class PCDoStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		child._collectEnvironment(env) for child in @children
		env.closeEnvironment()

	toString: (indent) -> "#{indent}do #{@children[0].toString(indent, true)}\n#{indent}while (#{@children[1].toString()})"

	###
	# @brief Type checking.
	#
	# The condition expression must have boolean type.
	#
	###
	_getType: (env) ->
		env.getEnvironment(@, @.__id)
		@children[0].getType(env)
		env.closeEnvironment()
		expType = @children[1].getType(env)
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if not expType.isEqual(new PCTType(PCTType.BOOL))
		new PCTType(PCTType.VOID)

	insideLoop: -> true

###
# @brief Representation of a for loop.
#
# Children:
#   - PCForInit
#   - PCExpression
#   - PCStatement
#
# Code example:
#
# for (int i = 0; i < n; i++) { ... }
#
###
class PCForStmt extends PCNode		# Add PCForUpdate class?
	constructor:(line, column, @body, @init, @expression, @update...) ->
		children = @update.concat([@body])
		children.unshift(@expression) if @expression
		children.unshift(@init) if @init
		super line, column, children...

	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		env.openEnvironment(@)
		@init._collectEnvironment(env)
		@body._collectEnvironment(env)
		env.closeEnvironment()

	toString: (indent) -> "#{indent}for (#{if @init then @init.toString() else ""}; #{if @expression then @expression.toString() else ""}; #{(o.toString("") for o in @update).join(", ")}) #{@body.toString(indent, true)}"

	###
	# @brief Type checking.
	#
	# The condition expression must have boolean type.
	#
	###
	_getType: (env) ->
		env.getEnvironment(@, @__id)
		@init.getType(env) if @init
		expType = @expression.getType(env) if @expression?
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Type of condition must be bool not #{expType}"}) if expType? and not expType.isEqual(new PCTType(PCTType.BOOL))
		update.getType(env) for update in @update
		@body.getType(env)
		env.closeEnvironment()
		new PCTType(PCTType.VOID)

	insideLoop: -> true

###
# @brief Representation of the for loop initialization part.
#
# Children:
#   - PCDecl
#   - PCExpression
#
# Code example:
#
# See PCForStmt.
#
###
class PCForInit extends PCNode
	toString: -> "#{(o.toString("") for o in @children).join(", ")}"

	# Collects complete environment for type checking
	_collectEnvironment: (env) ->
		child._collectEnvironment(env) for child in @children

	###
	# @brief Type checking.
	#
	# Check recursively.
	#
	###
	_getType: (env) ->
		child.getType(env) for child in @children
		new PCTType(PCTType.VOID)

###
# @brief Representation of a return statement.
#
# Children:
#   - PCExpression
#
# Code example:
#
# return 42;
#
###
class PCReturnStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> "#{indent}return#{if @children.length  == 1 then " #{@children[0].toString()}" else ""};"

	###
	# @brief Type checking.
	#
	# Check whether the expression matches the return type of the procedure.
	#
	###
	_getType: (env) ->
		type = @children[0].getType(env) if @children.length > 0
		type = new PCTType(PCTType.VOID) if not type?
		try
			expectedType = env.getExpectedReturnValue()
		catch e
			e.line = @line
			e.column = @column
			throw e
		throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "Expression of type #{type} doesn't match expected return type #{expectedType} for procedure."}) if not type.isEqual(expectedType)
		env.setReturnExhaustive()

###
# @brief Representation of one primitive statment. They are listed below:
#   - join
#   - lock
#   - unlock
#   - waitForCondition
#   - signal
#   - signalAll
#
# Children:
#   - PCExpression
#
# Code example:
#
# join (a1);
# lock (guard);
# unlock (guard);
# waitForCondition (c);
# signal (c);
# signalAll (c);
#
###
class PCPrimitiveStmt extends PCNode
	constructor: (line, column, @kind, expression) -> if expression then super line, column, expression else super line, column, []...

	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> "#{indent}#{PCPrimitiveStmt.kindToString(@kind)}(#{if @children.length  == 1 then " #{@children[0].toString()}" else ""});"

	###
	# @brief Type checking.
	#
	# join can only be applied to agents.
	#
	# lock and unlock can only be applied to locks.
	#
	# waitForCondition, signal and signalAll can only be applied to conditions
	# and they can only be used inside a monitor.
	#
	###
	_getType: (env) ->
		@_type = @children[0].getType(env) if @children.length > 0
		switch @kind
			when PCPrimitiveStmt.JOIN
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "join must be applied on agents, not #{@_type}!"}) if not @_type.isEqual(new PCTType(PCTType.AGENT))
			when PCPrimitiveStmt.LOCK, PCPrimitiveStmt.UNLOCK
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "lock and unlock must be applied on lock objects, not #{@_type}!"}) if not @_type.isEqual(new PCTType(PCTType.LOCK))
			when PCPrimitiveStmt.WAIT
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "waitForCondition can only be used in monitors!"}) if not @insideMonitor()
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "waitForCondition must be applied on condition or boolean objects, not #{@_type}!"}) if not @_type.isEqual(new PCTType(PCTType.Bool)) and not @_type.isEqual(new PCTType(PCTType.CONDITION))
			when PCPrimitiveStmt.SIGNAL, PCPrimitiveStmt.SIGNAL_ALL
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "signal and signalAll can only be used in monitors!"}) if not @insideMonitor()
				throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "signal and signalAll must be applied on condition objects, not #{@_type}!"}) if @children.length > 0 and not @_type.isEqual(new PCTType(PCTType.CONDITION))
		new PCTType(PCTType.VOID)

PCPrimitiveStmt.JOIN = 0
PCPrimitiveStmt.LOCK = 1
PCPrimitiveStmt.UNLOCK = 2
PCPrimitiveStmt.WAIT = 3
PCPrimitiveStmt.SIGNAL = 4
PCPrimitiveStmt.SIGNAL_ALL = 5

PCPrimitiveStmt.kindToString = (kind) ->
	switch kind
		when PCPrimitiveStmt.JOIN then "join"
		when PCPrimitiveStmt.LOCK then "lock"
		when PCPrimitiveStmt.UNLOCK then "unlock"
		when PCPrimitiveStmt.WAIT then "waitForCondition"
		when PCPrimitiveStmt.SIGNAL then "signal"
		when PCPrimitiveStmt.SIGNAL_ALL then "signalAll"

###
# @brief Representation of the println statement.
#
# Children:
#   - PCExpression
#
# Code example:
#
# println("Hallo" + " " + "Welt" + "!");
#
###
class PCPrintStmt extends PCNode
	collectEnvironment: (env) -> null

	# Collects complete environment for type checking
	_collectEnvironment: (env) -> null

	toString: (indent) -> "#{indent}println(#{(o.toString() for o in @children).join(", ")});"

	###
	# @brief Type checking.
	#
	# The expression list of the println statement may only contain expressions
	# of type int or string.
	#
	###
	_getType: (env) ->
		for child in @children
			type = child.getType(env)
			throw ({"line" : @line, "column" : @column, "wholeFile" : false, "name" : "InvalidType", "message" : "println can only process strings and integers, but no #{type}!"}) if not type.isEqual(new PCTType(PCTType.STRING)) and not type.isEqual(new PCTType(PCTType.INT))
		new PCTType(PCTType.VOID)
