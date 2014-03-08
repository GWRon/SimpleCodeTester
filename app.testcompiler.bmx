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
			Print "ERROR: Compiler not found: ~q"+uri+"~q"
			Return False
		EndIf

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
		If config.GetString("app_arch", "")
			result :+ " -g " + config.GetString("app_arch", "")
		End If
		'file
		result :+ " -o " + GetOutputFileURI() + " " + compileFile

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
		While binaryProcess.Alive()
			If binaryProcess.IOAvailable()
				'add new line indicator for followup lines
				If binaryOutput <> "" Then binaryOutput:+"~n"
				binaryOutput :+ binaryProcess.Read()
			EndIf
		Wend

		'print "expected: -"+expectedOutput+"-"
		'print "received: -"+binaryOutput+"-"
		If expectedOutput = binaryOutput
			Print "  VALIDATION SUCCESSFUL"
			Return True
		Else
			Print "  VALIDATION FAILED"
			Return False
		EndIf
	End Method
End Type