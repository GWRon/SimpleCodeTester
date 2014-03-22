Rem
	===========================================================
	MOD SPECIFIC COMPILER TEST CLASS
	===========================================================

	Class to compile a given code with a compiler with options and
	parameters compatible to "BlitzMax' bmk".

EndRem
SuperStrict
Import "base.testbase.bmx"
Import "base.processes.bmx"

Type TTestModCompiler Extends TTestBase
	Field compileMod:String = ""

	'the complete path (including filename)
	Global compilerUri:String = ""
	Global baseConfig:TConfigMap = New TConfigMap.Init()


	Method Init:TTestModCompiler( name:String="" )
		Super.Init(name)

		Return Self
	End Method


	Method SetCompileFile:TTestModCompiler( file:String )
		compileMod = file
		Return Self
	End Method

	Method GetTestType:String()
		Return "MODULE"
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
	End Method


	Method GetParams:String()
		Local result:String = ""

		'build flags
		result :+ "makemods"
		result :+ " -a" 'recompile
		If config.GetInt("threaded", 0) = 1
			result :+ " -h"
		EndIf
		If Not config.GetInt("debug", 0)
			result :+ " -r"
		EndIf
		If config.GetString("app_arch", "")
			result :+ " -g " + config.GetString("app_arch", "")
		End If
		'file
		result :+ " " + compileMod

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
	
End Type
