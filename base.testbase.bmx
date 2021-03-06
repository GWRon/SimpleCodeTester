﻿SuperStrict
Import Brl.Retro
Import "base.configmap.bmx"
Import "base.processes.bmx"


Rem
Example:

local test:TTestBase = new TTestBase.Init("BasicTest")
test.commandUri = "ls -l /home/ronny"
test.doValidation = FALSE
test.Run()
END REM

Type TTestBase
	Field name:String = "unnamed Test"
	'the uri to the command to run
	Field commandURI:String = ""
	'the process of the command when executed
	Field process:TCodeTesterProcess
	'configuration (parameters and other things)
	Field config:TConfigMap = New TConfigMap

	Field receivedOutput:String = ""
	Field receivedErrorOutput:String = ""
	Field validationOutput:String = ""
	Field expectedOutput:String = ""
	Field result:Int = 0
	'one might skip validation of output
	'eg. only check if execution was possible
	Field doValidation:Int = False
	Field validated:Int = -1

	Const RESULT_OK:Int = 1
	Const RESULT_FAILED:Int = 0
	Const RESULT_ERROR:Int = -1


	Method Init:TTestBase(name:String="")
		If name<>"" Then Self.name = name
		validated = False
		Return Self
	End Method


	Method GetName:String()
		Return name
	End Method


	Method GetTestType:String()
		Return "TEST"
	End Method


	'returns the complete commandline for process execution
	'eg. "ls -l *.bat"
	Method GetCommandline:String()
		Local params:String = "" 'base has no params
		Return commandURI + " " + params
	End Method


	'set what result is expected
	Method SetExpectedOutput:Int(output:String="")
		expectedOutput = output

		'force validation
		if expectedOutput <> "" then doValidation = True
	End Method


	Function LoadExpectedOutput:String(fileURI:String)
		Local file:TStream = ReadFile(fileURI)
		If Not file Then Return ""

		Local content:String = ""
		Local line:Int
		While Not Eof(file)
			If line > 0
				content :+ "~n"
			End If
			content :+ ReadLine(file)
			line :+ 1
		Wend

		Return content
	End Function


	'overrideable method to do additional processing
	'of the received output (eg. to parse for certain messages)
	Method ProcessOutput:Int()
		'
	End Method


	'overrideable method run after the process finished
	'eg. remove temporary files
	Method CleanUp:Int()
		'
	End Method


	'check if the test was passed
	Method Validate:Int()

		If Not doValidation
			validationOutput = ""
			Return True
		EndIf

		'by default we just check if the output corresponds
		'to one we defined before
		Print "expected: -"+expectedOutput+"-"
		Print "received: -"+receivedOutput+"-"
		validated = (expectedOutput = receivedOutput)

		if validated
			validationOutput = "OK"
		else
			validationOutput = "FAILED"
		endif

		Return validated
	End Method


	Method GetFormattedHeader:String(verbose:int = False)
		local text:string
		text :+ "* RUNNING " + GetTestType() + ": " + GetName() + "~n"
		if verbose
			text :+ "  COMMAND: "+ GetCommandline()
		endif
		return text
	End Method


	Method GetFormattedResult:String(verbose:int = False)
		local text:string

		If result = RESULT_ERROR
			text :+ "  -> PROCESS FAILED !" + "~n"
			text :+ "  ERROR MESSAGE>>>" + "~n"
			'output contains newline char already,skip adding it
			'but add indention
			text :+ "  " + receivedErrorOutput.Replace("~n", "~n  ") + "~n"
'			text :+ receivedOutput
			text :+ "  <<<" + "~n"
			return text
		EndIf

		if doValidation
			text :+ "  VALIDATION: " + validationOutput.Replace("~n", "~n  ") + "~n"
		endif

		If result = RESULT_OK
			text :+ "  -> OK" + "~n"
		ElseIf result = RESULT_FAILED
			text :+ "  -> FAILED" + "~n"
		EndIf

		return text
	End Method


	'checks if the given string is an error
	'- eg. they need an "[ERROR:" at start
	Method IsErrorLine:Int(line:String)
		If line.Trim() = "" Then Return False

		'this is no true error
        'as bmk might auto-compile some modules
        'eg. ar: Erzeugen von /path/to/BlitzMax/mod/pub.mod/oggvorbis.mod/oggvorbis.release.linux.x64.a
		If line.Find("ar:") >= 0 and line.Find("/mod/") >= 0 and line.EndsWith(".a") then return False

		Return True
	End Method


	Method GetErrorSummary:string()
		if not receivedErrorOutput then return ""

		local result:string
		local lines:string[] = receivedErrorOutput.split("~n")
		local filename:string = StripDir(name) 'name contains file name
		local foundFileLine:int = False
		For local i:int = 0 until lines.length
			if lines[i].Find("[") = 0
				local filePos:int = lines[i].Find(filename+";")
				if filePos > 0
					result = "["+Right(lines[i], (lines[i].length - filePos) - filename.length - 1) + "  (" + result + ")"
					foundFileLine = True
				endif
			endif
			if not foundFileLine
				result :+ lines[i]
			endif
		Next
		return result
	End Method


	Method Run:Int()
		'start the process execution
		process = New TCodeTesterProcess.Init( GetCommandline(), HIDECONSOLE )
		if not process then Throw "Run(): Failed to create new TCodeTesterProcess."

		receivedOutput = ""

		While not process.Eof() 'alive or having some output to process
			If process.IOAvailable()
				'append output from process if not empty
				'prepend a newline if needed
				'last line does not contain newline then !
				local processOutput:string

				'as soon as an error happens - set the result accordingly
				If process.ErrorIOAvailable()
					local errorOutput:string = process.ReadErrorIO()

					If IsErrorLine(errorOutput)
						processOutput :+ errorOutput

						if receivedErrorOutput <> "" then receivedErrorOutput :+ "~n"
						receivedErrorOutput :+ errorOutput
					endif
				EndIf

				If process.StandardIOAvailable()
					processOutput :+ process.ReadStandardIO()
				EndIf

				If processOutput <> ""
					if receivedOutput <> "" then receivedOutput :+ "~n"
					receivedOutput:+ processOutput
				endif
			EndIf
		Wend
		'if not done yet, finish up
		process.Close()


		if receivedErrorOutput
			result = RESULT_ERROR
		endif


		'run validation (but skip processing if we already have an error...)
		If result <> RESULT_ERROR
			'maybe someone wants to receive additional information from
			'the received text
			ProcessOutput()

			'run validation of the output
			If Validate() Then result = RESULT_OK Else result = RESULT_FAILED
		EndIf

		'run cleanup - eg removing temporary files
		CleanUp()

		Return result
	End Method
End Type
