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




PC.Node::compile = (compiler) ->
	throw new Error("Abstract method!")
PC.Node::_childrenCompile = (compiler) ->
	compiler.compile(c) for c in @children
# PC.Node::registerServices = (compiler) ->		# services like mutex, waitroom, ... -> only generate CCS for necessary services
# 	c.registerServices(compiler) for c in @children
	
	

PC.Program::compile = (compiler) -> 
	compiler.beginProgram()
	@_childrenCompile(compiler)
	compiler.endProgram()
	
	

PC.MainAgent::compile = (compiler) ->
	compiler.beginMainAgent()
	#i_r = compiler.getFreshContainer(PCCType.INT, "ret")
	#compiler.emitInput("channel1_create", null, i_r)
	#i_r = new PCCConstantContainer(-1)
	#compiler.getProcessFrame().addLocalVariable(new PCCVariableInfo(null, "r", null, true), i_r)
	@_childrenCompile(compiler)
	compiler.emitStop()
	compiler.endMainAgent()
	
	

PC.ProcedureDecl::compile = (compiler) ->
	compiler.beginProcedure(@name)
	proc = compiler.getProcedureWithNameOfClass(@name)
	if proc.isMonitorProcedure()
		guard = compiler.getVariableWithNameOfClass("guard", null, true)
		agent = compiler.getVariableWithNameOfClass("a", null, true)
		compiler.emitOutput("lock", guard.getContainer(compiler), agent.getContainer(compiler))
	compiler.compile(@getBody())		
	proc.emitExit(compiler)		# Ask the procedure to emit exit, because this depends on the procedure type: monitor procedures for example must return the mutex.
	compiler.endProcedure()
	[]
	
	

PC.FormalParameter::compile = (compiler) ->
	throw new Error("Not implemented!")
	
	

PC.Monitor::compile = (compiler) ->
	compiler.beginClass(@name)
	compiler.setNeedsMutex()
	@_childrenCompile(compiler)
	compiler.endClass()
# PC.Monitor::registerServices = (compiler) ->
# 	compiler.setNeedsMutex()
# 	super
	
	

PC.Struct::compile = (compiler) ->
	compiler.beginClass(@name)
	@_childrenCompile(compiler)
	compiler.endClass()
	
	


PC.ConditionDecl::compile = (compiler) ->
	compiler.setNeedsWaitRoom()
	context = {target: @, compiler: compiler}
	variable = new PCCVariableInfo(@, @name, new PC.Type(PC.Type.CONDITION))
	compiler.handleNewVariableWithDefaultValueCallback(variable)
	[]

PC.ConditionDecl::compileDefaultValue = (compiler) ->
	result = compiler.getFreshContainer(PCCType.INT)
	compiler.emitInput("wait_create", null, result)
	result
	
	
	

PC.Decl::compile = (compiler) ->
	type = @children[0]
	compiler.setNeedsMutex() if type.getType().type.kind == PC.Type.MUTEX
	compiler.compile(vd) for vd in @getDeclarators()
	[]
	
	
	

PC.VariableDeclarator::compile = (compiler) ->
	context = {target: @, compiler: compiler}
	variable = new PCCVariableInfo(@, @name, @getTypeNode().getType(compiler).type)
	compiler.handleNewVariableWithDefaultValueCallback(variable)

PC.VariableDeclarator::compileDefaultValue = (compiler) ->
	type = @getTypeNode().getType(compiler).type
	if @getInitializer()
		compiler.compile(@getInitializer(), type)
	else
		type.createContainer(compiler)
	
	
	

PC.VariableInitializer::compile = (compiler, type) ->
	if @isArray()
		cc = (compiler.compile(c, type.elementsType) for c in @children)
		type.createContainer(compiler, cc)
	else
		type.createContainer(compiler, compiler.compile(@children[0]))
	
	
	

PC.Expression::compile = (compiler) ->
	throw new Error("Not implemented!")
	
	

PC.StartExpression::compile = (compiler) ->
	compiler.setNeedsAgentManager()
	@children[0].compileSend(compiler)
	
	

PC.AssignExpression::compile = (compiler) ->
	c = compiler.compile(@getExpression())
	if @operator == "+="
		c = new PCCBinaryContainer(compiler.compile(@getDestination()), c, "+")
	else if @operator == "*="
		c = new PCCBinaryContainer(compiler.compile(@getDestination()), c, "*")
	else if @operator == "/="
		c = new PCCBinaryContainer(compiler.compile(@getDestination()), c, "/")
	else if @operator != "="
		throw new Error("Unknown assign operator")
	@getDestination().assignContainer(compiler, c)
	c
	
	

PC.AssignDestination::compile = (compiler) ->	# Returns the same value as array expression would do (used for +=, *=,  ...)
	arrayIndexCount = @children.length
	v = compiler.getVariableWithNameOfClass(@identifier, null)
	res = v.getContainer(compiler)
	(res = @getValueForArrayAtIndex(compiler, res, compiler.compile(@children[i]))) for i in [0...arrayIndexCount] by 1
	res
PC.AssignDestination::setValueForArrayAtIndex = (compiler, instanceContainer, indexContainer, valueContainer) ->
	compiler.emitOutput("array_access", instanceContainer, indexContainer)
	compiler.emitOutput("array_set", instanceContainer, valueContainer)
	valueContainer
PC.AssignDestination::assignContainer = (compiler, c) ->
	arrayIndexCount = @children.length
	v = compiler.getVariableWithNameOfClass(@identifier, null)
	if arrayIndexCount == 0
		v.setContainer(compiler, c)
	else
		ai = v.getContainer(compiler)
		(ai = @getValueForArrayAtIndex(compiler, ai, compiler.compile(@children[i]))) for i in [0..arrayIndexCount-2] by 1
		@setValueForArrayAtIndex(compiler, ai, compiler.compile(@children[arrayIndexCount-1]), c)
PC.AssignDestination::getValueForArrayAtIndex = (compiler, instanceContainer, indexContainer) ->
	compiler.emitOutput("array_access", instanceContainer, indexContainer)
	debugger
	result = compiler.getFreshContainer(instanceContainer.ccsType.getSubtype())
	compiler.emitInput("array_get", instanceContainer, result)
	result

	

PC.SendExpression::compile = (compiler) ->
	c = compiler.compile(@children[0])
	v = compiler.compile(@children[1])
	if @children[0].getType(compiler).capacity <= 0
		control = compiler.emitChoice()
		compiler.emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), ">="))
		compiler.emitOutput("put", c, v)	# Buffered
		p1 = compiler.emitProcessApplicationPlaceholder()
		control.setBranchFinished()
		compiler.emitCondition(new PCCBinaryContainer(c, new PCCConstantContainer(0), "<"))
		compiler.emitOutput("receive", c, v)	# Unbuffered
		p2 = compiler.emitProcessApplicationPlaceholder()
		control.setBranchFinished()
		compiler.emitMergeOfProcessFramesOfPlaceholders([p1, p2])
	else
		compiler.emitOutput("put", c, v)	# Buffered
	v
	
	
	

PC.ConditionalExpression::compile = (compiler) ->
	b = compiler.compile(@children[0])
	control = compiler.emitChoice()
	compiler.emitCondition(b)
	c = compiler.compile(@children[1])
	compiler.protectContainer(c)
	lp = compiler.emitProcessApplicationPlaceholder()
	control.setBranchFinished()
	compiler.emitCondition(new PCCUnaryContainer("!", b))
	c = compiler.compile(@children[2])
	compiler.protectContainer(c)
	rp = compiler.emitProcessApplicationPlaceholder()
	compiler.emitMergeOfProcessFramesOfPlaceholders([lp, rp])
	compiler.unprotectContainer()
	
	

PC.OrExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, "||")
	
	

PC.AndExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, "&&")
	
	

PC.EqualityExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PC.RelationalExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PC.AdditiveExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PC.MultiplicativeExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PC.UnaryExpression::compile = (compiler) ->
	new PCCUnaryContainer(@operator, compiler.compile(@children[0]))
	
	

PC.PostfixExpression::compile = (compiler) ->
	op = if @operator == "++" then "+" else if @operator == "--" then "-" else throw new Error("Unknown postfix operator")
	c = new PCCBinaryContainer(compiler.compile(@children[0]), new PCCConstantContainer(1), op)
	@children[0].assignContainer(compiler, c)
	c
	
	

PC.ReceiveExpression::compile = (compiler) ->
	c = compiler.compile(@children[0])
	res = compiler.getFreshContainer(c.ccsType.getSubtype())
	compiler.emitInput("receive", c, res)
	res
	
	


PC.ProcedureCall::compile = (compiler, instanceContainer, className) ->
	proc = compiler.getProcedureWithNameOfClass(@procedureName, className)
	compiler.protectContainer(instanceContainer) if instanceContainer
	compiler.protectContainer(compiler.compile(c)) for c in @children
	control = compiler.emitSequence()
	args = []
	args.unshift(compiler.unprotectContainer()) for c in @children
	instanceContainer = compiler.unprotectContainer() if instanceContainer
	args = proc.getAllArgumentContainers(compiler, args, instanceContainer)
	compiler.emitProcessApplication(proc.getProcessName(), args)
	control.setBranchFinished()	# left is finished
	if proc.returnType.kind != PC.Type.VOID
		res = compiler.getFreshContainer(proc.returnType.getCCSType())
		#compiler.emitInput("receive", compiler.getVariableWithNameOfClass("r", null, true).getContainer(compiler), res)
		compiler.emitInput("rreturn", null, res)
		res
	else
		null
PC.ProcedureCall::compileSend = (compiler, instanceContainer, className) ->
	proc = compiler.getProcedureWithNameOfClass(@procedureName, className)
	compiler.protectContainer(instanceContainer) if instanceContainer
	compiler.protectContainer(compiler.compile(c)) for c in @children
	args = []
	args.unshift(compiler.unprotectContainer()) for c in @children
	instanceContainer = compiler.unprotectContainer() if instanceContainer
	args = proc.getAllArgumentContainers(compiler, args, instanceContainer)
	result = compiler.getFreshContainer(PCCType.INT)
	compiler.emitInput(proc.getAgentStarterChannel(), null, result)
	compiler.emitOutput("start_set_arg", result, c) for c in args
	result


PC.ClassCall::compile = (compiler) ->
	className = @children[0].getType(compiler).identifier
	compiler.compile(@children[1], compiler.compile(@children[0]), className)
PC.ClassCall::compileSend = (compiler) ->
	className = @children[0].getType(compiler).identifier
	@children[1].compileSend(compiler, compiler.compile(@children[0]), className)
	

PC.ArrayExpression::compile = (compiler) ->
	a = compiler.compile(@children[0])
	compiler.protectContainer(a)
	t = compiler.compile(@children[1])
	a = compiler.unprotectContainer()
	compiler.emitOutput("array_access", a, t)
	res = compiler.getFreshContainer(a.ccsType.getSubtype())
	compiler.emitInput("array_get", a, res)
	res
	
	

PC.LiteralExpression::compile = (compiler) ->
	new PCCConstantContainer(@value)
	
	

PC.IdentifierExpression::compile = (compiler) ->
	v = compiler.getVariableWithNameOfClass(@identifier, null)
	v.getContainer(compiler)
	
	

PC.Statement::compile = (compiler, loopEntry) ->
	if @children.length > 0 then compiler.compile(@children[0], loopEntry) else []
	
	

PC.BreakStmt::compile = (compiler, loopEntry) ->
	[compiler.emitProcessApplicationPlaceholder()]
	
	

PC.ContinueStmt::compile = (compiler, loopEntry) ->
	loopEntry.emitCallProcessFromFrame(compiler, compiler.getProcessFrame())
	[]
	
	

PC.StmtBlock::compile = (compiler, loopEntry) ->
	compiler.reopenEnvironment(@)
	statusQuo = compiler.getProcessFrame()
	compiler.emitNewScope()
	breaks = SBArrayConcatChildren(compiler.compile(c, loopEntry) for c in @children)
	compiler.emitNewScope(statusQuo)
	compiler.closeEnvironment()
	breaks
	
	

PC.StmtExpression::compile = (compiler, loopEntry) ->
	compiler.compile(@children[0])
	[]
	
	

PC.SelectStmt::compile = (compiler, loopEntry) ->
	return if @children.length == 0
	compiler.reopenEnvironment(@)
	placeholders = []
	breaks = []
	for i in [0...@children.length-1] by 1
		control = compiler.emitChoice()
		breaks.concat(compiler.compile(@children[i], loopEntry))
		placeholders.push(compiler.emitProcessApplicationPlaceholder())
		control.setBranchFinished()
	breaks.concat(compiler.compile(@children[@children.length-1], loopEntry))
	placeholders.push(compiler.emitProcessApplicationPlaceholder())
	compiler.emitMergeOfProcessFramesOfPlaceholders(placeholders)
	compiler.closeEnvironment()
	breaks
	
	

PC.Case::compile = (compiler, loopEntry) ->
	cond = @getCondition()
	if cond
		compiler.compile(cond)
	else
		compiler.emitSimplePrefix(CCS.internalChannelName)
	compiler.compile(@getExecution(), loopEntry)
	
	

PC.IfStmt::compile = (compiler, loopEntry) ->
	compiler.reopenEnvironment(@)
	placeholders = []
	b = compiler.compile(@children[0])
	control = compiler.emitChoice()
	compiler.emitCondition(b)
	breaks = compiler.compile(@children[1], loopEntry)
	if !compiler.isCurrentProcessCompleted()
		placeholders.push(compiler.emitProcessApplicationPlaceholder())
	control.setBranchFinished()	# left is finished
	compiler.emitCondition(new PCCUnaryContainer("!", b))
	(breaks = breaks.concat(compiler.compile(@children[2], loopEntry))) if (@children.length == 3)
	if !compiler.isCurrentProcessCompleted()
		placeholders.push(compiler.emitProcessApplicationPlaceholder())
	control.setBranchFinished()	# right is finished
	compiler.emitMergeOfProcessFramesOfPlaceholders(placeholders)
	compiler.closeEnvironment()
	breaks
	
	

PC.WhileStmt::compile = (compiler) ->
	compiler.reopenEnvironment(@)
	entry = compiler.emitNextProcessFrame()
	b = compiler.compile(@children[0])
	control = compiler.emitChoice()
	compiler.emitCondition(b)
	breaks = compiler.compile(@children[1], entry)
	entry.emitCallProcessFromFrame(compiler, compiler.getProcessFrame())
	control.setBranchFinished()
	compiler.emitCondition(new PCCUnaryContainer("!", b))
	out = compiler.emitNextProcessFrame()
	out.emitCallProcessFromFrame(compiler, b.frame, b) for b in breaks
	compiler.closeEnvironment()
	[]
	

PC.DoStmt::compile = (compiler) ->
	compiler.reopenEnvironment(@)
	statusQuo = compiler.getProcessFrame()
	entry = compiler.emitNextProcessFrame()
	breaks = compiler.compile(@children[0], entry)
	b = compiler.compile(@children[1])
	control = compiler.emitChoice()
	compiler.emitCondition(b)
	entry.emitCallProcessFromFrame(compiler, compiler.getProcessFrame())
	control.setBranchFinished()
	compiler.emitCondition(new PCCUnaryContainer("!", b))
	breaks.push(compiler.emitProcessApplicationPlaceholder())
	control.setBranchFinished()
	out = compiler.emitNextProcessFrame([statusQuo])
	out.emitCallProcessFromFrame(compiler, b.frame, b) for b in breaks
	compiler.closeEnvironment()
	[]
	
	
	
	

PC.ForStmt::compile = (compiler) ->
	compiler.reopenEnvironment(@)
	statusQuo = compiler.getProcessFrame()
	if @init
		compiler.emitNewScope()
		compiler.compile(@init)
	entry = compiler.emitNextProcessFrame()
	breaks = []
	control = null
	if @expression 
		b = compiler.compile(@expression)
		control = compiler.emitChoice()
		compiler.emitCondition(new PCCUnaryContainer("!", b))
		breaks.push(compiler.emitProcessApplicationPlaceholder())
		control.setBranchFinished()
		compiler.emitCondition(b)
	breaks = breaks.concat(compiler.compile(@body, entry))
	compiler.compile(u) for u in @update
	entry.emitCallProcessFromFrame(compiler, compiler.getProcessFrame())
	control.setBranchFinished() if control
	out = compiler.emitNextProcessFrame([statusQuo])
	out.emitCallProcessFromFrame(compiler, b.frame, b) for b in breaks
	compiler.closeEnvironment()
	[]
	
	

PC.ForInit::compile = (compiler) ->
	compiler.compile(c) for c in @children
	[]
	
	

PC.ReturnStmt::compile = (compiler, loopEntry) ->
	if @children.length == 1
		compiler.setNeedsReturn()
		res = compiler.compile(@children[0])
		compiler.emitOutput("return", null, res)
	proc = compiler.getCurrentProcedure()
	if proc
		proc.emitExit(compiler)
	else 	# mainAgent
		compiler.emitExit()
	[]
	
	

PC.PrimitiveStmt::compile = (compiler, loopEntry) ->
	switch @kind
		when PC.PrimitiveStmt.JOIN
			compiler.setNeedsAgentJoiner()
			c = compiler.compile(@children[0], loopEntry)
			compiler.emitOutput("join_register", c, null)
			compiler.emitOutput("join", c, null)
		when PC.PrimitiveStmt.LOCK  
			c = compiler.compile(@children[0], loopEntry)
			if compiler.useReentrantLocks
				a = compiler.getVariableWithNameOfClass("a", null, true).getContainer(compiler)
				compiler.emitOutput("lock", c, a)
			else
				compiler.emitOutput("lock", c, null)
		when PC.PrimitiveStmt.UNLOCK  
			c = compiler.compile(@children[0], loopEntry)
			if compiler.useReentrantLocks
				a = compiler.getVariableWithNameOfClass("a", null, true).getContainer(compiler)
				compiler.emitOutput("unlock", c, a)
			else
				compiler.emitOutput("unlock", c, null)
		when PC.PrimitiveStmt.WAIT
			throw new Error("Unexpected expression!") if !(@children[0] instanceof PC.IdentifierExpression)
			cond = compiler.getVariableWithNameOfClass(@children[0].identifier)
			entry = compiler.emitNextProcessFrame()
			b = compiler.compile(cond.node.getExpression())
			control = compiler.emitChoice()
			compiler.emitCondition(new PCCUnaryContainer("!", b))
			c = cond.getContainer(compiler)
			compiler.emitOutput("add", c, null)
			g = compiler.getVariableWithNameOfClass("guard", null, true).getContainer(compiler)
			a = if compiler.useReentrantLocks then compiler.getVariableWithNameOfClass("a", null, true).getContainer(compiler) else null
			compiler.emitOutput("unlock", g, a)
			compiler.emitOutput("wait", c, null)
			compiler.emitOutput("lock", g, a)
			entry.emitCallProcessFromFrame(compiler, compiler.getProcessFrame())
			control.setBranchFinished()
			compiler.emitCondition(b)
			
		when PC.PrimitiveStmt.SIGNAL
			c = compiler.compile(@children[0], loopEntry)
			compiler.emitOutput("signal", c, null)
		when PC.PrimitiveStmt.SIGNAL_ALL
			c = if @children.length > 0 then compiler.compile(@children[0], loopEntry) else null
			vars = []
			if c
				throw new Error("Unexpected expression!") if !(@children[0] instanceof PC.IdentifierExpression)
				vars = [compiler.getVariableWithNameOfClass(@children[0].identifier)]
			else
				vars = compiler.getCurrentClass().getAllConditions()
			for v in vars
				c = v.getContainer(compiler)
				compiler.emitOutput("signal_all", c, null)
	[]
	
	

PC.PrintStmt::compile = (compiler, loopEntry) ->
	return if @children.length == 0
	compiler.protectContainer(compiler.compile(c)) for c in @children
	args = []
	args.unshift(compiler.unprotectContainer()) for c in @children

	out = args[0]
	(out = new PCCBinaryContainer(out, args[i], "^")) for i in [1...@children.length] by 1
	compiler.emitOutput("println", null, out)
	[]
	
	

