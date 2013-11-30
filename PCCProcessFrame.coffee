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
	Manages multiple versions of process frames. A process frame is the set of all arguments, local variables and temporary containers of a compile unit, also called a process groupable (e.g. a procedure) at a specific time.
	Process frames may exist in multiple versions: One version for each CCS process. Because of restrictions of CCS it is not always possible to compile into a single process. This class helps to manage the fragmentation of code into multiple processes.
	Versions are partially ordered.
###

###
	Groupable implements:
	 getProcessName()
###

class PCCProcessFrame
	constructor: (@groupable, @variables=[], @tempTypes=[], autoInit=true) ->		# tempTypes for incoming temp values
		@_freshInit() if autoInit
		null
	
	_freshInit: ->	# no copy
		@groupable.frameCount = 0 if @groupable.frameCount == undefined
		@processID = @groupable.frameCount++
		@containerIndex = 0
		@usedContainers = []
		@varTable = {}
		(@varTable[v.getIdentifier()] = @createContainer(v.getCCSType(), v.getSuggestedContainerName())) for v in @variables
		@protections = (@createContainer(@tempTypes[i], "t#{i}") for i in [0...@tempTypes.length] by 1)
		@initialVariableCount = @variables.length
	
	
	_argumentsForProcessDefinition: ->
		args = (@varTable[v.getIdentifier()] for v in @variables)
		args.concat(@protections)
	
	emitProcessDefinition: (compiler) ->	
		args = @_argumentsForProcessDefinition()
		compiler._silentlyAddProcessDefinition(@_getProcessName(), args)
	
	_getProcessName: ->	"#{@groupable.getProcessName()}#{if @processID > 0 then "_#{@processID}" else ""}"
	
	_getProcessArgCount: -> @initialVariableCount + @tempTypes.length
	#@initialVariableCount + @protections.length
	
	
	
	_didAlreadyUseContainerWithIdentifier: (id) ->
		(return true if c.identifier == id) for c in @usedContainers
		false
	
	createContainer: (ccsType, wish) ->
		if typeof wish is "string" and wish.length > 0 and wish.indexOf("f_") isnt 0 and not @_didAlreadyUseContainerWithIdentifier(wish)
			id = wish
		else
			id = "f_#{@containerIndex++}"
		container = new PCCVariableContainer(id, ccsType)
		@usedContainers.push(container)
		container
		
	getContainerForVariable: (identifier) ->
		throw new Error("Unknown variable!") if @varTable[identifier] == undefined
		@varTable[identifier]
	
	assignContainerToVariable: (identifier, container) ->
		throw new Error("Unknown variable!") if @varTable[identifier] == undefined
		@varTable[identifier] = container
	
	addLocalVariable: (variable, container) ->
		@variables.push(variable) if not @varTable[variable.getIdentifier()]
		@varTable[variable.getIdentifier()] = container
	
	
	protectContainer: (container) ->
		@protections.push(container)
	
	unprotectContainer: ->
		@protections.pop()
	
	getProtectedContainer: ->
		throw new Error("No protected containers available") if @protections.length == 0
		@protections[@protections.length-1]
		
	isContainerLocalVariable: (container) ->
		(return true if container.isEqual(c)) for v, c of @varTable
		false 
	
	
		
		
	
	createFollowupFrame: -> PCCProcessFrame.createFollowupFrameForFrames([@])
	_createFollowupFrameAcceptingTempTypes: (tempTypes) -> new PCCProcessFrame(@groupable, @variables[..], tempTypes)
	
	createNewScope: -> @copy()		# That's old: Creation of scope and transition to it is one step here and must be separated!
	
	
	_checkCallConsistency: (frame) ->
		fail = frame.protections.length != @tempTypes.length
		fail = true if frame.groupable != @groupable
		fail = true if frame.variables.length < @initialVariableCount
		for i in [0...@initialVariableCount] by 1
			(fail = true; break) if @variables[i].getIdentifier() != frame.variables[i].getIdentifier()
		throw new Error("Call consistency is violated!") if fail
		null
		###
		return if @parentFrame == frame or @ == frame
		while frame.parentFrame
			frame = frame.parentFrame
			return if frame == @parentFrame
		throw new Error("Frame must be connected in hierarchy")
		###
	
	_argumentsToCallProcessFromFrame: (frame) ->
		args = (frame.varTable[@variables[i].getIdentifier()] for i in [0...@initialVariableCount] by 1)
		args.concat(frame.protections[0...@tempTypes.length])
	
	emitCallProcessFromFrame: (compiler, frame, appPlaceholder) ->
		@_checkCallConsistency(frame)
		args = @_argumentsToCallProcessFromFrame(frame)
		@emitCallProcessWithArgumentContainers(compiler, args, appPlaceholder)
		
	emitCallProcessWithArgumentContainers: (compiler, containers, appPlaceholder) ->
		if containers.length != @_getProcessArgCount()
			throw new Error("Number of argument containers does not match number of required arguments") 
		if appPlaceholder
			appPlaceholder.set(@_getProcessName(), containers)
		else
			compiler.emitProcessApplication(@_getProcessName(), containers)
		
	copy: ->
		res = new PCCProcessFrame(@groupable, @variables[..], @tempTypes, false)
		@_copyVariablesToCopy(res)
		res.parentFrame = @
		res
	
	_copyVariablesToCopy: (res) ->
		res.processID = @processID
		res.containerIndex = @containerIndex
		res.usedContainers = @usedContainers[..]
		res.varTable = {}
		(res.varTable[v.getIdentifier()] = @varTable[v.getIdentifier()]) for v in @variables
		res.protections = @protections[..]
		res.initialVariableCount = @initialVariableCount
			
		

class PCCProcedureFrame extends PCCProcessFrame
	constructor: (procedure, variables, tempTypes, autoInit) -> 
		if not variables
			variables = procedure.arguments
			if procedure.isClassProcedure()
				variables.unshift(new PCCVariableInfo(null, "i", null, true)) 	#ToDo: add type
			#variables.unshift(new PCCVariableInfo(null, "r", null, true))
			
		super procedure, variables, tempTypes, autoInit
		
	getProcedure: -> @groupable
	
	#_argumentsForProcessDefinition: ->
		#args = super
		#args.unshift(PCCContainer.GUARD()) if @groupable.isMonitorProcedure()	# ???????
		#args.unshift(PCCContainer.INSTANCE()) if @groupable.isClassProcedure()
		#args.unshift(PCCContainer.RETURN())
		#args
	
	#_getProcessArgCount: ->
		#result = super + 1
		#result += 1 if @groupable.isMonitorProcedure()
		#result += 1 if @groupable.isClassProcedure()
		#result
	###
	getContainerForVariable: (identifier) ->
		if identifier == "i_r" then PCCContainer.RETURN()
		else if identifier == "i_i" then PCCContainer.INSTANCE()
		else if identifier == "i_g" then PCCContainer.GUARD()
		else super
	
	assignContainerToVariable: (identifier, container) ->
		throw new Error("Tried to assign read-only variable!") if identifier == "i_r" or identifier == "i_i" or identifier == "i_g"
		super
	
	addLocalVariable: (variable, container) ->
		identifier = variable.getName()
		throw new Error("Tried to add internal read-only variable!") if identifier == "i_r" or identifier == "i_i" or identifier == "i_g"
		super###
	
	_createFollowupFrameAcceptingTempTypes: (tempTypes) -> new PCCProcedureFrame(@groupable, @variables[..], tempTypes)
	
	###
	_argumentsToCallProcessFromFrame: (frame) ->
		args = super
		#args.unshift(PCCContainer.GUARD()) if @groupable.isMonitorProcedure()
		args.unshift(PCCContainer.INSTANCE()) if @groupable.isClassProcedure()
		args.unshift(PCCContainer.RETURN())
		args###
	
	copy: ->
		res = new PCCProcedureFrame(@groupable, @variables[..], @tempTypes, false)
		@_copyVariablesToCopy(res)
		res.parentFrame = @
		res
	
	
	
		


PCCProcessFrame::parentFrame = null	# closestAncestor
PCCProcessFrame::mark = (m) ->
	@marked = [] if not @marked
	@marked.push(m)

PCCProcessFrame.checkTempTypesEquality = (prot1, prot2) ->
	return false if prot1.length != prot2.length
	(return false if not prot1[i].ccsType.isEqual(prot2[i].ccsType)) for i in [0...prot1.length]
	true
PCCProcessFrame.checkFramesForConsistency = (frames) ->
	groupable = frames[0].groupable
	protections = frames[0].protections
	(if frames[i].groupable != groupable || !PCCProcessFrame.checkTempTypesEquality(protections, frames[i].protections)
		throw new Error("Inconsistent process frames")
	) for i in [1...frames.length] by 1
	null

PCCProcessFrame.findClosesAncestorForFrames = (frames) ->
	closestAncestor = null
	markedFrames = []
	currentFrames = frames.concat([])
	while closestAncestor == null
		(if currentFrames[i] != null
			currentFrames[i].mark(frames[i])
			markedFrames.push(currentFrames[i])
			(closestAncestor = currentFrames[i]; break) if currentFrames[i].marked.length == frames.length
			currentFrames[i] = currentFrames[i].parentFrame
		) for i in [0...frames.length] by 1
	(f.marked = null) for f in markedFrames
	closestAncestor
	
PCCProcessFrame.createFollowupFrameForFrames = (frames) ->
	PCCProcessFrame.checkFramesForConsistency(frames)
	closestAncestor = PCCProcessFrame.findClosesAncestorForFrames(frames)
	
	result = closestAncestor._createFollowupFrameAcceptingTempTypes(c.ccsType for c in frames[0].protections)
	result.parentFrame = closestAncestor
	result









PCCProcessFrame::compilerHandleNewVariableWithDefaultValueCallback = (compiler, variable) ->
	c = variable.compileDefaultValue(compiler)
	compiler.getProcessFrame().addLocalVariable(variable, c)
	variable

PCCProcessFrame::compilerGetVariable = (compiler, identifier) -> 
	(return new PCCLocalVariable(v.node, v.getName(), v.type, v.isInternal) if v.getIdentifier() == identifier) for v in @variables
	#if @varTable[identifier] then new PCCLocalVariable(identifier) else null
	null
		
PCCProcessFrame::compilerGetProcedure = (compiler, identifier, instanceContainer) -> null



#PCCProcedureFrame::compilerGetVariable = (compiler, identifier) -> @getProcedure().getVariableWithName(identifier)
#PCCProcedureFrame::compilerGetVariable = (compiler, identifier) -> 
#	if identifier == "i_r" or identifier == "i_i" or identifier == "i_g" then new PCCLocalVariable(identifier)
#	else super
		
PCCProcedureFrame::compilerGetProcedure = (compiler, identifier, instanceContainer) -> 
	p = @getProcedure()
	if p.getName() == identifier then p else p.getProcedureWithName(identifier)




###
class PCCContainerInfo
	constructor: (@payload, @isLocalVariable) ->


class PCCContainerInfoArray
	constructor: (temporaryItems=[]) -> @infos = (new PCCContainerInfo(c, false) for c in temporaryItems)
	copy: ->
		res = new PCCContainerProtectionArray()
		res.infos = @infos[..]
		res
	getCount: ->
		res = 0
		++res for ci in @infos
		res
	
	# Protecting Containers
	protectContainer: (container, isLocalVariable) ->
		@protections.push(new PCCContainerInfo(container, isLocalVariable))
	unprotectContainer: -> @infos.pop().container
	getContainer: ->
		throw new Error("getProtection: Nothing protected at the moment!") if @infos.length == 0
		@infos[@infos.length-1].payload
	getTemporaryContainers: ->
		res = []
		(res.push(ci.payload) if not ci.isLocalVariable) for ci in @infos
		res
	
	getCCSTypes: ->
		res = new PCCContainerInfoArray()
		res.infos = (new PCCContainerInfo(ci.payload.ccsType, ci.isLocalVariable) for ci in @infos)
		res
		
	getTemporaryTypes: ->
		res = []
		return res if infos.length == 0
		if @infos[0].payload instanceof PCCContainer
			(res.push(ci.payload.ccsType) if not cp.isLocalVariable) for ci in @infos
		else if infos[0].payload instanceof PCCType
			(res.push(ci.payload) if not cp.isLocalVariable) for ci in @infos
		else
			throw new Error("getTemporaryTypes not applicable on payload!")
		res
	
###

# Convenience

class PCCGroupable
	constructor: (@processName) ->
	getProcessName: -> @processName


###

{version: "1.0", tree: (new PCProgram((new PCMonitor("M", (new PCConditionDecl("c", (new PCRelationalExpression((new PCLiteralExpression(parseInt(3))), "<", (new PCLiteralExpression(parseInt(4))))))), (new PCConditionDecl("c2", (new PCLiteralExpression(true)))), (new PCConditionDecl("c3", (new PCLiteralExpression(false)))), (new PCProcedureDecl((new PCSimpleType(PCSimpleType.VOID)), "f", (new PCStmtBlock((new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.WAIT, (new PCIdentifierExpression("c")))))), (new PCStatement((new PCPrintStmt((new PCLiteralExpression("condition fulfilled!")))))))))), (new PCProcedureDecl((new PCSimpleType(PCSimpleType.VOID)), "g", (new PCStmtBlock((new PCStatement((new PCPrintStmt((new PCLiteralExpression("Before signal")))))), (new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.SIGNAL, (new PCIdentifierExpression("c")))))), (new PCStatement((new PCPrintStmt((new PCLiteralExpression("Behind signal")))))), (new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.SIGNAL_ALL)))), (new PCStatement((new PCPrintStmt((new PCLiteralExpression("Behind signallAll")))))))))))), (new PCDeclStmt((new PCSimpleType(PCSimpleType.MUTEX)), (new PCVariableDeclarator("guard", null)))), (new PCMainAgent((new PCStmtBlock((new PCDeclStmt((new PCClassType("M")), (new PCVariableDeclarator("m", null)))), (new PCDeclStmt((new PCSimpleType(PCSimpleType.AGENT)), (new PCVariableDeclarator("a", (new PCVariableInitializer(false, (new PCStartExpression((new PCProcedureCall("agent1", (new PCIdentifierExpression("m")))))))))))), (new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.LOCK, (new PCIdentifierExpression("guard")))))), (new PCStatement((new PCStmtExpression((new PCClassCall((new PCIdentifierExpression("m")), (new PCProcedureCall("f")))))))), (new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.UNLOCK, (new PCIdentifierExpression("guard")))))), (new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.JOIN, (new PCIdentifierExpression("a")))))))))), (new PCProcedureDecl((new PCSimpleType(PCSimpleType.VOID)), "agent1", (new PCStmtBlock((new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.LOCK, (new PCIdentifierExpression("guard")))))), (new PCStatement((new PCStmtExpression((new PCClassCall((new PCIdentifierExpression("m")), (new PCProcedureCall("g")))))))), (new PCStatement((new PCPrimitiveStmt(PCPrimitiveStmt.UNLOCK, (new PCIdentifierExpression("guard")))))))), (new PCFormalParameter((new PCClassType("M")), "m"))))))}

	
{version: "1.0", tree: (new PCProgram((new PCDeclStmt((new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("x", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(41))))))))), (new PCMainAgent((new PCStmtBlock((new PCStatement((new PCPrintStmt((new PCAdditiveExpression((new PCIdentifierExpression("x")), "+", (new PCLiteralExpression(parseInt(1)))))))))))))))}


{version: "1.0", tree: (new PCProgram((new PCDeclStmt((new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("n", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(0))))))))), (new PCProcedureDecl((new PCSimpleType(PCSimpleType.VOID)), "count", (new PCStmtBlock((new PCStatement((new PCForStmt((new PCStatement((new PCStmtBlock((new PCStatement((new PCStmtExpression((new PCPostfixExpression((new PCAssignDestination("n")), "++")))))), (new PCStatement((new PCPrintStmt((new PCLiteralExpression("Der neue Wert von n ist ")), (new PCIdentifierExpression("n")))))))))), (new PCForInit((new PCDecl((new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("i", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(0))))))))))), (new PCRelationalExpression((new PCIdentifierExpression("i")), "<", (new PCLiteralExpression(parseInt(10))))), (new PCStmtExpression((new PCPostfixExpression((new PCAssignDestination("i")), "++")))))))))))), (new PCMainAgent((new PCStmtBlock((new PCDeclStmt((new PCSimpleType(PCSimpleType.AGENT)), (new PCVariableDeclarator("a1", (new PCVariableInitializer(false, (new PCStartExpression((new PCProcedureCall("count")))))))))), (new PCDeclStmt((new PCSimpleType(PCSimpleType.AGENT)), (new PCVariableDeclarator("a2", (new PCVariableInitializer(false, (new PCStartExpression((new PCProcedureCall("count")))))))))), (new PCStatement((new PCPrintStmt((new PCLiteralExpression("Main agent ist terminiert! n = ")), (new PCIdentifierExpression("n"))))))))))))}



{version: "1.0", tree: (new PCProgram((new PCDeclStmt((new PCChannelType(PCSimpleType.INT, 5)), (new PCVariableDeclarator("c", null)))), (new PCProcedureDecl((new PCSimpleType(PCSimpleType.VOID)), "f", (new PCStmtBlock((new PCStatement((new PCForStmt((new PCStatement((new PCStmtExpression((new PCSendExpression((new PCIdentifierExpression("cc")), (new PCIdentifierExpression("i")))))))), (new PCForInit((new PCDecl((new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("i", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(0))))))))))), (new PCRelationalExpression((new PCIdentifierExpression("i")), "<", (new PCLiteralExpression(parseInt(5))))), (new PCStmtExpression((new PCPostfixExpression((new PCAssignDestination("i")), "++")))))))))), (new PCFormalParameter((new PCChannelType(PCSimpleType.INT, PCChannelType.CAPACITY_UNKNOWN)), "cc")))), (new PCMainAgent((new PCStmtBlock((new PCStatement((new PCStmtExpression((new PCStartExpression((new PCProcedureCall("f", (new PCIdentifierExpression("c")))))))))), (new PCStatement((new PCForStmt((new PCStatement((new PCPrintStmt((new PCReceiveExpression((new PCIdentifierExpression("c")))))))), (new PCForInit((new PCDecl((new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("i", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(0))))))))))), (new PCRelationalExpression((new PCIdentifierExpression("i")), "<", (new PCLiteralExpression(parseInt(5))))), (new PCStmtExpression((new PCPostfixExpression((new PCAssignDestination("i")), "++"))))))))))))))}



###
