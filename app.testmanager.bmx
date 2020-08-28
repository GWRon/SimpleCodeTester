Rem
	===========================================================
	APP SPECIFIC COMPILER TEST CLASS
	===========================================================

	Class to compile a given code with a compiler with options and
	parameters compatible to "BlitzMax' bmk".

ENDREM
SuperStrict
Import "base.directorytree.bmx"
Import "app.testcompiler.bmx" 'containing the compiler specific test class
Import "app.testmodcompiler.bmx" 'containing the compiler specific test class
?Threaded
Import Brl.Threads
?


Global SCT_VERSION:String = "0.2.2"

Type TTestManager
	Field tests:TList = CreateList()
?Threaded
	Global testsDone:TList = CreateList()
	'a lock for the done list
	Global testsDoneMutex:TMutex = CreateMutex()
?
	Field dirTree:TDirectoryTree = New TDirectoryTree
	Field verbose:int

	Field mods:TList = New TList


	Method Init:TTestManager(args:String[])
		ParseArgs(args)
		Return Self
	End Method


	Method AddTest( test:TTestBase )
		tests.addLast(test)
	End Method


	'generate a configuration which inherits from parental configurations
	'in parental folders
	Method GetInheritedConfig:TConfigMap( configFile:String, rootDirectory:String, currentDirectory:String )
		'all found configs are stored within an array and get
		'merged at the end - the top most array at last (to overwrite
		'parental settings)
		Local configs:TConfigMap[]

		'add the test's individual config if possible
		If FileSize(currentDirectory+"/"+configFile) > 0
			configs :+ [ New TConfigMap.Init(currentDirectory+"/"+configFile) ]
		EndIf

		'loop through all parental directories
		Local lastSlashPos:Int = -1
		While currentDirectory.StartsWith(rootDirectory)
			If FileSize(currentDirectory+"/base.conf") > 0
				configs :+ [ New TConfigMap.Init(currentDirectory+"/base.conf") ]
			EndIf

			'strip of deepest directory
			lastSlashPos = currentDirectory.FindLast("/")
			If lastSlashPos >= 0
				currentDirectory = currentDirectory[..lastSlashPos]
			Else
				'finished
				currentDirectory = ""
			EndIf
		Wend

		'add the basic configuration at last - so it is the base
		'of all configs (stack wise as it gets reversed during the
		'following merge)
		configs :+ [TTestCompiler.baseconfig]


		'return the merged config
		Return TConfigMap.CreateMerged(configs, True)
	End Method


	Method AddTestsFromDirectory( directory:String )
		'create a new directory tree containing all files/dirs of
		'interest for us
		dirTree = New TDirectoryTree.Init(directory, ["bmx", "conf", "res"], Null, ["*"], [".bmx"])
		dirTree.relativePaths = False
		dirTree.ScanDir()


		'load *.bmx files
		Local testFiles:String[] = dirTree.GetFiles("", "bmx")


		Local test:TTestCompiler
		For Local testFile:String = EachIn testFiles
			test = New TTestCompiler.Init(testFile).SetCompileFile(testFile)

			'try to load the expected result file
			'prefer OS/arch specific result files
			local testFileBase:string = StripExt(testFile)
			local arch:string = TTestCompiler.baseConfig.GetString("app_arch", "x86")
			?win32
			local OS:string = "win32"
			?linux
			local OS:string = "linux"
			?macos
			local OS:string = "macos"
			?
			if FileType(testFileBase+"." + OS + "." + arch + ".res") = FILETYPE_FILE
				test.SetExpectedOutput( test.LoadExpectedOutput(testFileBase + "." + OS + "." + arch + ".res") )
			Elseif FileType(testFileBase + "." + OS + ".res") = FILETYPE_FILE
				test.SetExpectedOutput( test.LoadExpectedOutput(testFileBase + "." + OS + ".res") )
			Elseif FileType(testFileBase + ".res") = FILETYPE_FILE
				test.SetExpectedOutput( test.LoadExpectedOutput(testFileBase + ".res") )
			EndIf

			'try to find a configuration for this test
			test.config = GetInheritedConfig( StripAll(testFile) + ".conf", directory, ExtractDir(testFile) )

			AddTest(test)
		Next
	End Method


	Method BuildMods()

		Print "=== STARTING MODULE BUILD ==="

		If LoadMods()
			Local config:TConfigMap = New TConfigMap.Init(TTestCompiler.baseConfig.GetString("test_base", "")+"/base.conf")

			For Local m:String = EachIn mods
				Local build:TTestModCompiler = New TTestModCompiler.Init(m).SetCompileFile(m)
				build.config = config
				print build.GetFormattedHeader(verbose)
				build.Run()
				print build.GetFormattedResult(verbose)
			Next
		Else
			Print "* No modules to process *"
		End If

		Print "=== FINISHED MODULE BUILD ==="
	End Method


	Method LoadMods:Int()
		Local file:TStream = ReadFile(TTestCompiler.baseConfig.GetString("test_base", "") + "/mods.conf")
		If Not file Then Return False

		While Not Eof(file)
			Local line:String = ReadLine(file).Trim()
			If line Then
				mods.AddLast(line.ToLower())
			End If
		Wend

		Return mods.Count() > 0
	End Method


?Threaded
	'helper function
	Function RunTestThread:Object(testObject:object)
		local test:TTestBase = TTestBase(testObject)
		if not test then return null

		test.Run()

		LockMutex(testsDoneMutex)
			testsDone.AddLast(test)
		UnlockMutex(testsDoneMutex)
	End Function
?

	Method RunTests:Int()
		Local start:Int = MilliSecs()
		If TTestCompiler.baseConfig.GetInt("make_mods") Then
			BuildMods()
		End If

		Print "=== STARTING TESTS ==="
		Print "* AMOUNT OF TESTS: " + tests.count()

		Local threadsEnabled:Int = TTestCompiler.baseConfig.GetInt("threadedTestRuns")
		?Not threaded
			threadsEnabled = False
		?
		
		If threadsEnabled
			?Threaded
				For Local test:TTestBase = EachIn tests
					Print test.GetFormattedHeader(verbose)
					test.Run()
					Print test.GetFormattedResult(verbose)
				Next
						
				'run up to 4 concurrent Threads
				Local maxThreads:Int = 4
				Local threads:TThread[maxThreads]
				Local testsToRun:TList = CreateList()
				'remove results from last test run (if any)
				testsDone.clear()

				'copy existing tests into a new list which can get
				'truncated later
				For Local test:TTestBase = EachIn tests
					testsToRun.AddLast(test)
				Next

				'repeat as long as there are tests to do
				Local allDone:Int = (testsToRun.Count() = 0)
				While Not allDone
					If testsToRun.Count() > 0
						Local useSlot:Int = -1
						'find a free thread slot
						For Local i:Int = 0 Until maxThreads
							If Not threads[i] Then useSlot = i;Exit
							If Not ThreadRunning(threads[i]) Then useSlot = i;Exit
						Next
						'wait a short time and try again
						If useSlot = -1
							Delay(1)
							Continue
						EndIf

						'kick off a new thread
						Local test:TTestBase = TTestBase(testsToRun.First())
						testsToRun.RemoveFirst()
						threads[useSlot] = CreateThread(RunTestThread, test)
					EndIf

					'adjust allDone to potentially finish the whileloop
					allDone = (testsToRun.Count() = 0)

					'check if there are no threads running anymore
					For Local i:Int = 0 Until maxThreads
						If Not threads[i] Then Continue
						If ThreadRunning(threads[i]) Then allDone = False
					Next

					'check if there is some output available
					If testsDone.count() > 0
						LockMutex(testsDoneMutex)
							For Local test:TTestBase = EachIn testsDone
								Print test.GetFormattedHeader(verbose)
								Print test.GetFormattedResult(verbose)
							Next
							testsDone.Clear()
						UnlockMutex(testsDoneMutex)
					EndIf

					Delay(1)
				Wend
				Print "finished"
			?
		Else
			For Local test:TTestBase = EachIn tests
				Print test.GetFormattedHeader(verbose)
				test.Run()
				Print test.GetFormattedResult(verbose)
			Next
		EndIf

		Print "=== FINISHED TESTS ==="
		Print "* TIME: "+ (MilliSecs() - start)+"ms"
		Print "* FAILED: "+ GetResultCount(TTestBase.RESULT_FAILED)
		If verbose
			For Local t:TTestBase = EachIn tests
				If t.result = TTestBase.RESULT_FAILED
					Print "    " + t.name
				EndIf
			Next
		EndIf
		Print "* ERROR: "+ GetResultCount(TTestBase.RESULT_ERROR)
		If verbose
			For Local t:TTestBase = EachIn tests
				If t.result = TTestBase.RESULT_ERROR
					Print "    " + t.name + t.GetErrorSummary()
				EndIf
			Next
		EndIf
		Print "* OK: "+ GetResultCount(TTestBase.RESULT_OK)
	End Method


	'returns how many tests got the specified resultType
	Method GetResultCount:Int( resultType:Int = 0 )
		Local count:Int = 0
		For Local test:TTestbase = EachIn tests
			If test.result = resultType Then count:+ 1
		Next
		Return count
	End Method


	Method ParseArgs(args:String[])

		Local count:Int

		If args.length = 0 Then
			ShowUsage()
		End If

		While count < args.length

			Local arg:String = args[count]

			If arg[..1] <> "-" Then
				Exit
			End If

			Select arg[1..]
				Case "h"
					ShowUsage()
				Case "v"
					ShowVersion()
				Case "m"
					TTestCompiler.baseConfig.Add("make_mods", "1")
				Case "verbose"
					verbose = True
			End Select

			count:+ 1
		Wend

		args = args[count..]

		If args.length = 0
			Print "Test directory missing from command line."
			End
		End If

		' store real path of tests
		TTestCompiler.baseConfig.Add("test_base", RealPath(args[0]))

		AddTestsFromDirectory(args[0])
	End Method

	Method ShowUsage()
		Print "usage : sct [-h] [-v] [-m] [-verbose] dir"
		Print "   -h    Show this help"
		Print "   -v    Version information"
		Print "   -m    Build modules first. Reads mods.conf for a list of mods to build."
		End
	End Method

	Method ShowVersion()
		Print "SimpleCodeTester (sct) version " + SCT_VERSION
		End
	End Method

End Type


