SuperStrict
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
		doValidation = True
	End Method


	Method LoadExpectedOutput:Int(fileURI:String)
		Local file:TStream = ReadFile(fileURI)
		If Not file Then Return False

		Local content:String = ""
		While Not Eof(file)
			If content
				content :+ "~n"
			End If
			content :+ ReadLine(file)
		Wend

		SetExpectedOutput(content)

		Return True
	End Method


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

		If Not doValidation Then Return True
		'by default we just check if the output corresponds
		'to one we defined before
		Print "expected: -"+expectedOutput+"-"
		Print "received: -"+receivedOutput+"-"
		validated = (expectedOutput = receivedOutput)
		Return validated
	End Method


	Method GetFormattedResult:String()
		local text:string
		text :+ "* RUNNING " + GetTestType() + ": " + GetName() + "~n"
		text :+ "  COMMAND: "+ GetCommandline() + "~n"

		If result = RESULT_ERROR
			text :+ "  -> PROCESS FAILED !" + "~n"
			text :+ "ERROR MESSAGE>>>" + "~n"
			'output contains newline char already,skip adding it 
			text :+ receivedOutput
			text :+ "<<<" + "~n"
		ElseIf result = RESULT_OK
			text :+ "  -> OK" + "~n"
		ElseIf result = RESULT_FAILED
			If validated = False
				text :+ "  -> VALIDATION FAILED" + "~n"
			Else
				text :+ "  -> FAILED" + "~n"
			EndIf
		EndIf

		return text
	End Method


	Method Run:Int()
		'start the process execution
		process = New TCodeTesterProcess.Init( GetCommandline() )
		receivedOutput = ""

		While process.Alive()
			If process.IOAvailable()
				'as soon as an error happens - set the result accordingly
				If process.ErrorIOAvailable() Then result = RESULT_ERROR

				'append output from process if not empty
				'prepend a newline if needed
				'last line does not contain newline then !
				local processOutput:string = process.Read()
				If processOutput <> ""
					if receivedOutput <> "" receivedOutput :+ "~n"
					receivedOutput:+ processOutput
				endif

				'add new line indicator for followup lines
				'If receivedOutput <> "" Then receivedOutput:+"~n"
				'receivedOutput :+ process.Read()
			EndIf
		Wend

		If result = RESULT_ERROR then return False

		'maybe someone wants to receive additional information from
		'the received text
		ProcessOutput()

		'run validation of the output
		If Validate() Then result = RESULT_OK Else result = RESULT_FAILED

		'run cleanup - eg removing temporary files
		CleanUp()

		Return result
	End Method
End Type