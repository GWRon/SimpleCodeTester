Rem
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
	Field handle:Size_T
	Field standardIO:TPipeStream
	Field errorIO:TPipeStream
	Field flags:Int = 0
	Field runAfterwards:TCodeTesterProcess


	Method Init:TCodeTesterProcess( name:String, flags:Int = -1, runNow:Int=True )
?MacOS
		If FileType(name+".app")=FILETYPE_DIR
			Local a:String = StripExt( StripDir(name) )
			name:+".app/Contents/MacOS/"+a
		EndIf
?
		If flags = -1
			self.flags = HIDECONSOLE
		Else
			Self.flags = flags
		EndIf
		
		Self.name = name

		'remove old processes when creating already
		FlushZombies()

		If runNow Then RunProcess()
		Return Self
	End Method


	Method Alive:Int()
		If handle
			If fdProcessStatus(handle) Then Return True
			handle = 0
		EndIf
		Return False
	End Method


	Method IOAvailable:Int()
		Return StandardIOAvailable() Or ErrorIOAvailable()
	End Method


	Function StreamHasLine:int(stream:TPipeStream)
		if stream.bufferPos <= 0 then return False
		
		For local n:int = 0 To stream.bufferpos
			'newline character found?
			If stream.readbuffer[n] = 10 then return True
		Next
		return False
	End Function


	Method Read:String()
		Local result:String = ""
		'prefer errors first?
		'If result="" Then result = ReadErrorIO()
		'If result="" Then result = ReadStandardIO()

		'or read them in straight one after another?
		result :+ ReadErrorIO()
		result :+ ReadStandardIO()

		Return result
	End Method


	Method ReadStandardIO:String()
		If StandardIOAvailable()
			'local hasLine:int = StreamHasLine(standardIO)
			'if not hasLine then return ""
			
			local res:string = standardIO.ReadLine().Replace("~r","") '.Replace("~n","")
			'read all what's left if app ended without newline
			if res.length = 0 and not handle then return ReadStreamBuffer(standardIO)
			return res
		EndIf
	End Method


	Method ReadErrorIO:String()
		If ErrorIOAvailable()
			local res:string = errorIO.ReadLine().Replace("~r","") '.Replace("~n","")
			'read all what's left if app ended without newline
			if res.length = 0 and not handle then return ReadStreamBuffer(errorIO)
			return res
		EndIf
	End Method


	Method StandardIOAvailable:Int()
		'readAvail() returns the number of bytes "to fetch"
		'bufferPos describes what was already fetched but not "read" yet
		Return standardIO and (standardIO.readAvail() or standardIO.bufferPos > 0)
	End Method


	Method ErrorIOAvailable:Int()
		Return errorIO and (errorIO.readAvail() or errorIO.bufferPos > 0)
	End Method


	Method ReadStreamBuffer:string(stream:TPipeStream)
		local result:string
		local n:int = stream.bufferPos
		local p1:int = n
		If (n>0)
			If stream.readbuffer[n-1] = 13
				p1 = n-1
			EndIf
		EndIf

		local p0:int = 0
		If stream.readbuffer[0] = 13
			p0 = 1
		EndIf

		If p1>p0
			result = String.FromBytes(Varptr stream.readbuffer[p0],p1-p0)
		EndIf
		
		stream.bufferPos = 0

		return result
	End Method


	Method CloseStreams()
		'print "CloseStreams() - name: " + name
		If standardIO
			standardIO.Close()
			standardIO = Null
		EndIf
		If errorIO
			errorIO.Close()
			errorIO = Null
		EndIf
	End Method
	

	Method Close()
		Terminate()

		If runAfterwards Then runAfterwards.RunProcess()
	End Method


	Method Terminate:Int()
		CloseStreams()

		Local res:Int
		If handle
			res = fdTerminateProcess(handle)
			handle = 0
		EndIf
		Return res
	End Method


	Method RunProcess:TCodeTesterProcess()
		'print "RunProcess: "+processes.Count()+" processes still running."
		Local infd:Size_T, outfd:Size_T, errfd:Size_T

		'remove old processes when running
		FlushZombies()

		handle = fdProcess(name, Varptr infd, Varptr outfd, Varptr errfd, flags)
		If Not handle Then Return Null

'		standardIO = TPipeStreamUTF8.Create(infd, outfd)
'		errorIO = TPipeStreamUTF8.Create(errfd, outfd)
		standardIO = TPipeStream.Create(infd, outfd)
		errorIO = TPipeStream.Create(errfd, outfd)

		if not standardIO then Throw "Failed to create standardIO stream" 
		if not errorIO then Throw "Failed to create errorIO stream" 

		processes.AddLast(Self)
		Return Self
	End Method


	Function FlushZombies()
		Local aliveList:TList = CreateList()
		For Local p:TCodeTesterProcess = EachIn processes
			If p.Alive()
				aliveList.AddLast p
			else
				p.Terminate()
			endif
		Next
		processes = aliveList
	End Function


	Method Eof:Int()
		'process alive, so might still output something 
		If Alive() Then Return False
		'still something to read?
		If IOAvailable() Then Return False
		Return True
	End Method


	Function TerminateAll() NoDebug
		For Local p:TCodeTesterProcess = EachIn processes
			p.Terminate()
		Next
		processes = Null
	End Function
End Type



Type TPipeStreamUTF8 Extends TPipeStream
	Method ReadPipe:Byte[]()
		Local n:Int = ReadAvail()
		If n
			Local bytes:Byte[] = New Byte[n]
			Read(bytes, n)
			Return bytes
		EndIf
	End Method


	Method FillBuffer:int()
		Local available:int = ReadAvail()
		'fill buffer
		If available
			'calc unused buffer size
			If bufferpos + available > 4096 then available = 4096 - bufferpos
			If available <=0 then RuntimeError "TPipeStreamUTF8 FillBuffer Overflow"
			'adjust buffer position
			bufferpos :+ Read(Varptr readbuffer[bufferpos], available)
		EndIf

		return available > 0
	End Method


	Method ReadUTF8FromBuffer:string(bufferOffset:int, size:int)
		local result:string = ""
		local c:int, d:int, e:int

		For local offset:int = bufferOffset To bufferOffset + size
			c = readbuffer[offset]
			
			If c < 128
				result :+ chr(c)
				continue
			EndIf

			offset :+ 1
			d = readbuffer[offset]
			If c < 224
				result :+ chr((c-192)*64 + (d-128) )
				continue
			EndIf

			offset :+1
			e = readbuffer[offset]
			If c < 240
				result :+ chr( (c-224)*4096 + (d-128)*64 + (e-128) ) + "Ä"
				continue
			EndIf
		Next

		return result
	End Method


	Method HasLine:int()
		'fill read buffer with new data (if available)
		FillBuffer()

		For local n:int = 0 To bufferpos
			'newline character found?
			If readbuffer[n] = 10 then return True
		Next
		return False
	End Method
	

	Method ReadLine:String()
		'fill read buffer with new data (if available)
		FillBuffer()

		Local p0:int, p1:int, line:string
		'read in existing buffer
		For local n:int = 0 To bufferpos
			'newline character found?
			'also generate a line if the buffer reached its end
			If readbuffer[n] = 10 or n = bufferpos-1
				p1 = n
				p0 = 0
				'skip double newlines (10,13)
				if readbuffer[n] = 10
					If (n>0) and readbuffer[n-1] = 13 then p1 = n - 1
					If readbuffer[0] = 13 then p0 = 1
				endif
				
				If p1 > p0
					line = ReadUTF8FromBuffer(p0, p1-p0)
					'line = String.FromBytes(Varptr readbuffer[p0], p1 - p0)
				EndIf
				'advance to next char
				n:+1
				bufferpos:-n

				If bufferpos then MemMove(readbuffer, Varptr readbuffer[n], Size_T(bufferpos))
				Return line
			EndIf
		Next		
	End Method


rem
	Method ReadChar:Int()
		Local c:Int = ReadByte()
		If c < 128 Then Return c
		Local d:Int = ReadByte()
		If c < 224 Then Return (c-192)*64 + (d-128)
		Local e:Int = ReadByte()
		If c < 240 Then Return (c-224)*4096 + (d-128)*64 + (e-128)
	End Method


	Method ReadLine:String()
		If ReadAvail()
			Local buf:Short[1024], i:Int
			'somehow "Eof()" returns False albeit there is nothing
			'to read - that is why we check ReadAvail() too
			While Not Eof() And ReadAvail()
				Local n:Int = ReadChar()
				If n =  0 Then Exit
				If n = 10 Then Exit
				If n = 13 Then Continue
				If buf.length = i Then buf = buf[..i+1024]
				buf[i] = n
				i:+1
			Wend
			Return String.FromShorts(buf, i)
		EndIf
		Return ""
	End Method
end rem

	Function Create:TPipeStreamUTF8( in:Int, out:Int )
		Local stream:TPipeStreamUTF8 = New TPipeStreamUTF8
		stream.readHandle = in
		stream.writeHandle = out
		Return stream
	End Function
End Type