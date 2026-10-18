# Jour 3 : Installation de Windows, jonction Entra et inscription Intune

*Trois jours perdus sur une machine virtuelle qui refusait de démarrer, puis une journée entière perdue sur une erreur d'inscription dont la cause tenait en un clic. La journée la plus coûteuse et la plus utile de la semaine.*

Mercredi 19 au jeudi 20 août 2026 · Parcours d'étude MD-102 · VM `W11-CORP-01` / nom d'hôte `LABVMGOCE`

**Ce qui existait à la fin de la journée**

- Windows 11 installé sur `W11-CORP-01`, appliqué avec DISM plutôt qu'installé depuis l'ISO
- Compte administrateur local `labadmin`, disposition de clavier suisse romand, paramètres régionaux corrects
- L'appareil réellement **joint à Entra**, pas simplement enregistré
- Autorité MDM définie sur le tenant, le correctif qui a tout débloqué
- Appareil inscrit avec succès dans Intune et visible sous All devices
- 32 tâches planifiées sous `\Microsoft\Windows\EnterpriseMgmt\`, la preuve de l'inscription

## Partie 1 : La VM refusait de démarrer. Trois jours.

### Le symptôme

```
SCSI DVD (0,1)
The boot loader failed.
```

La VM était correctement configurée. L'ISO était celle de Microsoft. Elle refusait de démarrer.

### Ce qui a été éliminé, et comment

| Hypothèse | Comment elle a été testée | Résultat |
|---|---|---|
| Téléchargement ISO corrompu | Retéléchargé et comparé les hachages, identique à l'octet près | Écarté |
| ISO réempaquetée ou non originale | Inspecté la liste des fichiers ; `__chunk_data` à la racine semblait suspect | **Mon erreur.** Le retéléchargement identique à l'octet près l'a réfutée. Le fichier est normal. |
| Catalogue de démarrage cassé | Lu le catalogue de démarrage El Torito brut. Section EFI valide au LBA 555, secteur de démarrage FAT12 valide | Écarté |
| Mauvaise architecture | Vérifié le type de machine de l'en-tête PE : `0x8664`, correct pour x64 | Écarté |
| Blocage par Secure Boot | Testé avec Secure Boot activé et désactivé | Écarté |
| Disposition du contrôleur SCSI | Deux ordres différents de disque et de DVD | Écarté |
| Mémoire dynamique / points de contrôle | Les deux désactivés | Écarté |
| Définition de VM corrompue | Supprimée et reconstruite de zéro | Écarté |

> **La vraie leçon de trois jours**
>
> Chacun de ces tests était raisonnable. L'erreur n'était aucun test en particulier, c'était de continuer à déboguer une voie alors qu'une autre voie existait. La question qui y a mis fin n'était pas « pourquoi cette ISO ne démarre-t-elle pas ? » mais **« ai-je vraiment besoin de démarrer depuis une ISO ? »**
>
> Non. Un installeur ISO est une enveloppe de confort autour de deux opérations : appliquer une image Windows sur un disque, et écrire un chargeur de démarrage. Les deux peuvent se faire directement.

### Le correctif : appliquer l'image avec DISM

> **Pourquoi**
>
> **« DISM »**, Deployment Image Servicing and Management. L'outil de Microsoft pour travailler hors ligne sur des images Windows. **« WIM »**, Windows Imaging Format, le fichier compressé à l'intérieur de l'ISO qui contient le système d'exploitation proprement dit. L'installeur dans lequel on clique d'habitude est une interface qui finit par appeler DISM.
>
> Le faire à la main saute entièrement le processus de démarrage. Le disque est monté sur le *portable*, écrit depuis le portable, puis démonté et rendu à la VM. La VM n'a jamais à démarrer depuis un support amovible, donc ce qui clochait sur cette voie cesse d'avoir de l'importance.

- **1. Monter** Attacher le disque virtuel de la VM au portable comme un lecteur normal.
- **2. Partitionner** Créer la partition système EFI et la partition Windows.
- **3. Appliquer** Décompresser le WIM sur la partition Windows.
- **4. Fichiers de démarrage** Écrire le chargeur de démarrage UEFI. Démonter. Démarrer la VM.

**Portable, PowerShell en administrateur.** Monter le disque et lui donner une table de partitions GPT :

```
Mount-VHD -Path "D:\VMs\W11-CORP-01\W11-CORP-01.vhdx"
Initialize-Disk -Number 1 -PartitionStyle GPT
```

Créer la partition système EFI, 500 Mo, FAT32, avec le GUID de type GPT qui la marque comme ESP :

```
New-Partition -DiskNumber 1 -Size 500MB `
  -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" -DriveLetter S
Format-Volume -DriveLetter S -FileSystem FAT32 `
  -NewFileSystemLabel "SYSTEM" -Confirm:$false
```

> **Règle Microsoft : l'ESP doit être en FAT32**
>
> **« ESP »**, EFI System Partition. Le firmware UEFI y lit le chargeur de démarrage avant que Windows n'existe. La spécification UEFI exige que cette partition soit en FAT32 ; le firmware n'est pas tenu de comprendre NTFS. Formatez-la en NTFS et la machine ne démarrera pas, sans erreur utile.
>
> Le GUID `c12a7328-f81f-11d2-ba4b-00a0c93ec93b` est l'identifiant standard de type de partition GPT pour une partition système EFI. C'est ainsi que le firmware trouve la partition en premier lieu.

Créer et formater la partition Windows avec tout l'espace restant :

```
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter W
Format-Volume -DriveLetter W -FileSystem NTFS `
  -NewFileSystemLabel "Windows" -Confirm:$false
```

Appliquer l'image Windows, puis écrire le chargeur de démarrage :

```
Expand-WindowsImage -ImagePath "E:\sources\install.wim" -Index 6 -ApplyPath "W:\"
bcdboot W:\Windows /s S: /f UEFI
```

> **Pourquoi -Index 6 et pourquoi /f UEFI**
>
> Un seul `install.wim` contient plusieurs éditions, Home, Home N, Pro, Pro N, Education, Enterprise et ainsi de suite. Chacune a un numéro d'index. L'index 6 est l'édition nécessaire ici. Exécutez `Get-WindowsImage -ImagePath "E:\sources\install.wim"` pour les lister avant de choisir.
>
> `bcdboot` écrit les Boot Configuration Data, le chargeur de démarrage et son magasin. `/s S:` dit de placer les fichiers de démarrage sur l'ESP. `/f UEFI` dit d'écrire uniquement les fichiers de démarrage UEFI, pas ceux du BIOS hérité. Sur une VM de génération 2 il n'y a pas de chemin BIOS, donc écrire les deux est inutile et écrire le mauvais laisse une machine qui ne démarre pas.

Ensuite démonter le disque et démarrer la VM. Elle a démarré directement sur l'OOBE.

## Partie 2 : Passer l'OOBE

> **Pourquoi**
>
> **« OOBE »**, Out Of Box Experience. L'assistant de configuration au premier démarrage : région, clavier, réseau, compte. Sur un appareil d'entreprise, c'est exactement là qu'Autopilot prend le relais, raison pour laquelle le comprendre compte au-delà du simple fait de le passer.

Windows 11 impose un compte Microsoft pendant l'OOBE par défaut. Pour un labo, on veut d'abord un compte local, pour que l'appareil soit joint délibérément plutôt que par accident.

**[VM]** Sur l'écran réseau, appuyer sur Shift + F10 pour ouvrir une invite de commandes→ saisir ms-cxh:localonly→ Enter

Cela ouvre la boîte de dialogue cachée de création de compte local. Le compte de labo créé était `labadmin`.

> **Ce qui a cassé : un mot de passe correct refusé à la connexion**
>
> Le mot de passe généré automatiquement fonctionnait collé dans un navigateur mais échouait à l'écran de connexion Windows, à répétition.
>
> **Cause :** le mot de passe contenait `)`. La disposition de clavier de la VM diffère de celle sous laquelle le mot de passe a été saisi. Sur une disposition suisse romande, le caractère produit par une touche physique donnée n'est pas celui d'une disposition US. Le mot de passe était correct. Les frappes ne l'étaient pas.
>
> **Correction :** réinitialiser vers un mot de passe uniquement alphanumérique. En labo, c'est le bon compromis. En production, on corrige la disposition de clavier à la place.

### Le correctif permanent : un fichier de réponses

Plutôt que de se battre avec l'OOBE à la main à chaque reconstruction, un fichier de réponses `unattend.xml` a été écrit pour définir automatiquement les paramètres régionaux, le clavier, le fuseau horaire et le compte local.

```
<InputLocale>100c:0000100c</InputLocale>   <!-- Swiss French -->
<SystemLocale>fr-CH</SystemLocale>
<UILanguage>en-GB</UILanguage>
<UserLocale>fr-CH</UserLocale>
<TimeZone>W. Europe Standard Time</TimeZone>
```

> **À retenir pour la suite**
>
> Le fichier de réponses se trouve dans `D:\VMs\unattend.xml`. Chaque reconstruction future l'utilise. Trois minutes de clics supprimées définitivement, et le problème de disposition de clavier ne peut plus se reproduire.

## Partie 3 : Jonction Entra ou enregistrement Entra. La distinction qui compte le plus.

Les deux se ressemblent presque dans l'interface et signifient des choses complètement différentes. Les confondre est l'une des erreurs de support les plus courantes sur le terrain, et l'examen le teste directement.

|  | **Joint** à Entra (Entra joined) | **Enregistré** auprès d'Entra (Entra registered, workplace join) |
|---|---|---|
| Qui a une identité | L'**appareil** appartient à l'organisation | Le **compte professionnel de l'utilisateur** est ajouté à un appareil personnel |
| Connexion | On se connecte à Windows avec le compte professionnel | On se connecte à Windows avec un compte personnel ou local |
| Usage typique | Appareil appartenant à l'entreprise | BYOD, téléphone ou portable personnel |
| Gestion Intune | Gestion complète de l'appareil | Limitée, au niveau des applications |

> **Ce qui a cassé : enregistré au lieu de joint**
>
> Sur la page **Access work or school**, il y a deux choses possibles. Saisir l'e-mail dans la case **Connect** effectue un *enregistrement*. Cliquer sur le petit lien bleu intitulé **"Join this device to Microsoft Entra ID"** effectue une *jonction*.
>
> La case e-mail est grande et évidente. Le lien est un petit texte en dessous. Le mauvais a été utilisé.
>
> **Correction :** déconnecter le compte professionnel, puis utiliser le lien bleu.

**[VM]** Settings→ Accounts→ Access work or school→ Connect→ puis le lien bleu Join this device to Microsoft Entra ID

### Comment vérifier lequel a vraiment eu lieu

**[VM]** PowerShell→ dsregcmd /status

| Champ | Ce qu'il indique |
|---|---|
| `AzureAdJoined` | `YES` signifie réellement joint. C'est celui qui compte. |
| `WorkplaceJoined` | `YES` signifie enregistré. Si celui-ci est YES et AzureAdJoined est NO, vous avez fait le mauvais. |
| `AzureAdPrt` | Primary Refresh Token. `YES` signifie que l'appareil détient un jeton valide et que l'authentification unique fonctionne. |
| `MdmUrl` | Renseigné signifie que l'appareil sait où se trouve son service de gestion. Vide signifie qu'il est joint mais pas géré. |
| `Device Name` | **À vérifier en premier, à chaque fois.** |

> **Ce qui a cassé : la commande a été exécutée sur la mauvaise machine**
>
> `dsregcmd /status` a été exécuté sur le portable hôte en croyant qu'il tournait dans la VM. Il a produit une page entière de sortie assurée, cohérente, entièrement hors sujet : `Device Name : DESKTOP-D8QPBL1`, `WorkplaceTenantName : PETROV`, invite dans `C:\Users\Admin`.
>
> **Cause :** deux fenêtres PowerShell qui se ressemblent exactement.
>
> **Correctif, et désormais règle permanente :** lire `Device Name` avant de lire quoi que ce soit d'autre. La VM est `LABVMGOCE`. Tout autre nom signifie que vous êtes sur la mauvaise machine. Chaque instruction de ce labo est désormais étiquetée **[Portable]** ou **[VM]** pour cette raison.

## Partie 4 : Erreur 80180003, et une journée entière pour trouver une cause qui tient en un clic

### Le symptôme

```
Something went wrong.
This user is not authorized to enroll. You can try to do this again
or contact your system administrator with the error code 80180003.
```

L'appareil était joint. L'utilisateur avait sa licence. Inscription refusée.

### Tout ce qui a été éliminé, dans l'ordre

| Vérifié | Où | Résultat |
|---|---|---|
| MDM user scope | Entra → Mobility (MDM and MAM) → Microsoft Intune → MDM user scope = All | Déjà correct |
| WIP / MAM user scope | Même panneau | Pas la cause |
| Restrictions d'inscription | Intune → Devices → Enrollment → Enrollment device platform restrictions | Windows MDM autorisé |
| Restrictions de limite d'appareils | Intune → Devices → Enrollment → Enrollment device limit restrictions | Sous la limite |
| Objets d'appareil obsolètes | Entra → Devices → All devices | Nettoyés, aucun changement |
| Licences | admin.microsoft.com → Users → Licenses and apps | **Vraie lacune trouvée**, Intune Suite n'avait pas de base Plan 1. Acheté une licence, CHF 6.50/mois. Nécessaire, mais pas la cause. |

### La vraie cause

> **Cause racine : l'autorité MDM était sur None**
>
> L'**autorité MDM** du tenant n'avait jamais été définie. Tous les autres paramètres de toute la chaîne étaient corrects et cela ne changeait rien, parce que le tenant n'avait pas déclaré quel service avait le droit de gérer les appareils.

![Panneau Choose MDM Authority avec None sélectionné : aucun service n'avait le droit de gérer les appareils](../../screenshots/01-day03-mdm-authority-none.png)

> **Pourquoi**
>
> **« MDM »**, Mobile Device Management. L'**autorité MDM** est une valeur unique au niveau du tenant qui désigne quel service possède la gestion des appareils. Historiquement, le choix se faisait entre Intune et Configuration Manager, et le paramètre existe toujours parce qu'un tenant ne doit pas avoir deux systèmes qui se disputent les mêmes appareils.
>
> Tant qu'elle n'est pas définie, la réponse à « qui gère les appareils ici ? » est *personne*, et chaque inscription est refusée à juste titre. Le message d'erreur dit que l'utilisateur n'est pas autorisé, ce qui vous oriente vers l'utilisateur. L'utilisateur n'a jamais été le problème.

### Comment elle a été trouvée

Pas par davantage de vérifications manuelles. En exécutant le diagnostic de Microsoft lui-même :

**[Navigateur]** https://aka.ms/IntuneWindowsEnrollment

Il a renvoyé, en une ligne, ce qu'une journée entière d'élimination n'avait pas donné :

> Devices cannot enroll because the MDM Authority is not set on the tenant.

### Le correctif, et pourquoi il est difficile à trouver

> **Règle Microsoft : aucun chemin de menu n'existe pour ce paramètre**
>
> Le panneau d'autorité MDM n'est accessible que par URL directe. Il n'existe aucun chemin de navigation vers lui dans les menus du centre d'administration Intune. Sur les tenants créés récemment, elle est souvent définie automatiquement, ce qui explique qu'elle n'apparaisse pas dans la plupart des tutoriels et que rien dans l'interface ne signale qu'elle manque.

**[Navigateur]** https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/ChooseMDMAuthorityBlade→ sélectionner Intune MDM Authority

### Confirmer que l'inscription a bien eu lieu

**[VM]** PowerShell→ `(Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*").Count`

Sortie : **32**.

> **Pourquoi c'est la vraie preuve**
>
> Quand un appareil Windows s'inscrit, le client MDM crée un dossier de tâches planifiées sous `\Microsoft\Windows\EnterpriseMgmt\`. Ce sont ces tâches qui se signalent réellement auprès d'Intune, récupèrent les stratégies et remontent l'état. Zéro tâche signifie que l'appareil n'est pas inscrit, quoi qu'en dise n'importe quel portail. Un dossier rempli signifie que le canal de gestion est réellement actif.
>
> C'est une bien meilleure vérification que de regarder le portail Intune, parce que le portail montre l'enregistrement qu'Intune détient, tandis que les tâches planifiées montrent ce que l'appareil lui-même croit.

## La liste de contrôle des échecs d'inscription, dans l'ordre de vérification

- **1. Autorité MDM** Est-elle seulement définie ? URL directe uniquement.
- **2. Licence** Attribuée, pas seulement achetée. Plan 1 présent comme base.
- **3. MDM user scope** Inclut-elle cet utilisateur ?
- **4. Restrictions** Plateforme autorisée. Limite d'appareils non atteinte.
- **5. Diagnostic** aka.ms/IntuneWindowsEnrollment

> **La leçon honnête**
>
> L'étape 5 aurait dû être l'étape 1. Microsoft publie un diagnostic qui lit la configuration réelle du tenant et nomme le défaut. Une journée a été passée à faire à la main ce qu'il fait en quelques secondes. Quand un éditeur livre un diagnostic pour exactement le problème que vous avez, exécutez-le avant de commencer à raisonner.

## À retenir pour l'examen

- **Joint** = l'appareil appartient à l'organisation. **Enregistré** = un compte professionnel ajouté à un appareil personnel. `dsregcmd /status` vous dit lequel.
- `AzureAdJoined : YES` est le champ qui confirme une vraie jonction. `WorkplaceJoined : YES` seul signifie que vous avez fait l'autre chose.
- L'autorité MDM est à l'échelle du tenant et doit être définie avant qu'un appareil puisse s'inscrire.
- L'erreur 80180003 accuse l'utilisateur. Vérifier d'abord le tenant.
- L'ESP doit être en FAT32. Le firmware UEFI n'est pas tenu de lire NTFS.
- Un appareil Windows inscrit a des tâches planifiées sous `\Microsoft\Windows\EnterpriseMgmt\`.
- `Get-WindowsImage` liste les éditions contenues dans un install.wim et leurs numéros d'index.

*Jour 3 sur 5, série de labo MD-102. Rédigé à partir du journal de session, 24 août 2026. Tenant de labo uniquement, rien de tout cela n'est de la production. Les identifiants du labo sont volontairement exclus de ce document.*
