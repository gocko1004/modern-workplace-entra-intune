# Reconstruction du tenant, du 15 au 25 septembre 2026

Reconstruction du lab `labtenant.onmicrosoft.com` après le démontage par script dans `../teardown/`. Même
règle que pour le démontage : scripter là où un script apprend quelque chose, passer par le portail là où
c'est le portail qu'il s'agit d'apprendre.

## Fichiers

| Fichier | S'exécute sur | Fonction |
|---|---|---|
| `00-host-cleanup.ps1` | Hôte | Libère de la mémoire sur l'hôte Hyper-V. Aperçu par défaut, `-Execute` pour appliquer |
| `01-create-groups.ps1` | Hôte, Graph | Crée les groupes du lab par requêtes Graph brutes, dynamiques et affectés |
| `02-build-vm.ps1` | Hôte | Machine de génération 2 qui démarre l'installeur depuis le DVD. **Conservé comme la voie qui a échoué** |
| `02b-apply-image.ps1` | Hôte | La voie qui fonctionne. Partitionne le disque pour UEFI, applique Windows avec DISM, écrit les fichiers de démarrage |
| `02c-diagnose-boot.ps1` | Hôte | Lit le disque en lecture seule et vérifie chaque étape de la chaîne de démarrage UEFI. Ne modifie rien |
| `02d-write-boot.ps1` | Hôte | Écrit le chargeur de démarrage sur un disque existant et vérifie qu'il est bien en place |
| `03-harvest-hwid.ps1` | **Dans la machine** | Capture le hachage matériel Autopilot dans un CSV |
| `r.cmd` | **Dans la machine** | Lanceur d'une lettre pour le script ci-dessus, pour n'avoir rien de pénible à taper |
| `04-fetch-hwid.ps1` | Hôte | Monte le disque de la machine en lecture seule, déverrouille BitLocker avec le mot de passe de récupération si nécessaire, en extrait le hachage |
| `05-harden-vm.ps1` | Hôte | Secure Boot, protecteur de clé, puis TPM, dans cet ordre. C'est l'ordre qui compte |
| `06-bitlocker-status.ps1` | **Dans la machine**, avec élévation | État BitLocker, PCR du protecteur TPM, la stratégie telle que reçue, le journal d'événements BitLocker. N'affiche jamais le mot de passe de récupération |
| `07-defender-status.ps1` | **Dans la machine**, avec élévation | Paramètres effectifs de Defender comparés à la stratégie, état du moteur, et chaque emplacement du registre où la stratégie peut se trouver |

Le CSV du hachage lui-même se trouve dans `C:\Intune-Packaging\`, hors du dépôt.

## La chaîne Autopilot

| # | Étape | Où | Ce qu'elle fait |
|---|---|---|---|
| 1 | **Hachage matériel** | Dans la machine | `Get-WindowsAutopilotInfo` a lu les identifiants du firmware dans un CSV. C'est ainsi que Microsoft reconnaît l'appareil avant qu'il ait un nom ou un utilisateur |
| 2 | **Importation** | Intune, Windows Autopilot devices | Enregistre le hachage auprès du tenant et crée un objet appareil Entra marqué `[ZTDId]` |
| 3 | **Groupe dynamique** | Entra ID | `Dyn-Autopilot-Devices`, règle `(device.devicePhysicalIds -any (_ -startsWith "[ZTDId]"))`. Chaque appareil importé y atterrit automatiquement |
| 4 | **Profil de déploiement** | Intune | `APUserDrivenEntraJoin` : piloté par l'utilisateur, joint à Entra, utilisateur standard, modèle de nom `CORP-%RAND:5%`. Affecté au groupe. L'état du profil est passé de Not assigned à Assigned |
| 5 | **Enrollment Status Page** | Intune | `ESPAutopilot`. Retient l'utilisateur sur l'écran de progression jusqu'à ce que les stratégies et les applications soient arrivées. Remplace la page par défaut pour ce groupe |
| 6 | **MDM user scope** | Intune, Automatic Enrollment | All. Décide quels utilisateurs déclenchent l'inscription dans Intune à la connexion. None signifie que l'appareil joint Entra ID mais n'est jamais géré, et rien ne vous prévient |
| 7 | **Licence** | Microsoft 365 admin center | L'utilisatrice de test `lea.test` a reçu Business Premium, qui inclut Intune et Entra ID P1 |
| 8 | **Autorisation de jonction des appareils** | Entra ID, Device settings | "Users may join devices to Microsoft Entra ID" réglé sur All |

## Ce qui a cassé

| # | Échec | Cause | Leçon |
|---|---|---|---|
| 1 | La machine ne démarrait pas depuis l'ISO | Le démarrage DVD UEFI en génération 2 échoue sur cet hôte. Le hachage de l'ISO correspondait à celui de Microsoft, et une machine de génération 1 l'a démarré | Contourner complètement le DVD. Appliquer l'image avec DISM depuis l'hôte |
| 2 | Le disque appliqué ne démarrait toujours pas | `bcdboot` a échoué et le script n'a jamais lu son code de sortie, puis a affiché un succès | Un `.exe` échoue en silence. Vérifier `$LASTEXITCODE`, puis vérifier que le fichier existe réellement |
| 3 | Pas de copier-coller vers la machine | Pas de presse-papiers pendant la configuration initiale. La session étendue exige une installation terminée et un utilisateur connecté | `Copy-VMFile` pousse les fichiers vers l'intérieur. Monter le disque permet de les en sortir |
| 4 | `Copy-VMFile` a refusé `System32` | Le service de copie invité tourne avec des droits restreints | Copier à la racine de `C:` à la place |
| 5 | Écran noir en pleine configuration | La sortie d'affichage s'est arrêtée. Aucun vidage sur incident sur le disque, donc le système d'exploitation lui-même a continué de tourner | Se connecter d'abord, démarrer ensuite, ne pas la laisser inactive |
| 6 | Ressources système insuffisantes au démarrage | 3.1 Go libres sur l'hôte, machine réglée sur 4 Go statiques | Mémoire dynamique, 2 Go au démarrage, une fois Windows installé |
| 7 | Erreur Internet à la connexion | Service NordVPN de nouveau en Running, démarrage Automatic | Même cause racine que le jour 13. Service désormais réglé sur Manual |
| 8 | `801C03ED` à la connexion | "Users may join devices" était sur **Selected**, et l'utilisatrice de test n'était pas sélectionnée | Voir ci-dessous |
| 9 | Refus "To sign in remotely" à l'ouverture de la console | La session étendue repose sur le Bureau à distance, et Lea est une utilisatrice standard hors du groupe Remote Desktop Users | `Set-VMHost -EnableEnhancedSessionMode $false` force la console de base. Le vrai correctif pour elle est une stratégie Intune, pas un changement local |
| 10 | Le script de récupération du hachage a signalé chaque fichier **missing** | Windows avait chiffré le disque avec BitLocker de lui-même dès que le TPM est apparu. Chaque `Test-Path` sur un volume verrouillé renvoie False | « Introuvable » et « impossible de regarder » sont deux réponses différentes. Le script vérifie maintenant d'abord que le volume est lisible, et le déverrouille avec le mot de passe de récupération sinon |

### Le constat `801C03ED`

`../teardown/README.md` consigne que les paramètres d'appareil Entra ont été remis par défaut pendant le
démontage. La valeur par défaut de "Users may join devices" est All. Le 25 septembre, il était sur
**Selected**.

Soit le changement a été fait et jamais enregistré, soit il a été consigné sans être vérifié. Quoi qu'il
en soit, le journal disait une chose et le tenant en disait une autre, et c'est le tenant qui a eu
raison.

La règle qui en ressort : **une entrée de journal est une affirmation, le paramètre réel est le fait.**
Même forme que l'échec 2, où la propre sortie du script affirmait un succès. Vérifier la chose elle-même.

## Où ça en est

Lea s'est connectée, la jonction Entra a réussi, et l'Enrollment Status Page est allée au bout de ses trois
étapes jusqu'au bureau.

**Confirmé le 25 septembre :** l'appareil apparaît dans Intune sous le nom `CORP-97322`, issu du modèle
`CORP-%RAND:5%`. Le
modèle de nom n'existe que dans le profil de déploiement Autopilot, donc cela prouve que c'est le profil
qui a piloté la configuration, et non une jonction professionnelle ou scolaire ordinaire.

![Rapport de chiffrement Intune listant CORP-97322, nom d'utilisateur principal masqué](../../screenshots/06-rebuild-corp-97322-in-intune.png)

**Confirmé le 29 septembre :** Secure Boot et le TPM sont de nouveau actifs via `05-harden-vm.ps1`, et la
machine démarre. Windows Security dans l'invité signale le processeur de sécurité présent et Secure Boot
actif, avec "all required certificate updates have been applied". C'est le remplacement de 2023 des
certificats Secure Boot de Microsoft de 2011, qui commencent à expirer en juin 2026.

## Conformité

Stratégie `CP-Windows`, Windows 10 and later, affectée à `Dyn-Autopilot-Devices` :

| Section | Paramètres requis |
|---|---|
| Device Health | BitLocker, Secure Boot, Code Integrity |
| System Security | Firewall, TPM, Antivirus, Antispyware |
| Defender | Microsoft Defender Antimalware, Real-time protection |

Le score de risque machine de Defender for Endpoint a été volontairement laissé non défini : cet essai est
désactivé, donc la vérification ne pourrait jamais passer.

**Première évaluation, 29 septembre : Not compliant**, sur une seule ligne de la Default Device Compliance
Policy intégrée : "Has a compliance policy assigned". L'appareil s'était synchronisé avant que
l'affectation au groupe ne l'atteigne. Cette ligne n'échoue que lorsque le paramètre de tenant "Mark
devices with no compliance policy assigned as" est sur Not compliant, donc ce paramètre est actif, ce qui
est le choix sûr. Encore un paramètre de tenant qui a survécu au démontage.

**Confirmé le 5 octobre : Compliant.** État par paramètre pour `CORP-97322` : les neuf paramètres à 1
Compliant, **0 Not applicable**.

![État par paramètre pour CP-Windows : neuf paramètres, chacun à 1 Compliant et 0 Not applicable, identifiants masqués](../../screenshots/07-rebuild-compliance-per-setting.png)

Le zéro compte. Une ligne Not applicable n'a jamais été vérifiée, et l'état global affiche quand même
Compliant dans ce cas. Les trois lignes Device Health viennent du rapport d'intégrité que Windows écrit au
démarrage, donc c'est une deuxième confirmation indépendante du TPM, de Secure Boot et du chiffrement
automatique, distincte de ce que l'hôte et Windows Security ont signalé.

## Defender Antivirus

Stratégie `ES-Defender-AV`, Endpoint security, Antivirus, affectée à `Dyn-Autopilot-Devices`, créée le
5 octobre. Douze paramètres : analyse en temps réel, comportementale, cloud et des scripts, téléchargements
analysés, niveau de blocage cloud High, délai étendu cloud de 50 secondes, échantillons sûrs envoyés
automatiquement, protection PUA en blocage, protection réseau en blocage, fusion administrateur local
désactivée, définitions vérifiées toutes les 4 heures.

Vérifié dans la machine avec `07-defender-status.ps1`.

**En vigueur :** les onze paramètres que `Get-MpPreference` rapporte correspondaient tous. Cinq d'entre eux
ne sont pas des valeurs par défaut de Windows (niveau de blocage cloud 2, délai étendu 50, protection
réseau 1, intervalle de mise à jour 4, MAPS 2), donc ils ne peuvent venir que de la stratégie. Une valeur
qui correspond à la cible uniquement parce que c'est aussi la valeur par défaut ne prouve rien, et ce
n'est pas le cas ici.

Moteur : mode d'exécution **Normal**, donc Defender est l'antivirus actif et non passif derrière un autre
produit. Tamper Protection activée.

**Où se trouve la stratégie :**

| Paramètre | Clé du fournisseur Intune | `Policies\Microsoft\Windows Defender\Policy Manager` | En vigueur |
|---|---|---|---|
| Temps réel, comportement, cloud, scripts, analyse des téléchargements | oui | oui | oui |
| PUA, protection réseau, échantillons, intervalle de mise à jour | oui | oui | oui |
| DisableLocalAdminMerge | non | oui, 1 | non rapporté par `Get-MpPreference` |
| CloudBlockLevel, CloudExtendedTimeout | oui | non | oui, 2 et 50 |

La clé fusionnée `PolicyManager\current\device\Defender` existe et est vide, contrairement à celle de
BitLocker, qui contenait les paramètres. Les deux paramètres cloud sont en vigueur sans être dans la clé
que Defender lit, donc ils sont stockés encore ailleurs. Pas tracé, donc aucun chemin n'est affirmé.

**Les deux vocabulaires.** Intune envoie `AllowRealtimeMonitoring 1`. Defender rapporte
`DisableRealtimeMonitoring False`. Même fait, nom différent, logique inversée. Chercher l'un des noms dans
la sortie de l'autre ne trouve rien.

**L'habitude :** vérifier l'effet d'abord, ce que le moteur fait réellement. Lire le registre seulement
pour expliquer un écart. Chaque domaine de stratégie stocke ses paramètres à sa façon, donc un script qui
suppose un seul emplacement signalera de faux écarts.

`07-defender-status.ps1` est aussi resté muet à sa première exécution : il gérait « clé absente » mais pas
« clé présente et vide ». Le silence ne se distingue pas d'un script qui n'aurait jamais atteint cette
ligne. Chaque résultat affiche maintenant ce qu'il est.

Toujours ouvert : définitions mises à jour pour la dernière fois à 01:10 le 5 octobre, avant l'arrivée de
l'intervalle de 4 heures. Une vérification ultérieure devrait montrer un horodatage plus récent.

## Edge SmartScreen

Windows Security avait signalé "the setting to block potentially unwanted app downloads is turned off".
Ce commutateur appartient à Edge, pas à Defender, donc la stratégie Defender ne pouvait pas le régler.

Stratégie `CFG-Edge-SmartScreen`, settings catalog, catégorie **Microsoft Edge\SmartScreen settings**,
affectée à `Dyn-Autopilot-Devices`, créée le 6 octobre :

- Configure Microsoft Defender SmartScreen : Enabled
- Configure Microsoft Defender SmartScreen to block potentially unwanted apps : Enabled
- Prevent bypassing Microsoft Defender SmartScreen prompts for sites : Enabled
- Prevent bypassing of Microsoft Defender SmartScreen warnings about downloads : Enabled

Deux pièges dans le sélecteur de paramètres :

- **Chercher "smart screen" avec un espace** a trouvé un autre produit : Windows SmartScreen pour les
  fichiers lancés depuis l'Explorateur. Le mot unique "SmartScreen" a trouvé celui d'Edge
- **Chaque paramètre Edge apparaît deux fois**, tel quel et avec "(User)". Celui sans suffixe s'applique à
  la machine quel que soit l'utilisateur connecté, ce qui convient à un groupe d'appareils. Il existe aussi
  une catégorie distincte "Default Settings (users can override)", qui est la mauvaise pour imposer un
  réglage

Vérifié dans Edge sur l'appareil, `edge://policy` :

| Policy | Value | Source | Applies to | Level | Status |
|---|---|---|---|---|---|
| SmartScreenEnabled | true | Platform | Device | Mandatory | OK |
| SmartScreenPuaEnabled | true | Platform | Device | Mandatory | OK |
| PreventSmartScreenPromptOverride | true | Platform | Device | Mandatory | OK |
| PreventSmartScreenPromptOverrideForFiles | true | Platform | Device | Mandatory | OK |

![edge://policy sur l'appareil : les quatre stratégies SmartScreen à true, Platform, Device, Mandatory, OK](../../screenshots/08-rebuild-edge-policy-smartscreen.png)

Source **Platform** signifie livré par la stratégie Windows, ce qui est la voie par laquelle Intune arrive,
par opposition à la gestion cloud propre à Edge. Applies To **Device** confirme que ce sont bien les
versions machine qui sont arrivées.

Windows Security, App & browser control : l'avertissement a disparu et Reputation-based protection affiche
une coche verte. Les deux commutateurs d'applications potentiellement indésirables sont maintenant
contrôlés par stratégie : **Block apps** par `ES-Defender-AV`, **Block downloads** par
`CFG-Edge-SmartScreen`.

## Windows s'est chiffré tout seul

Aucune stratégie BitLocker n'existe dans le tenant, puisque le démontage les a toutes supprimées. Après
l'ajout du TPM et la connexion de Lea, le volume Windows est apparu verrouillé par BitLocker une fois monté
sur l'hôte :

```
Encryption Method:    XTS-AES 128
Lock Status:          Locked
Key Protectors:       Numerical Password, TPM
```

C'est le chiffrement automatique des appareils de Windows, pas une stratégie. Trois signes :

- **XTS-AES 128** est la valeur par défaut du chiffrement automatique. Une stratégie BitLocker Intune règle
  en général XTS-AES 256
- **Le mot de passe de récupération a quand même été déposé en séquestre dans Entra ID**, et était visible
  dans Intune sous les Recovery keys de l'appareil. Sur un appareil joint à Entra, le chiffrement
  automatique sauvegarde la clé de lui-même
- **Personne ne l'a demandé.** Il s'est activé dès que les conditions matérielles ont été réunies : TPM,
  Secure Boot, et une connexion Entra

La conséquence pratique était la leçon inscrite dans le commentaire d'en-tête de `04-fetch-hwid.ps1`
lui-même : un hôte ne peut pas lire le disque chiffré d'un invité. Le mot de passe de récupération, lu
depuis Intune, l'a déverrouillé sur l'hôte pour récupérer le hachage. Le disque est resté monté en lecture
seule du début à la fin.

Un chiffrement appliqué par les valeurs par défaut de Windows, et non par une stratégie, est exactement ce
qu'une stratégie BitLocker construite plus tard doit reprendre. La méthode de chiffrement en particulier
ne s'applique qu'au moment où un volume est chiffré, donc une stratégie qui règle XTS-AES 256 ne
convertira pas ce volume d'elle-même.

## La stratégie BitLocker prend le relais

Stratégie `ES-BitLocker-OS`, Endpoint security, Disk encryption, affectée à `Dyn-Autopilot-Devices`,
créée le 5 octobre :

| Paramètre | Valeur |
|---|---|
| Require Device Encryption | Enabled |
| Allow Warning For Other Disk Encryption | Disabled, condition 1 du chiffrement silencieux |
| Allow Standard User Encryption | Enabled, condition 2 du chiffrement silencieux, nécessaire parce que Lea est une utilisatrice standard |
| Configure Recovery Password Rotation | Refresh on for Entra ID-joined devices |
| Encryption method, operating system drives | XTS-AES 256 |
| Enforce drive encryption type | Used Space Only |
| Additional authentication at startup | Require TPM. PIN, startup key, key and PIN : Do not allow |
| Recovery | Do not enable BitLocker until recovery information is stored : True. Mots de passe de récupération uniquement, ce qu'Entra ID stocke. Options de récupération masquées pour les utilisateurs |

Le portail étiquette les paramètres de récupération "AD DS". Sur un appareil joint à Entra, ils écrivent
dans Entra ID.

### Prédiction contre résultat

**Prédiction :** le disque est en XTS-AES 128 et la stratégie demande 256, la méthode de chiffrement ne
s'applique qu'au moment du chiffrement, donc le disque reste en 128 et le rapport signale un écart.

**Sur l'appareil**, `manage-bde -status C:` depuis une session élevée :

```
Conversion Status:    Used Space Only Encrypted, 100%
Encryption Method:    XTS-AES 128
Protection Status:    Protection On
Key Protectors:       Numerical Password (AAD backup), TPM
```

**Dans Intune**, Encryption report : état du profil Succeeded, détail d'état **"TPM not used for
protection of OS volume, but is required by policy"**.

La prédiction était donc à moitié juste. Le disque est bien resté en 128. Le rapport n'a pas signalé
l'écart de méthode, et a signalé à la place un problème de TPM, que l'appareil contredit : le TPM est un
protecteur et la protection est active. Toujours ouvert : savoir si le rapport est périmé, issu d'une
remontée antérieure à la prise d'effet de la stratégie, ou si Windows rapporte quelque chose que la liste
des protecteurs ne montre pas.

### Ce que l'appareil a réellement reçu

`06-bitlocker-status.ps1`, exécuté dans la machine, lit l'enregistrement propre de l'appareil au lieu du
rapport.

**La première exécution disait que quatre des huit paramètres étaient "(not present)".** C'était mon
script, pas l'appareil. Il demandait des noms de valeurs que j'avais supposés, et une réponse vide à une
question mal nommée ressemble exactement à « non défini ». La deuxième exécution a listé ce qu'il y avait
vraiment dans la clé, et a montré comment Windows stocke les paramètres de modèle d'administration :

- La clé fusionnée `PolicyManager\current\device\BitLocker` contient les paramètres CSP simples sous forme
  de valeurs (`RequireDeviceEncryption 1` et ainsi de suite)
- Pour les paramètres de modèle, elle ne contient qu'un pointeur, `<name>_ADMXInstanceData`, vers la clé
  de la source qui l'a envoyé : `PolicyManager\providers\2C56FB1B-...\default\Device\BitLocker`, qui est
  l'inscription Intune
- La vraie valeur se trouve là, sous forme de fragment XML

Décodé :

| Paramètre | Valeur brute sur l'appareil | Signification |
|---|---|---|
| EncryptionMethodByDriveType | `EncryptionMethodWithXtsOsDropDown_Name value="7"` | XTS-AES 256. 6 serait XTS-AES 128 |
| SystemDrivesEncryptionType | `OSEncryptionTypeDropDown_Name value="2"` | Used Space Only. 1 serait le chiffrement complet |
| SystemDrivesRecoveryOptions | `OSActiveDirectoryBackup_Name value="true"` | Sauvegarder les informations de récupération, ce qui sur cet appareil signifie Entra ID |
| SystemDrivesRequireStartupAuthentication | `ConfigurePINUsageDropDown_Name value="0"` | Code PIN de démarrage non autorisé |

Les huit paramètres sont arrivés, tous tels que configurés. Le protecteur TPM est scellé sur les **PCR 7 et
11**, "Uses Secure Boot for integrity validation".

Donc chaque fait côté appareil contredit le "TPM not used" du rapport. Et l'écart que Microsoft documente
pour exactement cette situation, un disque déjà chiffré avec une méthode différente de celle de la
stratégie, n'est pas apparu non plus dans le rapport. Les deux indiquent un rapport en retard, retard dont
le rapport lui-même prévient qu'il peut atteindre 24 heures.

Le disque a ensuite été déchiffré et rechiffré par la stratégie, ci-dessous, ce qui supprime complètement
l'écart de méthode. **Test : relire le rapport après 24 heures.** Attendu maintenant : aucun détail d'état
du tout. Si le message TPM est toujours là avec le disque fraîchement chiffré sous la stratégie,
l'explication du retard est fausse.

**Résultat, 6 octobre :** état du profil Succeeded, détails d'état **Success**. Le message TPM a disparu.

Ce que cela prouve et ne prouve pas : entre les deux lectures, deux choses ont changé, le temps écoulé et
le chiffrement lui-même, y compris un nouveau protecteur TPM créé par la stratégie. L'un ou l'autre a pu
effacer le message. Le résultat est donc **compatible avec** un rapport qui aurait été en retard, et ne le
prouve pas. Un test propre aurait attendu 24 heures avant de rechiffrer. Changer deux variables à la fois
est ce qui a rendu celui-ci non concluant.

### Déchiffrer et laisser la stratégie rechiffrer

Le correctif documenté par Microsoft pour un disque chiffré avant la stratégie, avec une méthode
différente, est de déchiffrer et de laisser la stratégie chiffrer à nouveau. Fait le 5 octobre. Cela a
aussi réglé le sort d'une deuxième clé exposée : le mot de passe de récupération issu de la rotation était
lui aussi apparu à l'écran, lors d'un `manage-bde -protectors -get` lancé après la rotation.

**Avant de commencer :** NordVPN a de nouveau été trouvé en cours d'exécution sur l'hôte, son service de
retour sur Automatic alors qu'il avait été réglé sur Manual. Avec "do not enable until recovery
information is stored", un chemin DNS cassé aurait laissé le disque déchiffré indéfiniment, parce que la
sauvegarde de la clé doit d'abord atteindre Entra ID. Le journal contenait déjà un dépassement de délai
vers Entra ID daté du 3 octobre. Arrêté, puis résolution DNS de `login.microsoftonline.com` confirmée
depuis l'intérieur de la machine.

`Disable-BitLocker -MountPoint C:`, pas `Suspend-BitLocker`. Suspend laisse le disque chiffré avec la clé
stockée en clair jusqu'à la reprise ou au redémarrage, ce dont les mises à jour de firmware ont besoin.
Disable déchiffre entièrement et supprime chaque protecteur.

Observé :

- **Protection Status est passé à Off à l'instant où le déchiffrement a commencé**, avec le disque encore
  chiffré à 100 %. À partir de cette seconde, le disque est effectivement sans protection
- Le déchiffrement a pris environ six minutes. Ensuite : `FullyDecrypted`, méthode `None`, protecteurs `{}`
- Redémarré, pour que le rapport d'intégrité au démarrage enregistre BitLocker désactivé
- **Aucune synchronisation, aucun clic.** Environ quatre minutes après le redémarrage : `EncryptionInProgress`,
  `XtsAes256`. Lea, utilisatrice standard, n'a vu aucune invite

Le journal BitLocker Management, du plus ancien au plus récent :

| Heure | Événement | |
|---|---|---|
| 14:19 | 770 | Déchiffrement démarré |
| 14:26 | 796 | Chiffrement logiciel, pas le chiffrement matériel du disque |
| 14:26 | 775 | Nouveau protecteur mot de passe de récupération créé |
| 14:26 | **845** | **Informations de récupération sauvegardées dans Entra ID** |
| 14:26 | 892 | Clé scellée sur le TPM, PCR 7 et 11, source Secure Boot |
| 14:26 | 775 | Nouveau protecteur TPM créé |
| 14:26 | **768** | **Chiffrement démarré, XTS-AES 256** |

**845 avant 768** : la clé était dans Entra ID avant qu'un seul secteur ne soit chiffré. Cet ordre est
toute la raison d'être de "Do not enable BitLocker until recovery information is stored".

Résultat : `FullyEncrypted`, `XtsAes256`, protection On, les deux protecteurs neufs. Rien de l'ancien
chiffrement ni d'aucune des deux clés exposées ne subsiste.

### La conformité a suivi le démarrage, pas le disque

| Moment | Disque | `CP-Windows`, ligne BitLocker |
|---|---|---|
| Démarré après le déchiffrement | Non chiffré au démarrage, puis rechiffré en quelques minutes | **Not compliant**, toujours affiché alors que le disque était entièrement chiffré depuis vingt minutes |
| Redémarré après le rechiffrement, puis attendu | Chiffré | **Compliant** |

La vérification de conformité BitLocker lit le rapport d'intégrité que Windows écrit au démarrage. Une
synchronisation ne le rafraîchit pas, seul un redémarrage le fait, et Intune l'évalue ensuite selon son
propre calendrier. Une vérification faite quelques minutes après le redémarrage affichait encore Not
compliant. Environ une demi-heure plus tard, elle affichait Compliant.

La conséquence en production : avec un accès conditionnel exigeant un appareil conforme, et l'action de
non-conformité réglée sur Immediately, déchiffrer la machine d'un utilisateur le bloque hors de
Microsoft 365 jusqu'à ce qu'un démarrage ultérieur ait été rapporté et évalué.

### La clé de récupération a été exposée, donc elle a été renouvelée

`manage-bde -protectors -get C:` affiche le mot de passe de récupération complet de 48 chiffres. Une
capture d'écran de celui-ci a atterri dans la conversation de travail, donc la clé a été traitée comme
consommée et renouvelée par rotation depuis Intune : appareil, BitLocker key rotation. C'est l'action que
le paramètre de rotation de la stratégie active. L'appareil a ensuite rapporté un nouvel identifiant de
protecteur mot de passe de récupération.

Vérifié avec une commande qui montre les identifiants sans le secret :

```powershell
(Get-BitLockerVolume C:).KeyProtector | Select KeyProtectorId, KeyProtectorType
```

`manage-bde -protectors -get` est le bon outil pour le diagnostic et le mauvais devant un partage d'écran.

## Le TPM a modifié le hachage matériel

Hachage récolté avant et après l'ajout du TPM, comparé octet par octet :

| | Avant TPM | Après TPM |
|---|---|---|
| Numéro de série | `<serial-redacted>` | inchangé |
| Longueur du hachage | 4000 caractères, 3000 octets | 4000 caractères, 3000 octets |
| Octets porteurs de données | 766 | 1112 |
| Remplissage à zéro | 2234 | 1888 |
| Octets différents | | 770 sur 3000, à partir de l'octet 2 |

Le hachage est un conteneur de taille fixe de 3000 octets, principalement du remplissage à zéro quand des
composants manquent. Ce remplissage est la longue série de caractères `A` à la fin du texte Base64. L'ajout
du TPM a rempli 346 octets de plus. Décoder quels champs ont changé demande l'outil `oa3tool` de
Microsoft, qui n'a pas été lancé, donc l'affirmation s'arrête ici à « le TPM a ajouté des données et le
hachage a changé ».

La première différence si tôt, à l'octet 2, est cohérente avec un champ de longueur dans l'en-tête qui
change et décale tout ce qui suit. C'est une inférence, pas un décodage.

Intune détient toujours le hachage **d'avant le TPM**.

Toujours ouvert :

- **Autopilot reconnaît-il encore la machine ?** À tester par un Autopilot Reset, en regardant si le profil
  s'applique à nouveau. Pas de supposition
- Profils de configuration encore à construire : pare-feu, anneaux de mise à jour, intégrité de la mémoire.
  BitLocker, Defender Antivirus et Edge SmartScreen sont faits, ci-dessus

## Échéance des licences

L'essai Business Premium devait se terminer le 27 septembre 2026. **Prolongé une fois, le 25 septembre,
jusqu'au 27 octobre 2026.** Gratuit, facturation récurrente laissée sur Off, et l'option de prolongation est
maintenant grisée, donc il ne peut pas être prolongé une nouvelle fois.

Il fournit Intune et Entra ID P1 à chaque utilisateur, et l'inscription automatique, les groupes
dynamiques et l'accès conditionnel dépendent tous d'Entra ID P1. Il existe un siège Intune Plan 1 payant,
valable jusqu'au 20 août 2027, qui ne couvre pas Entra ID P1.
