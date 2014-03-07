what it does
============
	
The SCT binary will traverse through a given directory, loads all available test files (defineable) and their configurations. Afterwards the tests are run (executed) and the output is checked if it is identical to a desired output. Errors are printed additionally to an statement whether the test failed or not.


Result Files
============

An equally to the test file named result file (xxx.res) is used for validation of output. More specific: the output of a test process is compared to the content of this result file. If they are identical the test is successful, else it is failed. 


Configuration Files
===================
Each test can be located somewhere within the given directory.
If in the test files directory a similar named xxx.conf is found,
this configuration is used.
If no configuration file was found, the testManager will look in
a directory one level higher.
IMPORTANT: as this new directory can contain multiple .conf-files
only an "base.conf" file is used to avoid ambiguity.

So this is allowed and gets used:
* sampletests/base.conf
* sampletests/mytest/mytestA.conf
* sampletests/mytest/mytestA.bmx <- uses mytest.conf
* sampletests/mytest/mytestB.bmx <- uses ../base.conf
* sampletests/mytest2/base.conf
* sampletests/mytest2/mytestA.bmx <- uses base.conf
* ... and so on

Each configuration file inherits the configuration of a parent
folder's "base.conf" (which also inherits from its parent).
