# Jour 2 : Utilisateurs, groupes et paramètres d'appareil du tenant

*Peupler l'annuaire, apprendre la différence entre appartenance attribuée et dynamique, et définir les règles à l'échelle du tenant qui décident qui a le droit de joindre un appareil tout court.*

Mercredi 19 août 2026 · Parcours d'étude MD-102 · Travail effectué sur l'iMac, pas sur le portable

**Ce qui existait à la fin de la journée**

- 30 utilisateurs dans `labtenant.onmicrosoft.com` : 10 créés à la main, 20 par PowerShell
- 5 groupes : 3 attribués, 2 dynamiques
- Anna Test titulaire du rôle Intune Administrator
- Paramètres d'appareil du tenant verrouillés : seul IT-Admins peut joindre des appareils, maximum 5 appareils par utilisateur
- PowerShell 7 et le SDK Microsoft Graph fonctionnels sur macOS

## 1. Pourquoi un annuaire doit exister avant toute autre chose

Intune n'a pas ses propres utilisateurs. Il les emprunte à Entra ID. Chaque stratégie, chaque restriction d'inscription, chaque profil Autopilot est attribué à *un groupe*, et un groupe est un conteneur d'utilisateurs ou d'appareils qui vivent dans Entra ID.

- **Entra ID** Contient les utilisateurs, les groupes, les appareils. La couche identité.
- **Groupe** L'unité que tout cible. Ne jamais cibler des individus.
- **Stratégie Intune** Conformité, configuration, Autopilot, applications. Tout est attribué à des groupes.

> **Pourquoi**
>
> **« Entra ID »** est le nom actuel de ce qui était Azure Active Directory. Les questions d'examen et la documentation plus ancienne disent encore Azure AD. C'est la même chose. Le renommage a eu lieu en 2023 et les commandes sous-jacentes portent toujours l'ancien nom, ce qui explique que vous verrez `AzureAdJoined` dans la sortie d'un outil exécuté en 2026.

## 2. Dix utilisateurs à la main, vingt par script

Les deux voies ont été utilisées à dessein, pour sentir la différence.

### À la main

**[Navigateur]** entra.microsoft.com→ Identity→ Users→ All users→ New user→ Create new user

**Dix utilisateurs ont pris environ dix minutes.** Chaque champ saisi, chaque page confirmée.

### Par PowerShell et Microsoft Graph

**Vingt utilisateurs ont pris 7.3 secondes.**

> **Pourquoi**
>
> **« Microsoft Graph »** est l'API unique derrière chaque service Microsoft 365. Le portail dans lequel vous cliquez n'est lui-même qu'un site web qui appelle Graph. Tout ce que le portail peut faire, Graph peut le faire, et Graph peut le faire trente fois dans une boucle.
>
> **« SDK »**, software development kit. Le module PowerShell `Microsoft.Graph` est un ensemble de cmdlets qui encapsulent les appels Graph, de sorte que vous écrivez `New-MgUser` au lieu de construire des requêtes HTTP à la main.
>
> C'est tout l'argument en faveur du script dans la gestion des postes de travail, et c'est pourquoi `notions de PowerShell` apparaît dans les offres d'emploi de support en Romandie. Dix utilisateurs, c'est une pause café. Trois cents utilisateurs, c'est une semaine que vous n'avez pas.

> **Ce qui a cassé : erreurs de données silencieuses**
>
> Deux enregistrements sont entrés faux et rien n'a protesté :
>
> - `aul.test` au lieu de `paul.test`, un premier caractère perdu dans les données source
> - Titre de poste `vice Desk Analyst` au lieu de `Service Desk Analyst`, la même classe d'erreur
>
> **Cause :** le script a fait exactement ce qu'on lui a dit. Graph valide le format, pas l'intention. `aul.test@labtenant.onmicrosoft.com` est un nom d'utilisateur principal parfaitement valide.
>
> **La leçon :** les opérations en masse multiplient les erreurs à la même vitesse qu'elles multiplient le travail. Toujours relire ce qui a été créé. `Get-MgUser -All | Select DisplayName, UserPrincipalName, JobTitle` prend deux secondes et attrape ça.

## 3. Groupes attribués et groupes dynamiques

Cinq groupes ont été construits, volontairement répartis entre les deux types.

| Groupe | Type | Comment l'appartenance est décidée |
|---|---|---|
| `IT-Admins` | Attribué | Quelqu'un ajoute un membre à la main. L'appartenance ne change que lorsqu'un humain la change. |
| `All-Corp-Devices` | Attribué | Idem. |
| `All-BYOD` | Attribué | Idem. |
| `Dyn-Windows-Devices` | Appareil dynamique | Entra évalue une règle. Tout appareil qui y correspond rejoint le groupe automatiquement. |
| `Dyn-Android-Devices` | Appareil dynamique | Idem, règle différente. |

#### Les deux règles utilisées

```
device.deviceOSType -eq "Windows"
device.deviceOSType -startsWith "Android"
```

> **Pourquoi -startsWith pour Android et -eq pour Windows**
>
> Android remonte son type d'OS avec des variantes, `Android`, `AndroidForWork`, `AndroidEnterprise` selon le mode d'inscription. Une correspondance exacte en manquerait la plupart. Windows remonte une seule valeur constante.
>
> C'est une vraie habitude à garder : correspondance large là où la plateforme est incohérente, exacte là où elle ne l'est pas.

> **Règle Microsoft : l'appartenance dynamique exige une licence**
>
> L'appartenance dynamique aux groupes est une fonctionnalité Microsoft Entra ID P1. Elle n'est pas disponible dans l'offre gratuite. L'essai Entra ID P2 activé au Jour 1 la couvre.
>
> L'appartenance n'est pas non plus instantanée. Entra évalue les règles selon son propre calendrier. Un appareil nouvellement créé peut mettre plusieurs minutes à apparaître dans un groupe dynamique, et une stratégie ciblant ce groupe ne s'appliquera pas tant qu'il n'y est pas. Beaucoup de problèmes « la stratégie ne fonctionne pas » sont en réalité des « l'appareil n'est pas encore dans le groupe ».

**[Navigateur]** entra.microsoft.com→ Identity→ Groups→ All groups→ New group→ Group type Security→ Membership type Dynamic Device→ Add dynamic query

> **Ce qui a cassé : le sélecteur de membres n'a pas validé**
>
> Les membres sélectionnés dans le sélecteur de membres du groupe n'ont pas été enregistrés. Aucune erreur n'est apparue. Le groupe est simplement resté vide.
>
> **Cause :** le sélecteur exige un clic explicite sur **Select** en bas du volet avant que le panneau parent n'enregistre le choix. Cliquer sur un nom ne fait que le surligner.
>
> **La leçon :** dans le portail Entra, ne jamais se fier à une ligne surlignée. Vérifier ensuite le nombre de membres du groupe.

## 4. Rôles : donner à quelqu'un des droits d'administration Intune

Anna Test a reçu le rôle **Intune Administrator**.

**[Navigateur]** entra.microsoft.com→ Identity→ Roles & admins→ All roles→ Intune Administrator→ Add assignments

> **Pourquoi ne pas simplement faire de tout le monde un Global Administrator**
>
> Parce que c'est le moyen le plus rapide de rater un audit de sécurité. Le **moindre privilège** signifie qu'un compte ne détient que les droits dont sa fonction a besoin. Intune Administrator peut tout faire dans Intune et rien en dehors. Si ce compte est compromis, le rayon d'impact est le parc d'appareils, pas le tenant entier.

> **Ce qui a cassé : Intune Administrator ne pouvait pas modifier Device settings**
>
> Connecté en tant qu'Anna, la page **Device settings** d'Entra s'affichait en lecture seule.
>
> **Cause :** Device settings vit dans Entra ID, pas dans Intune. Intune Administrator n'a aucune autorité dessus. Le rôle qui l'a est **Cloud Device Administrator**.
>
> **Pourquoi c'est important :** « Intune Administrator » donne l'impression de couvrir les appareils. Il couvre le service Intune. Les paramètres d'*identité* des appareils appartiennent à la plateforme d'identité. Cette distinction, Entra possède l'identité, Intune possède la gestion, est une de celles que l'examen teste à répétition.

## 5. Paramètres d'appareil du tenant : la barrière avant chaque inscription

Ce sont des interrupteurs à l'échelle du tenant dans Entra qui décident qui a le droit de joindre un appareil au tenant tout court. Ils se situent *au-dessus* de tout ce que fait Intune. Si cette barrière est fermée, aucune configuration Intune au monde ne laissera entrer un appareil.

**[Navigateur]** entra.microsoft.com→ Identity→ Devices→ Overview→ Device settings

| Paramètre | Valeur | Effet |
|---|---|---|
| Users may join devices to Microsoft Entra | `Selected → IT-Admins` | Seuls les membres d'IT-Admins peuvent effectuer une jonction Entra. Tous les autres sont refusés. |
| Maximum number of devices per user | `5` | Le sixième appareil d'un utilisateur est refusé tant qu'un autre n'est pas retiré. |

> **À retenir pour la suite : la liste de contrôle des échecs d'inscription commence ici**
>
> Quand un appareil refuse de s'inscrire, ces deux paramètres sont les deux premières choses à vérifier, avant de toucher à quoi que ce soit dans Intune :
>
> 1. L'utilisateur est-il dans le groupe autorisé à joindre des appareils ?
> 2. L'utilisateur a-t-il déjà atteint la limite d'appareils ? Les objets d'appareil obsolètes issus de reconstructions précédentes comptent dans la limite.
>
> Ces deux points ont été vérifiés et écartés lors de l'échec d'inscription du Jour 3. Aucun des deux n'était la cause, mais les éliminer était nécessaire.

## 6. Note sur l'outillage : PowerShell et Graph sur macOS

Le Jour 2 s'est déroulé sur l'iMac, ce qui voulait dire faire fonctionner l'outillage Microsoft hors de Windows.

- PowerShell 7.7 preview installé via Homebrew. Le binaire est `pwsh-preview`, pas `pwsh`.
- SDK `Microsoft.Graph` version 2.39.0. Le module s'installe sous forme d'un grand ensemble de sous-modules, un par charge de travail Graph, et le premier import est lent.

> **Pourquoi cela vaut la peine d'être su**
>
> PowerShell 7 est multiplateforme et bâti sur .NET. Windows PowerShell 5.1, la version livrée dans Windows, ne l'est pas. La plupart du travail Graph passe bien sur l'un comme sur l'autre, mais 5.1 a de vraies différences de syntaxe qui font mal. L'une d'elles a coûté du temps plus tard dans la semaine : `Set-Service -Name` accepte un seul nom en 5.1, tandis que `Stop-Service -Name` accepte un tableau. Passer un tableau au premier échoue. Le correctif a été une boucle `foreach`.

## 7. À retenir pour l'examen

- Tout dans Intune est attribué à un groupe, jamais à un utilisateur ou à un appareil individuel.
- L'appartenance attribuée est manuelle. L'appartenance dynamique est une règle qu'Entra évalue, et elle exige Entra ID P1.
- L'appartenance dynamique n'est pas instantanée. Prévoir le délai d'évaluation avant de conclure qu'une stratégie est cassée.
- Entra ID possède l'*identité* des appareils. Intune possède la *gestion* des appareils. Des rôles différents gouvernent chacune : Cloud Device Administrator contre Intune Administrator.
- "Users may join devices" et "Maximum devices per user" sont des barrières à l'échelle du tenant qui se situent au-dessus de toute configuration Intune.
- Les objets d'appareil obsolètes comptent dans la limite d'appareils par utilisateur.

*Jour 2 sur 5, série de labo MD-102. Rédigé à partir du journal de session, 24 août 2026. Tenant de labo uniquement, rien de tout cela n'est de la production.*
