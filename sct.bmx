SuperStrict

Framework brl.retro
Import "app.testmanager.bmx"

REM
	Readme:

	Each test can be located somewhere within the given directory.
	If in the test files directory a similar named xxx.conf is found,
	this configuration is used.
	If no configuration file was found, the testManager will look in
	a directory one level higher.
	IMPORTANT: as this new directory can contain multiple .conf-files
	only an "base.conf" file is used to avoid ambiguity.

	So this is allowed and gets used:
	sampletests/base.conf
	sampletests/mytest/mytestA.conf
	sampletests/mytest/mytestA.bmx <- uses mytest.conf
	sampletests/mytest/mytestB.bmx <- uses ../base.conf
	sampletests/mytest2/base.conf
	sampletests/mytest2/mytestA.bmx <- uses base.conf
	... and so on

	Each configuration file inherits the configuration of a parent
	folder's "base.conf" (which also inherits from its parent).
END REM



'adjust compiler path for this test class
TTestCompiler.SetCompilerURI("/home/ronny/Arbeit/Programmieren/BlitzMax/bin/bmk")
'adjust base config for all instances of that type
TTestCompiler.baseConfig.Add("app_type", "console")
TTestCompiler.baseConfig.Add("app_arch", "x86") 'unused yet
TTestCompiler.baseConfig.Add("debug", "0")
TTestCompiler.baseConfig.Add("threaded", "0")
TTestCompiler.baseConfig.Add("deleteBinaries", "1") 'delete binaries afterwards
TTestCompiler.baseConfig.fileUri = "baseConfig"

global testManager:TTestManager = new TTestManager.Init()
testManager.AddTestsFromDirectory("sampleTests")
testManager.RunTests()
