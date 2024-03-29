-------------------------------
-- Fonctions LUA pour Domoticz.
-- Version 1.2 - 05/2023
-------------------------------

--------------------------------
------ 	  USER SETTINGS	  ------
--------------------------------

-- domoticz
domoticzIP = '127.0.0.1'	--'127.0.0.1'
domoticzPORT = '8080'
domoticzUSER = '????????'		-- nom d'utilisateur
domoticzPSWD = '????????'		-- mot de pass
domoticzPASSCODE = ''			-- pour les interrupteurs protégés
domoticzURL = 'http://' .. domoticzIP .. ':' .. domoticzPORT

local debug_function = false


------------------------------------------
--
-- Setup JSON & curl
--
------------------------------------------
-- Version de LUA dans Domoticz 2022.1
LUA_VERSION = 'Lua 5.3'

-- Chemin vers le dossier lua et curl
if (package.config:sub(1,1) == '/')
then
	-- system linux
	luaDir = debug.getinfo(1).source:match("@?(.*/)")
	--curl = '/usr/bin/curl -m 8 '		 							-- ne pas oublier l'espace à la fin
	curl = "/usr/bin/curl -m 8 -u " .. domoticzUSER .. ":" .. domoticzPSWD .. ' "' .. domoticzURL
else
	-- system windows
	luaDir = string.gsub(debug.getinfo(1).source:match("@?(.*\\)"),'\\','\\\\')
	curl = 'c:\\Programs\\Curl\\curl.exe '		 					-- ne pas oublier l'espace à la fin
end

-- Chargement du fichier JSON.lua
json = assert(loadfile(luaDir..'JSON.lua'))()

-- Définitions curl
curl_param 		=  curl .. '/json.htm?type=command&param='
curl_device 	=  curl .. '/json.htm?type=devices&rid='
curl_settings 	=  curl .. '/json.htm?type=settings'
curl_scene 		=  curl .. '/json.htm?type=scenes'

time = os.date("*t")
-- Nombre de minutes pour l'heure courante
Time_Now = time.hour * 60 + time.min

-- Retourne l'heure actuelle ex: "12:45"
-- heure = string.sub(os.date("%X"), 1, 5)

-- Retourne la date ex: "01:01"
date = os.date("%d:%m")

--------------------------------
------ 	  FUNCTIONS		  ------
--------------------------------
-- VARIABLES
-- function Var_Create(vname,vvalue,vtype) 
-- function Var_Set(vname,vvalue,vtype)
-- function Var_Delete_By_Idx(index)
-- function Var_Delete_By_Name(vname)
-- function Var_Get_Idx(vname)
-- function Var_Get_Name(vindex)
-- function Var_Get_Data_By_Idx(vindex)
-- function Var_Get_Data_By_Name(vname)
-- function Typeof(var)

-- DEVICES
-- function Dev_Get_Data(dname, ddata)
-- function Dev_Get_Idx(dname)
-- function Dev_Set_Switch(dname,dvalue)
-- function Dev_Update(dname, svalue)

-- SCENES
-- Scene_Get_Data(scname,scdata)
-- Scene_Get_Devices(scname)

-- STRING
-- function Parse_String_Arguments(str)
-- function Split_String(str, delimiter)
-- function Split_String_Empty_Field(str, delimiter)

-- LOG, DUMPS, DEBUG
-- function DLog(log)
-- function Log(log, level, separator) 
-- function LogVariables(x,depth,name)
-- function SLog(char, L)

-- TABLE
-- function Get_Table_Name(tbl)
-- Print_r(tbl)

-- TIME
-- function Compare_Unix_Times(Time1, Time2)
-- function ConvTime(timestamp)
-- function Convert_Unix_Time(Unix_Time)
-- function Convert_Minutes(Minutes)
-- function TimeDiff(Time1,Time2)
-- function ElapsedTime(dName,dType)
-- function Sleep(n)
-- function WhichSeason()

-- MISCLANEOUS
-- function bool(data)
-- function Check_LUA_Version(Lua_Version)
-- function url_encode(str)
-- function Round(num, dec)

--------------------------------
------         END        ------
--------------------------------


--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  VARIABLES		  														------
------ 	   				 														------
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
-- Var_Set(vname,vvalue,vtype)
-- 	Set variable 'vname' à value 'vvalue'. Type par défaut: 2.
-- 	Paramètre :  '<name>','<value>' ou '<name>','<value>','<type>'
-- 	0 = Integer, e.g. -1, 1, 0, 2, 10.
-- 	1 = Float, e.g. -1.1, 1.2, 3.1.
-- 	2 = String e.g. On, Off, Hello.
-- 	3 = Date in format DD/MM/YYYY.
-- 	4 = Time in 24 hr format HH:MM.
--------------------------------------------------------------------------------------
function Var_Set(vname,vvalue,vtype)
	local cmd = 'updateuservariable'
	--
	-- Check/set vtype.
	--
	if (vtype == nil)
	then
		vtype = 2
	end
	--
	-- Crée ou met à jour la variable <vname>.
	--
	if (Var_Get_Idx(vname) == 0)
	then
		DLog("Creating variable: '" .. vname .. "' with value '" .. vvalue.. "'.")
		cmd = 'adduservariable'
	else
		DLog("Updating variable '" .. vname .. "' to '" .. vvalue.. "'.")
	end
    -- print(curl_param .. cmd ..'&vname=' .. url_encode(vname) .. '&vtype='.. vtype ..'&vvalue=' .. vvalue .. '"')
	os.execute(curl_param .. cmd ..'&vname=' .. url_encode(vname) .. '&vtype='.. vtype ..'&vvalue=' .. vvalue .. '"')
end

--------------------------------------------------------------------------------------
-- Var_Delete_By_Idx(vindex)
-- 	Suppression de la variable d'index <vindex>.
--------------------------------------------------------------------------------------
function Var_Delete_By_Idx(vindex)
	if (vindex == 0)
	then
		DLog("Index is invalid")
	else
		os.execute(curl_param..'deleteuservariable&idx='.. vindex.. '" &')
		-- os.execute(curl_param..'deleteuservariable&idx='.. vindex.. '"')
	end
end

--------------------------------------------------------------------------------------
-- Var_Delete_By_Name(vname)
-- 	Suppression de la variable <vname>.
--------------------------------------------------------------------------------------
function Var_Delete_By_Name(vname)
	local index = Var_Get_Idx(vname)
	if (index == 0)
	then
		DLog("Var_Delete_By_Name - Variable '" .. vname .."' not found")
	else
		Var_Delete_By_Idx(index)
		DLog("Variable '" .. vname .."' deleted")
	end
end

--------------------------------------------------------------------------------------
-- Var_Get_Idx(vname)
-- 	Retourne l'index de la variable <vname>.
--------------------------------------------------------------------------------------
function Var_Get_Idx(vname)
	local config = assert(io.popen(curl_param..'getuservariables"'))
	local jsonBloc = config:read('*all')
	config:close()
	jsonData = json:decode(jsonBloc)
	for index, variable in pairs(jsonData.result)
	do
		if (variable.Name == vname)
		then
			DLog("Var_Get_Idx - Idx: " .. variable.idx .. " Name: " .. variable.Name .. " Value: " .. variable.Value .. " Last update: " .. variable.LastUpdate)
			return variable.idx
		end
	end
	return 0
end

--------------------------------------------------------------------------------------
-- Var_Get_Name(vindex)
-- 	Retourne le nom de la variable d'index <vindex>.
--------------------------------------------------------------------------------------
function Var_Get_Name(vindex)
	local config = assert(io.popen(curl_param..'getuservariables"'))
	local jsonBloc = config:read('*all')
	config:close()
	jsonData = json:decode(jsonBloc)
	for index, variable in pairs(jsonData.result)
	do
		if (variable.idx == vindex)
		then
			DLog("Var_Get_Name - Idx:" .. variable.idx .. " Name: " .. variable.Name .. " Value: " .. variable.Value .. " Last update: " .. variable.LastUpdate)
			return variable.Name
		end
	end
	return 0
end

--------------------------------------------------------------------------------------
-- Var_Get_Data_By_Idx(vindex)
-- 	Lecture de la variable utilisateur d'index <vindex>.
--	Retourne le nom de la variable, son type et sa valeur.
--------------------------------------------------------------------------------------
function Var_Get_Data_By_Idx(vindex)
	local vdata = assert(io.popen(curl_param .. 'getuservariable&idx='.. vindex .. '"'))
	local jsonBloc = vdata:read('*all')
	vdata:close()
	local jsonData = json:decode(jsonBloc)
	
	if ((jsonData.result) == nil)
	then
		DLog("Var_Get_Data_By_Idx - Variable with index '" .. vindex .." not found.")
		return '', '', ''
	end	
	
	return jsonData.result[1].Name, jsonData.result[1].Type, jsonData.result[1].Value, jsonData.result[1].LastUpdate
end


--------------------------------------------------------------------------------------
-- Var_Get_Data_By_Name(vname)
-- 	Lecture d'une variable utilisateur <vname>.
--------------------------------------------------------------------------------------
function Var_Get_Data_By_Name(vname)
	local vindex = Var_Get_Idx(vname)
	if (vindex == 0)
	then
		DLog("Var_Get_Data_By_Name - Variable '" .. vname .. "' not found")
	else
		local _, vtype, vdata, vlastupdate = Var_Get_Data_By_Idx(vindex)

        if (vtype == nil) or (vdata == nil) or (vlastupdate == nil)
        then
        Log("Var_Get_Data_By_Name(vname) = " .. vname .. " has nul data")
        end
		
		DLog("Var_Get_Data_By_Name - Variable '" .. vname .. "' = " .. vdata .. " vlastupdate = " .. vlastupdate)
		return vdata, vtype, vlastupdate
	end
end

--------------------------------------------------------------------------------------
-- Typeof(var)
-- 	Retourne le type de la variable
-- 	'string' , 'number' , 'table'
--------------------------------------------------------------------------------------
function Typeof(var)
    local _type = type(var);
    if(_type ~= "table" and _type ~= "userdata") 
	then
        return _type;
    end
    local _meta = getmetatable(var);
    if(_meta ~= nil and _meta._NAME ~= nil) 
	then
        return _meta._NAME;
    else
        return _type;
    end
end

--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  DEVICES                  												------
------ 	   				 														------
--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- Dev_Set_Switch(dname, dvalue)
-- 	Set a Switch device to on/off or set_level if dimmmable.
-- 	Parm : 'On' (100), 'Off' (0), level <numeric value>
-- 	SwitchType 					Type			cmd 	level
-- 	Blinds Percentage Inverted 	Light/Switch	On,Off	0-100
-- 	Selector					Light/Switch	--		0,10,20..100
-- 	OnOff						Light/Switch	On,Off	
--------------------------------------------------------------------------------------
function Dev_Set_Switch(dname,dvalue)
	local idx = Dev_Get_Idx(dname)
	local passcode = '&passcode='..domoticzPASSCODE
	
	if (dvalue == 'On')
	then
		cmd = '&switchcmd=On'
	elseif (dvalue == 'Off')
	then
		cmd = '&switchcmd=Off'
	elseif (dvalue ~= nil)
	then 
		cmd = '&switchcmd=Set%20Level&level=' .. dvalue
	else
		Log("Device '" .. dname .. "' not set.", 4)
		return
	end
	os.execute(curl_param .. 'switchlight&idx=' .. idx .. cmd ..  passcode .. '" &')
end


--------------------------------------------------------------------------------------
-- Dev_Update(dname, svalue)
-- 	Update field(s) for device dname.
--  Parm: string with value(s), semi-columns separated 
--------------------------------------------------------------------------------------
function Dev_Update(dname,svalue)
	local idx = Dev_Get_Idx(dname)
	local passcode = '&passcode='.. domoticzPASSCODE
	os.execute(curl_param .. 'udevice' .. '&idx=' .. idx ..'&nvalue=0&svalue=' .. svalue .. '" &')
end

--------------------------------------------------------------------------------------
-- Dev_Get_Data(dname, ddata)
-- 	Return the value of field <ddata> in device <dname>.
--------------------------------------------------------------------------------------
function Dev_Get_Data(dname, ddata)
	local idx =  Dev_Get_Idx(dname)
	if (idx ~= 0)
	then
		local config = assert(io.popen(curl_device .. idx ..'"'))
		local jsonBloc = config:read('*all')
		config:close()
		jsonData = json:decode(jsonBloc)
		return jsonData.result[1][ddata]
	else
		Log("Device '" .. dname .. "' not found",4)
	end
end

--------------------------------------------------------------------------------------
-- Dev_Get_Idx(dname)
-- 	Retourne l'index du device <vname>, 0 si le device est invalide.
--------------------------------------------------------------------------------------
function Dev_Get_Idx(dname)
	local config = assert(io.popen(curl_param..'devices_list"'))
	local jsonBloc = config:read('*all')
	config:close()
	jsonData = json:decode(jsonBloc)
	for index, variable in pairs(jsonData.result)
	do
		if (variable.name == dname)
		then
			-- use 'value' instead of 'idx' w Domoticz running on amd CPU
			-- DLog("Dev_Get_Idx - Var: " .. variable.name .. " Index:" .. variable.value)
			-- return variable.value
			DLog("Dev_Get_Idx - Var: " .. variable.name .. " Index:" .. variable.idx)
			return variable.idx 
		end
	end
	return 0
end

--------------------------------------------------------------------------------------
-- Settings_Get_Data(sdata)
-- 	Retourne la valeur du champs <sdata> dans la table settings
--------------------------------------------------------------------------------------
function Settings_Get_Data(sdata)
	local config = assert(io.popen(curl_settings ..'"'))
	local jsonBloc = config:read('*all')
	config:close()
	jsonData = json:decode(jsonBloc)
	return jsonData[sdata]
end

--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  SCENES                  												------
------ 	   				 														------
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- Scene_Get_Data(scname,scdata)
-- 	Retourne la valeur 'scdata' de la scène/groupe 'scname'.
--------------------------------------------------------------------------------------
function Scene_Get_Data(scname, scdata)
	local config = assert(io.popen(curl_scene .. '"'))
	local jsonBloc = config:read('*all')
	config:close()
	jsonData = json:decode(jsonBloc)
	for index, variable in pairs(jsonData.result)
	do
		if (variable.Name == scname)
		then
			DLog("Variable info: " .. variable.Name .. " idx: " .. variable.idx .. " Status:" .. variable[scdata])
			return variable[scdata]
		end
	end
	return 0
end

--------------------------------------------------------------------------------------
-- Scene_Get_Devices(scname)
-- 	Retourne une table avec la liste des devices contrôlés dans la scène 'scname'.
--------------------------------------------------------------------------------------
function Scene_Get_Devices(scname)
	local Device_List = {}
	local scindex = Scene_Get_Data(scname, 'idx')
	local config = assert(io.popen(curl_param..'getscenedevices&idx='.. scindex .. '&isscene=true"'))
	local jsonBloc = config:read('*all')
	config:close()
	jsonData = json:decode(jsonBloc)
	for index, variable in pairs(jsonData.result)
	do
		Device_List[index] = variable.Name
	end
	return Device_List
end


--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  STRING                  												------
------ 	   				 														------
--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- Parse_String_Arguments(str)
--	Parse une chaîne de caractères et retourne une table avec les entrées [arg]=<value> 
--	Paramètre d"entrée: "<arg>=<value>,<arg>=<value>,.."
--------------------------------------------------------------------------------------
function Parse_String_Arguments(str)
     result = {}
     for arg, val in string.gmatch(str, "(%w+)=(%w+)") do
		print("arg= " .. arg .. " ,val= " .. val)
       result[arg] = val
     end
	 return tbl
end


--------------------------------------------------------------------------------------
-- Split_String(str, delimiter)
--	Split une chaine de caractère dans une table. 
--	Accepte les champs vides séparés par <delimiter>. Ex: a,b,,d retourne 4 éléments.
--------------------------------------------------------------------------------------
function Split_String(str, delimiter)
    result = {};
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

--------------------------------------------------------------------------------------
-- Split_String_Empty_Field(str, delimiter)
--	Split une chaine de caractère dans une table. 
--	Ignore les champs vides séparés par <delimiter>. Ex: a,b,,d retourne 3 éléments.
--------------------------------------------------------------------------------------
function Split_String_Empty_Field(str, delimiter)
  local result = {}  
  for s in string.gmatch(str, "[^"..delimiter.."]+") 
  do
	table.insert(result, s)
  end
  return result
end



function Sans_Accent(str) -- supprime les accents de la chaîne str
    if (str) then
	str = string.gsub (str,"Ç", "C")
	str = string.gsub (str,"ç", "c")
    str = string.gsub (str,"[-èéêë']+", "e")
	str = string.gsub (str,"[-ÈÉÊË']+", "E")
    str = string.gsub (str,"[-àáâãäå']+", "a")
    str = string.gsub (str,"[-@ÀÁÂÃÄÅ']+", "A")
    str = string.gsub (str,"[-ìíîï']+", "i")
    str = string.gsub (str,"[-ÌÍÎÏ']+", "I")
    str = string.gsub (str,"[-ðòóôõö']+", "o")
    str = string.gsub (str,"[-ÒÓÔÕÖ']+", "O")
    str = string.gsub (str,"[-ùúûü']+", "u")
    str = string.gsub (str,"[-ÙÚÛÜ']+", "U")
    str = string.gsub (str,"[-ýÿ']+", "y")
    str = string.gsub (str,"Ý", "Y")
     end
    return (str)
end

--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  LOG, DUMPS, DEBUG														------
------ 	   				 														------
--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- DLog(log) 
--	Post un message dans la log si la variable locale debug_function=true. 
--------------------------------------------------------------------------------------
function DLog(log, level, separator) 
	if (debug_function == true)
	then
		Log(" * " .. log, level, separator) 
	end
end

--------------------------------------------------------------------------------------
-- SLog(log) 
--	Post un message de séparation dans la log. 
--  char (optionel): caractère(s) de remplacement de '-'.
--  L: longueur de la ligne de séparation, max 70. 
--------------------------------------------------------------------------------------
function SLog(char, L)
    if (char == nil)
    then
        char = '-'
    end
    Separator_Str = "----------------------------------"
	if (L ~= nil) and (tonumber(L) < #Separator_Str)
	then
		Separator_Str = string.sub(Separator_Str,1,L)
	end
    Separator_Str, _ = string.gsub(Separator_Str, '-', char)
    Log(Separator_Str)
end

--------------------------------------------------------------------------------------
-- Log(log, level, separator) 
--	Post un message dans la log. 
--	level (optionnel):
--	1 = normal
--	2 = status
-- 	4 = error
-- 	Split le message à \n (défaut) ou à <separator>.
--------------------------------------------------------------------------------------
function Log(log, level, separator) 
	if (level == nil)
	then
		level = 2
	end
	if (progName == nil)
	then
		progName = " >> "
	end	
	if (separator == nil)
	then
		separator = "\n"
	end
	lines = Split_String(log, separator)
	for i, line in ipairs(lines)
	do
		line = "[" .. progName .. "] " .. line
		os.execute(curl_param .. 'addlogmessage&message=' .. url_encode(line) .. '&level=' .. level .. '" &') 
	end
end

--------------------------------------------------------------------------------------
-- LogVariables(x,depth,name)
-- 	Send variable contents to the log.
-- 	dump all variables supplied to the script.
-- 	usage LogVariables(_G,0,'')
--------------------------------------------------------------------------------------
function LogVariables(x,depth,name)
    for k,v in pairs(x) do
			print("var: " .. k .. " type: " .. type(v))
        if (depth > 0) 
			or 	((string.find(k,'device') ~= nil) or (string.find(k,'variable') ~= nil) 
			or  (string.sub(k,1,4) == 'time') or (string.sub(k,1,8) == 'security')) 
		then
            if type(v) == "string" then print(name .. "['" .. k .. "'] = '" .. v .. "'") end
            if type(v) == "number" then print(name .. "['" .. k .. "'] = " .. v) end
            if type(v) == "boolean" then print(name .."['"..k.."'] = "..tostring(v)) end
            if type(v) == "table" then LogVariables(v,depth+1,k); end
        end
    end
end

--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  TABLE                 												------
------ 	   				 														------
--------------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Retourne une chaîne de caractèrs avec le nom d'une table.
------------------------------------------------------------------------------
function Get_Table_Name(tbl)
	for name, v in pairs(_G) 
	do
		DLog("name: " .. name .. " v: " .. type(v))
		if (v == tbl)
		then
			return name
		end
	end
	return nil
end


--------------------------------------------------------------------------------------
-- Print_r(tbl)
-- 	Affiche le contenu d'un tableau.
--------------------------------------------------------------------------------------
function Print_r(tbl)
    local print_r_cache={}
	
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(tbl)]) then
            print(indent.."*"..tostring(tbl))
        else
            print_r_cache[tostring(tbl)]=true
            if (type(tbl)=="table") then
                for pos,val in pairs(tbl) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(tbl).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'.. val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(tbl))
            end
        end
    end
	
    if (type(tbl)=="table") then
        print(tostring(tbl).." {")
        sub_print_r(tbl,"  ")
        print("}")
    else
        sub_print_r(tbl,"  ")
    end
    print()
end


--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  TIME, DATE, DELAY, WAIT												------
------ 	   				 														------
--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- Compare_Unix_Times(Time1, Time2)
-- Return
--  0 : Time& < time2
--  1 : Time1 > Time2
--  2 : Time1 = Time2
--------------------------------------------------------------------------------------
function Compare_Unix_Times(Time1, Time2)
	if (Time1 < Time2)
	then return '0'
	elseif (Time1 > Time2)
	then return '1'
	else return '2'
	end
end

--------------------------------------------------------------------------------------
-- Conv_Date_To_UnixTime(timestamp)
--	Convert a date-hour string to a Unix time.  2022-03-15 16:49:22 -> 1647359362
--------------------------------------------------------------------------------------
function Conv_Date_To_UnixTime(timestamp)
	y, m, d, H, M, S = timestamp:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
	return os.time{year=y, month=m, day=d, hour=H, min=M, sec=S}
end

--------------------------------------------------------------------------------------
-- Convert_Unix_Time(Unix_Time)
--	Convert a Unix time to a date/hour string. 1647359362 -> 2022-03-15 16:49:22
--------------------------------------------------------------------------------------
function Convert_Unix_Time(Unix_Time)
	return os.date("%Y-%m-%d %H:%M:%S",Unix_Time)
end


------------------------------------------------------------------------------
-- Convert hour (HH:MM) to minutes.
------------------------------------------------------------------------------
function Conv_Time_To_Minutes(Heure)
	local H, M = Heure:match("(%d+):(%d+)")
	return H * 60 + M
end

------------------------------------------------------------------------------
-- Convert minutes to HH:MM.
------------------------------------------------------------------------------
function Convert_Minutes_To_HHMM(Minutes)
	local Hour = math.floor(Minutes/60)
	return string.format("%02d:%02d", Hour, math.fmod(Minutes, 60))
end

--------------------------------------------------------------------------------------
-- Time_Diff(Time1,Time2)
--	Gives 2 time values	
-- 	Usage: 
-- 	ex : give the time difference between now and the time that a devices is last changed in minutes
--------------------------------------------------------------------------------------
function Time_Diff(Time1,Time2)
	if Time2 == nil
	then
		Time2 = os.time()
	end

	if (string.len(Time1)>12) 
	then
		Time1 = Conv_Date_To_UnixTime(Time1)
	end
	if (string.len(Time2)>12)
	then 
		Time2 = Conv_Date_To_UnixTime(Time2)
	end
    DLog("Time1=" .. Convert_Unix_Time(Time1) .. " Time2=" .. Convert_Unix_Time(Time2))
	ResTime=os.difftime(Time1,Time2)
	return ResTime
end

--------------------------------------------------------------------------------------	
-- Elapsed_Time(dName,dType)
-- 	Returns the duration since last updated time of a device or a variable
-- 	Usage: ElapsedTime(name,'v|d')
-- 	Return seconds of last update date for a Variable or a Device 
--------------------------------------------------------------------------------------
function Elapsed_Time(dName,dType)
	if (dType == 'v')
	then 
		Update_Timestamp = uservariable_lastupdate[dName]
	elseif (dType == 'd')
	then
		Update_Timestamp = otherdevices_lastupdate[dName]
	end 
	return Time_Diff(Update_Timestamp)
end

function TimeDiff(Time)
	t2 = Conv_Date_To_UnixTime(Update_Timestamp)
	t1 = os.time()
	tDiff = os.difftime(t1,t2)
	return tDiff
end
	

--------------------------------------------------------------------------------------	
-- WhichSeason()
--  Retourne la saison courante.
--------------------------------------------------------------------------------------
function WhichSeason()
	local tNow = os.date("*t") 
	local dayofyear = tNow.yday 
	local season 
	if (dayofyear >= 79) and (dayofyear < 172) 
	then
		season = "Spring" 
	elseif (dayofyear >= 172) and (dayofyear < 266) 
	then 
		season = "Summer" 
	elseif (dayofyear >= 266) and (dayofyear < 355) 
	then 
		season = "Autumn" 
	else 
		season = "Winter"
	end
	return season 
end

--------------------------------------------------------------------------------------
-- Sleep(n)
-- 	Sleep for seconds (strongly not recommended)
--------------------------------------------------------------------------------------
function Sleep(n)
	os.execute("sleep " .. tonumber(n))
end


--------------------------------------------------------------------------------------
------ 	   				  														------
------ 	  MISCLANEOUS												            ------
------ 	   				 														------
--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- bool(data)
-- 	Return a string with the state of a boolean argument.
--------------------------------------------------------------------------------------
function bool(data)
	if data == true
	then
		return "true"
	else
		return "false"
	end
end	

--------------------------------------------------------------------------------------
--  Check LUA version.
--------------------------------------------------------------------------------------
function Check_LUA_Version(Lua_Version)
	if (_VERSION ~= Lua_Version)
	then
		Log("LUA version is '" .. _VERSION .. "'. Expected '" .. Lua_Version .. "'.", 4)
	end
end

--------------------------------------------------------------------------------------
--  Get_Domoticz_Version().
--------------------------------------------------------------------------------------
function Get_Domoticz_Version()
	local config = assert(io.popen(curl_param..'getversion"'))
	local jsonBloc = config:read('*all')
	config:close()
	jsonData = json:decode(jsonBloc)
	for index, variable in pairs(jsonData)
	do
		if (index == 'version')
		then
			return variable
		end
	end
	return 0
end

--------------------------------------------------------------------------------------
-- url_encode(str)
-- 	Encode url before passing to OpenURL functions
--------------------------------------------------------------------------------------
function url_encode(str)
	if (str) 
	then
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w %-%_%.%~])",
		function (c) return string.format ("%%%02X", string.byte(c)) end)
		str = string.gsub (str, " ", "+")
	end
	return str
end

--------------------------------------------------------------------------------------
-- Round(num, dec)
--	Round off a numerical value to <dec> decimals
--------------------------------------------------------------------------------------
function Round(num, dec)
	if (num == 0)
	then
		return 0
	else
		local mult = 10^(dec or 0)
		return math.floor(num * mult + 0.5) / mult
	end
end
