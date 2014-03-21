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




PCNode::compile = (compiler) ->
	throw new Error("Abstract method!")
PCNode::_childrenCompile = (compiler) ->
	compiler.compile(c) for c in @children
	
	

PCProgram::compile = (compiler) -> 
	compiler.beginProgram()
	@_childrenCompile(compiler)
	compiler.endProgram()
	
	

PCMainAgent::compile = (compiler) ->
	compiler.beginMainAgent()
	#i_r = compiler.getFreshContainer(PCCType.INT, "ret")
	#compiler.emitInput("channel1_create", null, i_r)
	#i_r = new PCCConstantContainer(-1)
	#compiler.getProcessFrame().addLocalVariable(new PCCVariableInfo(null, "r", null, true), i_r)
	@_childrenCompile(compiler)
	compiler.emitStop()
	compiler.endMainAgent()
	
	

PCProcedureDecl::compile = (compiler) ->
	compiler.beginProcedure(@name)
	proc = compiler.getProcedureWithName(@name)
	if proc.isMonitorProcedure()
		guard = compiler.getVariableWithName("guard", null, true)
		compiler.emitOutput("lock", guard.getContainer(compiler))
	compiler.compile(@getBody())		
	proc.emitExit(compiler)
	compiler.endProcedure()
	[]
	
	

PCFormalParameter::compile = (compiler) ->
	throw new Error("Not implemented!")
	
	

PCMonitor::compile = (compiler) ->
	compiler.beginClass(@name)
	@_childrenCompile(compiler)
	compiler.endClass()
	
	

PCStruct::compile = (compiler) ->
	compiler.beginClass(@name)
	@_childrenCompile(compiler)
	compiler.endClass()
	
	


PCConditionDecl::compile = (compiler) ->
	context = {target: @, compiler: compiler}
	variable = new PCCVariableInfo(@, @name, new PCTType(PCTType.CONDITION))
	compiler.handleNewVariableWithDefaultValueCallback(variable)
	[]

PCConditionDecl::compileDefaultValue = (compiler) ->
	result = compiler.getFreshContainer(PCCType.INT)
	compiler.emitInput("wait_create", null, result)
	result
	
	
	

PCDecl::compile = (compiler) ->
	type = @children[0]
	compiler.compile(vd) for vd in @getDeclarators()
	[]
	
	
	

PCVariableDeclarator::compile = (compiler) ->
	context = {target: @, compiler: compiler}
	variable = new PCCVariableInfo(@, @name, @getTypeNode().getType(compiler).type)
	compiler.handleNewVariableWithDefaultValueCallback(variable)

PCVariableDeclarator::compileDefaultValue = (compiler) ->
	type = @getTypeNode().getType(compiler).type
	if @getInitializer()
		compiler.compile(@getInitializer(), type)
	else
		type.createContainer(compiler)
	
	
	

PCVariableInitializer::compile = (compiler, type) ->
	if @isArray()
		cc = (compiler.compile(c, type.elementsType) for c in @children)
		type.createContainer(compiler, cc)
	else
		type.createContainer(compiler, compiler.compile(@children[0]))
	
	
	

PCExpression::compile = (compiler) ->
	throw new Error("Not implemented!")
PCExpression::getValueForArrayAtIndex = (compiler, instanceContainer, indexContainer) ->
	compiler.emitOutput("array_access", instanceContainer, indexContainer)
	result = compiler.getFreshContainer(instanceContainer.ccsType.getSubtype())
	compiler.emitInput("array_get", instanceContainer, result)
	result
	
	

PCStartExpression::compile = (compiler) ->
	@children[0].compileSend(compiler)
	
	

PCAssignExpression::compile = (compiler) ->
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
	
	

PCAssignDestination::compile = (compiler) ->	# Returns the same value as array expression would do (used for +=, *=,  ...)
	arrayIndexCount = @children.length
	v = compiler.getVariableWithName(@identifier, null)
	res = v.getContainer(compiler)
	(res = @getValueForArrayAtIndex(compiler, ai, compiler.compile(@children[i]))) for i in [0...arrayIndexCount] by 1
	res
PCAssignDestination::setValueForArrayAtIndex = (compiler, instanceContainer, indexContainer, valueContainer) ->
	compiler.emitOutput("array_access", instanceContainer, indexContainer)
	compiler.emitOutput("array_set", instanceContainer, valueContainer)
	valueContainer
PCAssignDestination::assignContainer = (compiler, c) ->
	arrayIndexCount = @children.length
	v = compiler.getVariableWithName(@identifier, null)
	if arrayIndexCount == 0
		v.setContainer(compiler, c)
	else
		ai = v.getContainer(compiler)
		(ai = @getValueForArrayAtIndex(compiler, ai, compiler.compile(@children[i]))) for i in [0..arrayIndexCount-2] by 1
		@setValueForArrayAtIndex(compiler, ai, compiler.compile(@children[arrayIndexCount-1]), c)
	

	

PCSendExpression::compile = (compiler) ->
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
	
	
	

PCConditionalExpression::compile = (compiler) ->
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
	
	

PCOrExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, "||")
	
	

PCAndExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, "&&")
	
	

PCEqualityExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PCRelationalExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PCAdditiveExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PCMultiplicativeExpression::compile = (compiler) ->
	left = compiler.compile(@children[0])
	compiler.protectContainer(left)
	right = compiler.compile(@children[1])
	left = compiler.unprotectContainer()
	new PCCBinaryContainer(left, right, @operator)
	
	

PCUnaryExpression::compile = (compiler) ->
	new PCCUnaryContainer(@operator, compiler.compile(@children[0]))
	
	

PCPostfixExpression::compile = (compiler) ->
	op = if @operator == "++" then "+" else if @operator == "--" then "-" else throw new Error("Unknown postfix operator")
	c = new PCCBinaryContainer(compiler.compile(@children[0]), new PCCConstantContainer(1), op)
	@children[0].assignContainer(compiler, c)
	c
	
	

PCReceiveExpression::compile = (compiler) ->
	c = compiler.compile(@children[0])
	res = compiler.getFreshContainer(c.ccsType.getSubtype())
	compiler.emitInput("receive", c, res)
	res
	
	


PCProcedureCall::compile = (compiler, instanceContainer, className) ->
	proc = compiler.getProcedureWithName(@procedureName, className)
	compiler.protectContainer(instanceContainer) if instanceContainer
	compiler.protectContainer(compiler.compile(c)) for c in @children
	control = compiler.emitSequence()
	args = []
	args.unshift(compiler.unprotectContainer()) for c in @children
	instanceContainer = compiler.unprotectContainer() if instanceContainer
	args = proc.getAllArgumentContainers(compiler, args, instanceContainer)
	compiler.emitProcessApplication(proc.getProcessName(), args)
	control.setBranchFinished()	# left is finished
	if proc.returnType.kind != PCTType.VOID
		res = compiler.getFreshContainer(proc.returnType.getCCSType())
		#compiler.emitInput("receive", compiler.getVariableWithName("r", null, true).getContainer(compiler), res)
		compiler.emitInput("rreturn", null, res)
		res
	else
		null
PCProcedureCall::compileSend = (compiler, instanceContainer, className) ->
	proc = compiler.getProcedureWithName(@procedureName, className)
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


PCClassCall::compile = (compiler) ->
	className = @children[0].getType(compiler).identifier
	compiler.compile(@children[1], compiler.compile(@children[0]), className)
PCClassCall::compileSend = (compiler) ->
	className = @children[0].getType(compiler).identifier
	@children[1].compileSend(compiler, compiler.compile(@children[0]), className)
	

PCArrayExpression::compile = (compiler) ->
	a = compiler.compile(@children[0])
	compiler.protectContainer(a)
	t = compiler.compile(@children[1])
	a = compiler.unprotectContainer()
	compiler.emitOutput("array_access", a, t)
	res = compiler.getFreshContainer(@children[0].getType(compiler).type)
	compiler.emitInput("array_get", a, res)
	res
	
	

PCLiteralExpression::compile = (compiler) ->
	new PCCConstantContainer(@value)
	
	

PCIdentifierExpression::compile = (compiler) ->
	v = compiler.getVariableWithName(@identifier, null)
	v.getContainer(compiler)
	
	

PCStatement::compile = (compiler, loopEntry) ->
	compiler.compile(@children[0], loopEntry)
	
	

PCBreakStmt::compile = (compiler, loopEntry) ->
	[compiler.emitProcessApplicationPlaceholder()]
	
	

PCContinueStmt::compile = (compiler, loopEntry) ->
	loopEntry.emitCallProcessFromFrame(compiler, compiler.getProcessFrame())
	[]
	
	

PCStmtBlock::compile = (compiler, loopEntry) ->
	statusQuo = compiler.getProcessFrame()
	compiler.emitNewScope()
	breaks = (compiler.compile(c, loopEntry) for c in @children).concatChildren()
	compiler.emitNewScope(statusQuo);
	breaks
	
	

PCStmtExpression::compile = (compiler, loopEntry) ->
	compiler.compile(@children[0])
	[]
	
	

PCSelectStmt::compile = (compiler, loopEntry) ->
	return if @children.length == 0
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
	debugger
	breaks
	
	

PCCase::compile = (compiler, loopEntry) ->
	cond = @getCondition()
	if cond
		compiler.compile(cond)
	compiler.compile(@getExecution(), loopEntry)
	
	

PCIfStmt::compile = (compiler, loopEntry) ->
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
	breaks
	
	

PCWhileStmt::compile = (compiler) ->
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
	[]
	

PCDoStmt::compile = (compiler) ->
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
	[]
	
	
	
	

PCForStmt::compile = (compiler) ->
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
	[]
	
	

PCForInit::compile = (compiler) ->
	compiler.compile(c) for c in @children
	[]
	
	

PCReturnStmt::compile = (compiler, loopEntry) ->
	if @children.length == 1
		res = compiler.compile(@children[0])
		compiler.emitOutput("return", null, res)
	compiler.getCurrentProcedure().emitExit(compiler)
	[]
	
	

PCPrimitiveStmt::compile = (compiler, loopEntry) ->
	switch @kind
		when PCPrimitiveStmt.JOIN
			c = compiler.compile(@children[0], loopEntry)
			compiler.emitOutput("join_register", c, null)
			compiler.emitOutput("join", c, null)
		when PCPrimitiveStmt.LOCK  
			c = compiler.compile(@children[0], loopEntry)
			compiler.emitOutput("lock", c, null)
		when PCPrimitiveStmt.UNLOCK  
			c = compiler.compile(@children[0], loopEntry)
			compiler.emitOutput("unlock", c, null)
		when PCPrimitiveStmt.WAIT
			throw new Error("Unexpected expression!") if !(@children[0] instanceof PCIdentifierExpression)
			cond = compiler.getVariableWithName(@children[0].identifier)
			entry = compiler.emitNextProcessFrame()
			b = compiler.compile(cond.node.getExpression())
			control = compiler.emitChoice()
			compiler.emitCondition(new PCCUnaryContainer("!", b))
			c = cond.getContainer(compiler)
			compiler.emitOutput("add", c, null)
			g = compiler.getVariableWithName("guard", null, true).getContainer(compiler)
			compiler.emitOutput("unlock", g, null)
			compiler.emitOutput("wait", c, null)
			compiler.emitOutput("lock", g, null)
			entry.emitCallProcessFromFrame(compiler, compiler.getProcessFrame())
			control.setBranchFinished()
			compiler.emitCondition(b)
			
		when PCPrimitiveStmt.SIGNAL  
			c = compiler.compile(@children[0], loopEntry)
			compiler.emitOutput("signal", c, null)
		when PCPrimitiveStmt.SIGNAL_ALL
			c = if @children.length > 0 then compiler.compile(@children[0], loopEntry) else null
			vars = []
			if c
				throw new Error("Unexpected expression!") if !(@children[0] instanceof PCIdentifierExpression)
				vars = [compiler.getVariableWithName(@children[0].identifier)]
			else
				vars = compiler.getCurrentClass().getAllConditions()
			for v in vars
				c = v.getContainer(compiler)
				compiler.emitOutput("signal_all", c, null)
	[]
	
	

PCPrintStmt::compile = (compiler, loopEntry) ->
	return if @children.length == 0
	out = compiler.compile(@children[0])
	# Wrong: I have to protect containers!!!
	(out = new PCCBinaryContainer(out, compiler.compile(@children[i]), "+")) for i in [1...@children.length] by 1
	compiler.emitOutput("println", null, out)
	[]
	
	

