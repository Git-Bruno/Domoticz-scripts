--[[
****************************************************************************************

 FICHIER DE CONFIGURATION UTILISÉ POUR LE SCRIPT script_time_Automation_Volets_V1.1.lua. 
 
****************************************************************************************

**************************************************************************************
	DESCRIPTION DE L'AUTOMATION 'BIOCLIM'. 
**************************************************************************************
 Le script d'automation 'BioClim' permet de contrôler l'ouverture ou la fermeture de volets 
 au lever/coucher du soleil ou selon des tranches horaires.
 Le terme 'volet' recouvre un volet physique ou des volets contenus dans un groupe zigate.
 Les volets contrôlés par le script sont définis dans des tables : 
  - Table 'Group_OnOff' pour le fonctionnement jour/nuit.
  - Table 'Groups_BioClim' pour le fonctionnement par tranches horaires.


 Le mode d'automation des volets est choisi grâce à des selector switches (Virtual Switch) à créer dans Domoticz.
 	- Mode 'Manuel'. Arrêt de l'automation.

 	- Mode 'Jour/Nuit'. Ouverture/Fermeture (ou On/Off) au lever/coucher de soleil.
 		- Ouverture (On): l'ordre 'On' est envoyé à l'heure du lever du soleil + l'offset TIME_DAY_OFFSET 
			avec une heure minimum définie par TIME_MINIMUM.
 		- Fermeture (Off): l'ordre 'Off' est envoyé à l'heure du coucher du soleil + l'offset TIME_NIGHT_OFFSET.

	- Mode 'BioClim'. Ouverture/Fermeture partielle des volets par plages horaires.
		- Les plages horaires et les niveaux d'ouverture sont définis dans des tables pour chaque groupe de volets.
		- 1 ou 2 tables peuvent être définies pour chaque groupe. Le choix de la configuration pour être automatique
		en fonction d'un seuil de température ou forcé à une valeur donnée par un selector switch (optionnel).
 		- Le mode 'BioClim' est validé pour le printemps et l'été.
 		- Optionnellement le niveau d'ouverture est adapté en fonction de la température exterieure.

	- Mode 'Auto'. Mode Jour/Nuit ET mode 'BioClim'.

 L'automation des volets peut être désactivée selon l'état de 2 switches virtuels optionnels quand:
	- Le switch 'AUTOMATION_SWITCH' est 'Off'.
	- Le switch 'SECURITY_SWITCH' est activé.


 Variables Domoticz.
 -------------------
 L'état BioClim est enregistré pour chaque groupe BioClim dans une variable Domoticz.
 Les états possibles pour chaque volet sont:
		-- : Aucune plage horaire encore validée.
		<BIOCLIM_MIN_LEVEL,100> : valeur d'ouverture.
		Off : Le volet a quitté le mode BioClim suite à un changement hors automation.
		    Il sera repris en mode BioClim si il est repositionné à la valeur d'ouverture +/- 15%.

 Les variables créées dans Domoticz sont supprimées :
		- Automatiquement à 2h00.
		- Au run suivant si le mode est 'Manuel' ou 'Jour/Nuit'.
		- Optionnellement, par un script 'Action' appelé quand le selector switch est en mode 'Manuel' ou 'Jour/Nuit'. 

 Installation.
 -------------
	1) Personaliser ce fichier.
	2) Définir les switches virtuels dans Domoticz, voir plus bas.
	3) Configurer domoticzUSER et domoticzPSWD dans le fichier fonctions.lua.
	4) Copier les fichiers suivants dans /home/pi/domoticz/scripts/lua/ :
		- ce fichier
		- fonctions.lua
        - includes.lua
		- script_time_Automation_Volets_V1.1.lua
]]


--**************************************************************************************
--
--	SWITCHES À CRÉER OBLIGATOIREMENT DANS DOMOTICZ.
--
--**************************************************************************************

-- Créer un selector switch virtuel par groupe de volets.
--	Nom: nom du switch, ex MODE_VOLETS_ETAGE. 
--       Ce nom doit être utilisé dans Group_OnOff et Groups_BioClim.
--  NomDz: nom du switch défini dans Domoticz, ex 'Volets Etage'. 
MODE_VOLETS_ETAGE   = "Volets Etage"
MODE_VOLETS_RDC     = "Volets RdC"
--
--	Valeur pour les selector switches de contrôle des groupes de volets.
--		0:'Manuel', 10:'Jour/Nuit', 20:'BioClim', 30:'Auto'.
--    	Reporter ces valeurs dans MODE_MANUAL, MODE_ONOFF, MODE_BIOCLIM et MODE_AUTO.
--
MODE_MANUAL	    = 'Manuel'		
MODE_ONOFF	    = 'Jour/Nuit'	
MODE_BIOCLIM	= 'BioClim'		
MODE_AUTO   	= 'Auto'

--------------------------------------------------------------------------------------------
--
-- SWITCHES ET CAPTEURS OPTIONNELS. 
--  Tous les switches et capteurs ci dessous sont optionnels.
--  Une valeur par défaut sera forcée si un switch ou un capteur optionnel n'est pas défini. 
--------------------------------------------------------------------------------------------

-- BIOCLIM_MODE, ,nom du selector switch virtuel.
--	Contrôle la sélection des tables BioClim #1 ou #2.
--	Nom: nom défini dans Domoticz, ex 'Mode BioClim'. 
--
BIOCLIM_MODE	 = 'Mode BioClim'
--	Valeurs, ce sont les labels donnés aux valeurs dans Domoticz.  
--		0:'Auto', 10:'Normal' (table #1), 20:'Canicule' (table #2).
--		Le mode 'Auto' sera activé si ce selector switch n'existe pas.
BIOCLIM_AUTO    = 'Auto'
BIOCLIM_1	    = 'Normal'
BIOCLIM_2	    = 'Canicule'

-- CLOSING_MODE, nom du switch On/Off virtuel.
--	Pour le choix d'une fermeture totale ou partielle des volets.
--	Nom: nom défini dans Domoticz, ex 'Fermeture mode Aération'. 
--	Valeurs:
--     	- Off: fermeture totale.
--     	- On: fermeture selon le 2ème paramètre des éléments de la table Group_OnOff.
-- 	La valeur sera 'Off' si ce selector switch n'existe pas.
CLOSING_MODE    = 'Fermeture mode Aération'

-- SECURITY_SWITCH, nom du selector switch virtuel.
--	Pour le choix du niveau sécurité, voir Config_Automation_Common.lua.
--	La valeur sera 'Off' si le switch n'existe pas.
SWITCH_SECURITY = 'Sécurité'
--
-- AUTOMATION_SWITCH, nom du switch On/Off virtuel.
--	Contrôle générale de l'automation, voir Config_Automation_Common.lua.
--	La valeur sera 'On' si le switch n'existe pas.
SWITCH_AUTOMATION 	= 'Automation'	

-- SENSOR_TEMPERATURE, nom du capteur de température .
--	Mesure de la température exterieure, voir Config_Automation_Common.lua.
--	L'ajustement de l'ouverture en fonction de la température est désactivé si le capteur n'existe pas.
SENSOR_TEMPERATURE  = 'Temperature Ext'

-- SENSOR_LUX, nom du capteur de luminosité .
--	Mesure de la luminosité exterieure, voir Config_Automation_Common.lua.
--	L'ajustement de l'heure d'ouverture/fermeture en fonction de la luminosité est désactivé si le capteur n'existe pas.
SENSOR_LUX = 'Capteur LUX-1'
--------------------------------------------------------------------------------------------


--**************************************************************************************
--
-- CONFIGURATION POUR LE MODE 'JOUR/NUIT' (ON/OFF).
--
--**************************************************************************************
-- Heure minimum, en minute, pour l'ouverture automatique.
TIME_MINIMUM		= '8:00'	
-- Offset après le lever du soleil.
TIME_DAY_OFFSET		= 10		
-- Offset après le coucher du soleil.
TIME_NIGHT_OFFSET	= 15			
-- Durée ajoutée à l'heure de fermeture automatique des volets au printemps et en été.
TIME_NIGHT_SEASON_OFFSET = 10	
-- Durée de la plage horaire pour l'ouverture/fermeture avancée en fonction de la luminosité
EARLY_ACTION_RANGE	= 20
-- Niveau de luminosité haute pour l'ouverture des volets.
LUX_LEVEL_HIGH  	= 25
-- Niveau de luminosité basse pour la fermeture des volets.
LUX_LEVEL_LOW  		= 5

-----------------------------------------------------------------------------------------------
-- GROUPES D'UNITÉS ONOFF. 
--
-- Tables avec la liste des volets ou groupe de volets pour l'ouverture/fermeture automatique.
--		- Le nom des groupes est libre.
--		- Ces noms sont utilisés comme index de la table 'Group_OnOff'.
--	Format des éléments: 
--		Une liste de nom de device, un nom de device, un nom de groupe Zigate. 
--      Par défaut l'ouverture et la fermeture est faite automatiquement le matin et le soir.
--      Pour ne faire que l'ouverture OU la fermeture ajouter le caractère '+' ou '-' devant
--      le nom de chaque device :
--          '+': ouverture automatique seulement.
--          '-': fermeture automatique seulement. 
-----------------------------------------------------------------------------------------------
-- Groupe_Etage = 'Grp Volets Etage'
Groupe_Etage    = {'Volet Chambre Bleue', 'Volet Chambre Verte', 'Volet Bureau'}
Groupe_RdC      = {'-Volet Chambre Bas', 'Volet Piano', 'Volet Salon', 'Volet SaM', '+Volet Cuisine'}

------------------------------------------------------------------------------------------
-- GROUP_ONOFF.
--  Table avec les paramètres de contrôle pour le mode 'Jour/Nuit' (On/Off).
-- 	Les index de la table sont les noms des GROUPE D'UNITÉS ONOFF.
--	Format des éléments: 
--      - Nom du selector switch pour le groupe,
--      - Pourcentage de fermeture finale ou nom de scène. Fermeture complète si non spécifié.
--		  L'utilisation de 2ème paramètres est contrôlée par le switch CLOSING_MODE.
-------------------------------------------------------------------------------------------
Group_OnOff = {} 
Group_OnOff['Groupe_Etage'] = {MODE_VOLETS_ETAGE, 'Aération Etage'}
Group_OnOff['Groupe_RdC']   = {MODE_VOLETS_RDC,  'Aération RdC'}
-- Group_OnOff['Groupe_Etage'] = {'Mode Volets Etage', 30}
-- Group_OnOff['Groupe_RdC'] = {'Mode Volets RdC', 80}


--**************************************************************************************
--
-- CONFIGURATION POUR LE MODE 'BIOCLIM'.
--  Temperature en °C.  Temps en minutes.
--**************************************************************************************
-- Période de monitoring 'BioClim'.
BIOCLIM_MONITOR_TIME    = 5
-- Offset par rapport aux heures de début/fin du mode 'Jour/Nuit'.
BIOCLIM_TIME_OFFSET     = 10
-- Température minimum pour activer le mode 'BioClim'.
TEMPERATURE_MINIMUM     = 25
-- Température de réference pour le calcul de l'ajustement d'ouverture en fonction de la température.
TEMPERATURE_REFERENCE   = 28 
-- Température pour la sélection de la configuration 'BioClim' #1 ou #2 (si définie).
TEMPERATURE_BIOCLIM_CONFIG = 31  
-- Niveau (%) d'ouverture minimum en mode 'BioClim'.
BIOCLIM_MIN_LEVEL       = 15
-- Optionel - Mettre en commentaire pour un fonctionnement toute l'année, sinon renseigner les saisons.
BIOCLIM_SEASONS         =  {'Spring','Summer'}

----------------------------------------------------------------------------------------
-- Liste des groupes 'BioClim' avec leurs switches de contrôle.
-- 	Les index de la table sont les noms des groupes 'BioClim'. Le nom des groupes est libre.
--	Les valeurs sont les noms des selector switches qui contrôlent chaque groupes.
----------------------------------------------------------------------------------------
Groups_BioClim = {} 
Groups_BioClim['BioClim_Volets_Etage']  = MODE_VOLETS_ETAGE
Groups_BioClim['BioClim_Volets_RdC']    = MODE_VOLETS_RDC

----------------------------------------------------------------------------------------
-- Définitions des tables BioClim pour les groupes de volets.
-- Il peut y avoir 1 ou 2 tables pour chaque groupe.
--	Format des entrées : 
--		- Index numérique : obligatoire pour ordonner la lecture de la table.
--		- Nom du volet dans Domoticz.
--		- Numéro de plage = {<Début plage horaire>, <Fin plage horaire>, <Niveau d'ouverture>}
--
--		Pour chaque volet les pages horaires doivent être chronologiquement contigues.
----------------------------------------------------------------------------------------

------------------------------------------------------------------------
-- Définitions des tables BioClim pour le groupe 'BioClim_Volets_Etage'.
------------------------------------------------------------------------
BioClim_Volets_Etage = {}

-- Table Bioclim #1 
BioClim_Volets_Etage[1] = {
	[1] = { 
	['Volet Chambre Bleue'] = {
		[1] = {'8:20', '10:00', 25},
		[2] = {'10:00', '15:00', 30},
		[3] = {'15:00', '16:30', 70}
		}
	},
		
	[2] = {	
	['Volet Chambre Verte'] = {
		[1] = {'8:20', '14:00', 25},
		[2] = {'14:00', '16:45', 30}
		}
	},	
	
	[3] = { 
	['Volet Bureau'] = {
		[1] = {'8:20', '14:00', 25},
		[2] = {'14:00', '15:30', 40},
		[3] = {'15:30', '16:30', 70}
		}
	}
}

-- Table Bioclim #2 
BioClim_Volets_Etage[2] = {
	[1] = { 
	['Volet Chambre Bleue'] = {
		[1] = {'8:00', '15:00', 15},
		[2] = {'15:00', '18:30', 25}
		}
	},
		
	[2] = {	
	['Volet Chambre Verte'] = {
		[1] = {'8:00', '14:10', 15},
		[2] = {'14:10', '17:00', 25}
		}
	},	
	
	[3] = { 
	['Volet Bureau'] = {
		[1] = {'8:00', '16:00', 25},
		[2] = {'16:00', '17:30', 70}
		}
	}
}

----------------------------------------------------------------------
-- Définitions des tables BioClim pour le groupe 'BioClim_Volets_RdC'.
----------------------------------------------------------------------
BioClim_Volets_RdC = {}

-- Table Bioclim #1 
BioClim_Volets_RdC[1] = {
	[1] = {	
	['Volet Chambre Bas'] = {
		[1] = {'8:45', '16:30', 40}
		}
	},
		
	[2] = { 
	['Volet Piano'] = {
		[1] = {'8:45', '14:30', 40 },
		[2] = {'14:30', '15:00', 70 }
		}
	},
	
	[3] = {
	['Volet Salon'] = {
		[1] = {'8:45', '8:50', 100 }
		}
	},
	
	[4] = {
	['Volet SaM'] = {
		[1] = {'8:45', '13:40', 100 },
		[2] = {'13:40', '14:20', 50 },
		[3] = {'14:20', '18:45', 20 },
		[4] = {'18:45', '19:30', 80 }
		}
	},
	
	[5] = {
	['Volet Cuisine'] = {
		[1] = {'8:45', '13:45', 100 },
		[2] = {'13:45', '15:00', 50 },
		[3] = {'15:00', '18:45', 30 }
		}
	}	
}

-- Table Bioclim #2 
BioClim_Volets_RdC[2] = {
	[1] = {	
	['Volet Chambre Bas'] = {
		[1] = {'8:45', '17:30', 20}
		}
	},
		
	[2] = { 
	['Volet Piano'] = {
		[1] = {'8:45', '14:30', 20 },
		[2] = {'14:30', '15:30', 50 }
		}
	},
	
	[3] = {
	['Volet Salon'] = {
		[1] = {'8:45', '15:00', 100 },
		[2] = {'15:00', '15:30', 75 },
		[3] = {'15:30', '17:30', 20 }
		}
	},
	
	[4] = {
	['Volet SaM'] = {
		[1] = {'8:45', '11:30', 100 },
		[2] = {'11:30', '14:00', 30 },
		[3] = {'14:00', '19:30', 20 }
		}
	},
	
	[5] = {
	['Volet Cuisine'] = {
		[1] = {'8:45', '13:00', 100 },
		[2] = {'13:00', '13:30', 60 },
		[3] = {'13:30', '18:45', 20 }
		}
	}	
}
