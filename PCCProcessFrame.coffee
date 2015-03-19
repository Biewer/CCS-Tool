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
	Optionally:
	 compilerGetProcedure(compiler, identifier)
###

class PCCProcessFrame
	
	###
		* @param groupable: An object that implements the «Groupable» interface. All process frames with the same groupable object are in the same process group.
		* @param variables: An array of PCCVariableInfo objects. The incoming variables that will get passed on transition to the represented process definition.
		* @param tempTypes: An array of PCTType objects, which represents the values that will get passed as temporary values on transition to the represented process definition.
		* @param autoInit: By default true. If the created process frame will be followup process frame, the creator of the frame might want to perform its own initialization, which it can communicate through this parameter.
		
		
		Variables:
			processID: Gives a process frame a unique identifier within the group, which is used to determine a unique name for the created process definition. For scopes the value of this variable is not relevant.
			containerIndex: The number of issued auto-named PCCVariableContainer objects (using @createContainer).
			usedContainers: An array of PCCVariableContainer objects that are already in use in the scope of the represented process definition.
			varTable: A map from PseuCo identifiers (string) to PCCContainer objects which represents the current value of the corresponding identifier.
			protections: A stack (array) of PCCContainer objects which represent a temporary value.
			initialVariableCount: The number of incomming variables.
			variables: An array of PCCVariableInfo objects, which represent the PseuCo variables currently covered by the process frame.
	###
	
	constructor: (@groupable, @variables=[], @tempTypes=[], autoInit=true) ->		# tempTypes for incoming temp values
		@_freshInit() if autoInit
		null
	
	_freshInit: ->	# no copy
		@groupable.frameCount = 0 if @groupable.frameCount == undefined		# add a global variable to the group in order to count its process frames
		@processID = @groupable.frameCount++	# this frame gets as index the number of the already created process frames (so it's unique);
		@containerIndex = 0
		@usedContainers = []
		@varTable = {}
		# auto-assign variable containers for the identifiers of the incoming variables; these will be used as the arguments of the represented process definition
		(@varTable[v.getIdentifier()] = @createContainer(v.getCCSType(), v.getSuggestedContainerName())) for v in @variables
		# the incoming temporary values will remain temporary values, so we'll create a new variable container for each of it and add it to protections array
		@protections = (@createContainer(@tempTypes[i], "t#{i}") for i in [0...@tempTypes.length] by 1)
		@initialVariableCount = @variables.length
	
	
	
	_argumentsForProcessDefinition: ->
		args = (@varTable[v.getIdentifier()] for v in @variables)
		args.concat(@protections)
	
	###
		Must be called before new containers get assigned to the variables or temporary values are pushed or popped!
	###
	emitProcessDefinition: (compiler) ->
		return if @isScope
		args = @_argumentsForProcessDefinition()
		compiler._silentlyAddProcessDefinition(@_getProcessName(), args)
	
	_getProcessName: ->	"#{@groupable.getProcessName()}#{if @processID > 0 then "_#{@processID}" else ""}"
	
	_getProcessArgCount: -> @initialVariableCount + @tempTypes.length
	
	
	
	_didAlreadyUseContainerWithIdentifier: (id) ->
		(return true if c.identifier == id) for c in @usedContainers
		false
	
	createContainer: (ccsType, wish) ->
		if typeof wish is "string" and wish.length > 0 and not wish.match(/^\$[0-9]/) and not @_didAlreadyUseContainerWithIdentifier(wish)
			id = wish
		else
			id = "$#{@containerIndex++}"
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
	
	###
		Returns the last pushed temporary value.
	###
	getProtectedContainer: ->
		throw new Error("No protected containers available") if @protections.length == 0
		@protections[@protections.length-1]
		
	isContainerLocalVariable: (container) ->
		(return true if container.isEqual(c)) for v, c of @varTable
		false 
	
	
		
		
	
	createFollowupFrame: -> PCCProcessFrame.createFollowupFrameForFrames([@])
	_createFollowupFrameAcceptingTempTypes: (tempTypes) -> new PCCProcessFrame(@groupable, @variables[..], tempTypes)
	
	getTypesForTemporaryValues: -> c.ccsType for c in @protections
		
	
	createScope: -> 
		res = new PCCProcessFrame(@groupable, @variables[..], @getTypesForTemporaryValues(), false)
		@_configureVariablesInScope(res)
		res
	
	_configureVariablesInScope: (res) ->
		res.processID = @processID
		res.initialVariableCount = @variables.length
		res.parentFrame = @
		res.isScope = true
		null
	
	
	

	
	
	###
		Guarantees that it is allowed to transition from »frame« to the receiver of the method call.
	###
	_checkTransitionConsistency: (frame) ->	
		fail = frame.protections.length != @tempTypes.length
		fail = true if frame.groupable != @groupable
		fail = @isScope and @varTable	# scope that already transitioned
		fail = true if frame.variables.length < @initialVariableCount
		for i in [0...@initialVariableCount] by 1
			(fail = true; break) if @variables[i].getIdentifier() != frame.variables[i].getIdentifier()
		throw new Error("Call consistency is violated!") if fail
		null
	
	_variablesForTransition: -> @variables[i] for i in [0...@initialVariableCount] by 1
	
	_argumentsToCallProcessFromFrame: (frame) ->
		args = (frame.varTable[v.getIdentifier()] for v in @_variablesForTransition())
		args.concat(frame.protections[0...@tempTypes.length])
	
	emitCallProcessFromFrame: (compiler, frame, appPlaceholder) ->	
		@_checkTransitionConsistency(frame)
		args = @_argumentsToCallProcessFromFrame(frame)
		@emitCallProcessWithArgumentContainers(compiler, args, appPlaceholder)
		
	emitCallProcessWithArgumentContainers: (compiler, containers, appPlaceholder) ->
		throw new Error("Illegal operation! This method cannot be used with scopes!") if @isScope
		if containers.length != @_getProcessArgCount()
			throw new Error("Number of argument containers does not match number of required arguments") 
		if appPlaceholder
			appPlaceholder.set(@_getProcessName(), containers)
		else
			compiler.emitProcessApplication(@_getProcessName(), containers)
	
	_emitScopeTransition: (compiler, frame) ->
		@containerIndex = frame.containerIndex
		@usedContainers = frame.usedContainers[..]
		@varTable = {}
		(@varTable[v.getIdentifier()] = frame.varTable[v.getIdentifier()]) for v in @_variablesForTransition()
		@protections = frame.protections[..]
	
	emitTransitionFromFrame: (compiler, frame) ->
		if @isScope
			@_checkTransitionConsistency(frame)
			@_emitScopeTransition(compiler, frame)
		else
			@emitCallProcessFromFrame(compiler, frame)
		
	
	
			
		

class PCCProcedureFrame extends PCCProcessFrame
	constructor: (procedure, variables, tempTypes, autoInit) -> 
		if not variables
			variables = procedure.arguments
			if procedure.isClassProcedure()
				variables.unshift(new PCCVariableInfo(null, "i", null, true)) 	#ToDo: add type
			variables.unshift(new PCCVariableInfo(null, "a", null, true))
			
		super procedure, variables, tempTypes, autoInit
		
	getProcedure: -> @groupable
	
	_createFollowupFrameAcceptingTempTypes: (tempTypes) -> new PCCProcedureFrame(@groupable, @variables[..], tempTypes)
	
	createScope: ->
		res = new PCCProcedureFrame(@groupable, @variables[..], @getTypesForTemporaryValues(), false)
		@_configureVariablesInScope(res)
		res
	
	
	

###
	This method creates a new process frame.
	@param frames: The array with the process frames that the new frame should be derived by.
###
PCCProcessFrame.createFollowupFrameForFrames = (frames) ->
	PCCProcessFrame.checkFramesForConsistency(frames)
	closestAncestor = PCCProcessFrame.findClosesAncestorForFrames(frames)
	
	result = closestAncestor._createFollowupFrameAcceptingTempTypes(frames[0].getTypesForTemporaryValues())
	result.parentFrame = closestAncestor
	result	


###
	Helping methods for creating a new frame.
###

# Check if the derivation frames fulfill the necessary conditions.
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
	

# Determin the closest ancestor
PCCProcessFrame::parentFrame = null		# closestAncestor
PCCProcessFrame::mark = (m) ->
	@marked = [] if not @marked
	@marked.push(m)

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
	









# Compiler delegate methods

PCCProcessFrame::compilerHandleNewVariableWithDefaultValueCallback = (compiler, variable) ->
	c = variable.compileDefaultValue(compiler)
	compiler.getProcessFrame().addLocalVariable(variable, c)
	# The order is important here, since compileDefaultValue is allowed to begin new process frames. 
	variable

PCCProcessFrame::compilerGetVariable = (compiler, identifier) -> 
	(return new PCCLocalVariable(v.node, v.getName(), v.type, v.isInternal) if v.getIdentifier() == identifier) for v in @variables
	null
		
PCCProcessFrame::compilerGetProcedure = (compiler, identifier, instanceContainer) -> null



		
PCCProcedureFrame::compilerGetProcedure = (compiler, identifier, instanceContainer) -> 
	p = @getProcedure()
	if p.getName() == identifier then p else p.getProcedureWithName(identifier)









# Convenience

class PCCGroupable
	constructor: (@processName) ->
	getProcessName: -> @processName


# PCCProcedure::compilerGetProcedure = (compiler, identifier, instanceContainer) -> 
# 	if @getName() == identifier then @ else @getProcedureWithName(identifier)
	
	
	
	
	
	
	
	
	
	
	


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




###

{version: "1.0", tree: (new PCProgram((new PCDecl(true, (new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("x", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(42))))))))), (new PCMainAgent((new PCStmtBlock((new PCDecl(true, (new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("y", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(7))))))))), (new PCStatement((new PCForStmt((new PCStatement((new PCStmtBlock((new PCStatement((new PCPrintStmt((new PCAdditiveExpression((new PCLiteralExpression("Die Zahl ist ")), "+", (new PCAdditiveExpression((new PCAdditiveExpression((new PCIdentifierExpression("x")), "+", (new PCIdentifierExpression("y")))), "+", (new PCIdentifierExpression("i")))))))))))))), (new PCForInit((new PCDecl(false, (new PCSimpleType(PCSimpleType.INT)), (new PCVariableDeclarator("i", (new PCVariableInitializer(false, (new PCLiteralExpression(parseInt(0))))))))))), (new PCRelationalExpression((new PCIdentifierExpression("i")), "<", (new PCLiteralExpression(parseInt(10))))), (new PCStmtExpression((new PCPostfixExpression((new PCAssignDestination("i")), "++"))))))))))))))}


###
