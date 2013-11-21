###
PseuCo Compiler
Copyright (C) 2013 Sebastian Biewer

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