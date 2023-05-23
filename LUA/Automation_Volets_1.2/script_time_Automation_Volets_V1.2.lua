--****************************************************************************
--                                                                           *
-- AUTOMATION DES VOLETS. OUVERTURE/FERMETURE ET MODE BIOCLIM.               *         
--                                                                           *
--****************************************************************************
VERSION = "1.2"

-- Nom du programme (logging).
progName    = "Automation Volets V" .. VERSION

debug_mode = false

--****************************************************************************
--                                                                           *
-- CHARGEMENT DES PACKAGES.                                                  *
--                                                                           *
--****************************************************************************
package.path = '/home/pi/domoticz/scripts/lua/functions.lua;' .. package.path 
require("functions.lua")
package.path = "/home/pi/domoticz/scripts/lua/Config_Automation_Volets_V" .. VERSION .. ".lua;" .. package.path 
require("Config_Automation_Volets_V" .. VERSION .. ".lua")

--****************************************************************************
--                                                                           *
-- CUSTO.                                                                    *
--                                                                           *
--****************************************************************************
-- Ecart en °C pour l'ajustement de l'ouverture en fonction de la température (au pas de 5%).
DELTA_TEMPERATURE       = 3
-- Delta entre position courante et consigne pour la reprise en mode 'BioClim' après manoeuvre manuelle d'un volet
MARGIN                  = 15
-- Valeur par défaut du niveau de luminosité basse.
DEFAULT_LUX_LEVEL_LOW   = 5
-- Valeur par défaut du niveau de luminosité haute
DEFAULT_LUX_LEVEL_HIGH  = 50

--
-- Modification des commandes en fonction de la version de Domoticz
-- Domoticz 2023.1
local OnCmd         = 'On'
local OffCmd        = 'Off'
-- Domoticz 2022.2
-- if (Get_Domoticz_Version() == "2022.2")
-- then
    -- OnCmd   = 'Open'
    -- OffCmd   = 'Close'
-- end

-- Heures d'ouverture et de fermeture automatique des volets.
local Time_Minimum  = Conv_Time_To_Minutes(TIME_MINIMUM)
local Time_Day      = math.max(timeofday['SunriseInMinutes'] + TIME_DAY_OFFSET, Time_Minimum)
local Time_Night    = timeofday['SunsetInMinutes'] + TIME_NIGHT_OFFSET 

--****************************************************************************
--                                                                           *
-- FONCTIONS LOCALES.                                                        *
--                                                                           *
--****************************************************************************

------------------------------------------------------------------------------
--
--  Post un message dans la log si debug_mode=true. 
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
--  FONCTIONS POUR LE MODE 'JOUR/NUIT'.                                      *
--                                                                           *
--****************************************************************************

--------------------------------------------------------------------------------
--
-- Envoi de la commande d'ouverture vers un device.
-- Pas d'ouverture avant Time_Minimum.
-- Ouverture à Time_Day ou si Early_Open car le seuil de luminosité est atteint.
--
--------------------------------------------------------------------------------
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
--  Device: nom d'un volet ou d'un groupe de volets.
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
    --
    --  Suppression du 1er caractère si '+' ou '-'
    --
    if (Exclude_OnOff == '+') or (Exclude_OnOff == '-')
    then 
        Device = string.sub(Device, 2)
    end
    --
    --  Traitement pour ouverture des volets sauf si le device est exclu ('-').
    --
    if (Exclude_OnOff ~= '-')
    then
        Send_On_Command(Device)
    end
    --
    --  Traitement pour la fermeture sauf si le device est exclu ('+').
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
--  Device_List: Liste des volets ou nom d'un volet ou d'un groupe de volets.
--  Off_Level: Niveau de fermeture finale ou nom de scène.
--
------------------------------------------------------------------------------
function OnOff_Command_Scheduler(Device_List, Off_Level)
    if (type(_G[Device_List]) == 'table')
    then
        --
        -- Envois des commandes On/Off vers la liste de volets contenus dans la table _G[Device_List].
        --  Device_List: Liste des voltes décrites dans un groupe ON/OFF.
        --  Device: Volets à traiter.
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
        -- Envoi de la commande On/Off à un seul volet (ou à un groupe zigate).
        --
        Send_OnOff_Commands(_G[Device_List], Off_Level)
    end
    -- LogVariables(_G,0,'')
end

--****************************************************************************
--                                                                           *
--  FONCTIONS POUR LE MODE 'BIOCLIM'.                                        *
--                                                                           *
--****************************************************************************

------------------------------------------------------------------------------
--
-- Process_BioClim(BioClim_Table)
--  Positionne les volets comme défini dans chaque plage horaire.
--  Voir contenu des variables BioClim_Volets_xxx.
--  Argument: nom du groupe BioClim défini dans Config_Automation_Volets_..lua.
--
------------------------------------------------------------------------------
function Process_BioClim(BioClim_Table)
    local BioClim_Config_Table_Size = #BioClim_Table

    local Slot_Start_Time = 0
    local Slot_End_Time = 0
    
    local Level = 100
    
    local BioClim_Levels_Tgt = {}
    local BioClim_Levels_Out = {}   
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
        local Last_Level = BioClim_Levels_Tgt[Device_Index]
        
        if (Margin == nil)
        then
            -- Init de la variable Margin.
            Margin = MARGIN
        end
        
        if (Last_Level == 'Off')
        then
            -- Set Last_Level pour comparaison de Current_Level avec la consigne.
            Last_Level = Level
        end
        
        -- Conversion état 'On' en 100, pour le test si manoeuvre manuelle.
        if (Last_Level == 'On')
        then 
            Last_Level = 100
        end
        -- Calcul de la difference entre l'état actuel et la consigne.   
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
        local Last_Level = BioClim_Levels_Tgt[Device_Index]  
        
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
                -- Test si le volet a été manoeuvré hors automation.
                if Level_Changed(Device,Device_Index) and (Level ~= 100)
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
        BioClim_Levels_Out[Device_Index] = Level
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
            table.insert(BioClim_Levels_Tgt, '--')
        end 
        Levels_In = table.concat(BioClim_Levels_Tgt,',')
        Var_Set(Var_BioClim, Levels_In)
        DLog("Init variable '" .. Var_BioClim .. "' : '" .. Var_Get_Data_By_Name(Var_BioClim) .. "'")
    else
        -- Récupération dans la table 'BioClim_Levels_Tgt' des états pour chaque volet du groupe.
        Levels_In = Var_Get_Data_By_Name(Var_BioClim)   
        BioClim_Levels_Tgt = Split_String(Levels_In,",")
    end 
    
    ----------------------------------------------------------------------------
    -- Parcours des éléments d'une table BioClim.
    --      Device_Index = numéro du volet dans la table BioClim.
    --      BioClim_Parameters = Paramètres BioClim pour le volet.
    ----------------------------------------------------------------------------
    for Device_Index, BioClim_Parameters in ipairs(BioClim_Table) 
    do
        --------------------------------------------------------------------------------
        -- Parcours des plages horaires pour chaque volet décrit dans une table BioClim:
        --      Device = Nom du volet.
        --      BioClim_Data = Table des plages horaires et consigne pour le volet.
        --------------------------------------------------------------------------------
        for Device, BioClim_Data in pairs(BioClim_Parameters) 
        do
            -- Slots = nombre de plages horaires pour le volet 'Device'.
            local Slots = #BioClim_Data            
            -------------------------------------------------
            -- Lecture des paramètres pour un volet: 
            --      Slot_Number = numéro de la plage horaire.
            --      Data[1]= Slot_Start_Time
            --      Data[2]= Slot_End_Time
            --      Data[3]= Level
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
                    BioClim_Levels_Out[Device_Index] = '--'
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
                        Level_Adjustment = math.floor((BIOCLIM_ADJUSTMENT_TEMP - Ext_Temperature)  / DELTA_TEMPERATURE) * 5
                        -- Limite le niveau d'ouverture entre BIOCLIM_MIN_LEVEL% et 100%.
                        New_Level = math.floor(math.max(Level + Level_Adjustment, BIOCLIM_MIN_LEVEL))
                        if (New_Level > 100)
                        then
                            New_Level = 100
                        end                     
                        DLog(Device .. " - Tref°: " .. BIOCLIM_ADJUSTMENT_TEMP .." T°: " .. Ext_Temperature.. " - Adj: " .. Level_Adjustment .. "%. Lvl: " .. Level .. " -> " .. New_Level)
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
    
    Levels_Out = table.concat(BioClim_Levels_Out,',')
    Levels_Tgt = table.concat(Tgt_Level,',')
    -- Print_r(BioClim_Table)
    Var_Set(Var_BioClim, Levels_Out)
    
    -- if (Levels_Out ~= Levels_Tgt)
    if (Levels_Out ~= Levels_In)
    then
        Log(string.sub(Var_BioClim,5) .. " - T°: ".. Ext_Temperature .. "° - Correction:" .. Level_Adjustment .. "% - " .. Levels_Tgt .. " -> " .. Levels_Out ..".")
    end
end

------------------------------------------------------------------------------
--
-- Exec_BioClim(BioClim_Table)
--  Sélectionne la table BioClim dans la table BioClim_Table.
--  Argument : Table des définitons BioClim pour un groupe de volets. 
--          Cette table peut avoir 1 ou 2 entrées.
--
------------------------------------------------------------------------------
function Exec_BioClim(BioClim_Table)
    DLog(BioClim_Table .." - BioClim mode: " .. Bioclim_Mode .. " - Cfg: " ..  BioClim_Config_Idx)    
    ------------------------------------------------------------------------------------
    -- Parcours des éléments de la table de la configuration BioClim_Table.
    --      Config_Index = Index de la table de configuration dans BioClim_Table.
    --      Config_BioClim = Table de configuration Bioclim.
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
    --
    -- VALIDATION DES CAPTEURS OPTIONNELS.
    --
    ------------------------------------------------------------------------------
    --
    -- Validation du capteur de température extérieured et l'ouverture en fonction de la température extérieure.
    --
    if (SENSOR_TEMPERATURE ~= nil) then Ext_Temperature = otherdevices_temperature[SENSOR_TEMPERATURE] end
    -- if (SENSOR_TEMPERATURE == nil) or (Ext_Temperature == nil) or (Ext_Temperature > 60)
    if (Ext_Temperature == nil) or (Ext_Temperature > 60) or (Ext_Temperature < BIOCLIM_ADJUSTMENT_TEMP)
    then
        -- Ext_Temperature = BIOCLIM_MINIMUM_TEMP
        Control_Temperature = false
    else
        Control_Temperature = true
    end
    Ext_Temperature = Round(tonumber(Ext_Temperature),1)
    
    --
    -- Validation du capteur de luminosité.
    --
    if (LUX_LEVEL_LOW == nil) then LUX_LEVEL_LOW = DEFAULT_LUX_LEVEL_LOW end
    if (LUX_LEVEL_HIGH == nil) then LUX_LEVEL_HIGH = DEFAULT_LUX_LEVEL_HIGH end
    if (SENSOR_LUX ~= nil)
    then
        Ext_Lux = tonumber(otherdevices[SENSOR_LUX])
        --
        -- Set des variables pour l'ouverture ou la fermeture avancée.
        --
        Early_Open  = false
        Early_Close = false 
        --
        -- Traitement si donnée du capteur de luminosité.
        --
        if (Ext_Lux ~= nil)
        then   
            --
            -- Test pour l'ouverture avancée.
            --
            if (Time_Now > Time_Day - EARLY_ACTION_RANGE) and (Time_Now < Time_Day) and (Ext_Lux >= LUX_LEVEL_HIGH) 
            then 
                Early_Open = true
            end
            --
            -- Test pour la fermeture avancée.
            --
            if (Time_Now > Time_Night - EARLY_ACTION_RANGE) and (Time_Now < Time_Night) and (Ext_Lux <= LUX_LEVEL_LOW)
            then 
                Early_Close = true 
            end
            --
            -- Delete en fonction de l'heure de la variable utilisées pour l'ouverture avancée.
            --
            if (Var_Get_Data_By_Name("Var_Early_Open") ~= nil) and ((Time_Now < Time_Day - EARLY_ACTION_RANGE) or (Time_Now > Time_Day))
            then
                Var_Delete_By_Name("Var_Early_Open")                
            end
            --
            -- Delete en fonction de l'heure de la variable utilisées pour la fermeture avancée.
            --
            if (Var_Get_Data_By_Name("Var_Early_Close") ~= nil) and
                ((Time_Now < Time_Night - TIME_NIGHT_OFFSET - EARLY_ACTION_RANGE) or (Time_Now > Time_Night + TIME_NIGHT_SEASON_OFFSET))
            then 
                Var_Delete_By_Name("Var_Early_Close")                
            end
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
    if (SW_AUTOMATION ~= nil) then Automation = otherdevices[SW_AUTOMATION] end
    if (Automation == nil) then Automation = 'On' end
    --
    -- Validation du switch SWITCH_SECURITY.
    --  Security = 'Off' si le switch n'existe pas.
    --
    if (SWITCH_SECURITY ~= nil) then Security = otherdevices[SWITCH_SECURITY] end
    if (Security == nil) then Security = 'Off' end
    --
    -- Validation du switch SW_CLOSING_MODE.
    --  Closing_Mode = 'Off' si le switch n'existe pas.
    --
    if (SW_CLOSING_MODE ~= nil) then Closing_Mode = otherdevices[SW_CLOSING_MODE] end
    if (Closing_Mode == nil) then Closing_Mode = 'Off' end
    
    --
    -- Validation du switch SW_BIOCLIM_MODE et sélection de la table Bioclim #1 ou #2.
    --  Bioclim_Mode = 'Auto' si le switch n'existe pas.
    --
    if (SW_BIOCLIM_MODE ~= nil) 
    then
        Bioclim_Mode = otherdevices[SW_BIOCLIM_MODE] 
    end
    if (Bioclim_Mode == nil) or (Bioclim_Mode == BIOCLIM_AUTO)
    then
        -- Mode Auto : Sélection de la table BioClim à utiliser en fonction de la température.
        Bioclim_Mode = 'Auto'
        if (Ext_Temperature < BIOCLIM_TABLE_SELECT_TEMP) then BioClim_Config_Idx = 1 else BioClim_Config_Idx = 2 end
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
                -- Ajout d'un délai à l'heure de fermeture pour les saisons définies dans BIOCLIM_SEASONS{}.
                BioClim_Season = true     
                Time_Night = Time_Night + TIME_NIGHT_SEASON_OFFSET
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
        --
        -- Sortie si il y a eu ouverture/fermeture avancée.
        --
        if  (Var_Get_Data_By_Name("Var_Early_Open") ~= nil) or (Var_Get_Data_By_Name("Var_Early_Close") ~= nil) 
        then
            return commandArray
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
        -- Parcours de la table 'Group_OnOff' pour l'ouverture ou la fermeture des volets.
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
        -- Set des variables Var_Early_Open & Var_Early_Close.
        --
        if (Early_Open == true) and (Time_Now > Time_Minimum)
        then
            -- Set de la variable indiquant que l'ouverture avancée est faite.
            Log("Ouverture avec " .. (Time_Day - Time_Now) .. "mn d'avance.\nHeure normale: " .. Convert_Minutes_To_HHMM(Time_Day))
            Var_Set("Var_Early_Open", 1, 0)
            DLog("Early_Open - Variable Var_Early_Open set")
        end
        if (Early_Close == true) and (Time_Now < Time_Night)
        then
            -- Set de la variable indiquant que la fermeture avancée est faite.
            Log("Fermeture avec " .. (Time_Night - Time_Now) .. "mn d'avance.\nHeure normale: " .. Convert_Minutes_To_HHMM(Time_Night))
            Var_Set("Var_Early_Close", 1, 0)
            Log("Early_Close - Variable Var_Early_Close set")
        end
    end

    ------------------------------------------------------------------------------
    --
    -- TRAITEMENT POUR LE MODE BIOCLIM.
    --
    ------------------------------------------------------------------------------  
    ----------------------------------------------------------------------
    -- Sélection de la table BioClim en fonction de la température.
    ----------------------------------------------------------------------

    if (Var_Get_Data_By_Name('Var_BioClim_Cfg') == nil)
    then 
        -- Init variable 'Var_BioClim_Cfg'
        Var_Set('Var_BioClim_Cfg', BioClim_Config_Idx, 0)
    else
        ------------------------------------------------------------------------
        -- Validation de la table de configuration. 
        -- Evite le yoyo quand Temp fluctue autour de BIOCLIM_TABLE_SELECT_TEMP.
        ------------------------------------------------------------------------
        Var_BioClim_Cfg, _, Var_BioClim_Cfg_LastUpdate  = Var_Get_Data_By_Name('Var_BioClim_Cfg')
        Var_BioClim_Cfg = tonumber(Var_BioClim_Cfg)
        Time_Difference = Time_Diff(Var_BioClim_Cfg_LastUpdate)      
        if (BioClim_Config_Idx == Var_BioClim_Cfg)
        then 
            Var_Set('Var_BioClim_Cfg', Var_BioClim_Cfg,0)
        else 
            if  (Time_Difference < -240) 
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
      
    -------------------------------------------------------------------
    -- Traitement des tables BioClim décrites dans Groups_BioClim.
    --  Groups_BioClim: Liste des groupe BioClim, voir fichier config.
    --  BioClim_Devices: Noms des groupes BioClim, voir fichier config.
    --  BioClim_Control: Etat du Selector switches pour chaque groupe.
    -------------------------------------------------------------------
    for BioClim_Devices, BioClim_Control in pairs(Groups_BioClim)
    do    
       
       DLog("Ext_Temperature: " .. Ext_Temperature .. " BIOCLIM_MINIMUM_TEMP: " .. BIOCLIM_MINIMUM_TEMP .. " BioClim_Season: " .. bool(BioClim_Season))
       
        --
        -- Construction du nom de la variable Domoticz pour les états de chaque groupe BioClim.
        --
        Var_BioClim = 'Var_' .. BioClim_Devices 
        --
        -- Test des conditions de NON exécution du mode BioClim.
        --
        DLog("BioClim_Control: " .. BioClim_Control .. " " .. otherdevices[BioClim_Control] .. " Automation: " .. Automation .. " Security:" .. Security)
        --
        -- Delete de la variable BioClim selon certaines conditions.
        --        
        if (otherdevices[BioClim_Control] == MODE_MANUAL)       -- mode Manuel,
            or (otherdevices[BioClim_Control] == MODE_ONOFF)    -- ou mode Jour/Nuit,
            or (Time_Now == 120)        -- ou 2AM
            or (Automation == 'Off')    -- ou mode Automation inactif
            or (Security ~= 'Off')      -- ou mode Sécurité actif
        then
            -- Pas de traitement BioClim.
            DLog("Pas de traitement BioClim pour '" .. BioClim_Control .. "'." )
            if (uservariables[Var_BioClim] ~= nil)
            then
                -- Delete de la variable d'état si elle existe.
                Var_Delete_By_Name(Var_BioClim)
            end
        --
        -- Test des conditions d'exécution du mode BioClim.
        --
        elseif (time.min % BIOCLIM_MONITOR_TIME == 0)           -- Validation exécution toutes les <BIOCLIM_MONITOR_TIME> minutes,
            and (Ext_Temperature > BIOCLIM_MINIMUM_TEMP)        -- et température extérieure supérieure au mini,
            and (Time_Now > math.max(Time_Day + BIOCLIM_TIME_OFFSET, Time_Minimum)) -- Validation si Time_Day corrigé > Time_Minimum,
            and (Time_Now < (Time_Night - BIOCLIM_TIME_OFFSET)) -- Validation si heure < Time_Night corrigé,
            and (BioClim_Season == true)                        -- Validation de la saison.
        then           
            DLog("Traitement BioClim")
            Exec_BioClim(BioClim_Devices)
        end
        New_Config_Selected = false
        --
        -- Log de l'état des modes de contrôle des volets toutes les 2h.
        --
        if (time.hour % 2 == 0) and (time.min % 60 == 0) 
            and (otherdevices[BioClim_Control] ~= MODE_MANUAL)
            and (Time_Now > Time_Day) and (Time_Now < Time_Night)
        then
            Str = BioClim_Control .. ". Mode: " .. otherdevices[BioClim_Control] .. "."
            if (uservariables[Var_BioClim] ~= nil)
            then
               Str = Str .. " T°: " .. Ext_Temperature .. "° Ouverture BioClim (%): "  .. uservariables[Var_BioClim]
            end
            Log(Str)
        end
    end
    
return commandArray


