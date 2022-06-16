
# Description de l'automation pour volets 'BioClim'
Le script d'automation 'BioClim' permet de contrôler l'ouverture ou la fermeture de volets au lever/coucher du soleil et en fonction de tranches horaires
configurables.

Le mode d'automation des volets est choisi par des Selector switches (Virtual Switch) à créer dans Domoticz.
* Mode 'Manuel'. Arrêt de l'automation.

* Mode 'Jour/Nuit'. Ouverture/Fermeture (ou On/Off) au lever/coucher de soleil.
  * Ouverture (On): l'ordre 'On' est envoyé à l'heure du lever du soleil + TIME_DAY_OFFSET avec une heure minimum définie par TIME_MINIMUM.
  * Fermeture (Off): l'ordre 'Off' est envoyé à l'heure du coucher du soleil + TIME_NIGHT_OFFSET.

* Mode 'BioClim'. Mode Jour/Nuit **ET** fermeture partielle des volets par plages horaires.
<br>Optionnellement le niveau d'ouverture peut être modifié en fonction de la température exterieure
<br>Le mode 'BioClim' est validé pour le printemps et l'été.
		
## L'automation 'BioClim' est désactivée si : 
- Le switch 'AUTOMATION_SWITCH est 'Off'. Ce switch est optionnel.
- Le switch virtuel 'SECURITY_SWITCH' est activée. Ce switch est optionnel.
    
## Variables Domoticz
L'état BioClim est enregistré pour chaque groupe BioClim dans une variable Domoticz. 
<br>Etats possibles pour chaque volet : 
* -- : Aucune plage horaire encore validée.
* <BIOCLIM_MIN_LEVEL,100> : valeur d'ouverture.
* On : Ouverture hors plage horaire BioClim.
* Off : Le volet a quitté le mode BioClim suite à un changement hors automation.
<br>Il sera repris en mode BioClim s'il est repositionné à la valeur d'ouverture +/- 15%.
		
Les variables créées dans Domoticz sont supprimées :
- Automatiquement à 2h00.
- Au run suivant si le mode est 'Manuel' ou 'Jour/Nuit'.
- Optionnellement, par un script 'Action' appelé quand le selector switch est en mode 'Manuel' ou 'Jour/Nuit'.

# Installation
1) Définir les switches virtuels dans Domoticz, voir fichier 'Automation_Config.lua'.
2) Personaliser le fichier 'Automation_Config.lua'.
3) Configurer domoticzUSER et domoticzPSWD dans le fichier 'Fonctions_LUA.lua'.
4) Copier les fichiers suivants dans /home/pi/domoticz/scripts/lua/ : 
<br> Automation_Config.lua
<br> Fonctions_LUA.lua
<br> script_time_Automation_Volet.lua

## Configuration HW/SW
Script testé avec la configuration suivante :
- Domoticz 2022-1 sur Raspberry PI 3B+.
- Coordinateur Zigate V2 Niveau 320.
- Pluging Domoticz-Zigbee 6.1.004.
- Volets Profalux avec motorisation type MOCT-xxxx.
