SuperStrict

Framework brl.standardio
Import "app.testmanager.bmx"

Rem
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
End Rem



'=== DEFAULT OPTIONS ===
'if there is no "base.conf" overriding them in the test directory

'uncomment for in-code test directory assignment
AppArgs = [AppArgs[0], "../../../Tools/BlitzMaxNG/bin/tests"]
'AppArgs = [AppArgs[0], "../../../Tools/BlitzMaxNG/bin/tests/test"]

'adjust compiler path for this test class
TTestCompiler.baseConfig.Add("bmk_path", "/path/to/BlitzMaxNG/bin/bmk")
'TTestCompiler.baseConfig.Add("bmk_path", "../../../../BlitzMaxNG/bin/bmk")

'adjust base config for all instances of that type
TTestCompiler.baseConfig.Add("app_type", "console")
TTestCompiler.baseConfig.Add("app_arch", "x86") 'unused yet
TTestCompiler.baseConfig.Add("debug", "0")
TTestCompiler.baseConfig.Add("threaded", "0")
TTestCompiler.baseConfig.Add("deleteBinaries", "1") 'delete binaries afterwards
TTestCompiler.baseConfig.Add("make_mods", "0") 
TTestCompiler.baseConfig.Add("quick", "0") 
TTestCompiler.baseConfig.fileUri = "baseConfig"


'=== RUN TESTS ===
Global testManager:TTestManager = New TTestManager.Init(AppArgs[1..])
testManager.RunTests()
