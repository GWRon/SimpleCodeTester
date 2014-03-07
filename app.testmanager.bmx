REM
	===========================================================
	APP SPECIFIC COMPILER TEST CLASS
	===========================================================

	Class to compile a given code with a compiler with options and
	parameters compatible to "BlitzMax' bmk".

ENDREM
SuperStrict
Import "base.directorytree.bmx"
Import "app.testcompiler.bmx" 'containing the compiler specific test class

Type TTestManager
	Field tests:TList = CreateList()
	Field dirTree:TDirectoryTree = new TDirectoryTree


	Method Init:TTestManager()
		return self
	End Method


	Method AddTest( test:TTestBase )
		tests.addLast(test)
	End Method


	'generate a configuration which inherits from parental configurations
	'in parental folders
	Method GetInheritedConfig:TConfigMap( configFile:string, rootDirectory:string, currentDirectory:string )
		'all found configs are stored within an array and get
		'merged at the end - the top most array at last (to overwrite
		'parental settings)
		local configs:TConfigMap[]

		'add the test's individual config if possible
		if fileSize(currentDirectory+"/"+configFile) > 0
			configs :+ [ new TConfigMap.Init(currentDirectory+"/"+configFile) ]
		endif

		'loop through all parental directories
		local lastSlashPos:int = -1
		while currentDirectory.StartsWith(rootDirectory)
			if fileSize(currentDirectory+"/base.conf") > 0
				configs :+ [ new TConfigMap.Init(currentDirectory+"/base.conf") ]
			endif

			'strip of deepest directory
			lastSlashPos = currentDirectory.FindLast("/")
			if lastSlashPos >= 0
				currentDirectory = Left(currentDirectory, lastSlashPos)
			else
				'finished
				currentDirectory = ""
			endif
		Wend

		'add the basic configuration at last - so it is the base
		'of all configs (stack wise as it gets reversed during the
		'following merge)
		configs :+ [TTestCompiler.baseconfig]


		'return the merged config
		return TConfigMap.CreateMerged(configs, true)
	End Method


	Method AddTestsFromDirectory( directory:string )
		'create a new directory tree containing all files/dirs of
		'interest for us
		dirTree = new TDirectoryTree.Init(directory, ["bmx", "conf", "res"], null, ["*"], [".bmx"])
		dirTree.ScanDir()


		'load *.bmx files
		local testFiles:string[] = dirTree.GetFiles("", "bmx")


		local test:TTestCompiler
		for local testFile:string = eachin testFiles
			test = new TTestCompiler.Init(testFile).SetCompileFile(testFile)
			'try to load the expected result file
			test.LoadExpectedOutput( StripExt(testFile) + ".res" )
			'try to find a configuration for this test
			test.config = GetInheritedConfig( StripAll(testFile) + ".conf", directory, ExtractDir(testFile) )

			AddTest(test)
		Next
	End Method


	Method RunTests:int()
		print "=== STARTING TESTS ==="
		print "* AMOUNT OF TESTS: " + tests.count()

		For local test:TTestBase = eachin tests
			test.Run()
		Next

		print "=== FINISHED TESTS ==="
		print "* FAILED: "+ GetResultCount(TTestBase.RESULT_FAILED)
		print "* ERROR: "+ GetResultCount(TTestBase.RESULT_ERROR)
		print "* OK: "+ GetResultCount(TTestBase.RESULT_OK)
	End Method


	'returns how many tests got the specified resultType
	Method GetResultCount:int( resultType:int = 0 )
		local count:int = 0
		For local test:TTestbase = eachin tests
			if test.result = resultType then count:+ 1
		Next
		return count
	End Method
End Type