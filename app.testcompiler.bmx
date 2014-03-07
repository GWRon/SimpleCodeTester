REM
	===========================================================
	APP SPECIFIC COMPILER TEST CLASS
	===========================================================

	Class to compile a given code with a compiler with options and
	parameters compatible to "BlitzMax' bmk".

ENDREM
SuperStrict
Import "base.testbase.bmx"
Import "base.processes.bmx"

Type TTestCompiler extends TTestBase
	field compileFile:string = ""

	'the complete path (including filename)
	global compilerUri:string = ""
	global baseConfig:TConfigMap = new TConfigMap.Init()


	Method Init:TTestCompiler( name:string="" )
		super.Init(name)

		return self
	End Method


	Method SetCompileFile:TTestCompiler( file:string )
		compileFile = file
		return self
	End Method


	Function SetCompilerURI:int( uri:string )
		if fileSize(uri) = -1
			print "ERROR: Compiler not found: ~q"+uri+"~q"
			return FALSE
		endif

		compilerUri = uri
	End Function


	'override cleanup to delete the binary afterwards
	Method CleanUp:int()
		if baseConfig.GetInt("deleteBinaries", 1) = true
			return DeleteFile( GetOutputFileURI() )
		else
			return TRUE
		endif
	End Method


	Method GetOutputFileURI:string()
?Win32
		return StripExt(compileFile)+".exe"
?
		return StripExt(compileFile)
	End Method


	Method GetParams:string()
		local result:string = ""

		'build flags
		result :+ "makeapp"
		result :+ " -a" 'recompile
		result :+ " -t " + config.GetString("app_type", "console").toLower()
		if config.GetInt("threaded", 0) = 1
			result :+ " -h"
		endif
		if config.GetInt("debug", 0) = 1
			result :+ " -d"
		endif
		'file
		result :+ " -o " + GetOutputFileURI() + " " + compileFile

		return result
	End Method


	'override generation of the commandline
	Method GetCommandline:string()
		'try to use a instance specific URI, if none is given
		'use the default type specific compiler URI
		local useCommandURI:string = commandURI
		if useCommandURI = "" then useCommandURI = compilerUri
		return usecommandURI + " " + GetParams()
	End Method

End Type