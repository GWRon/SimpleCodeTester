SuperStrict
Import "base.configmap.bmx"
Import "base.processes.bmx"


REM
Example:

local test:TTestBase = new TTestBase.Init("BasicTest")
test.commandUri = "ls -l /home/ronny"
test.doValidation = FALSE
test.Run()
END REM

Type TTestBase
	Field name:string = "unnamed Test"
	'the uri to the command to run
	Field commandURI:string = ""
	'the process of the command when executed
	Field process:TCodeTesterProcess
	'configuration (parameters and other things)
	Field config:TConfigMap = new TConfigMap

	Field receivedOutput:string = ""
	Field expectedOutput:string = ""
	Field result:int = 0
	'one might skip validation of output
	'eg. only check if execution was possible
	Field doValidation:int = FALSE

	Const RESULT_OK:int = 1
	Const RESULT_FAILED:int = 0
	Const RESULT_ERROR:int = -1


	Method Init:TTestBase(name:string="")
		if name<>"" then self.name = name
		return self
	End Method


	Method GetName:string()
		return name
	End Method


	'returns the complete commandline for process execution
	'eg. "ls -l *.bat"
	Method GetCommandline:string()
		local params:string = "" 'base has no params
		return commandURI + " " + params
	End Method


	'set what result is expected
	Method SetExpectedOutput:int(output:string="")
		expectedOutput = output

		'force validation
		doValidation = TRUE
	End Method



	Method LoadExpectedOutput:int(fileURI:string)
		local file:TStream = readfile(fileURI)
		if not file then return FALSE

		local content:string = ""
		While not Eof(file)
			content :+ readline(file)
		Wend
		SetExpectedOutput(content)

		return TRUE
	End Method

	'overrideable method to do additional processing
	'of the received output (eg. to parse for certain messages)
	Method ProcessOutput:int()
		'
	End Method


	'overrideable method run after the process finished
	'eg. remove temporary files
	Method CleanUp:int()
		'
	End Method


	'check if the test was passed
	Method Validate:int()
		if not doValidation then return TRUE
		'by default we just check if the output corresponds
		'to one we defined before
		print "expected: -"+expectedOutput+"-"
		print "received: -"+receivedOutput+"-"
		return expectedOutput = receivedOutput
	End Method


	Method Run:int()
		print "* RUNNING TEST: " + GetName()

		print "  COMMAND: "+ GetCommandline()

		'start the process execution
		process = new TCodeTesterProcess.Init( GetCommandline() )
		receivedOutput = ""

		while process.Alive()
			if process.IOAvailable()
				'as soon as an error happens - set the result accordingly
				if process.ErrorIOAvailable() then result = RESULT_ERROR

				'add new line indicator for followup lines
				if receivedOutput <> "" then receivedOutput:+"~n"
				receivedOutput :+ process.Read()
			endif
		Wend

		if result = RESULT_ERROR
			print "  -> PROCESS FAILED !"
			print "ERROR MESSAGE>>>"
			print receivedOutput
			print "<<<"
			return FALSE
		endif

		'maybe someone wants to receive additional information from
		'the received text
		ProcessOutput()

		'run validation of the output
		if Validate() then result = RESULT_OK else result = RESULT_FAILED

		if result = RESULT_OK
			print "  -> OK"
		elseif result = RESULT_FAILED
			print "  -> FAILED"
		endif

		'run cleanup - eg removing temporary files
		CleanUp()

		return result
	End Method
End Type