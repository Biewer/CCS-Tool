
class PCNode
	constructor: (@children...) -> 
		@parent = null
		c.parent = this for c in @children


# - Program
class PCProgram extends PCNode	# Children: (PCMonitor|PCStruct|PCMainAgent|PCDecl)+

# - MainAgent Decl
class PCMainAgent extends PCNode	# "mainAgent" PCStmtBlock

# - Procedure Decl
class PCProcedure extends PCNode	# Children: PCFormalParameter objects
	constructor: (resultType, @name, body, parameters...) ->
		parameters.unshift(resultType, body)
		super parameters...

# - Formal Parameter
class PCFormalParameter extends PCNode
	constructor: (type, @identifier) -> super type

# - Monitor Decl
class PCMonitor extends PCNode	# "monitor" <id> "{" (Procedure decl, condition decl or variable decl)+ "}"
	constructor: (@name, declarations...) -> super declarations...

# - Struct Decl
class PCStruct extends PCNode	# "struct" <id> "{" (Procedure decl or variable decl)+ "}"
	constructor: (@name, declarations...) -> super declarations...

# - Condition Decl
class PCConditionDecl extends PCNode	# condition <id> with <boolean expression>
	constructor: (@name, expression) -> super expression

# - Variable Decl
class PCDecl extends PCNode	# Children: Type and variable declarator(s)

class PCDeclStmt extends PCDecl

# - Variable Declarator
class PCVariableDeclarator extends PCNode	# Identifier and optional initializer
	constructor: (@name, initializer) -> super initializer

class PCVariableInitializer extends PCNode	# array initialization >= 1 child initializers, otherwise 1 child expression


# -- TYPES --

class PCArrayType extends PCNode	# n-dimensional array of non-array type
	constructor: (baseType, @arrayIndices) -> super baseType

# - Non-Array Type
class PCBaseType extends PCNode	# abstract (?)

class PCSimpleType extends PCBaseType
	constructor: (@type) -> throw "Unknown type" if @type < 0 or @type > 5

PCSimpleType::VOID = 0
PCSimpleType::BOOL = 1
PCSimpleType::INT = 2
PCSimpleType::STRING = 3
PCSimpleType::MUTEX = 4
PCSimpleType::AGENT = 5


# - Channel Type
class PCChannelType extends PCBaseType
	constructor:(@valueType, @capacity) ->

PCChannelType::CAPACITY_UNKNOWN = -1

# - Encapsulating Type
class PCClassType extends PCBaseType
	constructor: (@className) -> super



# -- EXPRESSIONS --
class PCExpression extends PCNode		# abstract

# - Expression List
class PCExpressionList extends PCNode

# - Start Expression
class PCStartExpression extends PCExpression	# One child: procedure or monitor call

# - Assign Expression
class PCAssignExpression extends PCExpression
	constructor: (destination, @operator, expression) -> super destination, expression

# - Assign Destination
class PCAssignDestination extends PCNode	# Variable or array element
	constructor: (@identifier, arrayIndexExpressions...) -> super arrayIndexExpressions...

# - Send Expression
class PCSendExpression extends PCExpression	# Children: First: The expression that returns the channel; Second: The expression that returns the value to send

# - Conditional Expression
class PCConditionalExpression extends PCExpression	# Three children

# - Or Expression
class PCOrExpression extends PCExpression # 2 children

# - And Expression
class PCAndExpression extends PCExpression # 2 children

# - Equality Expression
class PCEqualityExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right

# - Relational Expression
class PCRelationalExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right

# - Additive Expression
class PCAdditiveExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right

# - Multiplicative Expression
class PCMultiplicativeExpression extends PCExpression
	constructor: (left, @operator, right) -> super left, right

# - Unary Expression
class PCUnaryExpression extends PCExpression
	constructor: (@operator, expression) -> super expression

# - Postfix Expression
class PCPostfixExpression extends PCExpression
	constructor: (assignDestination, @operator) -> super assignDestination

# - Receive Expression
class PCReceiveExpression extends PCExpression	# 1 child

# - Prcedure Call
class PCProcedureCall extends PCExpression
	constructor: (@procedureName, args...) -> super args...	# arguments are expressions

# - Class Call
class PCClassCall extends PCExpression	# 2 children: expression that returns class and procedure call on that class

# - Array Expression
class PCArrayExpression extends PCExpression	# 2 children 

# - Literal Expression
class PCLiteralExpression extends PCExpression
	constructor: (@value) -> super

# - Identifier Expression
class PCIdentifierExpression extends PCExpression
	constructor: (@identifier) -> super


# -- STATEMENTS --

class PCStatement extends PCNode	# empty statement

# - Break Statement
class PCBreakStmt extends PCStatement
	constructor: -> super

# - Continue Statement
class PCContinueStmt extends PCStatement
	constructor: -> super

# - Statement Block
class PCStmtBlock extends PCStatement

# - Statement Expression
class PCStmtExpression extends PCStatement

# - Select Statement
class PCSelectStmt extends PCStatement	# children are cases

# - Case
class PCCase extends PCNode
	constructor: (execution, condition) -> super execution, condition

# - If Statement
class PCIfStmt extends PCStatement

# - While Statement
class PCWhileStmt extends PCStatement

# - Do Statement
class PCDoStmt extends PCStatement

# - For Statement
class PCForStmt extends PCStatement		# Add PCForUpdate class?
	constructor:(@init, @expression, @update...) ->
		children = @update.concat([])
		children.unshift(@expression) if @expression
		children.unshift(@init) if @init
		super children

# - For loop initialization
class PCForInit extends PCNode

# - Return Statement
class PCReturnStmt extends PCStatement

# - Primitive Statements
class PCPrimitiveStmt extends PCStatement
	constructor: (@kind, expression) -> super expression

PCPrimitiveStmt::JOIN = 0
PCPrimitiveStmt::LOCK = 1
PCPrimitiveStmt::UNLOCK = 2
PCPrimitiveStmt::WAIT = 3
PCPrimitiveStmt::SIGNAL = 4
PCPrimitiveStmt::SIGNAL_ALL = 5

# - Println Statement
class PCPrintStmt extends PCStatement
















