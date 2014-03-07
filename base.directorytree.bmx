REM
	===========================================================
	DIRECTORY SCANNING CLASS
	===========================================================

	This code allows scanning and storing the content of a given
	directory.

ENDREM
SuperStrict


Type TDirectoryTree
	Field directories:TMap            = CreateMap()
	Field filePaths:TMap               = CreateMap()
	'root path of the scanned directory
	Field baseDirectory:String         = ""
	'files to include/exclude in the tree. "*" means all
	Field _includeFileEndings:TList    = CreateList()
	Field _excludeFileEndings:TList    = CreateList()
	Field _includeDirectoryNames:TList = CreateList()
	Field _excludeDirectoryNames:TList = CreateList()


	'initialize object
	Method Init:TDirectoryTree( baseDirectory:string, includeFileEndings:string[] = null, excludeFileEndings:string[] = null, includeDirectoryNames:string[] = null, excludeDirectoryNames:string[] = null )
		if includeFileEndings then AddIncludeFileEndings(includeFileEndings)
		if excludeFileEndings then AddExcludeFileEndings(excludeFileEndings)
		if includeDirectoryNames then AddIncludeDirectoryNames(includeDirectoryNames)
		if excludeDirectoryNames then AddExcludeDirectoryNames(excludeDirectoryNames)

		self.baseDirectory = baseDirectory

		return self
	End Method


	'add a file ending to the list of allowed file endings
	Method AddIncludeFileEndings( endings:string[], resetFirst:int = FALSE )
		if resetFirst then _includeFileEndings.Clear()

		for local ending:string = eachin endings
			_includeFileEndings.AddLast(ending.toLower())
		Next
	End Method


	'add a file ending to the list of forbidden file endings
	Method AddExcludeFileEndings( endings:string[], resetFirst:int = FALSE )
		if resetFirst then _excludeFileEndings.Clear()

		for local ending:string = eachin endings
			_excludeFileEndings.AddLast(ending.toLower())
		Next
	End Method


	'add a directory name to the list of allowed directories
	Method AddIncludeDirectoryNames( dirNames:string[], resetFirst:int = FALSE )
		if resetFirst then _includeDirectoryNames.Clear()

		for local dirName:string = eachin dirNames
			_includeDirectoryNames.AddLast(dirName.toLower())
		Next
	End Method


	'add a directory to the list of forbidden directories
	Method AddExcludeDirectoryNames( dirNames:string[], resetFirst:int = FALSE )
		if resetFirst then _excludeDirectoryNames.Clear()

		for local dirName:string = eachin dirNames
			_excludeDirectoryNames.AddLast(dirName.toLower())
		Next
	End Method


	'scans all files and directories within the given base
	'directory.
	'if no file ending is added until scanning, all files
	'will get added
	Method ScanDir:int( directory:string="" )
		if directory = "" then directory = baseDirectory

		local dirHandle:int = ReadDir(directory)
		If Not dirHandle then return FALSE


		local file:string
		local uri:string
		Repeat
			file = NextFile(dirHandle)
			If file = "" then Exit
			'skip chgDir-entries
			If file = ".." or file = "." then continue

			uri = directory + "/" + file

			Select FileType(uri)
				case 1
					'skip forbidden file names
					if _excludeFileEndings.Contains( ExtractExt(file).toLower() ) then continue
					'skip files with non-enabled file endings
					if not _includeFileEndings.Contains( ExtractExt(file).toLower() ) and not _includeFileEndings.Contains("*") then continue

					filePaths.insert(uri, file)
				case 2
					'skip forbidden directories
					if _excludeDirectoryNames.Contains( file.toLower() ) then continue
					'skip directories with non-enabled directory names
					if not _includeDirectoryNames.Contains( file.toLower() ) and not _includeDirectoryNames.Contains("*") then continue

					directories.insert(uri, file)
					ScanDir(uri)
			End Select
		Forever

		return TRUE
	End Method


	'returns all found files for a given filter
	Method GetFiles:string[](fileName:string="", fileEnding:string="", URIstartsWith:string="")
		local result:string[]
		for local uri:string = eachin filePaths.Keys()
			'skip files with wrong filename - case sensitive
			if fileName <> "" and StripDir(uri) <> fileName then continue
			'skip uris not starting with given filter
			if URIstartsWith <> "" and not uri.StartsWith(URIstartsWith) then continue
			'skip uris having the wrong file ending - case INsensitive
			if fileEnding <> "" and ExtractExt(uri).toLower() <> fileEnding.toLower() then continue

			result :+ [uri]
		Next
		return result
	End Method
End Type