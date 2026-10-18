# Jour 4 : Conformité, configuration et BitLocker

*La différence entre une stratégie qui juge un appareil et une stratégie qui le modifie, pourquoi un appareil sain continuait à remonter non conforme, et ce dont BitLocker a réellement besoin pour tourner.*

Vendredi 21 août 2026 · Parcours d'étude MD-102 · VM `LABVMGOCE`

**Ce qui existait en fin de journée**

- Une stratégie de conformité qui évalue la VM et remonte **Compliant** sur les deux paramètres
- BitLocker activé, chiffrement terminé, clé de récupération déposée dans Intune
- Un profil de configuration qui applique une bannière d'ouverture de session, confirmée visible sur la VM
- Environ 24 Go de disque récupérés sur l'hôte et plusieurs Go de RAM libérés

## 1. Conformité ou configuration. La distinction centrale de la journée.

- **Stratégie de conformité** Regarde l'appareil. Rend un verdict : conforme ou non.
- **Profil de configuration** Modifie l'appareil. En silence. Pas de verdict, pas d'invite, pas de notification.

> **Pourquoi cette séparation existe**
>
> Les deux répondent à des questions différentes et alimentent des systèmes différents.
>
> Une **stratégie de conformité** produit un signal. C'est ce signal que consomme l'accès conditionnel : « seuls les appareils conformes accèdent à la messagerie de l'entreprise ». C'est une barrière, pas un correctif. Un appareil qui échoue à la conformité est toujours exactement dans le même état, il a simplement été marqué.
>
> Un **profil de configuration** est le correctif. Il pousse un paramètre et l'appareil l'applique. L'utilisateur n'est ni consulté ni informé. Quand le profil est retiré plus tard, le paramètre revient à sa valeur précédente.
>
> Il faut les deux. La configuration rend l'appareil correct. La conformité le prouve, et permet au contrôle d'accès d'agir sur cette preuve.

## 2. Construction de la stratégie de conformité

**[Navigateur]** intune.microsoft.com→ Devices→ Compliance→ Create policy→ Platform Windows 10 and later

### Les paramètres qui ont échoué, et pourquoi

Le premier essai utilisait les paramètres **Device Health** : BitLocker, Secure Boot, Code integrity. L'appareil est remonté non conforme sur BitLocker et Secure Boot alors que les deux étaient activés, de façon vérifiable.

Vérifié directement sur la VM :

```
Get-BitLockerVolume -MountPoint C:     # ProtectionStatus : On
Confirm-SecureBootUEFI                 # True
```

> **Ce qui a cassé : un appareil sain remonté non conforme**
>
> **Cause :** les paramètres Device Health ne lisent pas l'état en direct de l'appareil. Ils lisent un rapport **Device Health Attestation** (attestation d'intégrité de l'appareil) généré au démarrage et signé par le TPM.
>
> **Corrigé plus tard :** ma première conclusion ici était qu'un TPM virtuel Hyper-V ne peut pas produire une attestation acceptée par le service, et que ces paramètres ne pourraient donc jamais passer sur une VM. La reconstruction a prouvé le contraire. Sur un TPM virtuel 2.0 Hyper-V, BitLocker, Secure Boot et Code Integrity ont tous été évalués **Compliant**, voir [reconstruction, Conformité](../rebuild/README.md#conformité).
>
> Ce qui a réellement échoué ce jour-là n'a jamais été identifié, parce que je ne l'ai pas retesté. Deux éléments montrés par la reconstruction colleraient : le rapport n'est écrit qu'au démarrage, donc un changement fait après le démarrage n'est pas vu avant un redémarrage, et Intune évalue le rapport selon son propre calendrier, environ une demi-heure après le redémarrage dans la reconstruction.

> **La règle Microsoft : l'attestation se fait au démarrage, pas en direct**
>
> Les paramètres Device Health Attestation évaluent un rapport signé produit pendant le démarrage. Ils n'interrogent pas le système en cours d'exécution. La conséquence qui tombe à l'examen : un changement fait après le démarrage n'est pas reflété tant que l'appareil n'a pas redémarré.
>
> Une version antérieure citait une seconde conséquence, à savoir que les machines virtuelles ne peuvent pas satisfaire ces paramètres. La reconstruction l'a réfutée.

### Les paramètres qui ont fonctionné

Je suis passé à des paramètres qu'Intune évalue localement sur l'appareil plutôt qu'au travers de l'attestation :

**[Navigateur]** Compliance settings→ System Security→ Encryption→ Require encryption of data storage on device: Require

**[Navigateur]** Compliance settings→ Device Security→ Trusted Platform Module (TPM): Require

Les deux ont renvoyé **Compliant**.

> **À retenir pour la suite**
>
> Deux paramètres peuvent donner l'impression de vérifier la même chose et être évalués par des mécanismes totalement différents. "Require encryption of data storage" interroge l'appareil. "BitLocker" sous Device Health interroge le service d'attestation. Sur du matériel réel, les deux fonctionnent. Sur une VM, seul le premier fonctionne.
>
> Quand un résultat de conformité contredit ce que vous voyez sur l'appareil, la question à poser est *comment ce paramètre est-il évalué*, pas *qu'est-ce qui cloche sur l'appareil*.

### Deux valeurs par défaut à connaître

> **La règle Microsoft : les appareils sans stratégie**
>
> Intune a un paramètre au niveau du tenant : **Mark devices with no compliance policy assigned as**, dont la valeur par défaut est **Compliant**. Tout appareil qu'aucune stratégie ne cible est donc remonté comme conforme.
>
> En production, c'est généralement faux et il faut le passer à **Not compliant**. Sinon, un appareil qui est sorti de tous vos groupes remonte au vert.
>
> intune.microsoft.com→ Devices→ Compliance→ Compliance policy settings

**"Not applicable"** dans un rapport de stratégie n'est pas un échec. Cela veut dire que le paramètre ne s'applique pas à cette plateforme ou à cet état de l'appareil. Un paramètre réservé à Windows sur un appareil Android remonte Not applicable, pas Non-compliant.

## 3. Affectation : l'erreur qui fait qu'une stratégie ne fait rien

> **Ce qui a cassé : le profil ne ciblait rien**
>
> Un profil de configuration a été créé, enregistré, et appliqué à zéro appareil.
>
> **Cause :** `Dyn-Windows-Devices` avait été ajouté sous **Excluded groups** au lieu de **Included groups**. La section Included affichait "No results" et je ne l'ai pas remarqué.
>
> **Correction :** retirer d'Excluded, ajouter dans Included.
>
> **Pourquoi c'est facile à faire :** les deux sections sont directement l'une au-dessus de l'autre dans l'onglet Assignments, toutes deux avec un bouton "Add groups" identique. L'enregistrement réussit dans les deux cas, une stratégie affectée à personne est valide, juste inutile.

> **Vérification systématique**
>
> Après avoir affecté une stratégie, quelle qu'elle soit, la rouvrir et relire l'onglet Assignments. Included doit nommer un groupe. Les exclusions doivent être vides, sauf si vous y avez mis quelque chose délibérément.

## 4. BitLocker

> **Pourquoi**
>
> **BitLocker** chiffre le volume entier. Sans la clé, un disque volé n'est que du bruit. La clé est scellée dans le **TPM** et n'est libérée que si la séquence de démarrage est inchangée, c'est pour cela qu'il se déverrouille sans mot de passe sur une machine saine et exige une clé de récupération sur une machine altérée.
>
> Un **mot de passe de récupération** est la solution de repli à 48 chiffres. S'il n'est que sur l'appareil, il ne sert à rien quand c'est l'appareil que vous avez perdu. Le déposer dans Intune est tout l'intérêt de gérer BitLocker de manière centralisée.

> **Ce qui a cassé : erreur 0x80310030**
>
> ```
> BitLocker cannot be enabled. Bootable media detected.
> ```
>
> **Cause :** l'ISO Windows 11 était encore attachée au lecteur DVD virtuel de la VM. BitLocker refuse de chiffrer tant qu'un média amorçable amovible est présent, parce que ce média est un moyen de contourner la protection qu'il s'apprête à appliquer.
>
> **Correctif, sur le portable :**
>
> ```
> Set-VMDvdDrive -VMName "W11-CORP-01" -Path $null
> ```

> **Ce qui a cassé : chiffrement bloqué à 54.9 %**
>
> La progression est restée à 54.9 % pendant plusieurs minutes, sans erreur.
>
> **Deux causes empilées :**
>
> 1. **Le portable était sur batterie.** BitLocker ralentit volontairement le chiffrement sur batterie, pour éviter de vider une machine en pleine opération. C'est un comportement documenté, pas un défaut.
> 2. **Un point de contrôle était actif.** Son disque de différenciation avait grossi jusqu'à 12.1 Go, donc chaque écriture touchait deux fichiers.
>
> **Correction :**
>
> - Brancher le portable
> - `powercfg /setactive SCHEME_MIN`, passer au mode d'alimentation High Performance
> - Supprimer le point de contrôle. L'espace libre sur D: de l'hôte est passé de 40.1 Go à 57.5 Go.

### Le dépôt de la clé, et comment le vérifier

**[Navigateur]** intune.microsoft.com→ Devices→ All devices→ LABVMGOCE→ Recovery keys

Clés présentes. C'est la vérification qui compte, une clé de récupération qui n'existe que sur l'appareil chiffré ne protège personne.

> **La règle Microsoft : espace utilisé ou volume entier**
>
> **Encrypt used disk space only** est rapide et correct pour un appareil neuf, parce qu'il n'y a aucune donnée antérieure à récupérer dans l'espace libre.
>
> **Encrypt entire drive** est obligatoire pour un appareil qui a déjà servi, parce que les fichiers supprimés restent récupérables dans l'espace non alloué tant qu'ils n'ont pas été écrasés.
>
> La règle pratique : appareil neuf, espace utilisé. Appareil existant, disque entier.

## 5. Le profil de configuration : une bannière d'ouverture de session

J'ai choisi un paramètre délibérément visible, pour pouvoir constater l'effet de mes yeux plutôt que de faire confiance à un portail.

**[Navigateur]** intune.microsoft.com→ Devices→ Configuration→ Create→ New Policy→ Platform Windows 10 and later→ Profile type Settings catalog

Deux paramètres, tous deux sous **Local Policies Security Options** :

- **Interactive Logon Message Title For Users Attempting To Log On**
- **Interactive Logon Message Text For Users Attempting To Log On**

> **Pourquoi une bannière est un vrai contrôle, pas un gadget**
>
> Une bannière d'ouverture de session est une exigence standard dans les environnements réglementés. Elle établit que l'utilisateur a été informé de la surveillance et des règles d'usage acceptable avant d'accéder au système, ce qui rend une sanction défendable. Elle figure dans la plupart des référentiels de sécurité exactement pour cette raison.

Après synchronisation, la bannière est apparue sur la VM à l'ouverture de session. Pas d'invite, pas de notification, pas de consentement de l'utilisateur. C'est bien le point : **un profil de configuration modifie la machine en silence.**

## 6. Nettoyage de l'hôte

Le lab manquait sans cesse de ressources, j'ai donc fait un audit complet du portable.

| Quoi | Action | Récupéré |
|---|---|---|
| Point de contrôle de la VM et son disque de différenciation | Supprimé | ~17 Go |
| Fichiers de VM orphelins | Supprimés | ~7 Go |
| Services d'arrière-plan Adobe Bridge, Adobe Synchronizer, Figma Agent, Grammarly, Slack | Arrêtés et désactivés | Plusieurs Go de RAM |
| Extensions Chrome : outils SEO, Tag Assistant, extension Adobe, Career IO, MetaMask | Supprimées. MetaMask déplacé en sauvegarde dans `D:\VMs\chrome-extensions-removed\METAMASK-FULL-BACKUP`, jamais supprimé. NordPass laissé intact. | Nombre de processus Chrome et RAM nettement en baisse |

> **Ce qui a cassé : Set-Service avec un tableau**
>
> `Set-Service -Name` dans Windows PowerShell 5.1 accepte un seul nom à la fois. `Stop-Service -Name` accepte un tableau. Passer un tableau au premier échoue.
>
> **Correction :** une boucle `foreach`. Des cmdlets qui se ressemblent dans le même module ne partagent pas forcément le même comportement de paramètres.

## 7. Ce qu'il faut retenir pour l'examen

- La conformité **évalue** et rend un verdict. La configuration **modifie** l'appareil, en silence.
- Les paramètres Device Health Attestation lisent un rapport signé au démarrage, pas l'état en direct. Un changement fait après le démarrage a besoin d'un redémarrage avant de compter.
- La valeur par défaut pour un appareil sans stratégie de conformité est **Compliant**. À changer en production.
- "Not applicable" signifie que le paramètre ne s'applique pas, pas qu'il a échoué.
- Vérifier Included et Excluded à chaque affectation. Une stratégie affectée à personne s'enregistre sans broncher.
- BitLocker refuse de démarrer avec un média amorçable attaché, 0x80310030.
- BitLocker ralentit sur batterie. C'est voulu.
- Chiffrement de l'espace utilisé pour les appareils neufs. Volume entier pour les appareils déjà en service.
- Déposer la clé de récupération. Le vérifier sous l'onglet **Recovery keys** de l'appareil.

*Jour 4 sur 5, série de labs MD-102. Rédigé à partir du journal de session, 24 août 2026. Tenant de lab uniquement, rien de tout cela n'est de la production.*
