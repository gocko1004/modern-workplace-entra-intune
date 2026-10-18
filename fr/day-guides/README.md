# Lab Intune et Entra ID

*Index, référence de l'environnement, et ce qu'il vaut la peine de savoir avant d'ouvrir un jour en particulier.*

Parcours d'étude MD-102 · Jours 1 à 8, du 17 au 27 août 2026. Les jours 9 et suivants sont dans le [journal du lab](../LAB-LOG.md).

## Les guides par jour

| Jour | Sujet | Ce qui a coûté le plus de temps |
|---|---|---|
| [**1**](day-01-tenant-licensing-and-the-lab-vm.md)  17 août | **Tenant, licences et la VM du lab**  Obtenir un tenant avec des droits Intune et une VM sur laquelle Windows 11 tourne. | Hyper-V qui réserve toute la mémoire de démarrage. Rencontré trois fois. |
| [**2**](day-02-users-groups-and-tenant-device-settings.md)  19 août | **Utilisateurs, groupes et paramètres d'appareil du tenant**  Annuaire, appartenance attribuée ou dynamique, rôles, et les verrous en amont d'Intune. | Intune Administrator ne peut pas modifier les Device settings d'Entra. Cela relève de Cloud Device Administrator. |
| [**3**](day-03-windows-install-entra-join-and-intune-enrolment.md)  19 au 20 août | **Installation de Windows, jonction Entra et inscription Intune**  Le plus long. Déploiement DISM, joindre ou enregistrer, autorité MDM. | Trois jours sur une VM qui refusait de démarrer. Puis une journée entière sur l'erreur 80180003. |
| [**4**](day-04-compliance-configuration-and-bitlocker.md)  21 août | **Conformité, configuration et BitLocker**  Juger un appareil ou le modifier, et ce dont BitLocker a besoin. | Un appareil vérifiablement sain signalé non conforme, parce que l'attestation n'est pas l'état en direct. |
| [**5**](day-05-windows-autopilot.md)  24 août | **Windows Autopilot**  Hachage matériel, profil de déploiement, règle de groupe ZTDid, ESP. | Profil bloqué sur « Not assigned » parce que la règle de groupe correspondait aux appareils inscrits, pas aux appareils enregistrés. |
| [**6**](day-06-autopilot-end-to-end-deployment.md)  24 août | **Déploiement Autopilot de bout en bout**  Réinitialisation à distance, puis laisser Autopilot reconstruire l'appareil depuis l'OOBE. | Erreur 801c03ed à la jonction Entra, causée par notre propre durcissement du jour 2. Étape Account setup de l'ESP non résolue. |
| [**7**](day-07-orphaned-devices-policy-stores-and-admx.md) 24 au 25 août | **Appareils orphelins, magasins de stratégies et modèles d'administration** Récupérer un appareil qu'Intune ne pouvait plus atteindre. | Trois heures à prouver qu'une stratégie fonctionnait alors qu'elle avait fonctionné depuis le début. |
| [**8**](day-08-assignment-filters-and-android-enrolment.md) 26 au 27 août | **Filtres d'affectation et inscription Android** Cibler sans toucher aux groupes, et une deuxième plateforme sur du vrai matériel. | La configuration Android exigeait une boîte aux lettres sur le compte Entra, mentionnée nulle part dans le panneau. |

## Environnement

| Élément | Valeur |
|---|---|
| Tenant | `labtenant.onmicrosoft.com` |
| Administrateur général | `admin@labtenant.onmicrosoft.com` |
| Licences | Essai Microsoft Intune Suite, 250 licences, expire le 15 novembre 2026, facturation récurrente désactivée. Essai Entra ID P2, 100 licences. Un siège Intune Plan 1 payant, CHF 6.50/mois, comme plan de base requis. |
| Hôte | Dell XPS, Windows 11 Pro, 15.46 Go de RAM. VM sur `D:\VMs`. |
| VM du lab | Nom Hyper-V `W11-CORP-01`, nom d'hôte Windows `LABVMGOCE`. Génération 2, 4 Go au démarrage, 2 vCPU, disque dynamique de 64 Go, vTPM, Secure Boot activé, Default Switch. |
| Numéro de série Autopilot | `<serial-redacted>` |
| Fichier de réponses | `D:\VMs\unattend.xml`, clavier suisse romand, paramètres régionaux fr-CH, interface en-GB, fuseau horaire W. Europe, compte administrateur local |

## URL directes à garder sous la main

| Usage | URL |
|---|---|
| Centre d'administration Intune | `intune.microsoft.com` |
| Centre d'administration Entra | `entra.microsoft.com` |
| Centre d'administration Microsoft 365 (licences, facturation) | `admin.microsoft.com` |
| **Diagnostic d'inscription**, à lancer en premier quand l'inscription échoue | `https://aka.ms/IntuneWindowsEnrollment` |
| **Autorité MDM**, aucun chemin de menu n'existe, URL directe uniquement | `intune.microsoft.com/#view/Microsoft_Intune_Enrollment/ChooseMDMAuthorityBlade` |

## Les distinctions dont tout le reste dépend

### L'identité appartient à Entra ID. La gestion appartient à Intune.

Deux services distincts, deux portails distincts, deux jeux de rôles d'administration distincts. L'*identité* d'un appareil, est-il joint, à qui appartient-il, combien d'appareils un utilisateur peut-il avoir, c'est Entra. Ce qu'on *fait* à cet appareil, stratégie, conformité, applications, réinitialisation, c'est Intune. Presque chaque moment « pourquoi je ne peux pas modifier ça » remonte au fait d'être dans le mauvais service.

### Joint ou enregistré

**Joint** : l'appareil appartient à l'organisation, l'utilisateur se connecte à Windows avec le compte professionnel. **Enregistré** : un compte professionnel ajouté à un appareil que l'organisation ne possède pas. `dsregcmd /status` est le seul moyen fiable de savoir lequel des deux vous avez.

### Conformité ou configuration

La **conformité** évalue et rend un verdict. Elle ne change rien. Son résultat est ce que l'accès conditionnel consomme. La **configuration** modifie l'appareil, silencieusement, sans rien demander à l'utilisateur.

### Achetée ou attribuée

Une licence dans le pool du tenant n'accorde rien. Elle doit être attribuée à un utilisateur, et cet utilisateur doit se reconnecter avant que les nouveaux droits figurent dans son jeton.

### Attestation ou évaluation locale

Certains paramètres lisent un rapport établi au démarrage et signé par le TPM. D'autres lisent l'appareil en direct. Ceux du démarrage ne changent qu'après un redémarrage. Autopilot en mode self-deploying et le préprovisionnement sont une autre affaire : ils exigent une attestation TPM auprès du service Autopilot, et Microsoft ne les prend pas en charge sur des machines virtuelles.

Cette section disait d'abord qu'un TPM virtuel ne pouvait pas du tout satisfaire les paramètres de conformité lus au démarrage. La reconstruction a prouvé le contraire : les trois sont passés sur un TPM virtuel 2.0 Hyper-V.

## Commandes de diagnostic, selon ce que vous cherchez à savoir

| Question | Commande | Machine |
|---|---|---|
| Cet appareil est-il joint, et comment ? | `dsregcmd /status` | VM |
| Suis-je seulement sur la bonne machine ? | `dsregcmd /status` → lire `Device Name` d'abord | L'une ou l'autre |
| Est-il vraiment inscrit dans Intune ? | `(Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*").Count`  Différent de zéro signifie oui. | VM |
| BitLocker est-il réellement activé ? | `Get-BitLockerVolume -MountPoint C:` | VM |
| Secure Boot est-il réellement activé ? | `Confirm-SecureBootUEFI` | VM |
| Quelles éditions contient ce install.wim ? | `Get-WindowsImage -ImagePath "E:\sources\install.wim"` | Portable |
| Obtenir le hachage matériel Autopilot | `Get-WindowsAutopilotInfo -OutputFile C:\HWID.csv` | VM |

## Schémas d'échec vus plus d'une fois

| Schéma | Où il est apparu | Ce que cela signifie |
|---|---|---|
| **NordVPN casse silencieusement des panneaux du portail** | Deux fois en une semaine, le plus visiblement sur le panneau d'importation Autopilot, `Failed to fetch; error code 0` | Il tourne comme application de bureau, donc le mode navigation privée ne l'exclut pas. Vérifier le VPN avant le navigateur. |
| **La conformité lit le dernier démarrage** | Conformité du jour 4, et la reconstruction | Les paramètres Device Health lisent un rapport écrit au démarrage, donc un changement après le démarrage ne compte qu'après un redémarrage et la prochaine évaluation d'Intune. Le jour 4 a accusé le TPM virtuel ; la reconstruction a passé les trois sur un TPM virtuel 2.0. Le mode self-deploying et le préprovisionnement exigent toujours un TPM physique. |
| **Hyper-V réserve la mémoire d'emblée** | Trois fois, erreur `0x800705AA` | Fermer le navigateur avant de démarrer la VM. |
| **Le portail enregistre sans broncher avec rien de sélectionné** | Sélecteur de membres de groupe (jour 2), groupes Included et Excluded (jour 4) | Une stratégie affectée à personne est valide et silencieuse. Toujours relire l'affectation. |
| **Notre propre durcissement nous bloque plus tard** | Jour 6, erreur 801c03ed à la jonction Entra | La restriction de jonction et la limite de cinq appareils du jour 2 ont stoppé le déploiement du jour 6. L'échec est rarement un produit cassé, c'est un paramètre que quelqu'un a choisi, pour une bonne raison, un autre jour. |
| **Deux fenêtres PowerShell identiques** | Jour 3, `dsregcmd` sur l'hôte | C'est pour cela que chaque instruction de ces documents porte l'étiquette **[Portable]** ou **[VM]**. |

## Les deux leçons les plus coûteuses de la semaine

> **1. Changer d'approche, ne pas s'acharner à déboguer le chemin**
>
> Trois jours sont partis à faire démarrer une VM depuis une ISO. Chaque test était raisonnable. La question qui y a mis fin n'était pas *pourquoi ça ne démarre pas* mais *ai-je seulement besoin de démarrer depuis une ISO*. Appliquer l'image avec DISM a pris moins d'une heure et n'a plus jamais échoué.

> **2. Lancer le diagnostic de l'éditeur avant de raisonner à partir des premiers principes**
>
> Une journée entière d'élimination manuelle sur l'erreur 80180003, étendue utilisateur, restrictions, limites d'appareils, objets périmés, licences. Microsoft publie un diagnostic à `aka.ms/IntuneWindowsEnrollment` qui lit le tenant et nomme la panne. Il l'a trouvée en quelques secondes : l'autorité MDM n'était pas définie.

## Ce qui n'est pas dans ces documents

Les mots de passe, les clés de récupération et les hachages matériels sont délibérément exclus. Les identifiants du compte local du lab se trouvent dans le fichier de réponses sur le disque et nulle part ailleurs.

*Index de la série de labs MD-102. Rédigé à partir de l'enregistrement de session, le 24 août 2026. Tenant de lab uniquement, rien de tout cela n'est de la production.*
