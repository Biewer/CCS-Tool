class UIAppController
	constructor: (@pseuCoEditor, @ccsEditor, @executor, @console, @history) ->
		@observers = [@pseuCoEditor, @ccsEditor, @executor, @console, @history]
		@stepObservers = [@console, @history]
	
	didChangeEditorState: (editor) ->
		o.appDidChangeEditorState?(@, editor) for o in @observers
		null
	
	didUpdateConsole: (console) ->
		o.appDidUpdateConsole?(@, console) for o in @observers
		null
	
	willChangeCCS: (newCCS) ->
		o.appWillChangeCCS?(@, newCCS) for o in @observers
		null
	
	didChangeCCS: (newCCS) ->
		o.appDidChangeCCS?(@, newCCS) for o in @observers
		null
	
	setCCS: (newCCS) ->
		@willChangeCCS(newCCS)
		@ccs = newCCS
		@system = null
		@didChangeCCS(newCCS)
	
	resetCCS: ->
		@system = @ccs.system.copy()
		o.appDidResetCCS?(@, @system) for o in @observers
		@system
	
	willPerformStep: (step) ->
		o.appWillPerformStep?(@, step) for o in @stepObservers
		null
	
	didPerformStep: (step) ->
		o.appDidPerformStep?(@, step) for o in @stepObservers
		null
	
	performStep: (step) ->
		throw new Error("Cannot perform step when no CCS is available!") if not @ccs
		@willPerformStep step
		@system = @history.performStep step
		if step.action.channel.name == "println" and step.action.isOutputAction() and step.action.expression
			UILog "#{step.action.expression.evaluate()}"
		@didPerformStep step
	
	
	
	
	
	willOpenDocument: (document) ->
		# Coming later...
	didOpenDocument: (document) ->
		# Coming later...