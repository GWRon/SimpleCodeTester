REM
	===========================================================
	BASIC CONFIGURATION MAP
	===========================================================

	Code contains an class to hold certain key->value pairs.

ENDREM
SuperStrict
Import BRL.Map


Type TConfigMap
	Field values:TMap = CreateMap()
	Field fileUri:string = ""


	Method Init:TConfigMap( configFile:string="" )
		if configFile <> "" then LoadFromFile(configFile)

		return self
	End Method


	'clear all key->value pairs
	Method Reset:int()
		values.Clear()
		return TRUE
	End Method


	'create another configMap with the same values
	Method Copy:TConfigMap()
		local copyObj:TConfigMap = new TConfigMap

		'copy values
		for local key:string = eachin values.Keys()
			copyObj.Add(key, Get(key))
		Next
		return copyObj
	End Method


	'create a merged configMap of all given configurations (eg. base + extension)
	Function CreateMerged:TConfigMap( configs:TConfigMap[], reversed:int = FALSE )
		if configs.length = 0 then return null

		if reversed
			local newConfigs:TConfigMap[]
			for local i:int = 1 to configs.length
				newConfigs :+ [configs[configs.length - i]]
			Next
			configs = newConfigs
		endif


		local result:TConfigMap = configs[0].copy()
		for local i:int = 1 to configs.length-1
			'overwrite values or add new if not existing
			for local key:string = eachin configs[i].values.Keys()
				local value:object = configs[i].Get(key)
				if value then result.Add(key, value)
			Next
		Next
		return result
	End Function

	'try to load the configuration from a file
	Method LoadFromFile:int( fileUri:string )
		'skip resetting and loading if the file is not existing
		if filesize(fileUri) < 0 then return FALSE

		self.fileUri = fileUri

		'remove old values
		Reset()

		local file:TStream = readfile(fileUri)
		if not file
			'RuntimeError("ERROR: could not open file ~q"+fileUri+"~q for reading.")
			print "ERROR: could not open file ~q"+fileUri+"~q for reading."
			return FALSE
		endif

		local line:string = ""
		local splitPos:int = 0
		local key:string, value:string
		while not Eof(file)
			line = readline(file)

			'skip #comments
			if line.trim().Find("#") = 0 then continue

			'find first "=" (later ones could come from arguments/params)
			splitPos = line.Find("=")
			'no splitter means no assignment
			if splitPos < 0 then continue

			key = Left(line, splitPos).trim()
			value = Mid(line, splitPos+2).trim()

			Add(key, value)
		wend

		file.Close()
		return TRUE
	End Method


	Method ToString:string()
		local result:string = "TConfigMap"+"~n"
		result :+ "-> file: "+self.fileUri+"~n"
		result :+ "-> keys:"+"~n"
		for local key:string = eachin values.Keys()
			result :+ "  -> "+key+" : "+string(values.ValueForKey(key))+"~n"
		Next
		return result
	End Method


	Method Add:TConfigMap( key:string, data:object )
		values.insert(key, data)
		return self
	End Method


	Method AddString:TConfigMap( key:string, data:string )
		Add(key, object(data))
		return self
	End Method


	Method AddNumber:TConfigMap( key:string, data:float )
		Add( key, object( string(data) ) )
		return self
	End Method


	Method Get:object( key:string, defaultValue:object=null )
		local result:object = values.ValueForKey(key)
		if result then return result
		return defaultValue
	End Method


	Method GetString:string( key:string, defaultValue:string=null )
		local result:object = Get(key)
		if result then return String( result )
		return defaultValue
	End Method


	Method GetInt:int( key:string, defaultValue:int = null )
		local result:object = Get(key)
		if result then return Int( float( String( result ) ) )
		return defaultValue
	End Method
End Type