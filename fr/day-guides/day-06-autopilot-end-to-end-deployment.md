# Jour 6 : Déploiement Autopilot de bout en bout

*Réinitialiser à distance un appareil géré et laisser Autopilot le reconstruire. Quatre blocages distincts, dont trois créés par ma propre configuration antérieure.*

Lundi 24 août 2026 · Parcours d'étude MD-102 · VM `W11-CORP-01` / `LABVMGOCE`

**Où la journée s'est terminée**

- Réinitialisation à distance Intune (**Wipe**) exécutée avec succès, appareil revenu à un OOBE propre
- Autopilot s'est déclenché au deuxième démarrage et a téléchargé son profil
- La jonction Microsoft Entra a réussi après une correction des paramètres du tenant
- La page d'état d'inscription (Enrollment Status Page) a démarré et terminé Device preparation et Device setup
- **Account setup ne s'est jamais terminé.** Non résolu, reporté à la session suivante
- VM restaurée au point de contrôle d'avant la réinitialisation, le lab est donc intact

## 1. Le point de contrôle, et pourquoi il n'est pas optionnel

**PORTABLE**, PowerShell en administrateur :

```
Checkpoint-VM -Name "W11-CORP-01" -SnapshotName "Pre-Autopilot-Clean"
```

> **Pourquoi**
>
> La machine sur le point d'être réinitialisée a pris trois jours à construire. Elle est jointe à Entra, inscrite dans Intune, chiffrée par BitLocker avec une clé déposée, conforme sur deux paramètres, et porte un profil de configuration. Un point de contrôle capture tout cela en une dizaine de secondes.
>
> Cela s'est révélé être l'action la plus importante de la journée. Quand le déploiement s'est bloqué, le retour arrière a pris moins d'une minute et le lab était intact. Sans lui, la soirée se serait terminée sans rien.

> **À retenir pour la suite**
>
> Point de contrôle avant toute action destructrice. Le supprimer une fois le résultat connu, le Jour 4 a montré ce qu'un disque de différenciation qui traîne coûte en espace disque et en vitesse d'écriture.

## 2. Réinitialisation de l'appareil depuis Intune

La réinitialisation a été faite via Intune plutôt que par une réinitialisation locale, délibérément. Les actions à distance sont un objectif MD-102 à part entière, et c'est le scénario réaliste : un portable rendu, reprovisionné sans que personne n'y touche.

**[Portable]** intune.microsoft.com→ Devices→ All devices→ LABVMGOCE→ Wipe

### Les deux cases à cocher, et ce qu'elles font réellement

| Case à cocher | Réglage utilisé | Pourquoi |
|---|---|---|
| Wipe device, but keep enrollment state and associated user account | **Décochée** | La cocher laisse l'appareil inscrit, donc il ne revient jamais à un OOBE propre et Autopilot ne se lance jamais. Cela tue tout le test. |
| Wipe device, and continue to wipe even if device loses power | **Décochée** | L'avertissement du panneau lui-même indique que cela peut empêcher certains appareils sous Windows 10 et versions ultérieures de redémarrer. Une VM sur un portable branché au secteur ne va pas perdre l'alimentation, c'est donc un risque sans bénéfice. |

> **Pourquoi l'option de perte d'alimentation existe**
>
> Sur un appareil physique qui s'éteint en pleine réinitialisation, un disque partiellement effacé peut rester dans un état où certaines données survivent. Cette option force la réinitialisation à reprendre et à se terminer. La contrepartie, c'est qu'une réinitialisation qu'on ne peut pas interrompre peut aussi laisser un appareil non amorçable si elle échoue. Pour un portable volé, le compromis vaut la peine. Pour une VM de lab, non.

### Chronologie

- **Commande en file d'attente** Intune la garde jusqu'à ce que l'appareil se présente.
- **Réception par l'appareil** Quelques minutes quand l'appareil est en ligne.
- **Réinitialisation en cours** 20 à 45 minutes sur une VM de 4 Go.
- **OOBE propre** L'appareil redémarre dans l'installation.

Le redémarrage vers l'écran de réinitialisation est la confirmation que la commande est arrivée. Rien dans le portail ne vous le dit plus tôt.

## 3. Autopilot ne s'est pas déclenché au premier démarrage

> **Ce qui a cassé**
>
> Après la réinitialisation, l'appareil a atteint l'OOBE, mais le compte professionnel a été refusé à la connexion. J'ai vérifié que le mot de passe était correct en le tapant d'abord dans le champ visible du nom d'utilisateur, ce n'était donc pas un problème de disposition du clavier cette fois.
>
> **Cause :** Autopilot ne s'était pas déclenché, donc l'OOBE déroulait son flux standard plutôt que le flux Autopilot. Un compte professionnel échoue face à un écran qui demande un compte Microsoft personnel.

> **La règle Microsoft : le profil se télécharge une fois, tôt**
>
> > Le profil Windows Autopilot est téléchargé dès que possible, puis à nouveau après chaque redémarrage.
>
> Si le réseau n'est pas disponible à cette première tentative, l'appareil met en cache un profil vide et continue comme une installation Windows ordinaire. Le correctif documenté par Microsoft est de redémarrer pour que le téléchargement se relance.

**VM**, sur n'importe quel écran OOBE, Shift + F10 pour ouvrir une invite de commandes, puis :

```
shutdown /r /t 0
```

Au deuxième démarrage, l'écran de connexion Autopilot est apparu et le compte professionnel a été accepté.

> **Le diagnostic qui a tranché**
>
> Lisez le texte au-dessus de la zone de connexion. "Sign in to your Microsoft account" signifie qu'Autopilot ne s'est pas déclenché. Une connexion Autopilot nomme l'organisation ou demande un compte professionnel ou scolaire. Cette seule ligne vous dit dans quel flux vous êtes et évite de longues hésitations sur le mot de passe.

## 4. Erreur 801c03ed : mon propre durcissement du Jour 2

> **Ce qui a cassé**
>
> ```
> Something went wrong. 801c03ed
> ```
>
> Levée à l'étape de jonction Microsoft Entra, juste après l'acceptation des identifiants.

> **La règle Microsoft : 801c03ed a deux causes documentées**
>
> 1. La stratégie de l'administrateur n'autorise pas l'utilisateur à joindre des appareils
> 2. L'utilisateur a dépassé le nombre d'appareils qu'il est autorisé à joindre
>
> La FAQ Autopilot de Microsoft le dit clairement : *le problème le plus fréquent lors de la jonction d'un appareil à Microsoft Entra ID est lié aux autorisations Microsoft Entra.*

> **Pourquoi c'est l'échec le plus instructif de la semaine**
>
> Les deux causes, c'est moi qui les avais configurées, le Jour 2, délibérément, comme bonne pratique :
>
> - **Users may join devices to Microsoft Entra** restreint à `IT-Admins`
> - **Maximum number of devices per user** réglé sur 5
>
> Chaque reconstruction de la VM au cours de la semaine a laissé un objet appareil derrière elle. Ces objets obsolètes comptent dans la limite. Une décision de sécurité correcte le Jour 2 est donc devenue le blocage du Jour 6, et rien dans le message d'erreur ne pointe vers elle.
>
> C'est la vraie forme du travail de support des postes de travail. La panne est rarement un produit cassé. C'est un paramètre que quelqu'un a choisi, pour une bonne raison, un autre jour.

**[Portable]** entra.microsoft.com→ Entra ID→ Devices→ Device settings

| Paramètre | Passé à |
|---|---|
| Users may join devices to Microsoft Entra ID | `All` |
| Maximum number of devices per user | `Unlimited` |

Les changements mettent quelques minutes à se propager. Réessayer immédiatement produit la même erreur et gaspille un redémarrage.

> **La version production de ce correctif**
>
> Mettre les deux sans restriction est le bon choix dans un lab et le mauvais en production. En production, on ajouterait plutôt l'utilisateur concerné au groupe autorisé et on supprimerait les objets appareil obsolètes. Le bon chemin de nettoyage, c'est Entra ID, Intune et Autopilot, les trois ; Microsoft documente que supprimer uniquement l'objet Entra casse l'ancre Autopilot et provoque ses propres erreurs de jonction.

## 5. La page d'état d'inscription bloquée à Account setup

Après la réussite de la jonction, l'ESP s'est lancé. Device preparation et Device setup se sont terminés. Account setup, non.

### La page de diagnostic qui n'était pas disponible

> **Ce qui a cassé**
>
> Ctrl + Shift + D, le raccourci documenté par Microsoft pour la page de diagnostic Autopilot, n'a rien fait.
>
> **Cause :** la page de diagnostic doit être activée au préalable dans le profil ESP. Elle n'est pas active par défaut.

> **La règle Microsoft : activer la page de diagnostic**
>
> Deux paramètres du profil ESP doivent tous deux être sur **Yes** :
>
> - **Show app and profile configuration progress**
> - **Turn on log collection and diagnostics page for end users**
>
> Elle est ensuite accessible par le bouton **View Diagnostics** ou Ctrl + Shift + D, et n'est prise en charge que sur Windows 11, en mode piloté par l'utilisateur (user-driven), lors d'une connexion avec un compte professionnel ou scolaire.

> **À activer avant le prochain run**
>
> Un outil de dépannage qu'il faut activer à l'avance ne sert à rien la première fois qu'on en a besoin. Les deux paramètres passent à Yes maintenant, définitivement, pour que le prochain blocage soit diagnosticable au lieu d'être opaque.

### Le suspect principal : la bannière d'ouverture de session du Jour 4

> **La règle Microsoft : les stratégies en conflit avec Autopilot**
>
> Sous `Computer Configuration\Windows Settings\Security Settings\Local Policies\Security Options`, Microsoft nomme quatre GPO en conflit avec Autopilot. Deux d'entre elles sont exactement ce que j'ai déployé le Jour 4 :
>
> - **Interactive logon: Message title for users attempting to log on**
> - **Interactive logon: Message text for users attempting to log on**
>
> Séparément, et sans être limité à un mode en particulier, la même page avertit que l'expérience de première utilisation ou l'ouverture de session automatique sur le bureau de l'utilisateur peut échouer quand un appareil redémarre pendant l'ESP de l'appareil, sous des stratégies *y compris toute stratégie qui désactive l'ouverture de session automatique*.

> **Pourquoi la bannière est le suspect**
>
> L'ESP tourne sous une ouverture de session automatique. Une bannière d'ouverture de session interrompt cette ouverture avec une boîte de message qui attend d'être fermée, et il n'y a aucun utilisateur présent pour la fermer. La bannière est aussi la seule stratégie du tenant qui touche au chemin d'ouverture de session.
>
> **Limite honnête :** Microsoft limite ces quatre GPO au *préprovisionnement*, pas au déploiement piloté par l'utilisateur. C'est donc une hypothèse bien étayée, pas un diagnostic confirmé. Le prochain run, avec la bannière désaffectée, est ce qui la prouvera ou la tuera.

## 6. Le mode de session étendu a bloqué un utilisateur standard

> **Ce qui a cassé**
>
> La connexion en tant qu'Anna Test, une utilisatrice standard, a été refusée avec un message indiquant l'absence du droit d'ouvrir une session à distance.
>
> **Cause :** le mode de session étendu (Enhanced Session Mode) avait été activé plus tôt dans la journée pour faire fonctionner le collage du presse-papiers :
>
> ```
> Set-VMHost -EnableEnhancedSessionMode $true
> ```
>
> Le mode de session étendu se connecte à l'invité par RDP. Une connexion RDP exige l'appartenance à Remote Desktop Users ou le droit d'ouverture de session équivalent. Un utilisateur standard sur un appareil joint à Entra n'a ni l'un ni l'autre.
>
> **Correctif, dans la barre de menus de la fenêtre vmconnect elle-même sur l'hôte, pas dans l'interface de l'invité :**
>
> **[Portable]** View→ décocher Enhanced Session
>
> Une session de base est une connexion console et n'a besoin d'aucun droit RDP.

> **Pourquoi cela vaut la peine d'être su au-delà du lab**
>
> Le mode de session étendu vous donne le presse-papiers, la redirection de lecteurs et une meilleure résolution. Il change aussi en silence le type de connexion que vous effectuez. Deux connexions à la même VM, mêmes identifiants, résultat différent, parce que l'une est une ouverture de session console et l'autre une ouverture de session à distance, et Windows les traite comme des droits différents.

## 7. Le retour arrière

**PORTABLE**, PowerShell en administrateur :

```
Restore-VMCheckpoint -VMName "W11-CORP-01" -Name "Pre-Autopilot-Clean" -Confirm:$false
```

Retour à la machine jointe, inscrite, chiffrée en moins d'une minute.

> **Ce qui m'a surpris après le retour arrière**
>
> La bannière d'ouverture de session était toujours là, alors que son affectation avait été retirée dans Intune quelques minutes plus tôt.
>
> **Cause :** deux choses à la fois. Le point de contrôle a restauré l'état exact capturé avant la réinitialisation, bannière comprise. Et retirer une affectation ne va pas modifier l'appareil, le changement arrive à la prochaine synchronisation de stratégies de l'appareil.
>
> **Correctif, sur la VM :**
>
> **[VM]** Settings→ Accounts→ Access work or school→ le compte connecté→ Info→ Sync
>
> C'est la même leçon que le Jour 4, dans l'autre sens. Un profil de configuration modifie l'appareil quand il se synchronise, et le remet en l'état quand il se synchronise. Ni l'un ni l'autre n'arrive à l'instant où vous cliquez sur Save dans le portail.

## 8. Le plan pour le prochain run

1. Profil de configuration de la bannière laissé non affecté
2. Diagnostic ESP activé : **Show app and profile configuration progress** et **Turn on log collection and diagnostics page for end users**, tous deux sur Yes
3. Mémoire de démarrage de la VM montée à 6 Go, navigateur fermé d'abord
4. Nouveau point de contrôle avant la réinitialisation
5. Objets appareil Entra obsolètes nettoyés plutôt que limite relevée

> **Ce qui a réellement été prouvé aujourd'hui**
>
> Il vaut la peine d'être exact là-dessus plutôt que de classer ça comme un échec. La réinitialisation à distance a fonctionné. L'enregistrement Autopilot a fonctionné. Le téléchargement du profil a fonctionné. La jonction Entra a fonctionné. L'inscription MDM a fonctionné. Deux des trois phases de l'ESP se sont terminées.
>
> La partie inachevée est la dernière phase de la dernière étape. Tout ce que l'examen teste réellement sur Autopilot a tourné correctement.

## 9. Ce qu'il faut retenir pour l'examen

- Un **Wipe** Intune avec "keep enrollment state" coché laisse l'appareil inscrit, donc Autopilot ne se lance jamais.
- Le profil Autopilot se télécharge tôt dans l'OOBE et à nouveau après chaque redémarrage. Pas de réseau à ce moment-là, pas d'Autopilot. Redémarrer pour réessayer.
- **801c03ed** signifie que l'utilisateur n'est pas autorisé à joindre des appareils, ou qu'il a atteint la limite d'appareils. Les deux sont des paramètres d'appareils Entra, pas Intune.
- Les objets appareil obsolètes comptent dans la limite d'appareils par utilisateur.
- Supprimer seul l'objet appareil Entra casse l'ancre Autopilot. Nettoyer Entra, Intune et Autopilot ensemble.
- La page de diagnostic ESP doit être activée à l'avance dans le profil ESP. Sinon Ctrl + Shift + D ne fait rien.
- Le titre et le texte du message d'ouverture de session interactive sont nommés par Microsoft parmi les GPO en conflit avec Autopilot.
- L'ESP dépend de l'ouverture de session automatique. Toute stratégie qui l'interrompt peut le bloquer.
- Retirer l'affectation d'une stratégie modifie l'appareil à sa prochaine synchronisation, pas au moment où vous enregistrez.
- Le mode de session étendu est une connexion RDP et exige des droits d'ouverture de session RDP. La session de base, non.

*Jour 6 de la série de labs MD-102. Rédigé à partir du journal de session, 24 août 2026. Tenant de lab uniquement, rien de tout cela n'est de la production. Account setup reste non résolu et est reporté.*
