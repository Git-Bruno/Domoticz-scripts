----------------------------------------------------------------------------------------
--
-- Fichier des définitions des ressources gérées par Domoticz : 
-- 	devices, variables, scènes.
--	groupes et paramètres pour l'automation 'Bioclim' des volets
----------------------------------------------------------------------------------------

--**************************************************************************************
-- Description de l'automation 'BioClim' :
-- ---------------------------------------
-- Le script d'automation 'BioClim' permet de contrôler l'ouverture ou la fermeture de volets 
-- au lever/coucher du soleil et en fonction de tranches horaires configurables.
-- Le mode d'automation des volets est choisi par des Selector switches (Virtual Switch) à créer dans Domoticz.
--
-- 	- Mode 'Manuel'. Arrêt de l'automation.
--
-- 	- Mode 'Jour/Nuit'. Ouverture/Fermeture (ou On/Off) au lever/coucher de soleil.
-- 		Ouverture (On): l'ordre 'On' est envoyé à l'heure du lever du soleil + TIME_DAY_OFFSET 
--			avec une heure minimum définie par TIME_MINIMUM.
-- 		Fermeture (Off): l'ordre 'Off' est envoyé à l'heure du coucher du soleil + TIME_NIGHT_OFFSET.
--
--	- Mode 'BioClim'. Mode Jour/Nuit ET fermeture partielle des volets par plages horaires.
-- 			Optionellement le niveau d'ouverture peut être modifié en fonction de la température exterieure
--			Le mode 'BioClim' est validé pour le printemps et l'été.
--
-- L'automation 'BioClim' est désactivée si :
--
--	- Le switch 'AUTOMATION_SWITCH est 'Off'. Ce switch est optionnel.
--	- Le switch virtuel 'SECURITY_SWITCH' est activée. Ce switch est optionnel.
--
-- Variables Domoticz.
-- -------------------
-- L'état BioClim est enregistré pour chaque groupe BioClim dans une variable Domoticz.
--
-- Etats possibles pour chaque volet :
--		-- : Aucune plage horaire encore validée.
--		<BIOCLIM_MIN_LEVEL,100> : valeur d'ouverture.
--		On : Ouverture hors plage horaire BioClim.
--		Off : Le volet a quitté le mode BioClim suite à un changement hors automation.
--		Il sera repris en mode BioClim s'il est repositionné à la valeur d'ouverture +/- 15%.
--
-- Les variables créées dans Domoticz sont supprimées :
--		- Automatiquement à 2h00.
--		- Au run suivant si le mode est 'Manuel' ou 'Jour/Nuit'.
--		- Optionnellement, par un script 'Action' appelé quand le selector switch est en mode 'Manuel' ou 'Jour/Nuit'. 

-- Installation.
-- -------------
--	1) Définir les switches virtuels dans Domoticz.
--	2) Personaliser le fichier 'Automation_Config.lua'.
--	3) Configurer domoticzUSER et domoticzPSWD dans le fichier 'Fonctions_LUA.lua'.
--	4) Copier les fichiers suivants dans /home/pi/domoticz/scripts/lua/ :
--			Automation_Config.lua
--			Fonctions_LUA.lua
--			script_time_Automation_Volet.lua
--
--**************************************************************************************

----------------------------------------------------------------------------------------
-- Devices virtuels à créer dans Domoticz

--	Switch pour l'activation/désactivation de la sécurité (optionel).
--		Nom: libre, ex 'Automation'.
--		Type: Light/Selector Switch.
SECURITY_SWITCH		= 'Securité'	-- !! Nom de constante imposé !!

--	Switch pour l'activation/désactivation générale de l'automation (optionel).
--		Nom: libre, ex 'Automation'.
--		Type: Switch On/Off.
AUTOMATION_SWITCH 	= 'Automation'	-- !! Nom de constante imposé !!

--	Selector wwitch de mode BioClim.
--		Nom: libre, ex 'Mode Volets Etage'. 
--			Reporter le nom dans les tables 'Group_OnOff' et 'Group_BioClim'.
--		Type: Light/Selector Switch.
--		Valeurs:  0:'Manuel', 10:'Jour/Nuit', 20:'BioClim'.
MODE_MANUAL		= 'Manuel'		-- !! Nom de constante imposé !!
MODE_ONOFF		= 'Jour/Nuit'	-- !! Nom de constante imposé !!
MODE_BIOCLIM	= 'BioClim'		-- !! Nom de constante imposé !!
----------------------------------------------------------------------------------------


--**************************************************************************************
--
-- Configuration pour le mode 'Jour/Nuit' (On/Off).
--
--**************************************************************************************

-- Heure minimum, en minute, pour l'ouverture ou la mise en route automatique. Format H:MM
TIME_MINIMUM		= '8:00'	-- !! Nom de constante imposé !!
-- Offset après le lever du soleil
TIME_DAY_OFFSET		= 30		-- !! Nom de constante imposé !!
-- Offset après le coucher du soleil
TIME_NIGHT_OFFSET	= 5			-- !! Nom de constante imposé !!
-- Durée ajoutée à l'heure de fermeture automatique des volets au printemps et en été.
TIME_NIGHT_SEASON_OFFSET = 10	-- !! Nom de constante imposé !!

----------------------------------------------------------------------------------------
--	Définitions des groupes d'unité. 
--	Le nom des groupes est libre.
--	Format des entrées : une liste de nom de device ou un nom de device. 
----------------------------------------------------------------------------------------
Groupe_Etage = 'Grp Volets Etage'
Groupe_RdC = {'Volet Chambre 3', 'Volet Piano', 'Volet Salon', 'Volet SaM', 'Volet Cuisine'}

----------------------------------------------------------------------------------------
-- Table des paramètres de contrôle pour le mode 'Jour/Nuit' (On/Off).
-- 	L'index de la table est un nom de groupe d'unités.
--	Format des entrées : <Nom du selector switch pour le groupe>, <1er niveau en % si fermeture en 2 temps>.
----------------------------------------------------------------------------------------
Group_OnOff = {} -- !! Nom de variable imposé !!
Group_OnOff['Groupe_Etage'] = {'Mode Volets Etage'}
Group_OnOff['Groupe_RdC'] = {'Mode Volets RdC', 80}

--**************************************************************************************
--
-- Configuration pour le mode 'BioClim'.
--
--**************************************************************************************
-- Période de monitoring 'BioClim'
BIOCLIM_MONITOR_TIME = 5
-- Offset (mn) ajouté/retiré par rapport aux heures de début/fin du mode 'Jour/Nuit'.
BIOCLIM_TIME_OFFSET = 10
-- Température minimum pour autoriser le mode 'BioClim'.
TEMPERATURE_MINIMUM = 20 -- !! Nom de variable imposé !!
-- Température de réference pour le calcul de l'ajustement d'ouverture en fonction de la température.
TEMPERATURE_REFERENCE = 25 -- !! Nom de variable imposé !!
-- Défintion du capteur de température extérieure. 
SENSOR_EXTERNAL_TEMP = 'Temperature Ext' -- !! Nom de variable imposé !!
-- Activation/désactivation de l'ajustement de l'ouverture en fonction de la température.
Control_Temperature = true -- !! Nom de variable imposé !!
-- Niveau d'ouverture minimum en mode 'BioClim'.
BIOCLIM_MIN_LEVEL = 25

----------------------------------------------------------------------------------------
-- Liste des groupes 'BioClim' avec leurs paramètres de contrôle.
-- 	L'index de la table est un nom de groupe 'BioClim'. Le nom des groupes est libre.
--	La valeur est le nom du selector switch qui contrôle le groupe.
----------------------------------------------------------------------------------------
Group_BioClim = {} -- !! Nom de variable imposé !!
Group_BioClim['BioClim_Volets_Etage'] = 'Mode Volets Etage'
Group_BioClim['BioClim_Volets_RdC'] = 'Mode Volets RdC'

----------------------------------------------------------------------------------------
-- Définitions des groupes 'BioClim'.
--	Format des entrées : 
--		[Index numérique] : obligatoire pour ordonner la lecture de la table.
--		[Nom du volet dans Domoticz].
--		[Numéro de plage] = {<Début plage horaire>, <Fin plage horaire>, <Niveau d'ouverture>}
--
--		Pour chaque volet les pages horaires doivent être chronologiquement contigues.
----------------------------------------------------------------------------------------
BioClim_Volets_Etage = {
	[1] = { 
	['Volet Chambre 1'] = {
		[1] = {'8:20', '11:00', 30}
		}
	},
		
	[2] = {	
	['Volet Chambre 2'] = {
		[1] = {'8:30', '13:00', 50},
		[2] = {'13:00', '14:30', 70}
		}
	},	
	
	[3] = { 
	['Volet Bureau'] = {
		[1] = {'8:30', '13:00', 50},
		[2] = {'13:00', '14:30', 70}
		}
	}
}

BioClim_Volets_RdC = {
	[1] = {	
	['Volet Chambre 3'] = {
		[1] = {'9:00', '15:30', 50}
		}
	},
		
	[2] = { 
	['Volet Piano'] = {
		[1] = {'9:00', '14:00', 50 },
		[2] = {'14:00', '14:45', 70 }
		}
	},
	
	[3] = {
	['Volet Salon'] = {
		[1] = {'8:30', '8:31', 100 }
		}
	},
	
	[4] = {
	['Volet SaM'] = {
		[1] = {'13:45', '14:20', 50 },
		[2] = {'14:20', '19:00', 30 }
		}
	},
	
	[5] = {
	['Volet Cuisine'] = {
		[1] = {'14:00', '15:00', 80 },
		[2] = {'15:00', '18:00', 30 }
		}
	}	
}




