
# Description de l'automation pour volets 'BioClim'
Le script d'automation 'BioClim' permet de contrôler l'ouverture ou la fermeture de volets au lever/coucher du soleil et en fonction de tranches horaires
configurables.

Le mode d'automation des volets est choisi par des Selector switches (Virtual Switch) à créer dans Domoticz.
* Mode 'Manuel'. Arrêt de l'automation.

* Mode 'Jour/Nuit'. Ouverture/Fermeture (ou On/Off) au lever/coucher de soleil.
  * Ouverture (On): l'ordre 'On' est envoyé à l'heure du lever du soleil + OFFSET avec une heure minimum définie par TIME_MINIMUM.
  * Fermeture (Off): l'ordre 'Off' est envoyé à l'heure du coucher du soleil + OFFSET.
<br>OFFSET peut évoluer en fonction de la saison. 
<br>L'heure d'ouverture et de fermeture peut être modulée automatiquement en fonction de la luminosité si un capteur optionnel de luminosité existe.

* Mode 'BioClim'. Fermeture partielle des volets selon des plages horaires.
<br>Optionnellement le niveau d'ouverture peut être modulé automatiquement en fonction de la température extérieure si un capteur optionnel de température existe.
<br>Un fonctionnement 'Normal' ou 'Canicule' permet d'utiliser une configuration adaptée en fonction de la température exterieure. 
<br>Le mode 'BioClim' est validé pour certaines saisons. C'est un paramètre configurable.

* Mode 'Auto'. Mode Jour/Nuit **ET** mode BioClim.
		
## L'automation 'BioClim' est désactivée si : 
- Le switch virtuel 'AUTOMATION_SWITCH est 'Off'. Ce switch est optionnel.
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
1) Personaliser le fichier 'Config_Automation_Volets_V1.lua'.
<br>Définir les switches virtuels dans Domoticz
2) Configurer domoticzUSER et domoticzPSWD dans le fichier 'fonctions.lua'.
3) Copier les fichiers suivants dans /home/pi/domoticz/scripts/lua/ : 
<br> Config_Automation_Volets_V1.lua
<br> fonctions_LUA.lua
<br> script_time_Automation_Volets_V1.1.lua

## Configuration HW/SW
Script testé avec la configuration suivante :
- Domoticz 2022-1 et 2022-2 sur Raspberry PI 3B+.
- Coordinateur Zigate V2 Niveau 320.
- Pluging Domoticz-Zigbee 6.3.007.
- Volets Profalux avec motorisation type MOCT-xxxx.
