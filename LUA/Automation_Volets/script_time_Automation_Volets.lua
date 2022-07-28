--*******************************************************************************
--
-- Automation des volets selon les switches virtuels 'Mode Volets<xx>'].
--
--*******************************************************************************

local debug_mode = true

--****************************************
--
-- CHARGEMENT DES PACKAGES.
--
--****************************************
package.path = '/home/pi/domoticz/scripts/lua/Functions_LUA.lua;' .. package.path 
require("Functions_LUA.lua")
package.path = '/home/pi/domoticz/scripts/lua/Automation_Config.lua;' .. package.path 
require("Automation_Config.lua")


--****************************************
--
-- CUSTO.
--
--****************************************

-- Ecart en °C pour l'ajustement de l'ouverture en fonction de la température (au pas de 5%).
DELTA_TEMPERATURE = 3
-- Delta entre la postion courante et la consigne pour reprise en mode 'BioClim'.
MARGIN = 15


--****************************************
--
-- VARIABLES.
--
--****************************************

-- Nom du programme (logging).
progName 	= 'Automation Volets'

-- Heures d'ouverture et de fermeture automatique des volets.
local Time_Minimum = Conv_Time_To_Minutes(TIME_MINIMUM)
local Time_Day 		= math.max(timeofday['SunriseInMinutes'] + TIME_DAY_OFFSET, Time_Minimum)
local Time_Night 	= timeofday['SunsetInMinutes'] + TIME_NIGHT_OFFSET

local Season = WhichSeason()

local OnCmd			= 'On'
local OffCmd		= 'Off'

----------------------------------------------------------------------
-- Setup de variables en fonction des switches et capteurs optionnels.
----------------------------------------------------------------------

-- Validation du switch d'automation. Forcé à 'On' si nul.
local Automation	= otherdevices[AUTOMATION_SWITCH]
if (Automation == nil)
then
	Automation = 'On'
end
-- Lecture du switch de securité. Forcé à 'Off' si nul.
local Security = otherdevices[SECURITY_SWITCH]
if (Security == nil)
then
	Security = 'Off'
end

-- Validation de la température extérieure (précision 0.1°C).
local Ext_Temperature = otherdevices_temperature[SENSOR_EXTERNAL_TEMP]
if (Ext_Temperature == nil) or (Ext_Temperature > 60)
then 
	Ext_Temperature = TEMPERATURE_MINIMUM
	Control_Temperature = false
else
	Ext_Temperature = Round(tonumber(Ext_Temperature),1)
end


--****************************************
--
-- FONCTIONS LOCALES.
--
--****************************************

--------------------------------------------------------------------------------------
-- DLog(log) 
--	Post un message dans la log si debug_mode=true. 
--------------------------------------------------------------------------------------
local function DLog(log, level, separator) 
	if (debug_mode == true)
	then
		Log(" § " .. log,level, separator) 
	end
end

--****************************************************************************
--                                                                           *
--	Fonctions pour le mode 'Jour/Nuit'.                                      *
--                                                                           *
--****************************************************************************

------------------------------------------------------------------------------
-- OnOff_Command_Sender(Device, First_Level)
-- Envoi les commandes d'ouverture/fermeture Jour/Nuit.
--	La fermeture se fait en 2 temps si le paramètre First_Level est spécifié.
--		ex : OnOff_Command_Sender('Grp Volets RdC','60')
------------------------------------------------------------------------------
function OnOff_Command_Sender(Device, First_Level)
	--
	-- Ouverture automatique.
	--
	if (Time_Now == Time_Day)
	then
		commandArray[#commandArray +1]={[Device] = OnCmd}
		Log('Ouverture Automatique ' .. Device)
	end
	--
	-- Fermeture au 1er niveau 3mn avant la fermeture complète.
	--
 	if (First_Level ~= nil) and (Time_Now == (Time_Night - 3)) and (Dev_Get_Data(Device, 'Level') > First_Level)
	then
		-- commandArray[#commandArray +1]={[Device] = 'Set Level: ' .. First_Level}
		Dev_Set(Device,First_Level)
		Log(Device .. " - Fermeture à " .. First_Level .. "%.", 2)
	end
	--
	-- Fermeture  complète.
	--
	if (Time_Now == Time_Night)
	then
		commandArray[#commandArray +1]={[Device] = OffCmd}
		Log(Device .. " - Fermeture complète.", 2)
	end
end

------------------------------------------------------------------------------
-- Envoi des demandes d'ouverture/fermeture Jour/Nuit aux volets.
--	<Device_List> : Liste des volets ou nom d'un volet ou d'un groupe de volets.
--	<First_Level> (optionel) : 1er niveau de fermeture si la fermeture en 2 temps.
------------------------------------------------------------------------------
function OnOff_Command_Scheduler(Device_List,First_Level)
	if (type(Device_List) == 'table')
	then
		--
		--	 Parcours de la table contenant la liste des volets.
		--
		for index, Device in pairs(Device_List)
		do
			OnOff_Command_Sender(Device, First_Level)
		end
	else
		-- Envoi de la commande à un seul volet (ou à un  groupe zigate).
		OnOff_Command_Sender(Device_List, First_Level)
	end
end

--****************************************************************************
--                                                                           *
--	Fonctions pour le mode 'BioClim'.                                        *
--                                                                           *
--****************************************************************************

------------------------------------------------------------------------------
--
-- BioClim_Process(BioClim_Config)
--	Positionne les volets comme défini dans chaque plage horaire.
--	Voir contenu des variables BioClim_Volets_xxx.
-- 	parm : nom du groupe BioClim défini dans Automation_Config.lua.
--
------------------------------------------------------------------------------
function BioClim_Process(BioClim_Config)

	local BioClim_Config_Table_Size = #_G[BioClim_Config]

	local Slot_Start_Time = 0
	local Slot_End_Time = 0
	
	local Level = 100
	
	local BioClim_Status_In = {}
	local BioClim_Status_Out = {}	
	
	--***** DEBUT FONCTIONS LOCALES ********************************************
	----------------------------------------------------------------------------
	-- Compare l'état courant avec l'état enregistré et retourne 'true' si le 
	-- volet a été manoeuvré hors automation à +/- MARGIN.
	----------------------------------------------------------------------------
	local function Level_Changed(Device,Device_Index, Margin)
		local Margin
		local Current_Level = Dev_Get_Data(Device, 'Level')
		local Last_Level = BioClim_Status_In[Device_Index]
		
		if (Margin == nil)
		then
			Margin = MARGIN
		end
		
		-- Set Last_Level pour comparaison de Current_Level avec la consigne.
		if (Last_Level == 'Off')
		then
			Last_Level = Level
		end
		
		-- Conversion état 'On' en 100 pour test de manoeuvre si manoeuvre manuelle.
		if (Last_Level == 'On')
		then 
			Last_Level = 100
		end		
		
		Delta_Level = math.abs(Current_Level - Last_Level)
		DLog(Device .. " - Cur_Lvl: " .. Current_Level .. "  Tgt_Lvl: " .. Last_Level .. "  Delta: " .. Delta_Level, 2)
			
		if (Delta_Level > Margin)
		then
			-- Le volet a été manoeuvré hors automation.
			return true
		else
			-- Le volet est ouvert à la consigne +/- MARGIN.
			return false
		end
	end
	--*************************************************************************


	-------------------------------------------------------
	-- Positionne le volet et met à jour la variable d'état.
	-------------------------------------------------------
	local function Dev_Control(Device, Device_Index)	
		local Last_Level = BioClim_Status_In[Device_Index]	
		
		if 	(BioClim_Status_In[Device_Index] == 'Off') 
		---------------------------------------------------------------------------
		-- Etat enregistré = 'Off'. Test pour reprise en mode 'BioClim', sinon 'Off'.
		---------------------------------------------------------------------------
		then
			if (Level_Changed(Device,Device_Index) == false)
			then
				-- Reprise en mode BioClim car le volet est trouvé à la consigne à MARGIN près.
				Dev_Set(Device,Level)
			else
				-- Etat laissé 'Off' puisque le volet a été manoeuvré manuellement.  
				Level = 'Off'
			end			
		
		elseif ((type(Level) == 'number') or (Level =='On'))
		---------------------------------------------------------------------------
		-- Consigne = <0..100> (plage horaire validée) ou 'On'.
		---------------------------------------------------------------------------
		then
			---------------------------------------------------------------------------
			-- Etat initial '--'. 
			---------------------------------------------------------------------------
			if (Last_Level == '--') 
			then
				-- 1er contrôle du volet : ouverture à la consigne.
				Dev_Set(Device,Level)
				
			---------------------------------------------------------------------------
			-- Etat enregistré <0..100> (plage horaire validée) ou 'On'.
			---------------------------------------------------------------------------
			else


				-- Vérification si le volet a été manoeuvré hors automation.
				if Level_Changed(Device,Device_Index) 
				then
					Log(Device .. " - Mode BioClim Off",4)
					Level = 'Off'
				else 
					if ((tonumber(Last_Level) ~= nil) and (tonumber(Last_Level) ~= Level))
					-- Envoi commande 'SetLevel' si état courant different de la consigne.
					then
						Log("##### " .. Device .. " ##### Cmd: Lvl - Last_Lvl: " .. Last_Level .. " Lvl: " .. Level,2)
						Dev_Set(Device,Level)
					end
				end	
			end
		end		
			
		---------------------------------------------------------------------------
		-- Enregistrement de la consigne dans la table d'états de sortie.
		---------------------------------------------------------------------------
		BioClim_Status_Out[Device_Index] = Level
	end
	--*************************************************************************		

	
	--***** DEBUT DE TRAITEMENT BIOCLIM ***************************************
	-----------------------------------------------------------------
	-- Initialisation de la variable BioClim.
	-----------------------------------------------------------------
	if (Var_Get_Data_By_Name(Var_BioClim) == nil)
	then
		-- Création de la variable d'état si 1er passage par l'automation en mode BioClim.
		for i = 1, BioClim_Config_Table_Size
		do
			table.insert(BioClim_Status_In, '--')
		end	
		Status_In = table.concat(BioClim_Status_In,',')
		Var_Set(Var_BioClim, Status_In)
		Log("Init variable '" .. Var_BioClim .. "' : '" .. Var_Get_Data_By_Name(Var_BioClim) .. "'" , 2)
	else
		-- Récupération dans la table 'BioClim_Status_In' des états pour chaque volet du groupe.
		Status_In = Var_Get_Data_By_Name(Var_BioClim)	
		BioClim_Status_In = Split_String(Status_In,",")
	end	
	
	--------------------------------------------------------------
	-- Parcours des éléments de la table BioClim.
	--		Device_Index = numéro du volet dans la table BioClim.
	--		BioClim_Parameters = Paramètres BioClim pour le volet.
	--------------------------------------------------------------
 	for Device_Index, BioClim_Parameters in ipairs(_G[BioClim_Config]) 
	do
		---------------------------------------------------------------------------
		-- Parcours des plages horaires pour chaque volet
		--		Device = nom du volet.
		--		BioClim_Data = table des plages horaires et consigne pour le volet.
		---------------------------------------------------------------------------
		for Device, BioClim_Data in pairs(BioClim_Parameters) 
		do
			-- Slots = nombre de plages horaires pour le volet 'Device'.
			local Slots = #BioClim_Data
			
			-----------------------------------------------
			-- Lecture des paramètres pour un volet : 
			-- 		Slot_Number = numéro de la plage horaire.
			--		Data[1]= Slot_Start_Time
			--		Data[2]= Slot_End_Time
			--		Data[3]= Level
			-----------------------------------------------
			for Slot_Number, Data in ipairs(BioClim_Data)
			do				
				Slot_Start_Time = Conv_Time_To_Minutes(Data[1])
				Slot_End_Time = Conv_Time_To_Minutes(Data[2])
				Level = Data[3]
				
				--------------------------------------------------------------------------------------
				-- Pas de contrôle du volet si heure courante avant le début de la 1ère plage horaire.
				--------------------------------------------------------------------------------------
				if (Slot_Number == 1 ) and (Time_Now < Slot_Start_Time)
				then
					BioClim_Status_Out[Device_Index] = '--'
					break
				end
				
				------------------------------------------------------------
				-- Ouverture à la consigne si on est dans une plage horaire.
				------------------------------------------------------------
				if (Time_Now >= Slot_Start_Time) and (Time_Now < Slot_End_Time)
				then
					if (Control_Temperature == true) and (Level ~= 100)
					then
						-- Correction de l'ouverture en fonction de la température extérieure, par 5%.
						local Level_Adjustment = math.floor((Ext_Temperature - TEMPERATURE_REFERENCE) / DELTA_TEMPERATURE) * 5

						-- Limite le niveau d'ouverture entre BIOCLIM_MIN_LEVEL% et 100%.
						New_Level = math.max(Level - Level_Adjustment, BIOCLIM_MIN_LEVEL)
						if (New_Level > 100)
						then
							New_Level = 100
						end						
						DLog(Device .. " - Tref°: " .. TEMPERATURE_REFERENCE .." T°: " .. Ext_Temperature.. " - Corr: " .. Level_Adjustment .. "%. Lvl: " .. Level .. " -> " .. New_Level, 2)
						Level = New_Level
					end
					Dev_Control(Device, Device_Index)
					break				
				end		

				--------------------------------------------------------------------
				-- Heure courante après l'heure de fin de la dernière plage horaire.
				--------------------------------------------------------------------
				if (Slot_Number == Slots) and (Time_Now >= Slot_End_Time)
				then
					Level = 'On'
					Dev_Control(Device, Device_Index)
					break					
				end
			end
		end
	end	

	Status_Out = table.concat(BioClim_Status_Out,',')
	DLog(BioClim_Config .. " - Status_In: " .. Status_In.. " Status_Out: " .. Status_Out, 2)
	Var_Set(Var_BioClim, Status_Out)		
end

--**************************************************
--
-- MAIN PROGRAM.
--
--**************************************************
commandArray = {}

	Check_LUA_Version()
	
	--***************************************************************************
	-- 1) TRAITEMENT POUR LE MODE JOUR/NUIT.
	--***************************************************************************
	if (Security == 'Off') and (Automation ~= 'Off') 
	then
		DLog("***** Start On_Off process.", 2)	
		-- Ajout d'un délai supplementaire à l'heure de fermeture pour le printemps et l'été.
		if (Season == 'Spring') or (Season == 'Summer')
		then
			Time_Night = Time_Night + TIME_NIGHT_SEASON_OFFSET
		end
		-- Traitement Jour/Nuit.
		for Device_List_OnOff, Controls_OnOff in pairs(Group_OnOff)
		do
			if (otherdevices[Controls_OnOff[1]] ~= MODE_MANUAL)
			then
				OnOff_Command_Scheduler(_G[Device_List_OnOff], Controls_OnOff[2])
			end
		end		
		DLog("***** End On_Off process.", 2)
	end

	--***************************************************************************
	-- 2) TRAITEMENT POUR LE MODE BIOCLIM.
	--***************************************************************************
	for BioClim_Device_List, BioClim_Control in pairs(Group_BioClim)
	do
		-- Construction du nom de la variable Domoticz pour les états de chaque groupe BioClim.
		Var_BioClim = 'Var_' .. BioClim_Device_List	
		
		--------------------------------------------------------------------
		-- Test des conditions d'execution.
		--------------------------------------------------------------------
		if (otherdevices[BioClim_Control] ~= MODE_BIOCLIM) -- Mode BioClim inactif
			or (Time_Now == 120)		-- ou 2AM
			or (Automation == 'Off')	-- ou mode Automation inactif
			or (Security ~= 'Off')		-- ou mode Sécurité actif
		then 
			-- Delete de la variable d'état si elle existe
			if (uservariables[Var_BioClim] ~= nil)
			then
				Var_Delete_By_Name(Var_BioClim)
			end

		elseif (time.min % BIOCLIM_MONITOR_TIME == 0) 			-- Validation exécution toutes les <BIOCLIM_MONITOR_TIME> minutes,
			and (Ext_Temperature >= TEMPERATURE_MINIMUM) 		-- et température extérieure supérieur au mini,
			and (Season == 'Spring' or Season == 'Summer') 		-- et saison ok.
			and (Time_Now > math.max(Time_Day + BIOCLIM_TIME_OFFSET, Time_Minimum)) and (Time_Now < (Time_Night - BIOCLIM_TIME_OFFSET))	-- Validation plage horaire BioClim.
		then
			Log("\n>> " .. BioClim_Device_List .. " - Start BioClim process.", 2)			
			-- Traitement BioClim.
			BioClim_Process(BioClim_Device_List)
			Log("<< " .. BioClim_Device_List .. " - End BioClim process.", 2)
		end
	end
	
return commandArray


