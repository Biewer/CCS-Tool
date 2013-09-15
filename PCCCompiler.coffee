###
	The central coordination class for the compile process of PseuCo to CCS.
	You start the compilation process by creating a new PCCCompiler object with the node of your PseuCo tree and call compile() on it. You'll get a CCS tree on success
###


class PCCCompiler
	construct: (@program) ->
		@controller = null
		
		@curClass = null				# We can have only one class, so we don't need an array
		@procedures = []				# Procedure stack (procedures that are being compiled)
		
		@statements = []				# Statement stack (statements that are being compiled)
		@expressions = []				# Expression stack (expressions that are being compiled)
		
		@frames = []					# Process frame stack (Process frames (usually unfinished) to be managed by this compiler)
		@processDefinitionStack = []	# Process definition stack (process definition of frames and custom definitions)
		@processStack = []				# Stack of managed CCS processes; emitCCSProcess appends processes to the last element
		
		@definitionStorage =			# The dictionary to save process definitions ordered by kind
			global:
				environment: []
				procedures: []
			classes:
				monitors: []
				structs: []
		
		
	
	_initController: ->
		@controller = newPCCProgramController(@program)
		@program.collectVarsAndProcs(@controller)
	
	compile: -> 
		@_initController()
		@program.compile()
		# ToDo: return CCS tree
	
	
	###
		Delegates must implement the following methods:
		 compilerGetVariable(compiler, identifier, instanceContainer)
		 compilerGetProcedure(compiler, identifier, instanceContainer)
		 compilerHandleNewIdentifierWithDefaultValueCallback(compiler, identifier, callback, context)
		When these methods are called, the receiver may modify the compiler state by emitting CCS processes, pushing processes, ...
	###
	_getAccessDelegates: ->
		delegates = [PCCGlobalAccessDelegate]
		delegates.push(@curClass) if @curClass
		delegates.concat(@frames)
		delegates
	
	_getTopAccessDelegate: ->
		delegates = @_getAccessDelegates
		delegates[delegates.length-1]
	
	getVariable: (identifier, className) ->
		if className != null
			return @controller.getClassWithname(className).compilerGetVariable(@, identifier)
		delegates = @_getAccessDelegates()
		result = null
		while (result == null && delegates.length > 0)
			result = delegates.pop().compilerGetVariable(@, identifier)
		throw new Error("Could not resolve variable!") if result == null
		result
	
	getProcedure: (identifier, className) ->
		if className != null
			return @controller.getClassWithname(className).compilerGetProcedure(@, identifier)
		delegates = @_getAccessDelegates()
		result = null
		while (result == null && delegates.length > 0)
			result = delegates.pop().compilerGetProcedure(@, identifier)
		throw new Error("Could not resolve procedure!") if result == null
		result
	
	getFreshContainer: -> @getProcessFrame().createContainer()
	
	handleNewIdentifierWithDefaultValueCallback: (identifier, callback, context) ->		# callback returns a container
		@_getTopProcessDelegate().compilerHandleNewIdentifierWithDefaultValueCallback(@, identifier, callback, context)
	
	
	
	# Modifying the compiler state
	_getCurrentDefinitionContainer: ->
		if @curClass == null
			target = @definitionStorage.global
		else
			classes = @definitionStorage.classes
			target = (if @curClass instanceof PCCMonitor then classes.monitors else classes.structs)[@curClass.name]
		if @procedures.length > 0 then target.procedures else target.environment
	
	pushProcessFrame: (processFrame) ->
		@frames.push(processFrame)
		@pushCCSProcessDefinition(processFrame.createProcessDefinition())
		
	popProcessFrame: ->
		@frames.pop()
		@popCCSProcessDefinition()
	
	getProcessFrame: -> @frames[@frames.length-1]
	
	pushCCSProcessDefinition: (processDefinition) ->		# process is a CCS tree that is a valid (maybe empty, i.e. contains only stop) process definition; this process will be the new target for adding subprocesses via addCCSProcess
		# Important: Do not use this method for procedures. Create procedureFrames instead and push the frames using pushProcedureFrame!
		@processDefinitionStack.push(processDefinition)
		@pushCCSProcess(processDefinition.process)
		@_getCurrentDefinitionContainer().push(processDefinition)
	
	popCCSProcessDefinition: ->
		@processDefinitionStack.pop().process = @popCCSProcess()
	
	pushCCSProcess: (process) ->
		@processStack.push(process)
	
	popCCSProcess: (process) ->
		@processStack.pop()
		
		
	_appendProcessToProcess: (newProcess, existingProcess) ->
		if existingProcess instanceof PCCPrefix
			while existingProcess.getProcess() instanceof CCSPrefix
				existingProcess = existingProcess.getProcess()
			console.warn "PCCCompiler.emitCCSProcess: Final process was not 'stop'!" if !(existingProcess instanceof PCCStop)
			existingProcess.subprocesses[0] = newProcess
			existingProcess
		else if existingProcess instanceof CCSCondition
			existingProcess.subprocesses[0] = @_appendProcessToProcess(newProcess, existingProcess.getProcess())
			existingProcess
		else
			console.warn "PCCCompiler.emitCCSProcess: Replaced process was not 'stop'!" if !(existingProcess instanceof PCCStop)
			newProcess
	
	emitCCSProcess: (process) ->		# For procedure (mostly expressions) compilation only (?). After emitting a process that is not prefix or stop you should push a new procedure frame or ccs process definition!
		i = @processStack.length-1
		@processStack[i] = @_appendProcessToProcess(process, @processStack[i])
		process
			
		
		
	
	
	
	
	# Organising CCS structure
	
	beginClass: (className) ->
		throw new Error("Class is already chosen!") if @curClass != null
		@curClass = @controller.getClassWithName(className)
		classes = @definitionStorage.classes
		(if @curClass instanceof PCCMonitor then classes.monitors else classes.structs)[@curClass.name] = 
			environment: []
			procedures: []
		
	endClass: ->
		throw new Error("No class did begin!") if @curClass == null
		@curClass = null
	
	beginProcedure: (procedureName) ->
		procedure = @_getTopAccessDelegate().compilerGetProcedure(@, procedureName)
		throw new Error("Tried to begin unknown procedure!") if procedure == null
		@procedures.push(procedure)
		processFrame = new PCCProcedureFrame(procedure)
		@pushProcessFrame(processFrame)
		processFrame
	
	endProcedure: ->
		@popProcessFrame()
		@procedures.pop()
	
	
	beginStatement: (statement) ->
	endStatement: ->
	
	beginExpression: (expression) ->
	endExpression: ->






class PCCStackAssistant
	constructor: (@compiler, @process) ->
		@left = true
	
	setLeftTarget: ->
		return if @left
		@_checkStackConsistency()
		
	
	setRightTarget: ->
		return if not @left
		@_checkStackConsistency()
	
	_checkStackConsistency: ->
		(return if @process == p) for p in @compiler.processStack
		throw new Error("Assistant's process was not found on compiler's stack")



