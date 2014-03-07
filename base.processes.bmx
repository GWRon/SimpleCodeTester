REM
	===========================================================
	PROCESS HANDLING CLASSES
	===========================================================

	These types allow handling of executed processes and fetching
	their output strings.

ENDREM
SuperStrict
Import pub.freeprocess	'required for process handling


Type TCodeTesterProcess
	Global processes:TList = CreateList()

	Field name:String
	Field handle:Int
	Field standardIO:TPipeStreamUTF8
	Field errorIO:TPipeStreamUTF8
	Field waitingSince:Int = 0
	Field flags:Int = 0
	Field runAfterwards:TCodeTesterProcess


	Method Init:TCodeTesterProcess( name:string, flags:Int = 0, runNow:Int=True )
?MacOS
		If FileType(name)=2
			Local a:string = StripExt( StripDir(name) )
			name:+"/Contents/MacOS/"+a
		EndIf
?
		self.flags = flags
		self.name = name

		FlushZombies()

		If runNow Then RunProcess()
		Return self
	End Method


	Method Alive:Int()
		If handle
			If fdProcessStatus(handle) then Return True
			handle = 0
		EndIf
		If waitingSince = 0 Then waitingSince = MilliSecs()
		Return False
	End Method


	Method IOAvailable:Int()
		Return StandardIOAvailable() or ErrorIOAvailable()
	End Method


	Method Read:String()
		local result:string = ""
		if result="" then result = ReadErrorIO()
		if result="" then result = ReadStandardIO()
		return result
	End Method


	Method ReadStandardIO:String()
		If StandardIOAvailable() then Return standardIO.ReadLine().Replace("~r","").Replace("~n","")
	End Method


	Method ReadErrorIO:String()
		If ErrorIOAvailable() then Return errorIO.ReadLine().Replace("~r","").Replace("~n","")
	End Method


	Method StandardIOAvailable:Int()
		Return standardIO.bufferpos Or standardIO.readAvailable()
	End Method


	Method ErrorIOAvailable:Int()
		Return errorIO.bufferpos Or errorIO.readAvailable()
	End Method


	Method Close()
		If standardIO
			standardIO.Close()
			standardIO = Null
		endif
		If errorIO
			errorIO.Close()
			errorIO = Null
		endif

		terminate()

		If runAfterwards then runAfterwards.RunProcess()
	End Method


	Method Terminate:Int()
		Local res:Int
		If handle
			res = fdTerminateProcess(handle)
			handle = 0
		EndIf
		Return res
	End Method


	Method RunProcess:TCodeTesterProcess()
		Local infd:Int, outfd:Int, errfd:Int

		handle = fdProcess(name, Varptr infd, Varptr outfd, Varptr errfd, flags)
		If Not handle then Return Null

		standardIO = TPipeStreamUTF8.Create(infd, outfd)
		errorIO = TPipeStreamUTF8.Create(errfd, outfd)

		processes.AddLast(Self)
		Return Self
	End Method


	Function FlushZombies()
		Local aliveList:TList = CreateList()
		For Local p:TCodeTesterProcess = EachIn processes
			If p.Alive() then aliveList.AddLast p
		Next
		processes = aliveList
	End Function


	Method Eof:Int()
		If Alive() then Return False
		If StandardIOAvailable() then return False
		If ErrorIOAvailable() then return False
		Return True
	End Method


	Function TerminateAll() NoDebug
		For Local p:TCodeTesterProcess = EachIn processes
			p.Terminate()
		Next
		processes = Null
	End Function
End Type



Type TPipeStreamUTF8 Extends TStream
	Field readBuffer:Byte[4096]
	Field bufferPos:Int
	Field readHandle:Int, writeHandle:Int


	Method Close()
		If readHandle
			fdClose(readHandle)
			readHandle = 0
		EndIf
		If writeHandle
			fdClose(writeHandle)
			writehandle = 0
		EndIf
	End Method


	Method Read:Int( buffer:Byte Ptr, count:Int )
		Return fdRead( readHandle, buffer, count )
	End Method


	Method Write:Int( buffer:Byte Ptr, count:Int )
		Return fdWrite( writeHandle, buffer, count )
	End Method


	Method Flush()
		fdFlush(writeHandle)
	End Method


	Method ReadAvailable:Int()
		Return fdAvail(readHandle)
	End Method


	Method ReadPipe:Byte[]()
		local n:Int = ReadAvailable()
		If n
			Local bytes:Byte[] = New Byte[n]
			Read(bytes, n)
			Return bytes
		EndIf
	End Method


	Method _ReadByte:Int()
		Local n:Byte
		ReadBytes(Varptr n, 1)
		Return n
	End Method


	Method ReadChar:Int()
		Local c:Int = _ReadByte()
		If c < 128 then Return c
		Local d:Int = _ReadByte()
		If c < 224 then Return (c-192)*64 + (d-128)
		Local e:Int = _ReadByte()
		If c < 240 then Return (c-224)*4096 + (d-128)*64 + (e-128)
	End Method


	Method ReadLine:String()
		If ReadAvailable()
			Local buf:Short[1024], i:Int
			'somehow "Eof()" returns False albeit there is nothing
			'to read - that is why we check ReadAvailable() too
			While Not Eof() and ReadAvailable()
				Local n:Int = ReadChar()
				If n =  0 then Exit
				If n = 10 then Exit
				If n = 13 then Continue
				If buf.length = i then buf = buf[..i+1024]
				buf[i] = n
				i:+1
			Wend
			Return String.FromShorts(buf, i)
		EndIf
		Return ""
	End Method


	Function Create:TPipeStreamUTF8( in:Int, out:Int )
		Local stream:TPipeStreamUTF8 = New TPipeStreamUTF8
		stream.readHandle = in
		stream.writeHandle = out
		Return stream
	End Function
End Type