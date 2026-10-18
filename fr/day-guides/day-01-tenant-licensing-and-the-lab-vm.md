# Jour 1 : Tenant, licences et la VM de labo

*Obtenir un tenant Microsoft 365 avec les droits Intune, et une machine virtuelle Windows 11 qu'Intune acceptera.*

Lundi 17 août 2026 · Parcours d'étude MD-102 · Tenant `labtenant.onmicrosoft.com`

**Ce qui existait à la fin de la journée**

- Un tenant Microsoft 365, `labtenant.onmicrosoft.com`, administrateur général `admin@labtenant.onmicrosoft.com`
- Essai Microsoft Intune Suite : 250 licences, expirant le 15 novembre 2026, facturation récurrente désactivée
- Essai Microsoft Entra ID P2 : 100 licences
- Licences *attribuées* au compte administrateur, pas simplement achetées
- Hyper-V activé sur le portable
- Une machine virtuelle de génération 2 `W11-CORP-01` avec un TPM virtuel et Secure Boot, prête pour un système d'exploitation

## 1. Pourquoi un tenant, et pourquoi celui-ci

Intune n'est pas un logiciel qu'on installe. C'est un service qui vit à l'intérieur d'un tenant Microsoft 365. Rien dans le programme MD-102 ne peut se pratiquer sans, donc le tenant est l'étape zéro.

> **Pourquoi**
>
> **« Tenant »** (tenant) désigne l'instance dédiée du cloud Microsoft pour une seule organisation. Chaque compte utilisateur, groupe, enregistrement d'appareil, stratégie et licence appartient à exactement un tenant. Quand vous inscrivez un appareil, vous l'inscrivez *dans un tenant*. Deux tenants ne voient jamais les données l'un de l'autre.

### Les trois voies vers un tenant gratuit, et pourquoi deux d'entre elles ont échoué

| Voie | Résultat | Raison |
|---|---|---|
| **Microsoft 365 Developer Program**  (le bac à sable E5 gratuit classique) | Non disponible | Microsoft a fermé les inscriptions ouvertes. Il faut désormais un abonnement Visual Studio Enterprise ou Professional actif. Il n'y a aucune voie gratuite. |
| **Essai en libre-service Microsoft 365 E5** | Pas proposé en Suisse | La boutique suisse affiche E5 à CHF 54.33 par utilisateur et par mois et renvoie le bouton d'essai vers "contact sales". Aucun essai de 30 jours en libre-service n'existe sur cette boutique. |
| **Essai Microsoft Intune Suite** | **A fonctionné** | Libre-service, immédiat, 250 licences, aucun débit de carte si la facturation récurrente est désactivée. Tout ce que MD-102 teste se trouve ici. |

> **Règle Microsoft : essais et facturation**
>
> Un essai en libre-service se convertit automatiquement en abonnement payant à la fin de la période d'essai, sauf si la facturation récurrente est désactivée. Désactiver la facturation récurrente ne raccourcit *pas* l'essai. L'abonnement court toujours jusqu'à sa date d'expiration complète, il ne se renouvelle simplement pas.
>
> C'est pourquoi l'essai a été désactivé le premier jour plutôt que la veille de son expiration. Cela ne coûte rien et supprime le risque d'un débit surprise.

### Désactiver la facturation récurrente

**[Portable]** admin.microsoft.com→ Billing→ Your products→ Microsoft Intune Suite Trial→ Recurring billing: Off

## 2. Le piège des licences : achetée n'est pas attribuée

C'est la chose la plus utile apprise au Jour 1, et elle revient à l'examen.

- **Acheter / activer** Le tenant possède désormais 250 licences Intune. Elles sont dans un pool.
- **Attribuer** Une licence est rattachée à un compte utilisateur précis.
- **Droits actifs** Cet utilisateur peut désormais inscrire des appareils et utiliser le service.

Sautez la case du milieu et chaque symptôme ressemble à un tenant cassé. L'inscription échoue, des panneaux manquent, le portail affiche des fonctionnalités grisées. Rien n'est cassé. Le compte n'a simplement pas de licence.

**[Portable]** admin.microsoft.com→ Users→ Active users→ GocePetrov→ Licenses and apps→ cocher Microsoft Intune Suite et Microsoft Entra ID P2→ Save changes

> **Règle Microsoft : un changement de licence exige une nouvelle connexion**
>
> L'attribution de licence est inscrite dans le jeton d'accès émis à la connexion. Une session déjà ouverte garde son ancien jeton et ses anciens droits jusqu'à ce que ce jeton soit actualisé. Déconnectez-vous et reconnectez-vous, sinon le portail continuera de vous dire que vous n'avez pas la licence que vous venez d'attribuer.

### L'Intune Suite est un module complémentaire, pas un plan de base

Cela n'est apparu qu'au Jour 3, mais sa place est ici parce que c'est un fait de licence.

> **Règle Microsoft : Intune Suite exige un plan de base**
>
> **Microsoft Intune Suite** est un *module complémentaire*. Il superpose des fonctionnalités avancées (Remote Help, Endpoint Privilege Management, Advanced Analytics, Microsoft Tunnel) à un plan de base. Il ne porte pas lui-même le droit d'inscrire un appareil.
>
> **Microsoft Intune Plan 1** est le plan de base. Plan 1 porte les droits d'inscription MDM.
>
> Intune Suite sans Plan 1 en dessous, c'est une voiture sans moteur. Cela a été résolu en achetant une seule licence Intune Plan 1 à CHF 6.50 par mois.

## 3. Pourquoi le labo a besoin d'une machine virtuelle, pas du portable

Tout dans MD-102 consiste à faire des choses *à* un appareil géré : l'inscrire, le chiffrer, l'effacer, le réimager, le verrouiller. Rien de tout cela n'est survivable sur la machine sur laquelle vous travaillez tous les jours.

> **Pourquoi**
>
> **« VM »**, machine virtuelle. Un ordinateur complet qui tourne sous forme de logiciel à l'intérieur d'un autre ordinateur. Il a son propre disque, sa propre mémoire, son propre système d'exploitation, et sa propre identité pour ce qui concerne Intune. Quand vous le cassez, vous le supprimez et vous en construisez un autre. Quand vous l'effacez, rien de réel n'est perdu.
>
> **« Hyper-V »** est la plateforme de virtualisation intégrée de Microsoft, incluse dans Windows 11 Pro. Aucun logiciel tiers nécessaire.

### Activer Hyper-V

**[Portable]** Start→ saisir Turn Windows features on or off→ cocher Hyper-V (case parente, les deux enfants)→ OK→ redémarrer

## 4. Construire la VM, et pourquoi chaque paramètre est ce qu'il est

Ces commandes ont été exécutées dans **PowerShell en administrateur sur le portable**. Chacune des cmdlets Hyper-V `Get-VM*` et `Set-VM*` exige une élévation de privilèges. Un shell non élevé renvoie des erreurs d'accès refusé qui donnent l'impression que la VM n'existe pas.

#### Créer la machine

```
New-VM -Name "W11-CORP-01" -Generation 2 -MemoryStartupBytes 4GB `
  -Path "D:\VMs" -NewVHDPath "D:\VMs\W11-CORP-01\W11-CORP-01.vhdx" `
  -NewVHDSizeBytes 64GB -SwitchName "Default Switch"
```

| Paramètre | Pourquoi cette valeur |
|---|---|
| `-Generation 2` | La génération 2 fournit un firmware UEFI, ce qui permet Secure Boot et un TPM virtuel. La génération 1 est un BIOS hérité et ne peut pas du tout exécuter Windows 11. **La génération ne peut pas être changée après la création.** Trompez-vous et vous reconstruisez. |
| `-MemoryStartupBytes 4GB` | Le minimum Windows 11 est 4 Go. Sur un portable de 15.46 Go, c'est tout ce qui peut être dégagé. |
| `-NewVHDSizeBytes 64GB` | Le minimum Windows 11 est 64 Go. Le disque est à extension dynamique, il ne consomme donc que ce qui est réellement écrit. |
| `-SwitchName "Default Switch"` | Le commutateur NAT intégré d'Hyper-V. La VM partage la connexion internet du portable sans configuration réseau supplémentaire. L'accès internet n'est pas facultatif ici, un appareil géré dans le cloud qui ne peut pas atteindre le cloud n'est pas un appareil qu'Intune peut gérer. |

#### Désactiver ce qui consomme discrètement du disque

```
Set-VM -Name "W11-CORP-01" -AutomaticCheckpointsEnabled $false
Set-VMMemory -VMName "W11-CORP-01" -DynamicMemoryEnabled $false
Set-VMProcessor -VMName "W11-CORP-01" -Count 2
```

> **Pourquoi les points de contrôle automatiques sont désactivés**
>
> Un **point de contrôle** est un instant sauvegardé. Hyper-V l'implémente en gelant le disque principal et en écrivant chaque modification ultérieure dans un **disque de différenciation** séparé (un fichier `.avhdx`). Les points de contrôle automatiques en créent un à chaque démarrage de la VM.
>
> Deux coûts. Disque : le disque de différenciation grossit sans limite et il est invisible dans l'Explorateur sauf si on le cherche. Vitesse : chaque écriture touche désormais deux fichiers au lieu d'un. Plus tard dans le labo, un seul disque de différenciation de 12.1 Go a été la raison pour laquelle le chiffrement BitLocker rampait. Les points de contrôle manuels sont utiles. Les automatiques sont une taxe.

#### Le TPM virtuel : l'ordre compte

```
Set-VMKeyProtector -VMName "W11-CORP-01" -NewLocalKeyProtector
Enable-VMTPM -VMName "W11-CORP-01"
```

> **Pourquoi**
>
> **« TPM »**, Trusted Platform Module. Une puce dédiée (ici, une émulation logicielle) qui stocke des clés cryptographiques là où le système d'exploitation ne peut pas les lire. C'est ce qui permet à BitLocker de déverrouiller un disque automatiquement au démarrage sans demander de mot de passe, et c'est ce qui prouve l'identité d'un appareil à Entra ID.
>
> Windows 11 refuse de s'installer sans TPM 2.0. L'identité d'appareil Intune et BitLocker en dépendent tous les deux. Pas de TPM, pas de labo.
>
> **L'ordre compte.** `Set-VMKeyProtector` crée la clé qui protège le stockage propre du TPM virtuel. `Enable-VMTPM` l'active ensuite. Inversez les deux et la seconde commande échoue.

#### Secure Boot

```
Set-VMFirmware -VMName "W11-CORP-01" -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
```

> **Pourquoi**
>
> **Secure Boot** vérifie la signature numérique de chaque morceau de code qui s'exécute avant le démarrage de Windows. Les chargeurs de démarrage non signés ou altérés sont refusés. C'est une exigence de Windows 11, et c'est l'un des paramètres qu'une stratégie de conformité vérifiera plus tard.

> **Ce qui a cassé : modèle Secure Boot verrouillé**
>
> `Set-VMFirmware : Cannot modify the secure boot template ID property after the virtual TPM is initialized.`
>
> **Cause :** une fois `Enable-VMTPM` exécuté, le *modèle* Secure Boot est figé. Le modèle indique quelle autorité de certification approuver. `MicrosoftWindows` est déjà la valeur par défaut pour une VM de génération 2, donc le définir explicitement ne change rien.
>
> **Correction :** retirer `-SecureBootTemplate` et ne définir que l'état.
>
> ```
> Set-VMFirmware -VMName "W11-CORP-01" -EnableSecureBoot On
> ```

## 5. Le problème de mémoire, trois fois de suite

> **Ce qui a cassé : 0x800705AA**
>
> `'W11-CORP-01' could not initialize memory: Insufficient system resources exist to complete the requested service. (0x800705AA)`
>
> Rencontré trois fois distinctes au cours de la semaine.
>
> **Cause :** Hyper-V réserve la *totalité* de l'allocation de mémoire de démarrage avant que la VM n'exécute une seule instruction. Il n'emprunte pas progressivement. Demandez 4 Go et 4 Go doivent être libres, contigus et disponibles à cet instant. Le portable a 15.46 Go au total, et Chrome retenait à répétition entre 2'249 Mo et 5'236 Mo répartis sur des dizaines de processus en arrière-plan.
>
> **Correction :** fermer complètement Chrome avant de démarrer la VM, ou baisser la mémoire de démarrage. Plus tard dans la semaine, cela a conduit à un audit complet de ce qui mangeait la RAM : extensions de navigateur, services Adobe en arrière-plan, Figma Agent, Grammarly, Slack. Plusieurs gigaoctets ont été récupérés.

> **À retenir pour la suite**
>
> Avant de démarrer la VM, fermez le navigateur. C'est plus rapide que de diagnostiquer 0x800705AA une quatrième fois.

## 6. À retenir pour l'examen

- La génération 2 est une décision prise à la création et ne peut pas être changée. Génération 2 = UEFI = Secure Boot et vTPM disponibles.
- Une licence achetée ne fait rien. Elle doit être attribuée à un utilisateur, et l'utilisateur doit se reconnecter.
- Intune Suite est un module complémentaire. Intune Plan 1 est le plan de base qui porte les droits d'inscription.
- Facturation récurrente désactivée ne met pas fin à un essai plus tôt. L'essai court sur toute sa durée.
- Hyper-V réserve la mémoire de démarrage en totalité, d'emblée.
- `Set-VMKeyProtector` avant `Enable-VMTPM`. Le modèle Secure Boot se verrouille dès que le vTPM s'initialise.

*Jour 1 sur 5, série de labo MD-102. Rédigé à partir du journal de session, 24 août 2026. Tenant de labo uniquement, rien de tout cela n'est de la production.*
