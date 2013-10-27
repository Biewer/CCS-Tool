class UITabBar
	constructor: (@bar, @content) ->
		@bar.parentNode._tabBar = @
		@barItems = []
		@contentItems = []
		@activeContent = null
		for li in @bar.childNodes
			if li.nodeName == "LI"
				ref = li.dataset.tabContent
				throw new Error("Missing content reference!") if not ref
				content = $("##{ref}")[0]
				throw new Error("Missing content node!") if not content
				$(li).on("click", (event) -> @getTabBar()._handleItemClick(event))
				@barItems.push(li)
				@contentItems.push(content)
		@setItemAtIndex 1
	scrollTo: (x, y) ->
		@content.scrollLeft = x
		@content.scrollTop = y
	_handleItemClick: (event) ->
		i = @barItems.indexOf(event.target)
		@setItemAtIndex i
	setItemAtIndex: (i) ->
		@activeContent.style.display = "" if @activeContent
		@activeContent = @contentItems[i]
		@activeContent.style.display = "block"
	getIndexForContent: (node) ->
		i = @contentItems.indexOf(node)
		if i == -1
			if node.parentNode then @getIndexForContent(node.parentNode) else -1
		else
			i







Element::getTabBar = ->
	if @_tabBar then @_tabBar else @parentNode?.getTabBar()