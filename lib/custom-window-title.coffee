_updateWindowTitle = null

module.exports =
	configDefaults:
		template: '<%= fileName %><% if (projectName) { %> - <%= projectName %><% if (gitHead) { %> [<%= gitHead %>]<% } %><% } %>'

	config:
		template:
			type: 'string'
			default: '<%= fileName %><% if (projectName) { %> - <%= projectName %><% if (gitHead) { %> [<%= gitHead %>]<% } %><% } %>'

	subscriptions: null
	configSub: null
	project: null

	activate: (state) ->
		_ = require 'underscore'
		{ allowUnsafeNewFunction } = require 'loophole'
		path = require 'path'
		{CompositeDisposable} = require 'event-kit'

		os = require 'os'

		@subscriptions = new CompositeDisposable

		template = null

		@configSub = atom.config.observe 'custom-window-title-baincd.template', ->
			templateString = atom.config.get('custom-window-title-baincd.template')

			if templateString
				try
					template = allowUnsafeNewFunction -> _.template templateString
				catch e
					template = null
			else
				template = null

			atom.workspace.updateWindowTitle()

		_updateWindowTitle = atom.workspace.updateWindowTitle

		atom.workspace.updateWindowTitle = =>
			if template
				projectManagerTitle = if @project then @project.props.title else null

				item = atom.workspace.getActivePaneItem()

				fileName = item?.getTitle?() ? 'untitled'
				filePath = item?.getPath?()
				fileInProject = false
				fileIsModified = item?.isModified?()

				projectIdx = -1
				for i in [0..atom.project.getPaths().length - 1]
					itemPath = item?.getPath?()
					if itemPath && itemPath.startsWith(atom.project.getPaths()[i])
						projectIdx = i
						break

				projectPath = if projectIdx isnt -1 then atom.project.getPaths()[projectIdx] else null
				projectName = if projectPath then path.basename(projectPath) else null

				repo = atom.project.getRepositories()[projectIdx]
				gitHead = repo?.getShortHead()

				gitAdded = null
				gitDeleted = null
				relativeFilePath = null

				devMode = atom.inDevMode()
				safeMode = atom.inSafeMode?()

				hostname = os.hostname()
				username = os.userInfo().username

				if filePath and repo
					status = repo.getCachedPathStatus(filePath)
					if repo.isStatusModified(status)
						stats = repo.getDiffStats(filePath)
						gitAdded = stats.added
						gitDeleted = stats.deleted
					else if repo.isStatusNew(status)
						gitAdded = item.getBuffer?().getLineCount()
						gitDeleted = 0
					else
						gitAdded = gitDeleted = 0

				if filePath and projectPath
					relativeFilePath = path.relative(projectPath, filePath)
					if filePath.startsWith(projectPath)
						fileInProject = true

				try

					title = template {
						projectPath, projectName, fileInProject,
						filePath, relativeFilePath, fileName,
						fileIsModified,
						gitHead, gitAdded, gitDeleted
						devMode, safeMode, hostname, username,
						projectManagerTitle
					}

					if filePath or projectPath
						atom.setRepresentedFilename(filePath ? projectPath)
					document.title = title
				catch e
					_updateWindowTitle.call(this)
			else
				_updateWindowTitle.call(this)

		atom.workspace.updateWindowTitle()

		@subscriptions.add atom.workspace.observeTextEditors (editor) =>
			editorSubscriptions = new CompositeDisposable
			editorSubscriptions.add editor.onDidSave -> atom.workspace.updateWindowTitle()
			editorSubscriptions.add editor.onDidChangeModified -> atom.workspace.updateWindowTitle()
			editorSubscriptions.add editor.onDidDestroy -> editorSubscriptions.dispose()

			@subscriptions.add editorSubscriptions

	consumeProjectManager: ({getProject}) ->
		getProject (project) =>
			if project
				@project = project
				atom.workspace.updateWindowTitle()

	deactivate: ->
		@subscriptions?.dispose()
		@configSub?.dispose()
		atom.workspace.updateWindowTitle = _updateWindowTitle

	serialize: ->
