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
	constructor: (@groupable, @variables=[], @acceptTemp=false) ->
		@groupable.frameCount = 0 if @groupable.frameCount == undefined
		@processID = @groupable.frameCount++
		@containerIndex = 0
		@usedContainers = []
		@varTable = {}
		(@varTable[v] = @createContainer(v)) for v in @variables
		@tempContainer = if @acceptTemp then @createContainer("t") else null
		@initialVariableCount = @variables.length
	
	
	_argumentsForProcessDefinition: ->
		args = @varTable[v].identifier for v in @variables
		args.push(@tempContainer.identifier) if @acceptTemp
		args
	
	createProcessDefinition: ->		# This should be the first call on frame objects!
		args = @_argumentsForProcessDefinition()
		new CCSProcessDefinition(@_getprocessName(), new CCSStop(), args)
	
	_getProcessName: ->	"#{@groupable.getProcessName()}#{if @processID > 0 then "_#{@processID}" else ""}"
	
	_getProcessArgCount: ->
		result = @initialVariableCount
		result += 1 if @acceptTemp
		result
	
	
	
	_didAlreadyUseContainerWithIdentifier: (id) ->
		(return true if c.identifier == id) for c in @usedContainers
		false
	
	createContainer: (wish) ->
		if typeof wish is "string" and wish.length > 0 and wish.indexOf("f_") isnt 0 and not @_didAlreadyUseContainerWithIdentifier(wish)
			id = wish
		else
			id = "f_#{@containerIndex++}"
		container = new PCCVariableContainer(id)
		@usedContainers.push(container)
		container
		
	getContainerForVariable: (identifier) ->
		throw new Error("Unknown variable!") if @varTable[variable] == undefined
		@varTable[variable]
	
	assignContainerToVariable: (variable, container) ->
		throw new Error("Unknown variable!") if @varTable[variable] == undefined
		@varTable[variable] = container
	
	addLocalVariable: (variable, container) ->
		throw new Error("Variable already defined!") if @varTable[variable] != undefined
		@variables.push(variable)
		@varTable[variable] = container
	
	
		
		
	
	createFollowupFrame: -> PCCProcessFrame.createFollowupFrameForFrames([@])
	_createFollowupFrameAcceptingTempContainer: (acceptTemp) -> new PCCProcessFrame(@groupable, @variables, acceptTemp)
	
	
	
	_checkHierarchyConsistency: (frame) ->
		return if @parentFrame == frame or @ == frame
		while frame.parentFrame != null
			frame = frame.parentFrame
			return if frame == @
		throw new Error("Frame must be connected in hierarchy")
	
	_argumentsToCallProcessFromFrame: (frame) ->
		args = frame.varTable[v] for v in @variables
		args.push(frame.tempContainer) if @acceptTemp
		args
	
	createCallProcessFromFrame: (frame) ->
		@_checkHierarchyConsistency (frame)
		args = @__argumentsToCallProcessFromFrame (frame)
		@createCallProcessWithArgumentContainers(args)
		
	createCallProcessWithArgumentContainers: (containers) ->
		if containers.length != @_getProcessArgCount()
			throw new Error("Number of argument containers does not match number of required arguments") 
		new CCSProcessApplication(@_getProcessName(), (c.ccsTree() for c in containers))
		
		# Create procedure call without setting up a frame!?!?!?!
		
		

class PCCProcedureFrame
	constructor: (procedure, variables=procedure.arguments, acceptTemp) -> super procedure, variables, acceptTemp
		
	getProcedure: -> @groupable
	
	_argumentsForProcessDefinition: ->
		args = super
		args.unshift(PCCContainer.GUARD()) if @groupable.isMonitorProcedure()
		args.unshift(PCCContainer.INSTANCE()) if @groupable.isClassProcedure()
		args.unshift(PCCContainer.RETURN())
		args
	
	_getProcessArgCount: ->
		result = super + 1
		result += 1 if @groupable.isMonitorProcedure()
		result += 1 if @groupable.isClassProcedure()
		result
	
	
	_createFollowupFrameAcceptingTempContainer: (acceptTemp) -> new PCCProcedureFrame(@groupable, @variables, acceptTemp)
	
	
	_argumentsToCallProcessFromFrame: (frame) ->
		args = super
		args.unshift(PCCContainer.GUARD()) if @groupable.isMonitorProcedure()
		args.unshift(PCCContainer.INSTANCE()) if @groupable.isClassProcedure()
		args.unshift(PCCContainer.RETURN())
		args
	
	
	
		


PCCProcessFrame::parentFrame = null	# closestAncestor
PCCProcessFrame::marked = []
PCCProcessFrame.checkFramesForConsistency = (frames) ->
	groupable = frames[0].groupable
	hasTemp = frames[0].tempContainer != null
	(if frames[i].groupable != groupable || (frames[i].tempContainer != null) != hasTemp
		throw new Error("Inconsistent process frames")
	) for i in [1...frames.length] by 1
	null

PCCProcessFrame.findClosesAncestorForFrames = (frames) ->
	closestAncestor = null
	markedFrames = []
	currentFrames = frames.concat([])
	while closestAncestor == null
		(if currentFrames[i] != null
			currentFrames[i].marked.push(frames[i])
			markedFrames.push(currentFrames[i])
			(closestAncestor = currentFrames[i]; break) if currentFrames[i].marked.length == frames.length
			currentFrames[i] = currentFrames[i].parentFrame
		) for i in [0...frames.length] by 1
	(f.marked = []) for f in markedFrames
	closestAncestor
	
PCCProcessFrame.createFollowupFrameForFrames = (frames) ->
	PCCProcessFrame.checkFramesForConsistency(frames)
	closestAncestor = PCCProcessFrame.findClosesAncestorForFrames(frames)
	
	result = closestAncestor._createFollowupFrameAcceptingTempContainer(frames[0].tempContainer != null)
	result.parentFrame = closestAncestor
	result









PCCProcessFrame::compilerHandleNewIdentifierWithDefaultValueCallback: (compiler, identifier, callback, context) ->
	@addLocalVariable(identifier, callback(context))

PPCProcessFrame::compilerGetVariable: (compiler, identifier) -> 
	if @varTable[identifier] then new PCCLocalVariable(identifier) else null
		
PCCProcessFrame::compilerGetProcedure: (compiler, identifier, instanceContainer) -> null



PCCProcedureFrame::compilerGetVariable: (compiler, identifier) -> @getProcedure().getVariableWithName(identifier)
		
PCCProcedureFrame::compilerGetProcedure: (compiler, identifier, instanceContainer) -> 
	p = @getProcedure()
	if p.getName() == identifier then p else p.getProcedureWithName(identifier)



