
class UIConsole
	constructor: (div) ->
		div.innerHTML = ""
		@ul = document.createElement("UL")
		div.appendChild(@ul)
	
	addLine: (str, cssClass) ->
		str = str.replace(/\n/g, "<br />")
		str = str.replace(/\t/g, "&nbsp;&nbsp;&nbsp;")
		node = document.createElement("LI")
		cssClass = if cssClass then "log " + cssClass else "log"
		node.setAttribute("CLASS", cssClass)
		node.innerHTML = str
		@ul.appendChild(node)
		@ul.getTabBar().scrollTo(0, @ul.offsetHeight)
		bar = @ul.getTabBar()
		bar.setItemAtIndex(bar.getIndexForContent(@ul))
		UI.app.didUpdateConsole(@)
		node
	log: (msg) -> @addLine(msg)
	warn: (msg) -> @addLine(msg, "warning")
	error: (msg) -> @addLine(msg, "error")
	
	clear: -> @ul.innerHTML = ""


class UICCSConsole extends UIConsole
	addOutput: (action) -> @addLine("&gt;&gt;&gt; #{action.toString()}")
	addInput: (action) -> @addLine("&lt;&lt;&lt; #{action.toString()}")