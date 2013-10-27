

###
	Delegate methods:
	recognizerShouldBeginRecognising()
	recognizerDidChangeState()
###


class UIEventRecognizer
	constructor: (@nodes, @delegate) -> 
		@setEnabled(true)
		@state = UIEventRecognizer.POSSIBLE
	setEnabled: (enabled) ->
		return if enabled == @enabled
		@nabled = enabled
		if @enabled then @_enable() else @_disable()
	_enable: -> throw new Error("Not implemented!")
	_disable: -> throw new Error("Not implemented!")

UIEventRecognizer.POSSIBLE = 0
UIEventRecognizer.BEGAN = 1
UIEventRecognizer.CHANGED = 2
UIEventRecognizer.ENDED = 3

UIEventRecognizer.RECOGNIZED = 3


class UIClickRecognizer extends UIEventRecognizer
	constructor: ->
		super
		@requiredClicks = 1
	_enable: -> 
		@nodes.on("click", (event) -> )
			
			
	