Rem
	===========================================================
	APP SPECIFIC COMPILER TEST CLASS
	===========================================================

	Class to compile a given code with a compiler with options and
	parameters compatible to "BlitzMax' bmk".

ENDREM
SuperStrict
Import Brl.Retro
Import "base.testbase.bmx"
Import "base.processes.bmx"

Type TTestCompiler Extends TTestBase
	Field compileFile:String = ""

	'the complete path (including filename)
	Global compilerUri:String = ""
	Global baseConfig:TConfigMap = New TConfigMap.Init()


	Method Init:TTestCompiler( name:String="" )
		Super.Init(name)

		Return Self
	End Method


	Method SetCompileFile:TTestCompiler( file:String )
		compileFile = file
		Return Self
	End Method


	Function SetCompilerURI:Int( uri:String )
		If Not uri
			Print "ERROR: Compiler was not defined in option 'bmk_path'"
			Return False
		EndIf

		If FileType(uri) = FILETYPE_NONE
			' try real path
			Local dir:String = CurrentDir()
			ChangeDir baseConfig.GetString("test_base", "")
			uri = RealPath(uri)

			'move back into current dir
			ChangeDir dir

			If Not FileType(uri)
				Print "ERROR: Compiler not found: ~q"+uri+"~q"
				Return False
			End If
		EndIf


		' bmxpath is not set, we should try to set it to bmk's root path. (one up from bmk's bin path)
		If Not baseConfig.GetString("bmxpath", "")
			' bin dir
			Local bmxpath:String = ExtractDir(uri)
			' parent dir
			bmxpath = bmxpath[..bmxpath.FindLast("/")]

			If FileType(bmxpath) = FILETYPE_DIR
				baseConfig.Add("bmxpath", bmxpath)
				putenv_("BMXPATH=" + bmxpath)
			End If

		End If

		compilerUri = uri
		Return True
	End Function


	'override cleanup to delete the binary afterwards
	Method CleanUp:Int()
		If baseConfig.GetInt("deleteBinaries", 1) = True
?macos
			If config.GetString("app_type", "console").toLower() = "console"
				Return DeleteFile( GetOutputFileURI() )
			Else
				Return DeleteDir( GetOutputFileURI() + ".app", True )
			End If
?
			Return DeleteFile( GetOutputFileURI() )
		Else
			Return True
		EndIf
	End Method


	Method GetOutputFileURI:String()
?Win32
		Return StripExt(compileFile)+".exe"
?
		Return StripExt(compileFile)
	End Method


	Method GetParams:String()
		Local result:String = ""

		'build flags
		result :+ "makeapp"
		result :+ " -a" 'recompile
		result :+ " -t " + config.GetString("app_type", "console").toLower()
		If config.GetInt("threaded", 0) = 1
			result :+ " -h"
		EndIf
		If config.GetInt("debug", 0) = 1
			result :+ " -d"
		Else
			result :+ " -r"
		EndIf
		If config.GetInt("quick", 0) = 1
			result :+ " -quick"
		EndIf
		If config.GetString("app_arch", "")
			result :+ " -g " + config.GetString("app_arch", "")
		EndIf
		'file
		'result :+ " -o " + GetOutputFileURI() + " " + compileFile
		result :+ " -o ~q" + GetOutputFileURI() + "~q ~q" + compileFile+"~q"

		Return result
	End Method


	'override generation of the commandline
	Method GetCommandline:String()

		'try to use a instance specific URI, if none is given
		'use the default type specific compiler URI
		Local useCommandURI:String = commandURI

		If useCommandURI = "" Then
			If Not compilerUri
				If Not SetCompilerURI(config.GetString("bmk_path", ""))
					End
				End If
			End If
			useCommandURI = compilerUri
		End If

		Return usecommandURI + " " + GetParams()
	End Method


	'override Validation to execute the resulting binary
	'if validation is needed
	Method Validate:Int()
		If Not doValidation Then Return True
		Local binaryProcess:TCodeTesterProcess = New TCodeTesterProcess.Init( GetOutputFileURI(), HIDECONSOLE)
		if not binaryProcess then Throw "Validate(): Failed to create new TCodeTesterProcess."

		Local binaryOutput:String = ""
		'no need to read in the lines "live", just wait for the output...
		While binaryProcess.Alive()
			delay(1)
		Wend
		local bytes:byte[] = binaryProcess.standardIO.ReadPipe()
		if bytes
			binaryOutput = String.FromBytes(bytes, bytes.length).replace("~r", "")
			'skip last newline (it somehow gets added during output
			'(I assume to avoid the following prompt beginning on the
			' same line)
			binaryOutput = binaryOutput[.. binaryOutput.length-1]
		endif
		rem
		While binaryProcess.IOAvailable()
			local out:string = binaryProcess.Read()
			if out
				if binaryOutput <> "" then binaryOutput :+ "~n"
				binaryOutput :+ out
			endif
		Wend
		endrem
		binaryProcess.Close()
		binaryProcess = null

		If expectedOutput.length = binaryOutput.length and expectedOutput = binaryOutput
			validationOutput = "OK"

			validated = True
			'Print "  VALIDATION SUCCESSFUL"
			Return True
		Else
			'print expectedOutput.length+"  vs  " + binaryOutput.length
			validationOutput = "FAILED~n"

			local expectedLines:string[] = expectedOutput.split("~n")
			local binaryLines:string[] = binaryOutput.split("~n")
			local maxLineLength:int = 10
			local maxExpectedLineLength:int = 0
			local maxBinaryLineLength:int = 0
			For local i:int = 0 until expectedLines.length
				maxExpectedLineLength = max(maxExpectedLineLength, expectedLines[i].length)
			Next
			For local i:int = 0 until binaryLines.length
				maxBinaryLineLength = max(maxBinaryLineLength, binaryLines[i].length)
			Next
			maxLineLength = Max(maxLineLength, max(maxBinaryLineLength, maxExpectedLineLength))

			'at least caption-width
			maxBinaryLineLength = Max(9, maxBinaryLineLength)
			maxExpectedLineLength = Max(9, maxExpectedLineLength)


			if maxLineLength > 36
				validationOutput :+ "expected:~n-----~n"+expectedOutput+"~n------~n"
				validationOutput :+ "received:~n-----~n"+binaryOutput+"~n------~n"
			'side by side comparison
			else
				validationOutput :+ "   |" + LSet(" EXPECTED", maxExpectedLineLength+2)+"|" + LSet(" RECEIVED", maxBinaryLineLength+2)+"|~n"
				validationOutput :+ "---+" + LSet("", maxLineLength+2).Replace(" ", "-") + "+" + LSet("", maxBinaryLineLength+2).Replace(" ", "-")+"+~n"
				For local i:int = 0 until Max(expectedLines.length, binaryLines.length)
					local line:string = ""
					if expectedLines.length > i and binaryLines.length > i
						if expectedLines[i] <> binaryLines[i]
							local detail:string
							rem
							'debug information
							for local j:int = 0 until Min(expectedLines[i].length, binaryLines[i].length)
								if expectedLines[i][j] <> binaryLines[i][j]
									detail :+"@"+j+" ("+expectedLines[i][j]+"<>"+binaryLines[i][j]+") "
								endif
							Next
							detail :+ "  length " + expectedLines[i].length+", "+binaryLines[i].length
							detail :+ "  chars: "
							for local j:int = 0 until expectedLines[i].length
								detail :+ expectedLines[i][j]+" "
							Next
							detail :+ "  |  "
							for local j:int = 0 until binaryLines[i].length
								detail :+ expectedLines[i][j]+" "
							Next
							endrem

							validationOutput :+ "XX |" + LSet(expectedLines[i], maxLineLength+2)+"|" + Lset(binaryLines[i], maxBinaryLineLength+2)  +"|"+detail+"~n"

						else
							validationOutput :+ "OK |" + LSet(expectedLines[i], maxLineLength+2)+"|" + Lset(binaryLines[i], maxBinaryLineLength+2)  +"|~n"
						endif
					elseif expectedLines.length > i
						validationOutput :+ "XX |" + LSet(expectedLines[i], maxLineLength+2)+"|" + Lset("", maxBinaryLineLength+2).replace(" ", "#")  +"|~n"
					else
						validationOutput :+ "XX |" + LSet("", maxLineLength+2).replace(" ", "#")+"|" + Lset(binaryLines[i], maxBinaryLineLength+2) +"|~n"
					endif
				Next
			endif

			validated = False
			'Print "  VALIDATION FAILED"
			Return False
		EndIf
	End Method
End Type