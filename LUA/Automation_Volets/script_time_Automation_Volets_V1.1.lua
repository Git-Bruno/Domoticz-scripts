--****************************************************************************
--                                                                           *
-- Automation des volets. Ouverture/Fermeture et mode BioClim.               *         
--                                                                           *
VERSION = '1.1' -- 12/2022                                                   *
--                                                                           *
--****************************************************************************

-- Nom du programme (logging).
progName 	= 'Automation Volets V' .. VERSION

debug_mode = false

--****************************************************************************
--                                                                           *
-- CHARGEMENT DES PACKAGES.                                                  *
--                                                                           *
--****************************************************************************
package.path = '/home/pi/domoticz/scripts/lua/functions.lua;' .. package.path 
require("functions.lua")
package.path = '/home/pi/domoticz/scripts/lua/Config_Automation_Volets_V1.1.lua;' .. package.path 
require("Config_Automation_Volets_V1.1.lua")

--****************************************************************************
--                                                                           *
-- CUSTO.                                                                    *
--                                                                           *
--****************************************************************************
-- Ecart en °C pour l'ajustement de l'ouverture en fonction de la température (au pas de 5%).
DELTA_TEMPERATURE 	    = 3
-- Delta entre position courante et consigne pour la reprise en mode 'BioClim' après manoeuvre manuelle d'un volet
MARGIN 				    = 15
-- Valeur par défaut du niveau de luminosité basse.
DEFAULT_LUX_LEVEL_LOW 	= 5
-- Valeur par défaut du niveau de luminosité haute
DEFAULT_LUX_LEVEL_HIGH 	= 50
-- Durée de la plage horaire pour l'ouverture/fermeture avancée en fonction de la luminosité
EARLY_ACTION_RANGE		= 30

--
-- Modification des commandes en fonction de la version de Domoticz
-- Domoticz 2022.1
local OnCmd			= 'On'
local OffCmd		= 'Off'
-- Domoticz 2022.2
if (Get_Domoticz_Version() == "2022.2")
then
    OnCmd   = 'Open'
    OffCmd	= 'Close'
end

-- Heure minimum pour l'ouverture des volets.
local Time_Minimum  = Conv_Time_To_Minutes(TIME_MINIMUM)
-- Heures de lever et coucher du soleil.
local Time_Day 		= math.max(timeofday['SunriseInMinutes'] + TIME_DAY_OFFSET, Time_Minimum)
local Time_Night 	= timeofday['SunsetInMinutes']

--****************************************************************************
--                                                                           *
-- FONCTIONS LOCALES.                                                        *
--                                                                           *
--****************************************************************************

------------------------------------------------------------------------------
--
--	Post un message dans la log si debug_mode=true. 
--
------------------------------------------------------------------------------
local function DLog(log, level, separator) 
	if (debug_mode == true)
	then
		Log(" § " .. log,level, separator) 
	end
end

--****************************************************************************
--                                                                           *
--	FONCTIONS POUR LE MODE 'JOUR/NUIT'.                                      *
--                                                                           *
--****************************************************************************

------------------------------------------------------------------------------
--
-- Envoi de la commande d'ouverture vers un device.
-- Pas d'ouverture avant Time_Minimum.
-- Ouverture à Time_Day ou si dans les 15mn avant si la luminosité est forte.
--
------------------------------------------------------------------------------
function Send_On_Command(Device)
	if (Time_Now < Time_Minimum)
	then
		return
	end
	if (Time_Now == Time_Day) or (Early_Open == true)
	then
		commandArray[#commandArray + 1] = {[Device] = OnCmd .. ' REPEAT 2 INTERVAL 5'}
		Log("Ouverture Automatique " .. Device)
	end
end

------------------------------------------------------------------------------------------
--
-- Envoi de la commande de fermeture complète ou à Off_Level vers un device.
--	Device: nom d'un volet ou d'un groupe de volets.
--  Off_Level: niveau de fermeture finale, pris en compte si Closing_Mode est On.
--
-- La fermeture est faite à Time_Night ou dans les 15mn avant si la luminosité est faible.
------------------------------------------------------------------------------------------
function Send_Off_Command(Device, Off_Level)
    if (Time_Now == Time_Night) or (Early_Close == true)
	then
        --
        -- Test si fermeture complète ou à Off_Level.
        --
        if (Closing_Mode == 'Off')
        then
            -- Fermeture complète.
            commandArray[#commandArray + 1] = {[Device] = OffCmd .. ' REPEAT 2 INTERVAL 5'}
            Log(Device .. " - Fermeture complète.")
        else
            -- Fermeture à Off_Level (pourcentage ou scène).
            if (type(Off_Level) == 'number')
            then
                commandArray[#commandArray + 1] = {[Device] = 'Set Level: ' .. Off_Level .. ' REPEAT 2 INTERVAL 5'}
                Log(Device .. " - Fermeture à " ..Off_Level .. "%.")
            elseif (type(Off_Level) == 'string')
            then
                commandArray[#commandArray + 1] = {['Scene:' .. Off_Level] = 'On'}
                Command_Scene_On_Sent = true
            end            
        end
	end
end

-----------------------------------------------------------------------------------
--
-- Appels aux differentes fonctions d'ouverture ou de fermeture pour chaque device. 
--
-----------------------------------------------------------------------------------
function Send_OnOff_Commands(Device, Off_Level)
    Exclude_OnOff = string.sub(Device, 1, 1)
    if (Exclude_OnOff == '+') or (Exclude_OnOff == '-')
    then 
        Device = string.sub(Device, 2)
    end
    --
    --  Envoi de la commande d'ouverture sauf si le device est exclu ('-').
    --
    if (Exclude_OnOff ~= '-')
    then
        Send_On_Command(Device)
    end
    --
    --  Envoi de la commande de fermeture sauf si le device est exclu ('+').
    --
    if (Exclude_OnOff ~= '+')
    then
        Send_Off_Command(Device, Off_Level)
    end
end

------------------------------------------------------------------------------
--
-- Envois des commandes d'ouverture/fermeture Jour/Nuit aux volets.
--  Arguments:
--	Device_List: Liste des volets ou nom d'un volet ou d'un groupe de volets.
--  Off_Level: Niveau de fermeture finale ou nom de scène.
--
------------------------------------------------------------------------------
function OnOff_Command_Scheduler(Device_List, Off_Level)
	if (type(_G[Device_List]) == 'table')
	then
        --
        --	 Envois des commandes vers la liste de volets contenus dans la table _G[Device_List].
        --
		for index, Device in pairs(_G[Device_List])
		do
            Send_OnOff_Commands(Device, Off_Level)
            if (Command_Scene_On_Sent == true)
            then
                -- Log et sortie de boucle si commande 'Scene On' envoyée au moins une fois.
                Log(Device_List .. " - Exécution de la scène '" .. Off_Level .. "'.") 
                Command_Scene_On_Sent = false
                break
            end
		end
	else
        --
        -- Envoi de la commande à un seul volet (ou à un groupe zigate).
        --
        Send_OnOff_Commands(_G[Device_List], Off_Level)
	end
end

--****************************************************************************
--                                                                           *
--	FONCTIONS POUR LE MODE 'BIOCLIM'.                                        *
--                                                                           *
--****************************************************************************

------------------------------------------------------------------------------
--
-- Process_BioClim(BioClim_Table)
--	Positionne les volets comme défini dans chaque plage horaire.
--	Voir contenu des variables BioClim_Volets_xxx.
-- 	Argument: nom du groupe BioClim défini dans Automation_Config.lua.
--
------------------------------------------------------------------------------
function Process_BioClim(BioClim_Table)

	local BioClim_Config_Table_Size = #BioClim_Table

	local Slot_Start_Time = 0
	local Slot_End_Time = 0
	
	local Level = 100
	
	local BioClim_Status_In = {}
	local BioClim_Status_Out = {}	
    local Tgt_Level = {}
	
    local Level_Adjustment = 0
    
	--***** DEBUT FONCTIONS LOCALES ********************************************
	----------------------------------------------------------------------------
    --
	-- Compare l'état courant avec l'état enregistré et retourne 'true' si le 
	-- volet a été manoeuvré hors automation à +/- MARGIN.
    --
	----------------------------------------------------------------------------
	local function Level_Changed(Device,Device_Index, Margin)
		local Margin
		local Current_Level = Dev_Get_Data(Device, 'Level')
		local Last_Level = BioClim_Status_In[Device_Index]
		
		if (Margin == nil)
		then
			Margin = MARGIN
		end
		
		if (Last_Level == 'Off')
		then
            -- Set Last_Level pour comparaison de Current_Level avec la consigne.
			Last_Level = Level
		end
		
		if (Last_Level == 'On')
		then 
            -- Conversion état 'On' en 100 pour test de manoeuvre si manoeuvre manuelle.
			Last_Level = 100
		end
			
		Delta_Level = math.abs(Current_Level - Last_Level)
		DLog(Device .. " - Cur_Lvl: " .. Current_Level .. "  Last_Lvl: " .. Last_Level .. "  Delta: " .. Delta_Level)
			
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

	----------------------------------------------------------------------------
    --
	-- Positionne le volet et met à jour la variable d'état.
    --
	----------------------------------------------------------------------------
	local function Dev_Control(Device, Device_Index)	
		local Last_Level = BioClim_Status_In[Device_Index]	
        
        if (Last_Level ~= 'Off') and New_Config_Selected 
        then
            Last_Level = "--"
        end
		
		if (Last_Level == 'Off') 
		-----------------------------------------------------------------------------
		-- Etat enregistré = 'Off'. Test pour reprise en mode 'BioClim', sinon 'Off'.
		-----------------------------------------------------------------------------
		then
			if (Level_Changed(Device,Device_Index) == false)
			then
				-- Reprise en mode BioClim car le volet est trouvé à la consigne à MARGIN près.
                commandArray[#commandArray + 1] = {[Device] = 'Set Level: ' .. Level .. ' REPEAT 2 INTERVAL 10'}
			else
				-- Etat laissé 'Off' puisque le volet a été manoeuvré manuellement.  
				Level = 'Off'
			end			
		
		elseif (type(Level) == 'number')
		---------------------------------------------------------------------------
		-- Consigne = <0..100> (plage horaire validée) ou 'On'.
		---------------------------------------------------------------------------
		then
			---------------------------------------------------------------------------
			-- Etat initial '--' ou si il y a eu un switch de config. 
			---------------------------------------------------------------------------
			-- Test si 1er contrôle du volet pour ouverture à la consigne.
			if (Last_Level == '--') 
			then
                commandArray[#commandArray + 1] = {[Device] = 'Set Level: ' .. Level .. ' REPEAT 2 INTERVAL 10'}
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
						
					if (tonumber(Last_Level) ~= nil) and (tonumber(Last_Level) ~= Level)
					then
                        -- Envoi commande 'SetLevel' si état courant différent de la consigne.
                        commandArray[#commandArray + 1] = {[Device] = 'Set Level: ' .. Level .. ' REPEAT 2 INTERVAL 10'}
					end					
				end	
			end
		end		
			
		---------------------------------------------------------------------------
		-- Enregistrement de la consigne dans la table d'états de sortie.
		---------------------------------------------------------------------------
		BioClim_Status_Out[Device_Index] = Level
	end
	--***** FIN FONCTIONS LOCALES **-******************************************

	
	--***** DEBUT DE TRAITEMENT BIOCLIM ***************************************
	----------------------------------------------------------------------------
	-- Initialisation de la variable BioClim.
	----------------------------------------------------------------------------
	if (Var_Get_Data_By_Name(Var_BioClim) == nil)
	then
        -- Création de la variable d'état si 1er passage par l'automation en mode BioClim.
		for i = 1, BioClim_Config_Table_Size
		do
			table.insert(BioClim_Status_In, '--')
		end	
		Status_In = table.concat(BioClim_Status_In,',')
		Var_Set(Var_BioClim, Status_In)
		DLog("Init variable '" .. Var_BioClim .. "' : '" .. Var_Get_Data_By_Name(Var_BioClim) .. "'")
	else
		-- Récupération dans la table 'BioClim_Status_In' des états pour chaque volet du groupe.
		Status_In = Var_Get_Data_By_Name(Var_BioClim)	
		BioClim_Status_In = Split_String(Status_In,",")
	end	
    
	----------------------------------------------------------------------------
	-- Parcours des éléments de la table BioClim.
	--		Device_Index = numéro du volet dans la table BioClim.
	--		BioClim_Parameters = Paramètres BioClim pour le volet.
	----------------------------------------------------------------------------
 	for Device_Index, BioClim_Parameters in ipairs(BioClim_Table) 
	do
		---------------------------------------------------------------------------
		-- Parcours des plages horaires pour chaque volet:
		--		Device = nom du volet.
		--		BioClim_Data = table des plages horaires et consigne pour le volet.
		---------------------------------------------------------------------------
		for Device, BioClim_Data in pairs(BioClim_Parameters) 
		do
			-- Slots = nombre de plages horaires pour le volet 'Device'.
			local Slots = #BioClim_Data
			
			-------------------------------------------------
			-- Lecture des paramètres pour un volet: 
			-- 		Slot_Number = numéro de la plage horaire.
			--		Data[1]= Slot_Start_Time
			--		Data[2]= Slot_End_Time
			--		Data[3]= Level
			-------------------------------------------------
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
					Tgt_Level[Device_Index] = '--'
					break
				end
				
				------------------------------------------------------------
				-- Ouverture à la consigne si on est dans une plage horaire.
				------------------------------------------------------------
				if (Time_Now >= Slot_Start_Time) and (Time_Now < Slot_End_Time)
				then
					Tgt_Level[Device_Index] = Level
					if (Control_Temperature == true) and (Level ~= 100)
					then
						-- Correction de l'ouverture en fonction de la température extérieure, par 5%.
						Level_Adjustment = math.floor((TEMPERATURE_REFERENCE - Ext_Temperature)  / DELTA_TEMPERATURE) * 5
						
						-- Limite le niveau d'ouverture entre BIOCLIM_MIN_LEVEL% et 100%.
						New_Level = math.floor(math.max(Level + Level_Adjustment, BIOCLIM_MIN_LEVEL))
						if (New_Level > 100)
						then
							New_Level = 100
						end						
						DLog(Device .. " - Tref°: " .. TEMPERATURE_REFERENCE .." T°: " .. Ext_Temperature.. " - Corr: " .. Level_Adjustment .. "%. Lvl: " .. Level .. " -> " .. New_Level)
						Level = New_Level
					end
					Dev_Control(Device, Device_Index)
					break				
				end		

				--------------------------------------------------------------------------------------------
				-- Heure courante avant le début de la plage horaire suivante (plages horaire non contigue).
				--------------------------------------------------------------------------------------------
				-- print("***************** Slot_Number=" .. Slot_Number)
				-- if (Slot_Number ~= Slots)
				-- then
					-- Slot_Start_Time_Plage_Suivante = BioClim_Data[Slot_Number+1][1]
					-- print("***************** Début plage +1 = " ..  Slot_Start_Time_Plage_Suivante)
					-- if (Slot_Start_Time_Plage_Suivante ~= nil) and (Time_Now > Slot_End_Time) and (Time_Now < Conv_Time_To_Minutes(Slot_Start_Time_Plage_Suivante))
					-- then
						-- print("Device '" .. Device .. "' PLAGE NON CONTIGUE")
						-- Level = 100
					-- end
					-- print("Device '" .. Device .. "' Level= " .. Level)
				-- end
				
				--------------------------------------------------------------------
				-- Heure courante après l'heure de fin de la dernière plage horaire.
				--------------------------------------------------------------------
				if (Slot_Number == Slots) and (Time_Now >= Slot_End_Time)
				then
					-- Level = 'On'
					Level = 100
					Tgt_Level[Device_Index] = '100'
					Dev_Control(Device, Device_Index)
					break					
				end
			end
		end
	end	
    
	Status_Out = table.concat(BioClim_Status_Out,',')
    Level_In = table.concat(Tgt_Level,',')
	-- Print_r(BioClim_Table)
	Log(string.sub(Var_BioClim,5) .. " T:" .. Ext_Temperature .. "°. Adj:" .. Level_Adjustment .. "% - " .. Level_In .. " -> " .. Status_Out ..".")
	Var_Set(Var_BioClim, Status_Out)
		
end

------------------------------------------------------------------------------
--
-- Exec_BioClim(BioClim_Table)
--	Sélectionne la table BioClim dans la table BioClim_Table.
-- 	Argument : Table des définitons BioClim pour un groupe de volets. 
--          Cette table peut avoir 1 ou 2 entrées.
--
------------------------------------------------------------------------------
function Exec_BioClim(BioClim_Table)
	Log(BioClim_Table .." - BioClim mode: " .. Bioclim_Mode .. " - Cfg: " ..  BioClim_Config_Idx)    
    ------------------------------------------------------------------------------------
	-- Parcours des éléments de la table de la configuration BioClim_Table.
	--		Config_Index = Index de la table de configuration dans BioClim_Table.
	--		Config_BioClim = Table de configuration Bioclim.
	------------------------------------------------------------------------------------
    for Config_Index, Config_BioClim in pairs(_G[BioClim_Table])
    do
        -- Validation de l'index de la configuration BioClim.
        Size_Config_BioClim = #Config_BioClim
        BioClim_Config_Idx = math.min(Size_Config_BioClim, BioClim_Config_Idx)    
        if (Config_Index == BioClim_Config_Idx)
        then
            -- Traitement de la configuration BioClim après validation de l'index.
            Process_BioClim(Config_BioClim)
        end
    end
end

--****************************************************************************
--                                                                           *
-- MAIN PROGRAM.                                                             *
--                                                                           *
--****************************************************************************

commandArray = {}

	Check_LUA_Version(LUA_VERSION)
     
    ------------------------------------------------------------------------------
    -- VALIDATION DES CAPTEURS OPTIONNELS.
    ------------------------------------------------------------------------------
    --
    -- Validation du capteur de température extérieure.
    --
    if (SENSOR_TEMPERATURE ~= nil) then Ext_Temperature = otherdevices_temperature[SENSOR_TEMPERATURE] end
    if (SENSOR_TEMPERATURE == nil) or (Ext_Temperature == nil) or (Ext_Temperature > 60) or (Ext_Temperature < TEMPERATURE_REFERENCE)
    then
        Ext_Temperature = TEMPERATURE_MINIMUM
        Control_Temperature = false
    else
        Ext_Temperature = Round(tonumber(Ext_Temperature),1)
        Control_Temperature = true
    end
    --
    -- Validation du capteur de luminosité.
    --
    if (LUX_LEVEL_LOW == nil) then LUX_LEVEL_LOW = DEFAULT_LUX_LEVEL_LOW end
    if (LUX_LEVEL_HIGH == nil) then LUX_LEVEL_HIGH = DEFAULT_LUX_LEVEL_HIGH end
    if (SENSOR_LUX ~= nil)
    then
        Ext_Lux = tonumber(otherdevices[SENSOR_LUX])
        if (Ext_Lux ~= nil)
        then   
            -- Test pour la fermeture avancée.
            if (Time_Now > Time_Night - EARLY_ACTION_RANGE) and (Time_Now < Time_Night) and (Ext_Lux < LUX_LEVEL_LOW)
            then Early_Close = true else Early_Close = false end
            -- Test pour l'ouverture avancée.
            if (Time_Now > Time_Day - EARLY_ACTION_RANGE) and (Time_Now < Time_Day) and (Ext_Lux > LUX_LEVEL_HIGH) 
            then Early_Open = true else Early_Open = false end
        end
    end
     
    
    ------------------------------------------------------------------------------
    --
    -- VALIDATION DES SWITCHES OPTIONNELS.
    --
    ------------------------------------------------------------------------------
    --
    -- Validation du switch d'automation.
    --  Automation = 'On' si le switch n'existe pas.
    --
    if (SWITCH_AUTOMATION ~= nil) then Automation = otherdevices[SWITCH_AUTOMATION] end
    if (Automation == nil) then	Automation = 'On' end
    --
    -- Validation du switch SWITCH_SECURITY.
    --  Security = 'Off' si le switch n'existe pas.
    --
    if (SWITCH_SECURITY ~= nil) then Security = otherdevices[SWITCH_SECURITY] end
    if (Security == nil) then Security = 'Off' end
    --
    -- Validation du switch CLOSING_MODE.
    --  Closing_Mode = 'Off' si le switch n'existe pas.
    --
    if (CLOSING_MODE ~= nil) then Closing_Mode = otherdevices[CLOSING_MODE] end
    if (Closing_Mode == nil) then Closing_Mode = 'Off' end
    
    --
    -- Validation du switch BIOCLIM_MODE et sélection de la table Bioclim #1 ou #2.
    --  Bioclim_Mode = 'Auto' si le switch n'existe pas.
    --
    if (BIOCLIM_MODE ~= nil) then Bioclim_Mode = otherdevices[BIOCLIM_MODE] end
    if (Bioclim_Mode == nil) or (Bioclim_Mode == BIOCLIM_AUTO)
    then
        -- Mode Auto : Sélection de la table BioClim à utiliser en fonction de la température.
        Bioclim_Mode = 'Auto'
        if (Ext_Temperature < TEMPERATURE_BIOCLIM_CONFIG) then BioClim_Config_Idx = 1 else BioClim_Config_Idx = 2 end
    elseif (Bioclim_Mode == BIOCLIM_1)
    then 
        -- Selection de la table BioClim à utiliser en fonction
        BioClim_Config_Idx = 1 else BioClim_Config_Idx = 2 
    end 
    --
    -- Validation de la saison pour le mode BioClim.
    --
    if (BIOCLIM_SEASONS == nil)
    then
        BioClim_Season = true
    else
        for _, Season in pairs(BIOCLIM_SEASONS)
        do
            if Season == WhichSeason()
            then
                BioClim_Season = true
                break
            else
                BioClim_Season = false     
            end        
        end
    end

      
	------------------------------------------------------------------------------
    --
	-- TRAITEMENT POUR LE MODE JOUR/NUIT.
    --
	------------------------------------------------------------------------------
	if (Automation ~= 'Off')    -- mode Automation actif
		and (Security == 'Off') -- mode Sécurité inactif
	then
		DLog("\n***** Start On_Off process.")	
		if (BioClim_Season == true)
		then 
            -- Ajout d'un délai supplémentaire à l'heure de fermeture pour le printemps et l'été.
			Time_Night = Time_Night + TIME_NIGHT_SEASON_OFFSET
		end
        --
        -- Delete de la variable DZ Var_Early_Action utilisée pour l'ouverture/fermeture prématurée.
        --
        if (Time_Now == Time_Day + 1) or (Time_Now == Time_Night + 1)
        then
            DLog("Delete Var_Early_Action")
			Var_Delete_By_Name("Var_Early_Action")
        end   
        --
        -- Sortie si il y a eu ouverture/fermeture avancée.
        --
        Early_Action = Var_Get_Data_By_Name("Var_Early_Action")
        if  (Early_Action ~= nil)
        then
            return
        end
        -----------------------------------------------------------------------------------------
        -- Traitement On/Off pour tous les devices.
        --  Device_List_OnOff: Index de la table 'Group_OnOff'. 
        --      String, nom du groupe d'unité. Liste des volets ou des groupes de volets à gérer.
        --  Controls_OnOff: Selector switch pour le groupe
        --      [1]: Mode
        --      [2]: % fermeture ou scène.
        -----------------------------------------------------------------------------------------
        --
        -- Parcours de la table 'Group_OnOff'.
        --
		for Device_List_OnOff, Controls_OnOff in pairs(Group_OnOff)
		do
			if (otherdevices[Controls_OnOff[1]] == MODE_ONOFF) or (otherdevices[Controls_OnOff[1]] == MODE_AUTO)
			then
                -- Traitement Jour/Nuit.
				OnOff_Command_Scheduler(Device_List_OnOff, Controls_OnOff[2])
			end
		end   
        --
        -- Set de la variable Var_Early_Action.
        --
        if (Early_Open == true) and (Time_Now > Time_Minimum)
        then
            Log("Ouverture avec " .. (Time_Day - Time_Now) .. "mn d'avance.\nHeure normale: " .. Convert_Minutes_To_HHMM(Time_Day))
            -- Set de la variable indiquant une ouverture/fermeture déjà faite.
            Var_Set("Var_Early_Action", 1, 1)
			DLog("Early_Open - Variable Var_Early_Action set")
        end
        if (Early_Close == true) and (Time_Now < Time_Night)
        then
            Log("Fermeture avec " .. (Time_Night - Time_Now) .. "mn d'avance.\nHeure normale: " .. Convert_Minutes_To_HHMM(Time_Night))
            -- Set de la variable indiquant une ouverture/fermeture déjà faite.
            Var_Set("Var_Early_Action", 1, 1)
			DLog("Early_Close - Variable Var_Early_Action set")
        end
		DLog("***** End On_Off process.")
	end

	------------------------------------------------------------------------------
    --
	-- TRAITEMENT POUR LE MODE BIOCLIM.
    --
	------------------------------------------------------------------------------  
    ----------------------------------------------------------------------
    -- Séléction de la table BioClim en fonction de la température.
    ----------------------------------------------------------------------

    if (Var_Get_Data_By_Name('Var_BioClim_Cfg') == nil)
    then 
        -- Init variable 'Var_BioClim_Cfg'
        Var_Set('Var_BioClim_Cfg', BioClim_Config_Idx, 0)
    else
        ------------------------------------------------------------------------
        -- Validation de la table de configuration. 
        -- Evite le yoyo quand Temp fluctue autour de TEMPERATURE_BIOCLIM_CONFIG.
        ------------------------------------------------------------------------
        Var_BioClim_Cfg, _, Var_BioClim_Cfg_LastUpdate  = Var_Get_Data_By_Name('Var_BioClim_Cfg')
        Var_BioClim_Cfg = tonumber(Var_BioClim_Cfg)
        Time_Diff = Time_Diff(Var_BioClim_Cfg_LastUpdate)      
        if (BioClim_Config_Idx == Var_BioClim_Cfg)
        then 
            Var_Set('Var_BioClim_Cfg', Var_BioClim_Cfg,0)
        else 
            if  (Time_Diff < -190) 
            then
                -- Utilisation du nouveau BioClim_Config_Idx si observé pendant plus de 4mn.
                Var_BioClim_Cfg = BioClim_Config_Idx
                New_Config_Selected = true
                Var_Set('Var_BioClim_Cfg', BioClim_Config_Idx,0)
            else
                -- Selection de la même table de configuration si l'update de 'Var_BioClim_Cfg' date de moins de 4mn.
                BioClim_Config_Idx = Var_BioClim_Cfg
                New_Config_Selected = false
            end        
        end 
    end
    
    if New_Config_Selected 
    then 
        Log("Activation configuration BioClim '" .. BioClim_Config_Idx .. "'", 4) 
    end
      
    --------------------------------------------------------------
    -- Traitement des tables BioClim décrites dans Groups_BioClim.
    --------------------------------------------------------------
	for BioClim_Device_List, BioClim_Control in pairs(Groups_BioClim)
	do    
		-- Construction du nom de la variable Domoticz pour les états de chaque groupe BioClim.
		Var_BioClim = 'Var_' .. BioClim_Device_List	
		--
		-- Test des conditions de NON exécution du mode BioClim.
		--
        DLog("BioClim_Control: " .. BioClim_Control .. " " .. otherdevices[BioClim_Control])
		if (otherdevices[BioClim_Control] == MODE_MANUAL)       -- mode Manuel,
            or (otherdevices[BioClim_Control] == MODE_ONOFF)    -- ou mode Jour/Nuit,
			or (Time_Now == 120)		-- ou 2AM
			or (Automation == 'Off')	-- ou mode Automation inactif
			or (Security ~= 'Off')	    -- ou mode Sécurité actif
		then 
			if (uservariables[Var_BioClim] ~= nil)
			then
                -- Delete de la variable d'état si elle existe.
				Var_Delete_By_Name(Var_BioClim)
			end
        --
        -- Test des conditions d'exécution du mode BioClim.
        --
		elseif (time.min % BIOCLIM_MONITOR_TIME == 0) 			-- Validation exécution toutes les <BIOCLIM_MONITOR_TIME> minutes,
			and (Ext_Temperature >= TEMPERATURE_MINIMUM) 		-- et température extérieure supérieur au mini,
			and (Time_Now > math.max(Time_Day + BIOCLIM_TIME_OFFSET, Time_Minimum)) and (Time_Now < (Time_Night - BIOCLIM_TIME_OFFSET))	-- Validation plage horaire BioClim.
			and (BioClim_Season == true) 		-- et saison ok.
		then
            -- Traitement BioClim.
            DLog("\n***** Start BioClim process.")	
			Exec_BioClim(BioClim_Device_List)
			DLog("<< " .. BioClim_Device_List .. " - End BioClim process.")
		end
        New_Config_Selected = false
	end
	
return commandArray


