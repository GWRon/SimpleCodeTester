Rem
	===========================================================
	APP SPECIFIC COMPILER TEST CLASS
	===========================================================

	Class to compile a given code with a compiler with options and
	parameters compatible to "BlitzMax' bmk".

ENDREM
SuperStrict
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
		If Not uri Or FileType(uri) = FILETYPE_NONE
	
			If uri Then
				' try real path
				Local dir:String = CurrentDir()
				ChangeDir baseConfig.GetString("test_base", "")
				uri = RealPath(uri) 
				ChangeDir dir

				If Not FileType(uri)
					Print "ERROR: Compiler not found: ~q"+uri+"~q"
					Return False
				End If
			Else
					Print "ERROR: Compiler was not defined in option 'bmk_path'"
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

		Local binaryProcess:TCodeTesterProcess = New TCodeTesterProcess.Init( GetOutputFileURI() )
		Local binaryOutput:String = ""
		While not binaryProcess.Eof()
			If binaryProcess.IOAvailable()
				'append output from process if not empty
				'prepend a newline if needed
				'last line does not contain newline then !
				local out:string = binaryProcess.Read()
'do not ignore newlines - which somehow are triggered with out <> ""
'				If out <> ""
					if binaryOutput <> "" then binaryOutput :+ "~n"
					binaryOutput :+ out
'				endif

				'old: add new line indicator for followup lines
				'If binaryOutput <> "" Then binaryOutput:+"~n"
				'binaryOutput :+ binaryProcess.Read()
			EndIf
		Wend

		If expectedOutput = binaryOutput
			validated = True
			'Print "  VALIDATION SUCCESSFUL"
			Return True
		Else

			print "expected:~n-----~n"+expectedOutput+"~n------~n"
			print "received:~n-----~n"+binaryOutput+"~n------~n"


			validated = False
			'Print "  VALIDATION FAILED"
			Return False
		EndIf
	End Method
End Type