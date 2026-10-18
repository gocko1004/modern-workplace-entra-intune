# Jour 8 : filtres d'affectation et inscription Android

*Changer qui reçoit une stratégie sans toucher à un seul groupe, et placer une deuxième plateforme sous gestion sur du vrai matériel.*

Du mercredi 26 au jeudi 27 août 2026 · parcours d'étude MD-102 · machine virtuelle Windows `AB-18949`, téléphone Android personnel

**En fin de journée**

- Un filtre d'affectation construit et prouvé dans les deux sens sur un appareil réel
- Le tenant lié à Managed Google Play, après qu'un prérequis documenté a coûté une heure
- Un téléphone Android personnel inscrit en profil professionnel, évalué, en échec, corrigé et conforme
- Une stratégie de conformité Android construite, révélant que la conformité est par plateforme
- La gestion Apple comprise sans appareil Apple, délibérément non configurée

## 1. Ce qu'est un filtre d'affectation

> **Le problème qu'il résout**
>
> Jusqu'à aujourd'hui, chaque stratégie partait vers un groupe entier. Tout, ou rien.
>
> Un vrai parc a besoin de « ce groupe, mais seulement les machines Windows 11 » ou « ce groupe, mais pas les appareils personnels ». Sans filtres, on construit un groupe distinct pour chaque combinaison. Vingt stratégies avec trois variantes chacune, ce sont soixante groupes à créer, à maintenir, et un jour à hériter de quelqu'un qui est parti, sans savoir à quoi sert chacun d'eux.
>
> Un filtre est une règle réutilisable, évaluée sur l'appareil à chaque check-in. On le construit une fois, on l'applique à autant d'affectations qu'on veut, et les groupes restent intacts.

**[Portable]** intune.microsoft.com→ Tenant administration→ Assignment filters→ Create

Construit sous le nom `Filter-Corporate-Owned`, plateforme Windows 10 and later, avec la règle :

```
(device.deviceOwnership -eq "Corporate")
```

> **L'habitude à prendre**
>
> Sur la page Rules, il y a un bouton **Preview devices**. Il liste exactement quels appareils inscrits correspondent à la règle, avant que vous n'affectiez quoi que ce soit à qui que ce soit.
>
> Valider le ciblage avant le déploiement plutôt qu'après, c'est la différence entre un filtre et une supposition.

### Les trois modes

| Mode | Effet |
|---|---|
| Do not apply a filter | Tout le monde dans le groupe reçoit la stratégie |
| **Include** filtered devices in assignment | Seuls les appareils correspondant au filtre la reçoivent |
| **Exclude** filtered devices in assignment | Les appareils correspondants sont ceux qui ne la reçoivent **pas** |

## 2. Le prouver, en cinq étapes

> **Pourquoi le paramètre de test a été choisi avec soin**
>
> Le test évident consiste à vérifier si le pare-feu est activé après avoir appliqué une stratégie de pare-feu. Ce test ne vaut rien, parce que **Windows active le pare-feu par défaut**. Un résultat True est tout aussi compatible avec « la stratégie a fonctionné » qu'avec « la stratégie n'a rien fait ».
>
> `LogBlocked`, la journalisation des paquets rejetés par le pare-feu, est **désactivée** par défaut. Rien ne l'active par accident. Donc si elle affiche True, une seule chose l'a mise là.
>
> **Pour prouver qu'une stratégie fonctionne, choisissez un paramètre dont la valeur par défaut est l'inverse de ce que vous réglez.**

Chaque étape ne changeait qu'une seule variable :

| # | Configuration | `LogBlocked` | Ce que ça a prouvé |
|---|---|---|---|
| 1 | Aucune stratégie | False | Référence, l'état naturel |
| 2 | Stratégie affectée | **True** | Intune livre à cet appareil |
| 3 | Stratégie désaffectée | **False** | Le retrait l'annule. Pas de tatouage |
| 4 | Filtre, mode Include | **True** | Ajouter un filtre n'a pas cassé une affectation qui fonctionnait |
| 5 | Filtre, mode **Exclude** | **False** | Le filtre seul a stoppé la livraison |

> **Ce que cela établit**
>
> Pendant les étapes 4 et 5, l'appareil n'a jamais quitté `Dyn-Autopilot-Devices`. L'appartenance au groupe était identique. Le seul changement était le mode du filtre.
>
> **On peut changer qui reçoit une stratégie sans changer aucun groupe.** C'est tout l'intérêt, et c'est maintenant démontré plutôt que supposé.

> **Délais, et un piège**
>
> Les retraits atteignent un appareil nettement plus lentement que les affectations. Le service doit déterminer quoi retirer plutôt que simplement quoi envoyer.
>
> La vérification qui supprime le doute, c'est `mdmdiagnosticstool.exe` : si le chemin du paramètre figure encore dans le propre rapport de l'appareil, le retrait n'est pas encore arrivé et il n'y a rien à dépanner.

## 3. Filtres ou groupes dynamiques

|  | Filtre d'affectation | Groupe dynamique |
|---|---|---|
| Cible sur | Les propriétés de l'appareil : système d'exploitation, modèle, fabricant, propriété, catégorie | N'importe quel attribut de l'annuaire, utilisateurs ou appareils |
| Évalué | Au check-in de l'appareil. **Aucun délai d'appartenance** | Selon le calendrier propre de l'annuaire, avec un vrai délai |
| Utilisable par | Les stratégies et applications Intune uniquement | L'accès conditionnel, les licences, Autopilot, tout |
| Affectation d'un profil Autopilot | **Impossible** | **Obligatoire** |

> **Pourquoi la dernière ligne explique le Jour 5**
>
> Un filtre lit les propriétés d'un appareil **inscrit**. Un appareil enregistré dans Autopilot n'est pas encore inscrit, donc il n'a aucune propriété à lire. Un filtre n'a rien à quoi correspondre.
>
> C'est pour cela que le profil de déploiement Autopilot avait besoin d'un groupe dynamique sur l'identifiant Zero Touch Deployment, et qu'aucun filtre n'aurait jamais pu le remplacer.
>
> La plupart des vrais tenants utilisent les deux : des groupes dynamiques là où quelque chose en dehors d'Intune a besoin de l'appartenance, des filtres pour affiner les affectations à l'intérieur d'Intune.

## 4. Lier le tenant à Managed Google Play

> **Rien côté Android ne fonctionne sans cela**
>
> Android Enterprise passe par Google. Avant qu'un appareil Android puisse s'inscrire par quelque méthode que ce soit, le tenant Intune doit être lié à une entreprise Google.

**[Portable]** intune.microsoft.com→ Devices→ Enrollment→ Android→ Managed Google Play

### Le prérequis qui a coûté une heure

> **Ce qui a cassé**
>
> Le formulaire d'inscription de Google a envoyé un code de vérification à six chiffres à `admin@labtenant.onmicrosoft.com`. Ouvrir cette boîte aux lettres a renvoyé :
>
> ```
> Microsoft.Exchange.Clients.Owa2.Server.Core.OwaUserHasNoMailboxAndNoLicenseAssignedException
> ```
>
> Le tenant avait Intune Suite et Entra ID P2. Aucun des deux n'inclut Exchange Online, donc le compte n'avait pas de boîte aux lettres.

> **La documentation Microsoft le dit deux fois**
>
> > Le compte doit également disposer d'une boîte aux lettres configurée pour terminer le processus de validation requis par Google.
>
> > Le compte Microsoft Entra doit disposer d'une boîte aux lettres active pour terminer le processus de validation requis par Google.
>
> C'est un prérequis strict, pas une commodité facultative. Google valide l'adresse quel que soit le chemin de connexion utilisé.

> **Le détour, et ce qu'il a coûté**
>
> Google proposait **Sign in with Microsoft**, un chemin fédéré qui semblait contourner entièrement le code. Il a échoué avec "Your account was not created" et aucun autre détail. Raisonnable de supposer que la boîte aux lettres n'était plus nécessaire. Ce n'était pas le cas.
>
> Résolu en prenant une **version d'évaluation Microsoft 365 Business Standard**, uniquement parce qu'elle inclut Exchange Online, et en l'affectant au compte admin. Cherchez dans la Marketplace le produit dont vous avez besoin plutôt qu'un nom de plan : la recherche "Exchange Online" ne renvoyait qu'un module complémentaire Defender, alors que "Business Standard" renvoyait la version d'évaluation qui provisionne réellement une boîte aux lettres.

> **Le deuxième échec, et sa cause**
>
> Même avec une boîte aux lettres, l'inscription a de nouveau échoué. Les soupçons se sont portés sur NordVPN, qui avait cassé des panneaux du portail deux fois plus tôt dans ce labo, et sur le filtrage web de Malwarebytes. Les deux ont été arrêtés. Aucun n'était responsable.
>
> **L'URL d'inscription porte un jeton à usage unique émis au moment où vous cliquez sur Connect to Google now.** Il avait expiré pendant le détour par la boîte aux lettres. Fermer le panneau, le rouvrir et relancer le flux depuis le début a fonctionné immédiatement.

> **À retenir**
>
> Quand une inscription fédérée échoue sans détail, **relancez le flux depuis le panneau d'origine avant de déboguer quoi que ce soit d'autre**. Le jeton est émis quand vous cliquez, pas quand vous finissez de vous connecter. Une heure est partie dans des théories sur le navigateur et les logiciels de sécurité qui n'ont jamais été la cause.

### Le choix du compte, et pourquoi il compte pour de bon

> **Cette liaison ne se défait pas facilement**
>
> Le compte utilisé devient l'administrateur Android du tenant, de façon permanente. En changer signifie déconnecter et réinscrire chaque appareil Android.
>
> Utilisez une **identité d'organisation**, jamais un compte Gmail personnel. Quand la personne qui possède ce compte personnel s'en va, la liaison devient ingérable.
>
> Depuis août 2024, Microsoft recommande d'utiliser le compte Microsoft Entra plutôt qu'une adresse Gmail, et c'est le chemin pris ici.

Google a ensuite proposé des abonnements gratuits facultatifs : Google Workspace Essentials Starter et Chrome Enterprise Core. **Android Enterprise était déjà marqué Included**, ce qui est tout ce qu'Intune exige. Les autres ont été refusés, au nom du principe qu'un service gratuit doit quand même être géré et, un jour, nettoyé.

## 5. Inscrire un téléphone Android personnel

**[Téléphone]** Play Store→ Intune Company Portal→ Sign in with work account→ Set up work profile

> **Ce qu'est réellement un profil professionnel**
>
> Android crée un **second conteneur** sur le même téléphone. Les applications professionnelles reçoivent un badge en forme de mallette. Les applications personnelles restent en dehors, intactes.
>
> La séparation est réelle, pas cosmétique. Les applications personnelles ne voient pas les fichiers professionnels et les applications professionnelles ne voient pas les fichiers personnels. Intune ne gère que le côté professionnel. Il ne peut pas lire les photos, messages ou applications personnels.
>
> Cela s'est démontré par accident : une capture d'écran prise dans une application professionnelle s'est enregistrée dans le stockage du profil professionnel et était inaccessible depuis le côté personnel.

> **La séparation est configurable, et c'est matière à examen**
>
> Un profil de restrictions d'appareil Android Enterprise contrôle si des données peuvent franchir la frontière : copier-coller entre profils, partage depuis les applications professionnelles vers les personnelles, et visibilité des contacts. Par défaut, c'est bloqué.

## 6. La conformité est par plateforme

> **Ce que le téléphone a signalé**
>
> > No compliance policies have been assigned to the device. Your device must receive compliance policies before it can be used to access your organization's resources.

> **Deux choses ont provoqué ce message ensemble**
>
> 1. **Les stratégies de conformité sont par plateforme.** La stratégie Windows construite au Jour 4 ne fait rien pour Android. Chaque plateforme a besoin de la sienne
> 2. Le paramètre à l'échelle du tenant **Mark devices with no compliance policy assigned as** avait été changé de Compliant en **Not compliant** la veille
>
> Hier, ce changement était une décision de durcissement abstraite. Aujourd'hui, il est apparu sur un vrai téléphone sous la forme d'un appareil bloqué. Avec la valeur par défaut, il aurait été silencieusement laissé passer comme conforme, sans jamais avoir été évalué.

**[Portable]** Devices→ Compliance→ Create policy→ Android Enterprise→ Personally-owned work profile

### La scission Android 12

> **Google a changé la façon de spécifier les mots de passe**
>
> La page des paramètres est divisée en deux branches, et la raison est un vrai changement de plateforme :
>
> | Branche | Paramètre | Valeurs |
> |---|---|---|
> | Android 12 et ultérieur | Password complexity | None, Low, Medium, High |
> | Android 11 et antérieur | Required password type, plus la longueur minimale | Numeric, alphabetic, alphanumeric, with symbols |
>
> Avec Android 12, Google a retiré les exigences fines de longueur et de caractères et les a remplacées par trois niveaux de complexité. On ne dit plus « au moins six caractères avec un chiffre ». On choisit un niveau et Google décide de ce qui le satisfait.
>
> **Réglez les deux branches.** Vous ne savez pas quelle version tourne sur chaque appareil d'un parc.

### Mot de passe du profil professionnel ou mot de passe de l'appareil

> **Deux paramètres distincts, et le bon pour le BYOD (bring-your-own-device)**
>
> **Require a password to unlock work profile** sécurise uniquement le conteneur professionnel.
>
> Les paramètres **Device password** sécurisent tout le téléphone, côté personnel compris.
>
> Sur un appareil personnel, prenez celui du profil professionnel. Il est moins intrusif, c'est ce qu'une vraie organisation réglerait pour le BYOD, et il respecte la frontière du conteneur au lieu de passer par-dessus.

### Actions en cas de non-conformité, et le délai de grâce

> **Le paramètre qui mérite le plus d'être compris**
>
> Chaque stratégie porte une action par défaut : **Mark device noncompliant**, planifiée à **0 days**, c'est-à-dire immédiatement.
>
> Régler cette planification à trois jours crée un **délai de grâce** : un appareil qui échoue n'est pas marqué non conforme pendant trois jours, ce qui laisse à l'utilisateur le temps de corriger avant que l'accès conditionnel ne commence à le bloquer.
>
> Zéro jour, c'est honnête et brutal. Quelqu'un dont le mot de passe expire pendant la nuit perd l'accès à sa messagerie avant le petit-déjeuner, sans avertissement et sans autre issue qu'un appel au support.

### La chaîne, de bout en bout

- **Stratégie affectée** À un groupe dynamique d'appareils Android.
- **Appareil évalué** À son check-in suivant.
- **Contrôle en échec** Aucun mot de passe de profil professionnel défini.
- **Utilisateur invité à agir** Company Portal a nommé l'échec exact.
- **Conforme** Après avoir défini le verrouillage du profil professionnel.

> **Pourquoi cela vaut la peine d'être raconté en entretien**
>
> On n'a jamais dit à l'utilisateur « votre appareil est cassé ». On lui a dit exactement quelle exigence échouait et on lui a donné un bouton pour corriger. C'est ce que fait une stratégie de conformité bien configurée, et c'est la différence entre une stratégie qui fonctionne et une stratégie qui génère des tickets au support.

## 7. Apple, compris sans appareil Apple

**[Portable]** Devices→ Enrollment→ Apple→ Apple MDM Push Certificate

Délibérément non configuré. Il n'y a aucun appareil Apple dans ce labo, et le certificat crée une obligation de renouvellement annuel avec de vraies conséquences si on l'oublie.

| Étape | Ce qui se passe |
|---|---|
| 1 | Consentir à ce que Microsoft envoie des données d'appareil et d'utilisateur à Apple |
| 2 | Télécharger une demande de signature de certificat depuis Intune |
| 3 | L'apporter sur l'Apple Push Certificates Portal, se connecter avec un Apple ID, la charger. Apple émet un certificat |
| 4 | Charger le certificat d'Apple en retour dans Intune, avec l'Apple ID utilisé |

> **Les quatre faits qui comptent, tous issus de l'étape 4**
>
> - Le certificat est valable **un an** et doit être renouvelé
> - Il doit être renouvelé avec le **même Apple ID**. Un autre n'est pas un renouvellement, c'est un nouveau certificat
> - Un nouveau certificat signifie que **chaque appareil Apple doit être réinscrit**, à la main
> - Donc l'Apple ID doit être un **compte d'organisation**. Quand la personne qui possède un compte personnel s'en va, le parc sort de gestion tout seul
>
> Structurellement identique à la liaison du compte Google plus tôt le même jour : une identité qui doit survivre à celui qui l'a configurée.

> **Bon à savoir aussi**
>
> **Automated Device Enrolment** est l'équivalent Apple de Windows Autopilot, piloté par Apple Business Manager. **FileVault** est l'équivalent macOS de BitLocker et se trouve sous Endpoint security, Disk encryption.

## 8. À retenir pour l'examen

- Un filtre affine une affectation sans changer l'appartenance au groupe. Le mode Include ne livre qu'aux correspondances ; le mode Exclude livre à tout le monde sauf aux correspondances.
- Les filtres sont évalués au check-in de l'appareil, donc il n'y a pas de délai d'appartenance. Les groupes dynamiques sont évalués selon le calendrier de l'annuaire.
- Un filtre ne fonctionne qu'à l'intérieur d'Intune. L'accès conditionnel, les licences et Autopilot ont tous besoin de vrais groupes.
- Un filtre ne peut pas affecter un profil Autopilot, parce qu'un appareil non inscrit n'a aucune propriété à faire correspondre.
- Limites : 200 filtres par tenant, 3 072 caractères par filtre. Les filtres d'applications gérées ne s'appliquent qu'aux stratégies de protection des applications et de configuration des applications.
- Supprimer un filtre exige de le retirer d'abord de chaque affectation.
- Android Enterprise exige que le tenant soit lié à Managed Google Play. Rien côté Android ne fonctionne sans cela.
- Cette liaison exige que le compte Microsoft Entra ait une **boîte aux lettres active**, parce que Google valide l'adresse.
- Le compte de liaison est permanent. En changer signifie réinscrire chaque appareil Android.
- La gestion par administrateur d'appareil Android est dépréciée pour les appareils avec Google Mobile Services.
- Les stratégies de conformité sont par plateforme. Une stratégie Windows ne fait rien pour Android.
- Sur Android 12 et ultérieur, les règles de mot de passe sont un niveau de complexité. Sur Android 11 et antérieur, c'est un type plus une longueur minimale.
- Le mot de passe du profil professionnel et le mot de passe de l'appareil sont des paramètres distincts. En BYOD, celui du profil professionnel est le bon.
- Les actions en cas de non-conformité marquent par défaut un appareil non conforme à 0 jour. Un délai de grâce laisse aux utilisateurs le temps de corriger.
- Aucun appareil Apple ne peut s'inscrire sans certificat push MDM Apple, valable un an, renouvelable uniquement avec le même Apple ID.

*Jour 8 de la série de labos MD-102. Rédigé à partir du journal de session, 26 et 27 août 2026. Tenant de labo uniquement, pas de production. Chaque chemin de portail et chaque commande de ce document a été exécuté pendant la session et son résultat vérifié.*
