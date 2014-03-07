SuperStrict

Import brl.retro
Import "base.processes.bmx"


'===== EXAMPLE =====
'relies on having "echo" as a working command in the bash/shell/whatever
local testProcess:TCodeTesterProcess = new TCodeTesterProcess.Init("echo Line~nAnotherLine")
local testResult:string
local testWantedResult:string = "Line~nAnotherLine"

'print "TEST:START"
while testProcess.Alive()
	if testProcess.IOAvailable()
		'add new line indicator for followup lines
		if testResult<>"" then testResult:+"~n"
		testResult :+ testProcess.Read()
	endif
Wend
'print "TEST:END"

if testResult = testWantedResult
	print "TEST:OK"
else
	print "TEST:FAILED"
endif




'===== EXAMPLE2 =====
'reset and overwrite previous assignments
testProcess = new TCodeTesterProcess.Init("echo Line~nAnotherLine")
testResult = ""
testWantedResult = "Line~nAnotherLineWithMoreText"

'print "TEST:START"
while testProcess.Alive()
	if testProcess.IOAvailable()
		'add new line indicator for followup lines
		if testResult<>"" then testResult:+"~n"
		testResult :+ testProcess.Read()
	endif
Wend
'print "TEST:END"

if testResult = testWantedResult
	print "TEST:OK"
else
	print "TEST:FAILED"
endif
