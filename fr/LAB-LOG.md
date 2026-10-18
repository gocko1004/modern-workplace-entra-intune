# Journal du labo

Le registre courant du labo, tenu jour par jour : ce qui a été construit, ce qui a cassé, le texte exact de l'erreur, ce qui a été vérifié, la cause, le correctif, et ce que ça a appris. Les échecs sont conservés volontairement.

Environnement de labo personnel, pas de la production. Le nom du tenant, l'ID du tenant et les numéros de série des appareils sont remplacés par des valeurs de substitution.

---

## Jour 1, lundi 17 août

**Construit :**
- Tenant Microsoft 365 `labtenant.onmicrosoft.com`, administrateur général `admin@labtenant.onmicrosoft.com`
- Intune Suite Trial activé, 250 licences, expire le 15 novembre 2026
- Entra ID P2 Managed Trial activé, 100 licences
- Hyper-V activé sur l'hôte, `W11-CORP-01` créée : génération 2, TPM activé, Secure Boot activé, disque dynamique de 64 Go, Default Switch

**Cassé :**
1. "Enregistrer ou imprimer" sur la confirmation d'inscription ne faisait rien au clic
2. Entra ID P2 affichait Actif dans Vos produits, mais 0 licence attribuée sur 100
3. `Start-VM` refusait de lancer la VM

**Texte de l'erreur :**
```
Impossible d'allouer 4096Mo de mémoire RAM: Insufficient system resources
exist to complete the requested service. (0x800705AA)
```

**Cause :**
1. Popup ou boîte de dialogue d'impression bloquée par le navigateur. Il n'y avait en fait aucun problème.
2. Acheter un abonnement et l'attribuer à un utilisateur sont deux opérations distinctes. Un Actif au niveau du tenant ne donne pas la capacité à l'utilisateur.
3. L'hôte avait 2.63 Go libres sur 15.46 Go, Chrome occupant 4'570 Mo répartis sur 32 processus. Hyper-V réserve d'emblée toute la mémoire **de démarrage**, avant que la VM ne tourne. Le minimum de la mémoire dynamique n'a aucune importance au démarrage.

**Correction :**
1. Identifiants notés à la main. Ctrl+P vers PDF comme sauvegarde.
2. Licence Entra ID P2 attribuée à l'utilisateur admin, puis déconnexion et reconnexion pour que le jeton récupère la nouvelle capacité.
3. Onglets Chrome fermés et mémoire de démarrage abaissée de 4 Go à 3 Go, en gardant la dynamique entre 1 et 6 Go.

**Appris :**
- Actif au niveau du tenant et attribué au niveau de l'utilisateur sont deux choses différentes. Une licence non attribuée est la première chose à vérifier quand une fonctionnalité est "achetée" mais absente, et c'est la même cause racine derrière des inscriptions Intune qui échouent sans raison visible.
- Un changement de licence demande une nouvelle connexion avant de prendre effet. Ça ressemble à un bug, ce n'en est pas un.
- Hyper-V réserve la RAM de démarrage d'emblée. Sur un hôte de 16 Go, l'allocation de démarrage est le chiffre qui décide si une VM démarre tout court.
- Windows 11 sous Hyper-V exige la génération 2, et le TPM doit être activé explicitement avec `Set-VMKeyProtector` avant `Enable-VMTPM`. Sans ça, l'installation échoue avec "This PC can't run Windows 11" et aucun détail utile.

---

## Jour 2, prévu le mardi 18 août, fait en réalité le mercredi 19 août

Un jour de retard sur le plan. Je le note plutôt que de le cacher.

**Construit :**
- 10 utilisateurs créés à la main dans le portail Entra, puis supprimés
- 20 utilisateurs créés avec PowerShell 7 et le SDK Microsoft Graph, avec fonction, service et emplacement d'utilisation CH renseignés sur chacun
- 5 groupes de sécurité, tous créés dans le cloud, aucun synchronisé depuis l'on-prem :
  - Assigned : `IT-Admins` (5 membres), `All-Corp-Devices` (vide), `All-BYOD` (vide)
  - Dynamic Device : `Dyn-Windows-Devices`, `Dyn-Android-Devices`
- Rôle Intune Administrator attribué à Anna Test, puis connexion avec son compte pour voir ce que le rôle permet et ne permet pas
- Device settings, à l'échelle du tenant : jonction restreinte à `IT-Admins`, authentification multifacteur (MFA) pour joindre laissée désactivée, nombre maximal d'appareils par utilisateur abaissé de 50 à 5

Règles dynamiques utilisées :
```
device.deviceOSType -eq "Windows"
device.deviceOSType -startsWith "Android"
```

**Cassé :**
1. Le premier utilisateur ne s'enregistrait pas. La validation échouait sur l'onglet Basics.
2. Créé `aul.test@labtenant.onmicrosoft.com` au lieu de `paul.test`. La première lettre a disparu et rien ne s'est plaint.
3. Fonction saisie comme "vice Desk Analyst" au lieu de "Service Desk Analyst". Mêmes premiers caractères manquants.
4. Créé `IT-Admins` en sélectionnant 5 membres pendant la création, mais le groupe est sorti avec 0 membre.
5. Sur la page Device settings, "Members allowed to join devices" affichait "No results" et j'ai cru que le groupe n'était pas là.
6. Connecté en tant qu'Anna, impossible de modifier quoi que ce soit sur la page Device settings.

**Texte de l'erreur :**
```
Validation failed. Required information is missing or not valid for following tabs: Basics.
```
Anna a reçu un message de permission en essayant d'enregistrer, lui indiquant qu'elle n'avait pas les droits suffisants.

Les numéros 2, 3 et 4 n'ont produit **aucune erreur**. Rien à l'écran, rien dans le portail.

**Cause :**
1. Le Display name était vide. C'est un champ obligatoire, donc la règle l'attrape. Ce qui m'a trompé, c'est que Mail nickname se remplit tout seul à partir de l'UPN mais pas Display name, si bien que la zone du nom a l'air remplie alors que seule la moitié l'est. Le portail pointe d'ailleurs vers l'onglet, pas vers le champ.
2. et 3. Les premiers caractères ont été perdus à la saisie. Rien ne pouvait l'attraper parce que `aul.test` est un UPN parfaitement valide. Il est bien formé, ce n'est juste pas la valeur que je voulais.
4. Le sélecteur de membres dans le formulaire de création n'a pas validé la sélection.
5. Ce panneau affiche ce qui est actuellement sélectionné, pas une recherche dans l'annuaire. Il disait "No results" parce que rien n'avait encore été ajouté.
6. Anna a Intune Administrator. Ce rôle peut lire la page Device settings mais pas la modifier. La modifier demande Cloud Device Administrator.

**Correction :**
1. Retour sur l'onglet Basics et champ Display name renseigné.
2. Pas corrigé. Supprimé les 10 utilisateurs manuels et créé les 20 avec le script à la place.
4. Membres ajoutés ensuite depuis la page Members du groupe lui-même, ce qui a fonctionné.
5. Cliqué sur **+ Add** pour ouvrir le vrai sélecteur, puis trouvé `IT-Admins` tout de suite.
6. Rien à corriger. C'est le rôle qui fonctionne comme prévu.

**Appris :**

Manuel contre script. Dix utilisateurs à la main m'ont pris **10 minutes**. Vingt utilisateurs par script ont pris **7.3 secondes**. Soit 60 secondes par utilisateur contre 0.37 seconde, environ **162 fois plus rapide**. Mais la vitesse n'est pas l'essentiel. À la main, j'ai produit **une erreur silencieuse sur dix comptes**. Le script en a produit **zéro sur vingt**, parce que la règle de minuscules et l'emplacement d'utilisation sont écrits une fois et appliqués à tout. Le faire à la main convient pour une équipe de deux ou trois. À cinquante ou cinq cents, la question ne se pose pas, et dans un vrai poste la liste arrive de toute façon généralement en CSV, donc aucune raison de retaper quoi que ce soit.

Deux types d'échec différents, et la différence compte. Le nom d'affichage vide était **bruyant**. Il m'a arrêté, donc il m'a coûté une minute. `aul.test` était **silencieux**. Il m'a laissé continuer et serait ressorti plus tard sous la forme d'un utilisateur qui ne peut pas se connecter et dont l'adresse mail est fausse. Le bruyant est le moins cher. Le silencieux est le plus cher, et c'est celui que l'automatisation supprime.

À l'échelle du tenant contre attribué. Tout ce qui se trouve sur la page Device settings s'applique au **tenant entier**. Mettre le maximum d'appareils à 5 s'applique à chaque utilisateur, moi compris. C'est différent d'une stratégie de conformité ou d'un profil de configuration, qu'on attribue à un groupe précis et qui n'affecte que ce groupe. L'échelle du tenant, c'est là qu'on casse tout le monde d'un coup.

Moindre privilège. J'ai donné à Anna Intune Administrator plutôt que Global Administrator parce que c'est le plus petit rôle qui couvre le travail. Si son compte est compromis, les dégâts se limitent à Intune au lieu du tenant entier.

**En suspens pour le Jour 3 :** les deux groupes dynamiques ont des règles valides et 0 membre parce qu'il n'y a encore aucun appareil inscrit. Je n'ai pas pu mesurer le temps qu'un groupe dynamique met à se peupler. À reporter au Jour 3, quand `W11-CORP-01` sera joint à Entra ID.

---

# Jours 9 à 14, du 27 août au 9 septembre 2026

Condensé. Seulement les échecs, parce que les réussites sont dans `06_SKILLS_OBTAINED.md` et dans `tutorials/`.

---

## Jour 9. Windows LAPS renvoyait 0x80070190 et le portail ne disait rien d'utile

**Tentative :** construit une stratégie Windows LAPS, attribuée, appareil synchronisé, puis tenté de récupérer le mot de passe administrateur local depuis le panneau de l'appareil.

**Texte de l'erreur :**
```
0x80070190
```

La stratégie Intune se déclarait appliquée avec succès. Le panneau de l'appareil n'affichait aucun mot de passe.

**Cause :** trouvée en lisant le journal d'événements de l'appareil plutôt que le portail.

```powershell
Get-WinEvent -LogName "Microsoft-Windows-LAPS/Operational" -MaxEvents 15
```

Événement 10059 : *"Local admin password solution is not enabled for this tenant."*

Il existe un commutateur au niveau du tenant dans Microsoft Entra qui active LAPS pour l'annuaire. Il n'est mentionné ni dans le panneau LAPS d'Intune ni dans la stratégie elle-même. Tant qu'il n'est pas activé, la stratégie s'applique correctement à l'appareil, l'appareil tente de déposer le mot de passe, et l'annuaire le refuse.

**Correction :** commutateur du tenant activé, `Invoke-LapsPolicyProcessing` lancé sur l'appareil, le mot de passe est apparu.

**Appris :** une stratégie qui se déclare en succès parle de la livraison, pas du résultat. Le journal d'événements de l'appareil était le seul endroit qui portait la vraie raison. Troisième commutateur au niveau du tenant ce mois-ci qui se trouve loin de la fonctionnalité qu'il contrôle, après la valeur par défaut de conformité et le bouton des données de diagnostic Windows.

---

## Jour 11. Un groupe dynamique ne peut pas être sa propre exception

**Tentative :** construire trois anneaux de mise à jour (pilote, large, critique) avec un ciblage sans chevauchement. L'anneau pilote existant était attribué à `Dyn-Windows-Devices`, le groupe dynamique qui attrape chaque appareil Windows.

**Texte de l'erreur :** aucun. Exclure un groupe de lui-même n'a pas de sens, donc il n'y a rien qui puisse échouer.

**Cause :** c'est la conception qui était fausse, pas l'outil. Un seul groupe dynamique contenant tout est correct pour l'anneau large. Un pilote est par définition un sous-ensemble choisi à la main, et aucune règle d'appartenance n'exprime "ces trois machines".

**Correction :** créé `Grp-Ring-Pilot` comme groupe de sécurité **attribué**, ajouté l'appareil du labo, réattribué l'anneau pilote à ce groupe, puis inclus `Dyn-Windows-Devices` sur l'anneau large et exclu `Grp-Ring-Pilot`.

**Appris :** dynamique pour la masse, attribué pour les exceptions. Ajouter une machine au groupe pilote la fait maintenant passer d'un anneau à l'autre sans toucher à aucune règle.

Confirmé aussi : Intune n'a pas de classement par priorité pour les anneaux de mise à jour. Deux anneaux qui ciblent un même appareil, c'est un conflit, les paramètres en conflit ne sont pas écrits, et l'appareil garde silencieusement ses valeurs précédentes. Des anneaux qui se chevauchent ressemblent exactement à "Intune ne fonctionne pas".

---

## Jour 11. Une stratégie dont le nom ne correspondait pas à ce qu'elle déployait

**Tentative :** créé une stratégie de mise à jour des fonctionnalités nommée `Feature-Pin-24H2`, généré le rapport.

**Texte de l'erreur :** aucun. Le rapport affichait la stratégie comme saine.

**Cause :** la colonne Versions indiquait **Windows 11, version 25H2**. Le nom était une étiquette tapée par un humain. La version était ce que le service allait réellement faire.

![Rapport de mise à jour des fonctionnalités : stratégie Feature-Pin-24H2, colonne Versions Windows 11, version 25H2](../screenshots/11-lab-day11-feature-pin-deploys-25h2.png)

**Correction :** stratégie renommée pour correspondre à son comportement.

**Appris :** c'est comme ça qu'un verrouillage de version échoue en silence pendant des mois dans un vrai tenant. Personne ne lit la colonne version, on lit le nom. Le propre rapport du service l'emporte sur l'étiquette.

---

## Jour 13. La stratégie antivirus imposait une valeur non sécurisée

**Tentative :** construit une stratégie Defender Antivirus, attribuée, synchronisé, vérifié avec `Get-MpPreference`.

**Texte de l'erreur :** aucun. La stratégie se déclarait appliquée avec succès.

```
PUAProtection           : 0
DisableLocalAdminMerge  :
SignatureUpdateInterval : 4
CloudBlockLevel         : 2
CloudExtendedTimeout    : 50
SubmitSamplesConsent    : 1
```

**Cause :** quatre valeurs étaient présentes sur l'appareil, ce qui prouvait la livraison, l'attribution et la licence en une seule étape, et situait donc le défaut dans la stratégie plutôt que dans la synchronisation. En ouvrant la stratégie, la protection contre les applications potentiellement indésirables était explicitement réglée sur **off**.

Pire que non configuré. Un "off" explicite écrase ce que l'appareil ferait autrement, et se déclare quand même appliqué.

![Stratégie Defender Antivirus avec PUA Protection explicitement réglée sur off](../screenshots/04-lab-day13-pua-protection-off.png)

**Correction :** réglée sur Block, enregistré, synchronisé. `PUAProtection` est passé de 0 à 1.

**Appris :** l'ordre du diagnostic est tout l'enjeu. Prouver que la stratégie est arrivée, puis questionner son contenu. La plupart des gens font l'inverse et passent une heure sur la synchronisation.

---

## Jour 13. Select-Object a inventé un paramètre qui n'existait pas

**Tentative :** lire `DisableLocalAdminMerge` dans le registre pour confirmer qu'il s'était appliqué.

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Defender" | Select-Object DisableLocalAdminMerge, PUAProtection, AllowOnAccessProtection
```

**Texte de l'erreur :** aucun. Trois en-têtes de colonne affichés sans rien dessous, ce qui se lit exactement comme trois paramètres non définis.

**Cause :** `Select-Object` crée une colonne pour n'importe quel nom de propriété qu'on lui donne, que l'objet la possède ou non. Le chemin était faux, donc chaque propriété demandée était absente, donc chaque colonne était vide.

**Correction :** arrêté de deviner les chemins et cherché sur le nom de la valeur à la place.

```powershell
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Property -contains "DisableLocalAdminMerge" } | Select-Object -ExpandProperty Name
```

**Appris :** un nom de propriété faux est indiscernable d'un paramètre non défini, ce qui envoie dépanner quelque chose qui n'a jamais été cassé. Quand le nom est incertain, vider la clé avec `Format-List` ou chercher dans l'arborescence sur le nom de la valeur. Ne jamais sélectionner une supposition.

Noté honnêtement : après avoir cherché dans l'arborescence PolicyManager et dans l'arborescence Windows Defender, `DisableLocalAdminMerge` n'était observable sur cette build par aucune méthode. Il est coché dans la stratégie et la stratégie s'applique de façon démontrable. Consigné comme lacune documentée plutôt que comme réponse inventée.

---

## Jour 13. Le portail disait pas d'accès. Il avait tort.

**Tentative :** récupérer une clé de récupération BitLocker depuis Devices, l'appareil, BitLocker recovery keys, Show Recovery Key.

**Texte de l'erreur :**
```
You do not have access to view this BitLocker recovery key.
```

![Portail refusant d'afficher une clé de récupération BitLocker, ID de clé masqués](../screenshots/05-lab-day13-portal-key-access-denied.png)

**Investigation, dans l'ordre :**

1. Vérifié les rôles d'annuaire du compte. **Global Administrator**, Direct, Permanent, Active. Ce rôle porte `microsoft.directory/bitlockerKeys/key/read`, donc la cause annoncée était déjà douteuse.
2. Réessayé dans une fenêtre privée avec les extensions désactivées et un jeton neuf. Même échec, ce qui écarte un jeton périmé et écarte une interférence d'extension de navigateur, qui avait causé deux échecs de portail plus tôt dans ce labo.
3. Appelé les mêmes données via Microsoft Graph à la place :

```
GET https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys
GET https://graph.microsoft.com/v1.0/informationProtection/bitlocker/recoveryKeys/{id}?$select=key
```

Les deux ont renvoyé **200 OK** une fois `BitlockerKey.ReadBasic.All` et `BitlockerKey.Read.All` consentis dans Graph Explorer.

![Graph Explorer : 403 Forbidden sur recoveryKeys, demandant le consentement des permissions](../screenshots/05-lab-day13-graph-403-before-consent.png)

![Graph Explorer : 200 OK sur le même point de terminaison recoveryKeys](../screenshots/05-lab-day13-graph-recoverykeys-200-ok.png)

**Correction :** aucun appliqué. La clé est lisible via l'API. C'est le panneau du portail qui échoue.

**Appris :** un message d'erreur du portail est une affirmation, pas un diagnostic. Deux vérifications indépendantes l'ont contredit. Quand l'interface et l'API ne sont pas d'accord, c'est l'API qui dit la vérité, parce que l'interface n'est qu'un client qui l'appelle. Aussi : lister les clés qui existent et lire la valeur d'une clé sont deux permissions distinctes, séparées à dessein parce qu'une clé de récupération neutralise purement et simplement le chiffrement du disque.

---

## Jour 13. Trois clés de récupération, un seul disque

Le panneau de l'appareil listait trois clés de récupération BitLocker pour un seul lecteur de système d'exploitation.

Pas un défaut. Chaque événement de chiffrement et chaque rotation du mot de passe de récupération crée un nouveau protecteur et le dépose, et les anciens restent dans l'annuaire. C'est pour ça que l'écran de récupération affiche un **Key ID**, et que donner la mauvaise clé à un utilisateur est rejeté sans explication.

![Trois clés de récupération BitLocker listées pour un seul appareil, ID de clé masqués](../screenshots/12-lab-day13-three-recovery-keys.png)

Identifier celle qui est active sur l'appareil :

```powershell
manage-bde -protectors -get C:
```

---

## Jour 13. Le chiffrement plus fort qui n'a rien changé

Le disque avait été chiffré à la main le jour 4 et rapportait :

```
VolumeStatus         : FullyEncrypted
EncryptionMethod     : XtsAes128
ProtectionStatus     : On
EncryptionPercentage : 100
```

**Appris :** les paramètres de méthode de chiffrement ne prennent effet qu'au moment où le chiffrement démarre. Une organisation qui durcit son standard de 128 bits à 256 bits obtient une stratégie qui rapporte 100 % de succès et qui ne change rien sur aucune machine existante. Seuls les appareils chiffrés après l'arrivée de la stratégie reçoivent le nouvel algorithme. Migrer un parc existant signifie déchiffrer et rechiffrer chaque disque, ce qui est un projet plutôt qu'un changement de stratégie.

---

## Jour 13. Une dépendance silencieuse dans une seule stratégie BitLocker

Vérifié dans la documentation Microsoft du fournisseur de services de configuration BitLocker : la rotation du mot de passe de récupération est *"effective only when Active Directory back up for recovery password is configured to required"*.

Donc *Do not enable BitLocker until recovery information is stored* n'est pas seulement un paramètre de sécurité. Laissez-le sur False et la stratégie de rotation configurée dans une autre section de la même page ne fait silencieusement rien. Aucun avertissement nulle part dans l'interface.

Confirmé aussi à la même source : les paramètres étiquetés **AD DS** déposent dans **Microsoft Entra ID** sur les appareils joints à Entra. *"For Microsoft Entra joined devices, the BitLocker recovery password is backed up to Entra ID."* L'étiquette est héritée de la stratégie de groupe et ne décrit pas le comportement actuel.

La clé de stratégie `FVE` complète a été lue sur l'appareil et les quinze valeurs décodées. L'une d'elles, autorisant BitLocker sur des machines sans Trusted Platform Module, s'était activée toute seule comme effet secondaire de l'activation de l'authentification avancée au démarrage. Rien dans le portail ne l'indiquait.

---
---

## Jour 14. Des valeurs par défaut qui ressemblaient à un succès

**Tentative :** construit `FW-Baseline-Windows`, attribuée, synchronisé, vérifié avec le bon magasin de stratégies.

```powershell
Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, LogBlocked, AllowLocalFirewallRules
```

Résultat sur les trois profils :

```
Enabled                 : True
DefaultInboundAction    : Block
DefaultOutboundAction   : Allow
LogBlocked              : False
AllowLocalFirewallRules : True
```

**Première conclusion, et elle était fausse.** Trois valeurs correspondaient à la stratégie, donc la stratégie était clairement arrivée, donc les deux qui ne correspondaient pas étaient un problème de configuration.

**Ce qui s'est réellement passé :** `Enabled: True`, `Block` en entrée et `Allow` en sortie sont les **valeurs par défaut de Windows**. Elles correspondaient à la cible par coïncidence. Rien de la stratégie n'avait atteint la machine. Le volet de synchronisation d'Intune le disait clairement : **Policies, No policy updates**. Les deux valeurs qui différaient étaient le seul signal honnête dans cette sortie.

**Cause :** `Win-Security-Baseline-Lite`, le profil du catalogue de paramètres construit le jour 4, possédait encore les mêmes paramètres de pare-feu et réglait les quatre commutateurs de fusion sur **True** alors que la nouvelle stratégie les réglait sur **False**. L'état par paramètre affichait chacun d'eux deux fois avec **Conflict**. Windows n'a appliqué ni l'un ni l'autre.

`Default Inbound Action` affichait **Succeeded** dans le même rapport, parce que les deux stratégies le réglaient sur Block. Des valeurs identiques dans deux stratégies ne sont pas en conflit. Seules les valeurs différentes le sont.

![État par paramètre : chaque paramètre de fusion du pare-feu listé deux fois en Conflict, Default Inbound Action en Succeeded](../screenshots/13-lab-day14-firewall-merge-conflict.png)

**Correction :** retiré toute la catégorie Firewall de `Win-Security-Baseline-Lite` pour qu'une seule stratégie possède le pare-feu. Résolu par la propriété, pas en alignant les valeurs à deux endroits, parce que des valeurs alignées laissent le même piège à la personne suivante.

Après le correctif, le volet de synchronisation est passé de "No policy updates" à **7 of 10 succeeded** et les valeurs sont arrivées. Private est resté faux pendant un tour de plus parce que ses sous-paramètres n'avaient jamais été configurés, seulement son bouton d'activation.

**Appris :**

1. **Une valeur qui correspond à votre cible n'est pas une preuve de livraison quand c'est aussi la valeur par défaut.** Choisir une valeur de vérification qui diffère de la valeur par défaut, sinon on ne distingue pas le succès de la coïncidence.
2. Deux stratégies qui possèdent un même paramètre est la raison la plus courante pour laquelle une stratégie d'apparence correcte ne fait rien.
3. La ligne Policies du volet de synchronisation Intune est un vrai diagnostic. "No policy updates" veut dire que le service pense n'avoir rien à envoyer.

---

## Jour 14. Réduction de la surface d'attaque, audit d'abord

Déployé 19 règles de réduction de la surface d'attaque en mode audit, vérifié sur l'appareil :

```powershell
Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Actions
```

Dix-neuf valeurs, toutes à `2` (audit). Contrairement au cas du pare-feu, il n'y a ici aucune ambiguïté de valeur par défaut : sans stratégie la liste est vide, donc les valeurs elles-mêmes prouvent la livraison.

Passé une règle en blocage et relu. Une valeur est passée à `1`.

La colonne des actions n'a pas d'étiquettes, ce qui est inutilisable sur une vraie machine. Apparier les identifiants avec les actions :

```powershell
$p = Get-MpPreference; 0..($p.AttackSurfaceReductionRules_Ids.Count-1) | ForEach-Object { "{0}  {1}" -f $p.AttackSurfaceReductionRules_Ids[$_], $p.AttackSurfaceReductionRules_Actions[$_] }
```

`9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2` est la règle contre le vol d'identifiants. Les journaux d'événements Defender et le rapport de réduction de la surface d'attaque portent cet identifiant et jamais le nom convivial, donc l'appariement est ce qui permet de retraduire une entrée de journal en règle.

---

## Jour 14. App Control for Business

Déployé avec les contrôles intégrés, mode audit activé, programme d'installation managé et confiance fondée sur la réputation activés. Vérifié sur l'appareil :

```powershell
citool --list-policies
```

`VerifiedAndReputableDesktopEvaluation` indiquait **Is Currently Enforced: true**. Juste en dessous, `VerifiedAndReputableDesktop`, la même stratégie sans "Evaluation", indiquait false. Désactiver le mode Audit dans Intune inverse laquelle des deux est active. Tout le reste de cette liste est livré avec Windows.

---

## Jour 14. Endpoint Privilege Management

Deux stratégies sont nécessaires et l'ordre compte. La **stratégie de paramètres d'élévation** installe le client et définit la réponse par défaut, qui a été réglée sur refuser toutes les demandes. La **stratégie de règles d'élévation** définit quels binaires peuvent s'élever et ne fait rien tant que la stratégie de paramètres n'existe pas.

La règle utilisait un hachage de fichier SHA-256 plutôt qu'un certificat. Le portail explique pourquoi : une règle qui ne correspond qu'à un certificat laisse n'importe quel fichier signé s'élever s'il est renommé pour correspondre, donc une règle par certificat a besoin d'un chemin restreint à côté. Un hachage correspond à exactement un binaire, ce qui est plus fort, mais casse dès que Windows Update remplace le fichier.

Vérifié sur l'appareil, les deux vérifications tirées de la documentation Microsoft :

```powershell
Get-Service | Where-Object DisplayName -like "*EPM*"; Test-Path "C:\Program Files\Microsoft EPM Agent"
```

`MEMEPMSvc` en cours d'exécution, répertoire de l'agent présent.

---

## Jour 15. Lignes de base de sécurité

Appliqué la Security Baseline for Windows 10 and later, version 25H2, au groupe d'appareils dynamique.

Le rapport affichait **les cinq compteurs à zéro**, In Progress compris, plus d'une heure après l'attribution. Le rapport des lignes de base est plus lent que celui des profils de configuration. Des zéros partout veut dire qu'aucun appareil n'a encore remonté, pas qu'il n'y a rien à remonter.

Les versions de lignes de base utilisent des schémas incohérents selon les produits : Windows `25H2`, Defender for Endpoint `24H1`, Edge `139`, Microsoft 365 Apps `2512`, HoloLens `Version 1`. Lire la version sur chaque ligne de base plutôt que de supposer un schéma unique.

---

## Jour 15. L'accès conditionnel, et la faille d'authentification multifacteur qu'il a créée

Construit `CA-Require-Compliant-Device` : tous les utilisateurs inclus, le compte administrateur exclu, toutes les ressources ciblées, contrôle d'octroi **require device to be marked as compliant**.

Deux avertissements du portail sur cette page, tous deux réels :

- *"You must first disable security defaults before enabling a Conditional Access policy."* Les deux s'excluent mutuellement. Une stratégie s'enregistre en rapport uniquement sans les désactiver ; elle ne s'activera pas.
- Le mode rapport uniquement déclenche quand même une invite de certificat d'appareil sur macOS, iOS, Android et Linux alors qu'il n'impose rien, donc ces plateformes ont été exclues.

Vérifié avec le simulateur **What If** plutôt qu'en se connectant, ce qui compte parce que le compte administrateur est exclu et ne produirait donc jamais de résultat en rapport uniquement pour cette stratégie. What If évalue une connexion hypothétique pour n'importe quel utilisateur, sans connexion nécessaire et sans latence de journal.

Exécution en rapport uniquement : stratégie listée sous "Policies that will apply", State **Report-only**.

![What If : CA-Require-Compliant-Device sous Policies that will apply, State Report-only](../screenshots/14-lab-day15-whatif-report-only.png)
Après désactivation des paramètres de sécurité par défaut et activation de la stratégie, la même exécution indiquait State **On**.

**La conséquence, notée parce que c'est une vraie régression dans ce tenant.** Désactiver les paramètres de sécurité par défaut a supprimé l'exigence d'authentification multifacteur à l'échelle du tenant. La stratégie de remplacement ne vérifie que la conformité de l'appareil. Plus rien dans ce tenant n'exige l'authentification multifacteur. Dans un vrai déploiement, la prochaine stratégie construite est celle qui la remet, et l'ordre des opérations ici est exactement la manière dont des organisations se retrouvent moins sécurisées juste après être "passées à l'accès conditionnel".

---

# Jours 16 à 18, 11 septembre 2026

---

## Jour 16. La page de paramètres Endpoints qui n'existait pas

**Tentative :** connecter Defender for Endpoint à Intune. L'instruction de Microsoft est d'activer la connexion depuis le portail Defender, Settings, Endpoints, Advanced features.

**Texte de l'erreur :** aucun. La page Settings listait six éléments et **Endpoints n'en faisait pas partie**.

**Cause :** la licence. La page de paramètres Endpoints n'apparaît que lorsque le tenant détient une licence Defender for Endpoint, et sans elle il n'y a aucun bouton de connexion Intune à activer. La page du connecteur Intune disait seulement que le connecteur n'était pas configuré, sans mention de licence.

**Correction :** pris un essai Microsoft Defender for Endpoint P2 depuis le centre d'administration Microsoft 365, puis **annulé l'abonnement immédiatement**. L'annulation laisse l'accès actif jusqu'à la fin de la période, sans conversion en plan payant. C'est plus solide que de couper la facturation récurrente, et c'est maintenant la pratique établie pour les essais sur ce tenant.

La licence ne nécessite aucune attribution par utilisateur. Le portail le dit clairement : *"These licenses do not need to be individually assigned."*

**Appris :** une page de paramètres manquante est un signal de licence, pas un problème de navigation. Aucun des deux portails ne le disait.

---

## Jour 16. Defender for Business bloquait les pages de paramètres

Après la licence, le portail Defender s'est ouvert en **Defender for Business**, pas Defender for Endpoint, parce que Microsoft 365 Business Premium est sur ce tenant et qu'il embarque le produit destiné aux petites entreprises.

Son assistant de configuration interceptait chaque tentative d'ouvrir Settings et renvoyait à l'écran d'accueil. Il n'y a pas moyen de le contourner autrement qu'en terminant ou en sautant l'assistant.

**Appris :** le produit qu'on obtient dans le portail Defender dépend de la licence que détient le tenant, et la variante Business se comporte différemment de la variante Enterprise. Bon à reconnaître avant de supposer qu'un portail est cassé.

Aussi : le bouton de connexion Intune se trouve sous **Optional features**, pas Advanced features.

---

## Jour 16. L'intégration, et sa preuve sur l'appareil

Stratégie de détection et réponse des points de terminaison créée dans Intune avec le type de package de configuration client réglé sur **Auto from connector**, qui récupère le blob d'intégration depuis le connecteur plutôt que d'exiger un package téléchargé. C'est pour ça que le connecteur doit être activé d'abord.

Vérifié sur l'appareil :

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status" | Select-Object OnboardingState, OrgId
```

```
OnboardingState : 1
OrgId           : <org-id>
```

Le score de risque de la machine a ensuite été branché dans la stratégie de conformité Windows à **Medium**, ce qui complète la chaîne : Defender note l'appareil, Intune lit le score et le marque non conforme au-dessus du seuil, l'accès conditionnel le bloque. Trois produits, un seul résultat.

---

## Jour 16. Le propre test de détection de Microsoft n'a rien produit

**Tentative :** lancer le test de détection Defender for Endpoint documenté, qui simule un schéma de téléchargement et exécution depuis `http://127.0.0.1/1.exe`.

**Texte de l'erreur :** aucun. Aucune alerte n'est apparue, ni au bout de dix minutes ni au bout de cinquante.

**Cause :** rien n'écoute sur `127.0.0.1`, donc le téléchargement échoue et aucun processus n'est jamais exécuté. L'alerte dépend du moteur comportemental de Defender qui reconnaît la tentative, et sur un appareil intégré une heure plus tôt il n'y a aucune base comportementale sur laquelle travailler.

**Correction :** utilisé le fichier de test EICAR à la place, une chaîne inerte de 68 octets publiée par l'European Institute for Computer Antivirus Research précisément pour qu'un antivirus puisse être testé sans logiciel malveillant.

```powershell
Invoke-WebRequest -Uri "https://secure.eicar.org/eicar.com.txt" -OutFile "$env:USERPROFILE\Downloads\eicar.txt"
```

Windows Security sur l'appareil a affiché `Virus:DOS/EICAR_Test_File`, Severe, en quelques secondes. L'alerte a atteint le portail Defender quelques minutes plus tard.

**Appris :** le test documenté par Microsoft vérifie que la télémétrie circule, et sur un appareil fraîchement intégré il peut légitimement ne rien produire. EICAR teste directement le moteur antivirus et est déterministe.

---

## Jour 16. Ce que l'alerte contenait réellement

Quatre choses à garder du triage de l'alerte de bout en bout.

**Defender enregistre le contenu des scripts, pas seulement les noms de fichiers.** L'arborescence de processus portait chaque commande PowerShell exécutée sur cette machine dans l'heure précédente, chacune avec un SHA256 du texte du script, y compris des commandes sans aucun rapport avec l'alerte. Sur un appareil managé, tout ce qui est tapé dans une console est lisible par quiconque peut ouvrir le portail. C'est la réponse honnête quand un utilisateur demande ce que l'entreprise peut voir.

**La ligne de correction est toute l'histoire en une phrase :** *"Defender detected and quarantined 'Virus:DOS/EICAR_Test_File' in file 'eicar.txt', preventing attempted creation by 'powershell.exe'."* Bloqué au moment de l'écriture, donc le fichier n'a jamais fini d'atterrir.

**La gravité différait entre les deux endroits et les deux avaient raison.** Windows Security disait **Severe**, qui est la classification propre à la menace. Le portail disait **Informational**, parce que la gravité d'une alerte tient compte du fait qu'elle a été bloquée. Une menace bloquée n'est pas un incident.

**`Remote session initiator device name DESKTOP-D8QPBL1` sur `::1`** est la connexion en session étendue Hyper-V depuis l'hôte, que Windows rapporte comme une session Bureau à distance. À reconnaître pour ne pas la prendre pour quelque chose de suspect dans un vrai triage.

**Un décalage d'horloge de neuf heures** entre la machine virtuelle et les horodatages du portail. Dans une vraie investigation, c'est ce qui fait qu'un journal d'appareil et une alerte du portail refusent de s'aligner.

---

## Jour 17. Test-Path a renvoyé True depuis la mauvaise machine

**Tentative :** confirmer que l'application Win32 s'était installée sur la machine virtuelle.

```powershell
Test-Path "C:\Program Files\7-Zip\7zFM.exe"
```

A renvoyé **True**.

**Cause :** cette commande avait été lancée sur le portable, pas sur la machine virtuelle. 7-Zip était sur
le portable parce que l'installateur y avait été téléchargé pour l'empaquetage. Sur la machine virtuelle,
le chemin n'existait pas du tout.

Le journal de l'Intune Management Extension l'a confirmé de son côté : aucune activité d'application
Win32, d'aucune sorte, dernière entrée vieille de plusieurs heures.

**Correction :**

```powershell
Restart-Service -Name IntuneManagementExtension -Force
```

Redémarrer l'extension force une évaluation immédiate de la stratégie d'applications au lieu d'attendre
le cycle horaire. L'application s'est installée trois minutes plus tard.

![État d'installation de 7-Zip 26.03 sur l'appareil : Installed sur la VM du lab, UPN masqué](../screenshots/15-lab-day17-7zip-installed.png)

**Leçon :** un résultat venant de la mauvaise machine est pire qu'aucun résultat, parce qu'il arrête
l'investigation. Chaque étape de vérification doit nommer la machine avant la commande.

---

## Jour 17. Les règles de détection sont combinées par un ET, et les scripts ont deux conditions

Construit les trois types de règle de détection sur la même application.

**Règle de fichier :** `C:\Program Files\7-Zip`, `7zFM.exe`, le fichier ou dossier existe.

**Règle de registre :** `HKEY_LOCAL_MACHINE\SOFTWARE\7-Zip`, la clé existe.

Ajouter la deuxième règle ne signifie pas que l'une ou l'autre peut correspondre. **Intune exige que
toutes les règles de détection passent.** La plupart des gens supposent l'inverse, et c'est une raison
fréquente pour laquelle une application remonte Failed après une installation qui a manifestement
fonctionné.

**Règle par script personnalisé**, qui remplace les règles manuelles au lieu de s'y ajouter :

```powershell
$path = "C:\Program Files\7-Zip\7zFM.exe"
if (-not (Test-Path $path)) { exit 1 }
$version = (Get-Item $path).VersionInfo.FileVersion
if ([version]$version -ge [version]"26.0") {
    Write-Output "7-Zip $version detected"
    exit 0
}
exit 1
```

Le script vérifie que le fichier existe **et** que la version est à jour, de sorte qu'une installation
obsolète remonte comme non détectée et se fait mettre à niveau. Aucune des deux règles manuelles ne peut
exprimer cela.

**La règle qui piège les gens :** un script de détection doit **se terminer avec le code 0 et écrire
quelque chose sur la sortie standard**. Un code de sortie 0 sans sortie compte comme non détecté. Les
échecs de script de détection sont écrits dans `AgentExecutor.log`, qui est un fichier différent de
`IntuneManagementExtension.log`.

---

## Jour 17. Le téléversement qui s'est bloqué

La première tentative sur l'application Win32 est restée sur *"Your app is not ready yet"* pendant six
minutes pour un package de 1.6 MB, et Assigned indiquait No parce que le groupe n'avait pas été ajouté
dans l'assistant.

Supprimée et recréée, en restant sur l'assistant jusqu'à la fin du téléversement. La deuxième tentative a
fonctionné.

**Leçon :** le conseil donné par la bannière elle-même est juste. Un téléversement bloqué ne se rétablit
pas, et six minutes pour 1.6 MB, c'est un blocage, pas de la lenteur. Ce tenant a déjà subi deux fois
des interférences côté navigateur sur les appels au portail, avec la même signature.

---

## Jour 18. Ce que le type d'application Store ne demande pas

Déployé **Notepads App** via **Microsoft Store app (new)**. L'assistant n'a demandé ni package, ni
commande d'installation, ni commande de désinstallation, ni règle de détection. Le Store fournit les
quatre.

Vérifié sur l'appareil :

```powershell
Get-AppxPackage -Name "*Notepads*" | Select-Object Name, Version
```

```
19282JackieLiu.Notepads-Beta 1.5.6.0
```

`Get-AppxPackage` est l'équivalent UWP d'un coup d'œil dans Program Files. Les applications UWP ne
s'installent pas dans un dossier qu'on peut parcourir, donc la règle de détection par chemin de fichier
écrite pour l'application Win32 serait inutile ici.

**Install behavior était verrouillé sur User** et System grisé, parce que les applications UWP
s'installent dans un profil utilisateur plutôt qu'à l'échelle de la machine. C'est la différence pratique
entre une application Store et un package Win32.

Noté aussi : chercher `Notepad++` dans le Store ne renvoie rien, parce que `++` casse la recherche.
Chercher `Notepad` le renvoie.

---

## Jour 18. Microsoft 365 Apps

Déployé via le type d'application dédié **Microsoft 365 Apps for Windows 10 and later** avec le
Configuration designer, avec Word, Excel, PowerPoint et Outlook seulement, 64 bits, canal **Monthly
Enterprise**, suppression des autres versions activée.

Le choix du canal est le point d'examen. **Current Channel** livre les fonctionnalités dès qu'elles sont
prêtes, ce qui est imprévisible pour un parc géré. **Monthly Enterprise** les regroupe en une seule
version mensuelle prévisible. **Semi-Annual Enterprise**, c'est deux fois par an, pour les parcs dont les
logiciels cassent facilement.

L'alternative au Configuration designer est **XML**, qui prend le fichier produit par l'Office Deployment
Tool. Même résultat, mais le XML atteint des paramètres que le designer n'expose pas.

**Default file format** réglé sur Office Open XML. Laissé vide, Office pose la question à l'utilisateur au
premier lancement, ce qui fait un appel au support évitable.

---

# Jours 19 à 22, 11 septembre 2026

---

## Jour 19. Les stratégies de protection des applications ciblent des utilisateurs, pas des appareils

**Tentative :** affecter une stratégie de protection des applications Android à `Dyn-Windows-Devices`,
le groupe dynamique utilisé pour tout le reste ce mois-ci.

**Texte de l'erreur :** aucun. La page d'affectation l'a accepté et a affiché *"1 devices, 0 users"*.

![Stratégie de protection des applications affectée à Dyn-Windows-Devices : Group Members 1 devices, 0 users](../screenshots/16-lab-day19-app-protection-device-group.png)

**Cause :** les stratégies de protection des applications s'appliquent à **l'identité d'un utilisateur à
l'intérieur d'une application**, pas à un appareil. Toute la prémisse est que l'appareil est non géré, non
inscrit et inconnu, donc il n'y a aucun objet appareil auquel attacher la stratégie. Un groupe d'appareils
n'a personne à qui l'appliquer et la stratégie n'aurait rien protégé.

**Correction :** retiré le groupe d'appareils, affecté `All-BYOD` à la place.

**Leçon :** le type de groupe suit le type de stratégie. Les stratégies de configuration et de conformité
ciblent des appareils. La protection des applications cible des utilisateurs. Se tromper produit une
stratégie qui se déclare affectée et ne fait rien du tout.

Noté aussi : le ciblage par type d'appareil (Managed ou Unmanaged) a quitté la page Apps pour l'étape
Assignments, donc la documentation plus ancienne envoie chercher au mauvais endroit.

---

## Jour 19. Les deux périodes de grâce hors ligne

Conditional launch reprend deux fois le même paramètre avec des valeurs différentes et des actions
différentes, et c'est la partie qui vaut la peine d'être mémorisée :

| Paramètre | Valeur | Action |
|---|---|---|
| Offline grace period | 720 minutes | Block access |
| Offline grace period | 90 days | **Wipe data** |

Douze heures hors ligne bloquent l'application jusqu'à ce que l'appareil se synchronise. Quatre-vingt-dix
jours hors ligne effacent les données de l'entreprise de l'application, en partant du principe que le
téléphone est perdu. Les données personnelles ne sont pas touchées.

C'est la **réinitialisation sélective**, et la distinction avec la réinitialisation de l'appareil est la
question d'examen : la réinitialisation sélective ne retire que les données de l'entreprise des
applications gérées par stratégie, la réinitialisation de l'appareil efface toute la machine.

---

## Jour 21. Le module Graph qui n'existe plus

**Tentative :** se connecter à Microsoft Graph avec le module cité dans la plupart des supports d'étude
MD-102.

```powershell
Install-Module Microsoft.Graph.Intune -Scope CurrentUser -Force
Connect-MSGraph
```

**Texte de l'erreur :**

```
AADSTS700016: Application with identifier 'd1ddf0e4-d672-4dae-b554-9d5bdfd93547'
was not found in the directory '<tenant-id>'.
```

**Cause :** `Microsoft.Graph.Intune` est déprécié. Il s'authentifie via une inscription d'application fixe
qui n'est pas présente dans les tenants créés récemment. L'erreur se lit comme un problème de
tenant et c'est en fait un module mort.

**Correction :** le SDK PowerShell Microsoft Graph actuel.

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement -Scope CurrentUser -Force
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","DeviceManagementConfiguration.Read.All"
```

Connecté via l'application `14d82eec-204b-4c2f-b7e8-296a70dab67e`, Microsoft Graph Command Line
Tools.

**Leçon :** l'ancien module portait un jeu de permissions fixe, figé dans son inscription. Le nouveau
prend `-Scopes` et demande exactement ce qu'on nomme. C'est le moindre privilège appliqué à son propre
outillage, et c'est aussi pourquoi l'ancien échoue : son inscription a disparu.

Installé seulement `Microsoft.Graph.Authentication` et `Microsoft.Graph.DeviceManagement` plutôt que le
module `Microsoft.Graph` complet, qui compte environ quarante sous-modules.

---

## Jour 21. Une cmdlet Graph qui ne renvoyait rien avant d'être forcée à lever une erreur

**Tentative :** lire les états de stratégie de conformité d'un appareil non conforme.

```powershell
$d = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq 'DESKTOP-D8QPBL1'"
Get-MgDeviceManagementManagedDeviceCompliancePolicyState -ManagedDeviceId $d.Id
```

**Texte de l'erreur :** aucun. Sortie vide. `$d` était renseigné et le nom de la cmdlet était correct.

**Correction :**

```powershell
Get-MgDeviceManagementManagedDeviceCompliancePolicyState -ManagedDeviceId $d.Id -ErrorAction Stop
```

A renvoyé les données immédiatement.

**Leçon :** un résultat vide d'une cmdlet Graph ne prouve pas qu'il n'y a pas de données. Il faut la
forcer à lever une erreur avant de conclure quoi que ce soit. C'est la même classe d'erreur que
`Select-Object` qui invente des colonnes vides pour des noms de propriété qui n'existent pas.

---

## Jour 21. Le changement de conformité qui aurait bloqué tout un parc

**Constat, via Graph plutôt que par le portail.** Trois appareils dans le tenant. `DESKTOP-D8QPBL1`,
le portable, signalé **noncompliant**.

```powershell
Get-MgDeviceManagementDeviceCompliancePolicySettingStateSummary | Select-Object SettingName, NonCompliantDeviceCount, CompliantDeviceCount
```

```
Windows10CompliancePolicy.DeviceThreatProtectionRequiredSecurityLevel     1     1
Windows10CompliancePolicy.StorageRequireEncryption                        0     2
Windows10CompliancePolicy.TpmRequired                                     0     2
DefaultDeviceCompliancePolicy.RequireDeviceCompliancePolicyAssigned       0     5
```

**Cause :** l'exigence de score de risque de l'appareil ajoutée à la stratégie de conformité le matin
même. `AB-18949` passe parce qu'il est intégré à Defender for Endpoint et remonte un score.
`DESKTOP-D8QPBL1` échoue parce qu'il n'est pas intégré, et **l'absence de score compte comme un échec,
pas comme un inconnu**.

**C'est la séquence la plus dangereuse des domaines 3 et 5 réunis.** Une exigence de conformité a été
activée qui dépend d'un second produit. Chaque appareil pas encore intégré à ce produit est passé non
conforme à l'instant de l'enregistrement. La stratégie d'accès conditionnel exigeant un appareil conforme
était déjà sur On. Dans un vrai tenant, cela bloque chaque utilisateur dont la machine n'a pas terminé
l'intégration à Defender, soit, sur un grand parc, la plupart d'entre eux, dans l'heure qui suit un
changement qui avait l'air inoffensif.

**L'ordre qui l'évite :** intégrer d'abord chaque appareil à Defender, confirmer qu'ils remontent tous un
score, puis ajouter l'exigence de niveau de menace à la conformité. Jamais dans l'autre sens.

Rien n'a cassé ici uniquement parce que le compte administrateur est exclu de la stratégie d'accès
conditionnel. Cette exclusion est la seule chose qui sépare ce changement d'un tenant verrouillé.

---

## Jour 21. Corrections (Remediations), et le code de sortie inversé

Deux packages de remédiation construits.

**`Detect-LowDiskSpace`**, détection seulement, sans script de remédiation. Signale tout appareil sous
20% d'espace libre sur C:. C'est la vérification qui aurait attrapé l'échec du jour 3, où une
réinitialisation de Windows s'est bloquée à 98% parce que le volume de l'hôte était plein et que rien,
nulle part, ne le disait.

**`Fix-TimeService`**, détection plus remédiation. Détecte le service Windows Time arrêté ou désactivé et
le remet sur Automatic et Running. La dérive d'horloge casse Kerberos, la validation des certificats et
toute tentative de corréler un journal d'appareil avec une alerte du portail, ce qui est exactement le
décalage de neuf heures trouvé plus tôt dans la semaine.

**La convention de code de sortie est inversée par rapport aux règles de détection d'application Win32,
et elle piège tout le monde :**

| | Règle de détection d'application Win32 | Script de détection de remédiation |
|---|---|---|
| Exit 0 | L'application **est** installée | L'appareil est **sain**, ne rien faire |
| Exit 1 | L'application n'est pas installée | **Problème trouvé**, exécuter la remédiation |

Un script de détection doit aussi écrire sur la sortie standard, dans les deux cas.

**Bloqué d'abord par un prérequis :** Create était grisé avec *"Use of remediations requires Windows
license verification to be enabled."* C'est une deuxième bascule dans Tenant administration, Connectors
and tokens, Windows data, à côté de la bascule des données de diagnostic activée pour le jour 11.

À noter honnêtement : cette bascule est une **attestation, pas une vérification**. Elle liste Windows
Enterprise E3/E5, Microsoft 365 F3/E3/E5, Education A3/A5 ou Windows VDA. Ce tenant a Microsoft 365
Business Premium, qui n'est pas dans la liste. Microsoft ne le vérifie pas ; on l'affirme et la
fonctionnalité se débloque. Acceptable sur un tenant de lab avec une machine virtuelle. Sur le tenant
d'un employeur, c'est un problème de conformité de licences qui ressort dans un audit plutôt que dans le
portail.

C'est le **quatrième** interrupteur au niveau du tenant ce mois-ci qui ne se trouve nulle part près de
la fonctionnalité qu'il conditionne, après la valeur par défaut de conformité, LAPS et les données de
diagnostic.

---

## Jour 21. Script de plateforme contre remédiation

Rien à construire, mais la distinction est matière d'examen :

| | Script de plateforme | Remédiation |
|---|---|---|
| S'exécute | Une fois, une seule | Selon une planification, de façon répétée |
| Détection | Aucune | Un script de détection séparé décide s'il faut agir |
| Rapport | Réussi ou échoué | Par appareil : avec problème, sans problème, problème corrigé, problème réapparu |
| À utiliser pour | La configuration unique à l'inscription | Tout ce qui peut dériver à nouveau |

Un script de plateforme qui s'exécute une fois ne peut pas corriger un problème qui revient. C'est toute
la raison d'être des corrections.

---

## Jour 22. Endpoint Analytics mis en service

Activé depuis Reports, Endpoint analytics, Introduction, en collectant depuis tous les appareils gérés
dans le cloud.

Le score affiche **0 contre une référence de 12**, marqué *Insufficient data*. La bannière indique que
cela prend jusqu'à 24 heures après un redémarrage de l'appareil.

La référence de 12 est la **médiane de toutes les organisations qui utilisent Endpoint Analytics**. Le
score n'est pas mesuré par rapport à la perfection, il est mesuré par rapport à tous les autres, c'est
pourquoi la comparaison est une liste déroulante.

Cinq rapports : Startup performance, Application reliability, Work from anywhere, Resource performance,
Battery health.

---

## En attente, à vérifier à la prochaine session

| Élément | Attendu |
|---|---|
| Règle de détection de `7-Zip 26.03` volontairement cassée en `7zFM64.exe` | Le statut passe de Installed à Failed |
| `W32Time` arrêté et désactivé sur la machine virtuelle | `Fix-TimeService` le remet sur Running et Automatic |
| `Detect-LowDiskSpace` | Les premiers résultats apparaissent |
| Score Endpoint Analytics | Se remplit environ 24 heures après un redémarrage de l'appareil |

Déjà deux constats tirés des éléments en attente :

**Redémarrer l'Intune Management Extension force une synchronisation (check-in), pas une réévaluation
de la détection.** Le journal montrait `[Win32AppAsync] Starting app check in` puis `End app check in`
six secondes plus tard, sans aucun traitement d'application. Une règle de détection modifiée attend que
le service publie une nouvelle version de la stratégie.

**Les résultats de remédiation sont écrits dans `AgentExecutor.log`**, le même fichier que les échecs de
script de détection, séparé de `IntuneManagementExtension.log`.

---

# Jour 23, 14 septembre 2026. Contenu terminé.

---

## Le diagnostic en six couches qui a ouvert la journée

**Tentative :** confirmer que la remédiation `Fix-TimeService` avait réparé le service Windows Time,
arrêté et désactivé volontairement trois jours plus tôt.

**Texte de l'erreur :** aucun, nulle part. Le service était toujours Stopped et Disabled. Le portail
signalait la remédiation comme **Without issues**.

**La chaîne, dans l'ordre où elle a réellement été traitée :**

1. La machine tournait depuis le 13 septembre 19:23, donc une remédiation horaire avait eu de nombreuses
   occasions. Pas un problème de temps de fonctionnement.
2. Le portail disait Without issues, et c'était **vrai mais à propos de la mauvaise machine**.
   Device status ne listait que `DESKTOP-D8QPBL1`, le portable, où W32Time est sain. `AB-18949`, la
   machine qui était cassée, n'était pas du tout dans la liste.
3. L'affectation était correcte : `Dyn-Windows-Devices`, Hourly. L'appartenance au groupe était
   correcte : les deux appareils présents.
4. `IntuneManagementExtension.log` ne contenait rien, parce que **les corrections écrivent dans
   `HealthScripts.log`**, un fichier séparé dans le même dossier. Ce fichier disait :

```
[HS] Get 2 active user sessions
[HS] Total valid AAD User session count is 0
[HS] Scheduler Get 0 script policies for user session 0, user id = 00000000-0000-0000-0000-000000000000
[HS] no user id available to schedule next run.
```

   Deux sessions Windows actives, zéro reconnue comme session Microsoft Entra, donc zéro stratégie de
   script récupérée.

5. `whoami` renvoyait `azuread\admin`, donc le compte était le bon. `dsregcmd /status` montrait pourquoi :

```
DeviceAuthStatus : FAILED. Error: 0xd000023c
Previous Prt Attempt : 2026-09-14 08:06:22 UTC
      Attempt Status : 0xc000023c
          HTTP Error : 0x80072ee7
```

   `0x80072ee7`, c'est **nom non résolu**. Le Primary Refresh Token en cache était encore valide jusqu'au
   25 septembre, c'est pourquoi la machine avait toujours l'air connectée et apparaissait toujours dans
   le portail, mais rien de ce qui exigeait un jeton frais ne fonctionnait.

6. `Test-NetConnection login.microsoftonline.com -Port 443` échouait sur la résolution de nom. La même
   requête via `-Server 8.8.8.8` répondait immédiatement. Le DNS de la machine virtuelle pointe sur
   `172.19.16.1`, le **Default Switch Hyper-V sur l'hôte**.

**Cause :** NordVPN tournant sur le portable, cassant le redirecteur DNS du Default Switch. La machine
virtuelle avait internet tout du long et ne pouvait pas résoudre un nom.

**Correction :**

```powershell
Clear-DnsClientCache
dsregcmd /RefreshPrt
```

puis fermeture et réouverture de session, parce que `HealthScripts.log` montre que le planificateur se
déclenche à l'ouverture de session utilisateur :
`[OnSessionChange][HS] Request health script check in for user logon.`

Résultat :

```
[HS] Got 2 script(s) for user d9b968ad-... in session 1
[HS] finish ProcessResolvedPolicies, resolved policy count is 2
[HS] Calcuated earliest time is 9/14/2026 8:50:06 AM
```

`DeviceAuthStatus` est passé de FAILED à **SUCCESS**.

**Leçon, et c'est tout l'enseignement du lab en un seul incident :**

- Un statut vert dans le portail peut être vrai et concerner quand même une autre machine. Lire le nom
  de l'appareil avant de lire l'état.
- Chaque charge de travail écrit dans son propre journal. Les corrections sont dans `HealthScripts.log`,
  les applications Win32 dans `IntuneManagementExtension.log`, l'exécution des scripts et des
  applications dans `AgentExecutor.log`. Chercher dans le mauvais fichier ne renvoie rien et donne
  l'impression qu'il n'y a rien à trouver.
- Un jeton en cache masque un jeton cassé. Être connecté n'est pas la même chose que pouvoir
  s'authentifier.
- **Troisième cause côté hôte qui se présente comme un problème d'invité ce mois-ci**, après le volume
  hôte plein qui a bloqué une réinitialisation de Windows à 98% et la mémoire de l'hôte qui a empêché
  une restauration d'état enregistré. Quand l'invité n'a aucun sens, regarder l'hôte.

---

## Jour 23. Intune Suite et la structure des modules complémentaires

Tenant administration, Intune add-ons. Microsoft Intune Suite affiche **61 days left in trial**, avec
Intune Plan 2 et Endpoint Privilege Management listés séparément comme disponibles à l'essai ou à
l'achat.

L'onglet Capabilities en liste neuf, toutes Active. Le détail important est lesquelles portent
l'étiquette **"Included in Intune Plan 2"** :

| Capacité | Incluse dans |
|---|---|
| Remote Help (et intégration ServiceNow) | Suite |
| Endpoint Privilege Management | Suite |
| Advanced endpoint analytics | Suite |
| Enterprise App Management | Suite |
| Cloud PKI | Suite |
| Microsoft Tunnel for Mobile Application Management | **Plan 2** |
| Support for specialty devices | **Plan 2** |
| Firmware over-the-air update | **Plan 2** |

**Plan 2 est un sous-ensemble de la Suite, pas un produit séparé.** C'est cette relation que l'examen
demande.

---

## Jour 23. Enterprise App Management, et ce que ça vous coûte

Déployé Notepad++ via **Enterprise App Catalog app**, en choisissant le MSI plutôt que l'EXE parce qu'un
MSI porte un code produit, ce qui donne une règle de détection fiable et une commande de désinstallation
propre sans rien deviner.

Méthode de mise à jour réglée sur **Automatically update**. L'option énonce elle-même son compromis :
*"This resets and blocks custom settings, including install and uninstall scripts."*

Confirmé à l'écran : après l'avoir sélectionnée, les pages Program, Requirements et Detection rules
étaient toutes **préremplies et verrouillées**. Microsoft en est propriétaire, ce qui est précisément ce
qui lui permet de remplacer les versions sans casser le déploiement.

L'alternative, **Update with supersedence**, conserve les paramètres personnalisés mais transforme chaque
nouvelle version en une chaîne de remplacement (supersedence) construite à la main.

**La comparaison à garder.** La même classe d'application, deux voies :

| | Win32 (7-Zip) | Enterprise App Catalog (Notepad++) |
|---|---|---|
| Outil d'empaquetage | Requis | Aucun |
| Commande d'installation | Écrite à la main | Fournie |
| Règle de détection | Écrite à la main, trois types essayés | Fournie |
| Mises à jour | Réempaquetage manuel ou remplacement | Automatiques |
| Scripts personnalisés | Oui | Non |
| Convient pour | N'importe quoi | Seulement les applications du catalogue |

La voie Win32 reste nécessaire pour les logiciels métier, qui sont l'essentiel de ce qu'un vrai parc fait
tourner. Y recourir quand le catalogue a déjà l'application, c'est du travail perdu.

---

## Jour 23. Copilot dans Intune, et pourquoi c'est resté conceptuel

Tenant administration, Copilot. *"Copilot hasn't been set up yet. To use Copilot, your Global or
Billing Administrator will have to add capacity. Then have your Security Administrator set it up."*

Tarifs vérifiés chez Microsoft avant de décider de ne pas le faire :

| | |
|---|---|
| Unité de calcul de sécurité (SCU) provisionnée | **$4 par SCU et par heure** |
| SCU en dépassement | $6 par SCU |
| Minimum | 1 SCU |
| Changement de capacité effectif | sous 30 minutes, dans les deux sens |

Une heure, c'est $4 sur le papier et plus près de deux heures facturées en pratique, parce que le
provisionnement et le déprovisionnement prennent chacun jusqu'à trente minutes. Il faut aussi un
abonnement Azure avec un moyen de paiement, ce qui est une relation de facturation permanente plutôt
qu'un achat ponctuel. Le forum de support de Microsoft lui-même contient la question de quelqu'un qui l'a
laissé tourner six jours par accident.

**Décision : pas acheté.** L'examen le teste de façon conceptuelle et les concepts sont connus :

- La capacité s'achète séparément sous forme de SCU dans Azure. Aucune licence Intune ne l'inclut, pas
  même la Suite
- Deux rôles, volontairement séparés : Global ou Billing Administrator ajoute la capacité, Security
  Administrator le configure
- Il apparaît **à l'intérieur des panneaux existants** plutôt que comme une section à part
- Les réponses sont **ancrées dans les données du tenant**, donc il peut expliquer pourquoi un
  appareil nommé est non conforme

---

## Jour 23. Windows 365, construction bloquée par les licences

Devices, Manage Windows 365 Cloud PCs, Provision Cloud PCs. Vide, avec **Create policy grisé** faute de
licences Windows 365. Vérifié sur la place de marché : **aucun essai n'existe**. Enterprise est à
CHF 24.50 par licence et par mois, Business CHF 22.40, Frontline CHF 36.70.

Pas acheté. Business aurait été moins cher et inutile, parce que Windows 365 Business n'est pas du tout
géré par Intune.

Ce que représentent les quatre onglets de cette page, qui est le contenu d'examen :

**Enterprise contre Business.** Enterprise est géré via Intune et le Cloud PC apparaît dans la liste des
appareils en recevant chaque stratégie. Business est en libre-service, plafonné à 300 utilisateurs, pas
géré par Intune. MD-102 ne couvre qu'Enterprise.

**Une stratégie d'approvisionnement définit quatre choses :** le type de jointure (jointure Microsoft
Entra ou jointure hybride), le réseau (réseau hébergé par Microsoft ou connexion réseau Azure), l'image
(galerie ou personnalisée), et le nommage, la langue et la région.

**La connexion réseau Azure** n'est nécessaire que pour son propre réseau virtuel, ce que la jointure
hybride exige parce qu'elle a besoin d'une ligne de vue réseau vers un contrôleur de domaine. Le réseau
hébergé par Microsoft est la valeur par défaut et ne demande aucun abonnement Azure.

**L'approvisionnement est déclenché par deux choses ensemble :** l'utilisateur détient une licence
Windows 365 **et** il est dans le groupe que la stratégie d'approvisionnement cible. Les deux, pas l'un
ou l'autre.

**Retirer la licence lance une période de grâce de sept jours** avant que le Cloud PC soit
désapprovisionné.

**Les actions propres aux Cloud PC**, en plus du jeu d'actions à distance habituel : **Resize** change le
matériel virtuel, **Reprovision** reconstruit depuis l'image et détruit tout ce qui s'y trouve, **Place
under review** le gèle et en prend un instantané pour une investigation.

---

## Contenu terminé

Jours 1 à 23, les cinq domaines. Ce qui reste, c'est la consolidation avant l'examen.

---

## Reconstruction, 15 au 25 septembre. Autopilot de bout en bout depuis une machine vierge

Compte rendu complet, par étapes, dans `rebuild/README.md`. Résumé :

Machine construite en appliquant l'image Windows avec DISM depuis l'hôte, après l'échec du démarrage DVD
en génération 2. Hachage matériel récolté dans la machine à l'écran de première exécution, extrait en
montant son disque sur l'hôte, importé dans Intune. Le groupe dynamique l'a attrapé sur `[ZTDId]`, profil
de déploiement et Enrollment Status Page affectés au groupe, MDM user scope confirmé sur All, licence
attribuée à l'utilisateur de test.

Huit échecs en chemin. Les deux à garder :

**`bcdboot` a échoué en silence.** Un exécutable natif signale l'échec via `$LASTEXITCODE`, que
`$ErrorActionPreference = 'Stop'` ne voit pas. Le script a affiché un succès sur un disque sans chargeur
de démarrage.

**`801C03ED` à la connexion.** "Users may join devices to Microsoft Entra ID" était sur Selected. Le
journal du démontage (teardown) indiquait ce paramètre comme remis aux valeurs par défaut. Le journal
avait tort et le tenant avait raison.

---

## Identité, 17 et 18 octobre 2026

Compte rendu complet dans [identity/README.md](identity/README.md). Résumé :

Parti de la faille laissée ouverte au jour 15 : paramètres de sécurité par défaut désactivés et aucune
stratégie d'accès conditionnel, donc rien n'exigeait l'authentification multifacteur (MFA) pour les
utilisateurs.

Construit d'abord le compte d'accès d'urgence : cloud uniquement, Global Administrator, dans un groupe
d'exclusion auquel des rôles peuvent être affectés, avec un mot de passe hors ligne et une clé d'accès
(passkey) dans Authenticator. La clé d'accès a été enregistrée via un passe d'accès temporaire
(Temporary Access Pass) à usage unique, puis les méthodes push et code qu'Authenticator avait ajoutées
à côté ont été retirées. Testé avec une vraie connexion.

Puis trois stratégies d'accès conditionnel en mode rapport uniquement : MFA pour tous les
utilisateurs, authentification héritée bloquée, appareil conforme pour l'utilisateur de test sous
Windows. Vérifiées avec What If pour l'utilisateur de test et pour le compte d'urgence, puis avec une
vraie connexion depuis la VM, puis activées.

À retenir :

**L'avertissement de verrouillage présélectionne "Exclude current user".** C'est la protection de
Microsoft, et elle est juste dans un tenant sans compte d'urgence. Ici, elle aurait exempté
le compte Global Administrator habituel de la stratégie MFA.

**La vraie connexion était sur l'autre onglet.** Après que j'ai ouvert Outlook sur le web dans Edge sur la VM jointe, le journal des connexions interactives ne contenait que la connexion Windows. Les connexions Edge, avec les
résultats en rapport uniquement, étaient dans le journal des connexions non interactives.

**Un script a trouvé ce que What If ne pouvait pas,** une fois qu'il listait aussi les utilisateurs
exclus. Un audit PowerShell en lecture seule via Microsoft Graph a montré que les trois stratégies
excluaient l'utilisateur d'urgence, pas le groupe protégé `EmergencyAccess`. What If donne la même
réponse pour les deux. J'ai modifié les trois pour exclure le groupe, puis relancé le script pour confirmer.

**Le compte d'urgence a servi pour de vrai le lendemain de sa création.** Le compte administrateur habituel ne
pouvait pas effectuer la MFA lors d'une nouvelle connexion. Le compte d'urgence lui a émis un mot de
passe d'accès temporaire à usage unique, et Authenticator a été enregistré avec.
