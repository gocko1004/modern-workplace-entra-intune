# Jour 7 : appareils orphelins, magasins de stratégies et modèles d'administration

*Récupérer un appareil qu'Intune ne pouvait plus atteindre, et trois heures passées à prouver qu'une stratégie fonctionnait alors qu'elle avait fonctionné depuis le début.*

Du lundi 24 au mardi 25 août 2026 · parcours d'étude MD-102 · machine virtuelle `W11-CORP-01`

**En fin de journée**

- Déploiement Windows Autopilot terminé de bout en bout, l'objectif qui avait échoué deux fois auparavant
- Un appareil dont Intune avait perdu la trace, récupéré sans qu'Intune ne l'atteigne jamais
- Les deux échecs précédents attribués à la machine hôte, et non à une erreur de configuration
- Un profil de catalogue des paramètres construit, appliqué, retiré et confirmé dans les deux sens
- Des paramètres d'application tierce amenés dans Intune par l'import d'un modèle d'administration

## 1. Ce qu'est Intune, en un paragraphe

> **Le modèle mental sur lequel tout le reste repose**
>
> Intune est un site web où l'on fixe des règles pour les ordinateurs de l'entreprise. On ne touche jamais aux ordinateurs eux-mêmes. Chaque ordinateur contacte Intune à intervalles réguliers, récupère les règles qui s'appliquent à lui et les met en œuvre.
>
> **Rien ne se passe au moment où vous cliquez sur Save.** Le changement attend que cet ordinateur reprenne contact. Ce seul fait explique l'essentiel de la confusion dans ce document, et l'essentiel de la confusion de quiconque apprend cela pour la première fois.
>
> Le nom technique de ce contact est une **synchronisation** (sync), et le mécanisme s'appelle la **gestion des appareils mobiles (MDM)**. C'est un système en mode pull : l'appareil demande, le service répond. Le service ne peut rien pousser vers un appareil qui ne demande jamais.

## 2. L'appareil qui a disparu d'Intune

> **Ce qui a cassé**
>
> **Devices** → **All devices** était complètement vide. Aucun ordinateur listé, alors qu'un était géré la veille.

Microsoft Entra, le service d'identité qui se trouve derrière Intune, détenait encore un enregistrement pour l'appareil. L'ouvrir a montré quelque chose d'utile :

**[Portable]** entra.microsoft.com→ Entra ID→ Devices→ All devices→ AB-25025

| Champ | Valeur | Ce que ça nous a appris |
|---|---|---|
| Join type | Microsoft Entra joined | L'appareil avait encore une identité valide |
| Owner | Goce Petrov | Le bon appareil, pas un doublon périmé |
| Mobile device management | **None** | Rien ne le gère. La veille, on y lisait "Microsoft Intune" |
| Bannière en haut | "This device is a Windows Autopilot device" | Son inscription matérielle avait survécu, ce qui s'est révélé être le chemin du retour |

### Ce qu'est un appareil orphelin

> **En clair**
>
> L'ordinateur détenait encore tout ce qu'il lui fallait pour être géré : une identité valide, un certificat prouvant cette identité, et l'adresse du service de gestion. De son propre point de vue, c'était une machine d'entreprise normale et inscrite.
>
> Intune n'en avait aucune trace. Il n'y avait aucune entrée sur laquelle cliquer, donc rien à quoi envoyer une commande. Chaque action à distance, y compris la synchronisation, le wipe et la livraison de stratégies, exige un enregistrement d'appareil sur lequel agir.
>
> **L'appareil se croyait géré. Le service ignorait qu'il existait.** C'est ça, un orphelin.

### Comment nous l'avons créé

- **1. Wipe lancé** Intune a envoyé une commande de réinitialisation d'usine.
- **2. L'appareil a obéi** La réinitialisation a démarré et l'a signalé.
- **3. Enregistrement supprimé** Intune a supprimé l'entrée de l'appareil, à juste titre.
- **4. Instantané restauré** Nous avons ramené la machine virtuelle à l'état d'avant le wipe.

> **À retenir**
>
> **Ne jamais restaurer un instantané de machine virtuelle après avoir lancé un wipe à distance.** L'instantané ramène l'appareil en arrière dans le temps. Le service ne recule pas avec lui. Tout ce qui suit, c'est les deux qui ne sont plus d'accord sur la réalité.
>
> C'est propre au travail en labo avec des machines virtuelles, mais la même forme apparaît avec du matériel physique chaque fois qu'un appareil est restauré depuis une image de sauvegarde après avoir été mis hors service dans la console.

## 3. Le récupérer, sans Intune

> **La règle qui a rendu la récupération possible**
>
> Intune tient **deux listes distinctes**, et il est courant de les confondre.
>
> | Liste | Où elle se trouve | Ce qu'elle contient |
> |---|---|---|
> | Appareils gérés | Devices → All devices | Les ordinateurs actuellement sous gestion |
> | Inscriptions Autopilot | Devices → Enrollment → Windows → Devices | Le matériel enregistré pour la configuration automatique |
>
> Un wipe retire l'appareil de la **première** liste. Il ne touche jamais à la **seconde**.

> **Pourquoi la seconde liste survit**
>
> Autopilot identifie une machine par un **hachage matériel**, un long code dérivé de ses caractéristiques physiques : la puce de sécurité, la carte mère, le disque, les cartes réseau. Il n'est pas stocké sur le disque de l'ordinateur, donc effacer le disque ne peut pas le supprimer.
>
> Voyez-le comme une empreinte digitale gardée au dossier. La personne peut changer de nom, de vêtements et d'adresse, l'empreinte l'identifie toujours.
>
> C'est une conception délibérée, pas une faille. C'est précisément ainsi qu'un portable rendu par un employé qui part est remis à la personne suivante sans que personne à l'IT ne le déballe.

### Le correctif

Parce que l'inscription avait survécu, l'appareil pouvait être ramené **depuis son propre côté**, sans qu'Intune ne l'atteigne jamais.

**[Machine virtuelle]** Settings→ System→ Recovery→ Reset this PC→ Remove everything→ Local reinstall

> **Local reinstall ou cloud download**
>
> **Local reinstall** reconstruit Windows à partir des fichiers déjà présents sur le disque. Rapide, aucun téléchargement.
>
> **Cloud download** va chercher une copie fraîche chez Microsoft, environ 4 Go. À choisir quand on soupçonne les fichiers locaux d'être endommagés. Ici ils étaient sains, donc local était le bon choix.

Au redémarrage, la machine est arrivée à l'**expérience de première utilisation (OOBE, out-of-box experience)**, les écrans de configuration du premier démarrage. Elle a présenté son hachage matériel, Microsoft l'a fait correspondre à l'inscription, et Autopilot a pris la main.

> **L'écran qui vous dit qu'Autopilot s'est déclenché**
>
> Lisez le texte au-dessus de la zone de connexion. **"Let's set things up for your work or school"** signifie que le profil Autopilot a été téléchargé et appliqué. **"Sign in to your Microsoft account"** signifie que non, et un compte professionnel y sera refusé, aussi correct que soit le mot de passe.
>
> S'il ne s'est pas déclenché, appuyez sur `Shift + F10` pour ouvrir une invite de commandes et lancez `shutdown /r /t 0`. Le profil est redemandé au démarrage suivant.

### La preuve qu'il a réellement été reconstruit

L'appareil est revenu dans Intune sous le nom `AB-18949`. Il s'appelait `AB-25025`.

> **Pourquoi le changement de nom est la preuve**
>
> Le profil de déploiement Autopilot porte un **modèle de nom d'appareil**, un motif qui génère un nom au moment de la configuration. Un nouveau nom signifie que le modèle a tourné à nouveau, donc qu'il s'agit d'un objet appareil nouvellement créé et non de l'ancien qui se reconnecte.
>
> Sans cela, « il est revenu » et « il a été reconstruit » sont identiques vus de la console.

## 4. Pourquoi la tentative précédente s'est figée à 98 pour cent

> **Ce qui a cassé**
>
> La réinitialisation s'est arrêtée à 98 pour cent et y est restée. Le disque travaillait dur pendant tout ce temps, ce qui donnait l'impression que Windows était occupé plutôt que bloqué.

Mesurer la machine hôte a donné la réponse immédiatement :

|  | Tentative échouée | Tentative réussie |
|---|---|---|
| Espace libre sur le lecteur D | **0 Go** | 77.4 Go |
| Le disque virtuel a grossi jusqu'à | 22.97 Go, puis est mort | 30.69 Go, puis a terminé |

> **Pourquoi un disque hôte plein ressemble exactement à une panne Windows**
>
> La machine virtuelle ne voit pas le vrai disque dur en dessous d'elle. Elle ne voit que son propre disque virtuel, qui annonce plein d'espace libre, donc elle continue d'écrire normalement.
>
> L'hôte ne peut pas faire grossir le fichier qui porte ce disque virtuel, parce que le vrai lecteur est plein. L'écriture échoue. La machine virtuelle traite une écriture échouée comme un incident passager et réessaie. Indéfiniment.
>
> Le résultat, c'est une forte activité disque avec une barre de progression qui ne bouge jamais. Tout pointe vers Windows, et rien de tout cela n'est Windows.

> **À retenir**
>
> **Vérifiez l'espace libre sur l'hôte avant tout wipe ou toute reconstruction.** Un cycle complet de wipe et redéploiement sur cette installation consomme environ 30 Go, donc gardez au moins 40 Go libres.
>
> Aucune documentation Microsoft ne le mentionne, parce que la machine hôte n'est pas leur affaire. C'est la vôtre.

## 5. Erreur 0x800705AA, et pourquoi la mémoire dynamique ne l'a pas sauvée

> **Ce qui a cassé**
>
> ```
> Failed to restore 'W11-CORP-01'.
> Could not allocate 3536 MB of RAM: Insufficient system
> resources exist to complete the requested service. (0x800705AA)
> ```
>
> L'hôte avait 3.52 Go libres. La machine virtuelle en voulait 3.45 Go. Elle a échoué à la marge, parce que Hyper-V a besoin de la mémoire demandée plus sa propre surcharge par-dessus.

> **Le mot qui l'explique : restore**
>
> Le message dit **restore**, pas start. La machine virtuelle était dans un **état enregistré** (saved state), la version Hyper-V de la mise en veille prolongée : le contenu de sa mémoire a été écrit sur disque lors de son dernier arrêt.
>
> Restaurer un état enregistré signifie remettre cette mémoire **exactement comme elle était**. Ce n'est pas un démarrage à froid, donc elle ne peut pas démarrer plus petite et grandir. La mémoire dynamique (Dynamic Memory), qui permet à une machine de commencer avec moins et de s'étendre au besoin, n'a aucun effet ici, parce qu'il n'y a rien à négocier.

> **Deux portes de sortie**
>
> - **Libérer de la mémoire sur l'hôte.** Deux navigateurs étaient ouverts, retenant ensemble 4.3 Go. En fermer un a résolu le problème
> - **Abandonner l'état enregistré** avec `Remove-VMSavedState`, pour que la machine démarre à froid. La mémoire dynamique s'applique alors et elle peut démarrer avec ce que l'hôte peut lui céder. Le coût, c'est la perte de la session suspendue

> **Les réglages de mémoire dynamique utilisés**
>
> ```
> Set-VMMemory -VMName "W11-CORP-01" -DynamicMemoryEnabled $true `
>   -MinimumBytes 2GB -StartupBytes 4GB -MaximumBytes 8GB
> ```
>
> Sur un hôte de 16 Go qui fait tourner un navigateur et d'autres travaux, une allocation fixe est le mauvais choix. La mémoire dynamique laisse Hyper-V donner à la machine virtuelle ce qui est réellement disponible et le récupérer sous pression. Une allocation fixe de 6 Go aurait simplement échoué au démarrage.

## 6. Stratégies de conformité, et celle que vous n'avez pas créée

**[Portable]** intune.microsoft.com→ Devices→ All devices→ AB-18949→ Device compliance

Deux stratégies étaient listées. Une seule avait été construite à la main.

| Stratégie | Évaluée en tant que | Origine |
|---|---|---|
| `Win-Baseline-Compliance` | L'utilisateur connecté | Construite au Jour 4 |
| `Default Device Compliance Policy` | Compte système | **Intégrée.** Présente dans chaque tenant |

> **Les mots mêmes de Microsoft**
>
> > Les paramètres de stratégie de conformité sont des configurations à l'échelle du tenant qui agissent comme une stratégie de conformité intégrée que chaque appareil reçoit.
>
> Elle ne peut pas être créée et ne peut pas être supprimée. Elle est évaluée sous le compte système parce qu'elle n'appartient à aucun utilisateur.

### Ce que fait réellement une stratégie de conformité

> **Elle inspecte. Elle ne corrige pas.**
>
> Une stratégie de conformité regarde un appareil et rend un verdict : conforme ou non. Elle ne change rien. Comme une inspection d'hygiène : l'inspecteur ne nettoie pas la cuisine, il note si elle était propre.
>
> Un **profil de configuration** est l'inverse. Il change l'appareil et ne rend aucun verdict.
>
> Il faut les deux. La configuration rend l'appareil correct ; la conformité le prouve, et donne à l'accès conditionnel quelque chose sur quoi agir.

### La valeur par défaut qui laisse passer

**[Portable]** intune.microsoft.com→ Endpoint security→ Device compliance→ Compliance policy settings

> **Le paramètre, et pourquoi la valeur par défaut est mauvaise**
>
> **Mark devices with no compliance policy assigned as** est livré réglé sur **Compliant**.
>
> Autrement dit : un appareil qui n'a jamais été évalué est traité comme sain. On le laisse passer à cause d'un contrôle manquant, pas d'un contrôle réussi.
>
> Changé en **Not compliant**. Les recommandations de Microsoft disent la même chose : si vous utilisez l'accès conditionnel avec des stratégies de conformité, changez ce paramètre.

> **La distinction à retenir**
>
> Ce paramètre n'affecte que les appareils **sans aucune stratégie affectée**. Un appareil qui a une stratégie et la réussit reste conforme dans les deux cas. Le changer ne met pas en danger les appareils qui fonctionnent.

## 7. Construire un profil de catalogue des paramètres

**[Portable]** intune.microsoft.com→ Devices→ Manage devices→ Configuration→ Create→ New policy

Plateforme **Windows 10 and later**, type de profil **Settings catalog**, nommé `Win-Security-Baseline-Lite`.

> **Ce qu'est le catalogue des paramètres**
>
> Une liste consultable de milliers de paramètres Windows individuels. Vous choisissez ceux que vous voulez et composez votre propre profil.
>
> Ils sont écrits dans un **fournisseur de services de configuration (CSP)** sur l'appareil, le composant qui reçoit les instructions de gestion et les met en œuvre. C'est la même cible que celle où écrit la stratégie de groupe traditionnelle, atteinte par internet plutôt que depuis un contrôleur de domaine à l'intérieur d'un bâtiment.

> **Cherchez, ne parcourez pas**
>
> La recherche renvoie des **catégories** contenant des correspondances, pas des paramètres. Cliquez sur une catégorie et ses paramètres apparaissent en dessous. Avec des milliers de paramètres, l'arborescence est inutilisable pour trouver quoi que ce soit de précis.

### Ajouter un paramètre n'est pas la même chose que l'activer

> **Ce qui a cassé**
>
> Les deux paramètres SmartScreen ont été ajoutés au profil et tous deux affichaient **Disabled**. Enregistrer à ce moment-là aurait déployé un profil qui désactivait SmartScreen.
>
> Ajouter un paramètre l'amène dans le profil avec une valeur par défaut. Cela ne l'active pas.

### Le piège SMBv1

> **Un paramètre qui signifie le contraire de ce qu'il a l'air de dire**
>
> Sous **Administrative Templates\MS Security Guide**, `Configure SMB v1 server` était réglé sur **Enabled**, ce qui ressemblait à du durcissement.
>
> Sa propre description dit autre chose :
>
> > Disabling this setting disables server-side processing of the SMBv1 protocol. (Recommended.) Enabling this setting enables server-side processing of the SMBv1 protocol. (Default.)
>
> **Enabled aurait activé le protocole par lequel WannaCry s'est propagé.** Corrigé en Disabled. À noter qu'il exige aussi un redémarrage pour prendre effet.

> **Pourquoi le paramètre client se comporte différemment**
>
> `Configure SMB v1 client driver` est Enabled *plus* une liste déroulante indiquant "Disable driver (recommended)". Là, Enabled signifie « appliquer le choix de la liste déroulante », et c'est la liste déroulante qui porte l'action.
>
> Le paramètre serveur n'a pas de liste déroulante, donc Enabled et Disabled *sont* l'action. Même formulation, sens opposé, selon que le paramètre a une valeur enfant ou non.

### Sept paramètres sont devenus cinquante-cinq

> **Pourquoi le compte a bondi**
>
> Sept paramètres ont été choisis. La liste appliquée en affichait 55. Sélectionner les paramètres du pare-feu a automatiquement entraîné leurs paramètres enfants dépendants : journalisation, mode furtif, comportement de fusion des stratégies, actions par défaut en entrée et en sortie, trois de chaque, une fois par profil réseau.
>
> Ces enfants arrivent avec leurs propres valeurs par défaut, qui ne sont pas toujours ce qu'une personne soucieuse de sécurité choisirait.
>
> **Relisez la liste complète appliquée après chaque profil de catalogue des paramètres.** Ce que vous cochez n'est pas toujours ce qui part.

## 8. Trois heures sur les magasins de stratégies

> **Ce qui a cassé**
>
> Intune signalait les 55 paramètres comme **Succeeded**. La machine virtuelle signalait le paramètre de journalisation du pare-feu à `False`. À répétition, à travers plusieurs synchronisations, une modification du profil et un redémarrage.

### L'outil qui a tranché

Plutôt que de continuer à deviner, nous avons demandé à l'appareil d'écrire tout ce qu'il avait reçu.

**[Machine virtuelle]** PowerShell en administrateur

```
mdmdiagnosticstool.exe -out C:\MDMDiag
```

Cela produit un rapport listant chaque stratégie que l'appareil détient. Y chercher les paramètres du pare-feu a donné la réponse dans le chemin lui-même :

```
./Vendor/MSFT/Firewall/MdmStore/DomainProfile/EnableLogDroppedPackets
```

> **La règle que personne ne vous dit**
>
> Le Pare-feu Windows ne garde pas ses paramètres à un seul endroit. Il tient plusieurs **magasins de stratégies** distincts :
>
> - **PersistentStore**, les règles configurées localement sur cette machine
> - **MdmStore**, les règles livrées par la gestion des appareils mobiles, c'est-à-dire Intune
> - **ActiveStore**, le résultat combiné de tous les magasins, ce qui est réellement appliqué
>
> `Get-NetFirewallProfile` sans argument lit **PersistentStore**. Le paramètre se trouvait dans **MdmStore** depuis le début. Les deux lectures étaient justes ; elles décrivaient des choses différentes.

**[Machine virtuelle]** La bonne commande

```
Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, LogBlocked
```

> **À retenir**
>
> Quand un paramètre est livré de façon vérifiable mais invisible sur l'appareil, vous lisez presque certainement le mauvais magasin plutôt que de regarder une stratégie cassée.
>
> `mdmdiagnosticstool.exe` est le propre registre de l'appareil et il prime sur la console comme sur n'importe quelle commande isolée. Il nomme aussi le magasin dans le chemin, ce qui transforme un problème insoluble en un problème de deux minutes.

## 9. Tester une stratégie dans les deux sens

### Pourquoi le premier test ne prouvait rien

> **Un test qui ne peut pas échouer n'est pas un test**
>
> Le premier contrôle était de savoir si le pare-feu était activé. Il l'était, sur les trois profils. Mais **Windows active le pare-feu par défaut**, donc True était tout aussi compatible avec « la stratégie a fonctionné » qu'avec « la stratégie n'a rien fait ».

> **La règle qui en découle**
>
> **Pour prouver qu'une stratégie fonctionne, choisissez un paramètre dont la valeur par défaut est l'inverse de ce que vous réglez.** La journalisation du pare-feu est désactivée par défaut, donc la voir activée est sans ambiguïté.

### Les deux moitiés

- **Affecter** Profil attaché, appareil synchronisé. LogBlocked →
- **Désaffecter** Groupe retiré, appareil synchronisé. LogBlocked →

> **Pourquoi la moitié retrait compte**
>
> Certains paramètres **tatouent**. La stratégie est retirée et le paramètre reste en place de façon permanente, parce que rien n'a jamais été écrit pour le remettre. Sur un parc de plusieurs centaines de machines, c'est très difficile à défaire.
>
> Ce paramètre est revenu proprement. C'est désormais un fait vérifié plutôt qu'une supposition, ce qui est toute la raison de faire le test.

> **Délais**
>
> Les retraits mettent nettement plus de temps à atteindre un appareil que les ajouts. Le service doit déterminer quoi retirer plutôt que simplement quoi envoyer. Plusieurs synchronisations et environ quinze minutes ont été nécessaires ici.

## 10. Importer un modèle d'administration

> **Le problème que cela résout**
>
> Intune connaît les paramètres Windows et les applications de Microsoft. Il ne sait rien de Firefox, Adobe Reader, Zoom ou quoi que ce soit d'autre. Telles quelles, ces applications ne peuvent pas du tout être gérées depuis Intune.
>
> Un **modèle d'administration**, extension de fichier `.admx`, est un fichier publié par l'éditeur du logiciel, qui liste chaque stratégie que son application prend en charge. C'est le même format que la gestion Windows utilise depuis vingt ans. Chargez-le et Intune acquiert ces paramètres.
>
> Le fichier `.adml` qui l'accompagne contient les noms affichés et les descriptions dans une langue.

**[Portable]** intune.microsoft.com→ Devices→ Manage devices→ Configuration→ Import ADMX→ Import

### L'ordre est obligatoire

> **Dépendances**
>
> Firefox déclare Mozilla comme espace de noms parent, donc les fichiers doivent être importés dans l'ordre :
>
> 1. `mozilla.admx` avec `en-US\mozilla.adml`. Attendre que Status affiche **Available**
> 2. `firefox.admx` avec `en-US\firefox.adml`
>
> Dans l'ordre inverse, l'import échoue avec une erreur d'espace de noms manquant. Pour vérifier si un modèle a des dépendances, ouvrez-le dans un éditeur de texte et cherchez `using prefix` dans la section `policyNamespaces`.

| Limite documentée | Valeur |
|---|---|
| Nombre maximal de modèles par tenant | 20 |
| Taille maximale par fichier | 1 Mo |
| Fichiers de langue par modèle | 1, et ce doit être `en-US` |
| Statut de la fonctionnalité | Préversion publique |
| Non pris en charge | Les types de paramètres à liste modifiable (combo box) échouent à l'import |

> **Quand ne pas importer**
>
> Les paramètres Chrome et Edge sont déjà intégrés au catalogue des paramètres. Les recommandations de Microsoft sont explicites : n'importez pas de modèles pour des paramètres déjà disponibles là. Importer les modèles intégrés de Windows lui-même est déconseillé pour la même raison, et ne se fait que lorsqu'un modèle est requis comme parent pour autre chose.

### Construire un profil à partir de paramètres importés

**[Portable]** Configuration→ Create→ New policy→ Windows 10 and later→ Templates→ Imported Administrative templates (Preview)

> **Computer Configuration, pas User Configuration**
>
> L'arborescence des paramètres propose les deux. **Computer Configuration** s'applique à l'appareil quelle que soit la personne qui se connecte. **User Configuration** suit un utilisateur. Pour le durcissement d'un appareil, toujours la première.

Vérifié ensuite sur l'appareil :

```
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Mozilla\Firefox" | Select-Object -Property * -Exclude PS*
```

| Valeur | Résultat | Signification |
|---|---|---|
| `DisableTelemetry` | 1 | Les données d'utilisation ne quittent plus la machine |
| `BlockAboutConfig` | 1 | L'utilisateur ne peut pas atteindre la page de paramètres cachés de Firefox pour défaire la stratégie |
| `PasswordManagerEnabled` | 0 | Les identifiants ne peuvent pas être stockés dans le navigateur |

## 11. L'erreur qui s'est répétée trois fois

> **Enabled signifie « activé ». Jamais « sécurisé ».**
>
> | Paramètre | Enabled signifie | Voulu |
> |---|---|---|
> | Configure SMB v1 server | SMBv1 est activé | Disabled |
> | Enable Log Dropped Packets | La journalisation est activée | Enabled |
> | Password Manager | Le gestionnaire de mots de passe est activé | Disabled |
>
> Chacun des trois a été mal réglé à la première tentative, de la même manière, pour la même raison.

> **L'habitude qui l'évite**
>
> Si le nom du paramètre ne contient pas un verbe comme **Disable** ou **Block**, le nom ne vous dit rien sur la direction sûre. Survolez l'icône d'information et lisez la description avant de choisir.
>
> Les paramètres dont le nom porte déjà le verbe, comme `DisableTelemetry`, se comportent comme prévu : Enabled désactive la télémétrie.

## 12. À retenir pour l'examen

- Un wipe supprime l'enregistrement d'appareil Intune. Il ne supprime **pas** l'inscription Autopilot, ce qui explique qu'un appareil effacé revient par Autopilot à chaque fois jusqu'à sa désinscription.
- La désinscription se fait dans Devices → Enrollment → Windows → Devices, et c'est ce que vous faites quand une machine quitte l'entreprise.
- Retire supprime les données d'entreprise et la gestion, en laissant les données personnelles. Wipe est une réinitialisation d'usine. Delete ne supprime que l'enregistrement de la console et laisse l'appareil configuré et non géré.
- Les appareils Autopilot ne peuvent pas être supprimés depuis le centre d'administration Entra. L'inscription fait autorité.
- Les paramètres de stratégie de conformité sont à l'échelle du tenant et agissent comme une stratégie intégrée que chaque appareil reçoit.
- "Mark devices with no compliance policy assigned as" vaut Compliant par défaut, ce qui laisse passer. Changez-le quand vous utilisez l'accès conditionnel.
- Une stratégie de conformité juge. Un profil de configuration change. L'accès conditionnel agit sur le jugement.
- Ajouter un paramètre à un profil de catalogue des paramètres l'amène à une valeur par défaut, pas activé.
- Sélectionner un paramètre parent peut entraîner silencieusement ses enfants avec leurs propres valeurs par défaut.
- Le Pare-feu Windows tient plusieurs magasins de stratégies. Seul ActiveStore montre ce qui est appliqué.
- `mdmdiagnosticstool.exe` produit le propre registre de l'appareil de chaque stratégie qu'il détient, y compris le chemin qui nomme le magasin.
- Les modèles d'administration doivent être importés dans l'ordre des dépendances, espace de noms parent en premier.
- Les modèles importés sont limités à 20 fichiers, 1 Mo chacun, un fichier de langue `en-US` par modèle.
- Le retrait d'une stratégie atteint un appareil plus lentement que son affectation.

*Jour 7 de la série de labos MD-102. Rédigé à partir du journal de session, 24 et 25 août 2026. Tenant de labo uniquement, pas de production. Chaque commande et chaque chemin de portail de ce document a été exécuté et sa sortie vérifiée pendant la session.*
