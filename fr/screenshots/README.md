# Captures d'écran

Prises dans mon tenant et caviardées avant la mise en ligne. Nom du tenant, identifiants de tenant et
d'appareil, comptes administrateur, numéros de série, clés de récupération et mots de passe sont noircis,
pas floutés.

Numérotées dans l'ordre de la visite guidée de [ARCHITECTURE.md](../ARCHITECTURE.md). Chaque titre
ci-dessous est une étape de la visite, avec le même titre que dans le schéma. Les étapes 1, 2 et 8 se
montrent en direct dans les portails, pas en captures.

## Étape 3 · Ne jamais perdre l'accès

| Capture | Ce qu'elle montre | Pourquoi c'est important | Page |
|---|---|---|---|
| `01-emergency-access-tap-sign-in.png` | Une connexion authentifiée avec un **passe d'accès temporaire** (Temporary Access Pass) | Comment un compte sans méthode obtient sa première méthode forte, pour enregistrer une clé d'accès (passkey) | [Identité](../identity/README.md#2-une-clé-daccès-sur-un-compte-sans-méthode) |
| `02-emergency-access-passkey-only.png` | Compte d'urgence avec une seule méthode utilisable, une **clé d'accès** ; méthode préférée par le système Fido2 | **Authenticator avait aussi ajouté les notifications push et les codes**, tous deux vulnérables à l'hameçonnage. Supprimés | [Identité](../identity/README.md#2-une-clé-daccès-sur-un-compte-sans-méthode) |
| `03-emergency-access-passkey-aaguid.png` | L'AAGUID de la clé d'accès | La valeur que signale Authenticator sur Android. Graph enregistre cette clé d'accès comme attestée ; le profil ne l'exige pas, donc une clé d'accès non attestée aurait aussi été acceptée | [Identité](../identity/README.md#2-une-clé-daccès-sur-un-compte-sans-méthode) |

## Étape 4 · Les règles d'accès

| Capture | Ce qu'elle montre | Pourquoi c'est important | Page |
|---|---|---|---|
| `04-access-rules-no-policies-after-teardown.png` | Page des stratégies d'accès conditionnel sur son écran Get Started : aucune stratégie | La stratégie du jour 15 avait disparu après le démontage, et rien ne l'a remplacée | [Identité](../identity/README.md#le-point-de-départ) |
| `05-access-rules-security-defaults-off.png` | Security defaults sur **Disabled** | Sans stratégie non plus, **rien n'exigeait l'authentification multifacteur (MFA) pour les utilisateurs**, un mois après que le jour 15 a consigné la lacune | [Identité](../identity/README.md#le-point-de-départ) |
| `06-access-rules-lockout-warning.png` | « Don't lock yourself out! » avec **Exclude current user** présélectionné | Le garde-fou de Microsoft, mauvais ici : le compte d'urgence est le garde-fou, et la valeur par défaut exempterait le compte administrateur habituel de la MFA | [Identité](../identity/README.md#4-accès-conditionnel) |
| `07-access-rules-whatif-test-user.png` | Résultat What If pour l'utilisateur de test : CA001 et CA003 s'appliquent, report-only | Simulé avant que quoi que ce soit soit activé. Les entrées sont listées sur la page | [Identité](../identity/README.md#what-if-avant-toute-activation) |
| `08-access-rules-whatif-emergencyaccess-excluded.png` | Résultat What If pour le compte d'urgence : aucune stratégie ne s'applique, raison **Users and groups** | L'exclusion tient pour les trois stratégies | [Identité](../identity/README.md#what-if-avant-toute-activation) |
| `09-access-rules-report-only-sign-in.png` | Résultats report-only sur une vraie connexion Microsoft Edge : CA001 et CA003 Success, CA002 Not applied | **Trouvé dans le journal non interactif**, pas dans l'interactif | [Identité](../identity/README.md#une-vraie-connexion-toujours-en-rapport-uniquement) |
| `10-access-rules-ca001-ca002-ca003-on.png` | CA001, CA002 et CA003, toutes les trois **On** | Activées seulement après que What If et la connexion en report-only ont concordé | [Identité](../identity/README.md#activées) |

## Étape 5 · Le poste de travail

| Capture | Ce qu'elle montre | Pourquoi c'est important | Page |
|---|---|---|---|
| `11-workstation-mdm-authority-none.png` | Choose MDM Authority réglé sur **None** | **Erreur 80180003**, « not authorized to enroll ». Le tenant n'avait jamais déclaré quel service gère les appareils, donc chaque inscription était refusée. L'erreur accuse l'utilisateur ; l'utilisateur n'a jamais été le problème | [Jour 3](../day-guides/day-03-windows-install-entra-join-and-intune-enrolment.md#la-vraie-cause) |
| `12-workstation-dyn-autopilot-devices.png` | `Dyn-Autopilot-Devices` avec la VM du lab comme membre | **Le profil est resté Not assigned** tant qu'il ciblait `Dyn-Windows-Devices` : `deviceOSType` ne correspond qu'aux appareils inscrits. La règle ZTDid correspond dès l'enregistrement | [Jour 5](../day-guides/day-05-windows-autopilot.md#la-bonne-règle) |
| `13-workstation-autopilot-apuserdrivenentrajoin.png` | Profil de déploiement `APUserDrivenEntraJoin` : User-Driven, Microsoft Entra joined | User-driven parce que le mode self-deploying exige un TPM 2.0 physique | [Jour 5](../day-guides/day-05-windows-autopilot.md#4-le-profil-de-déploiement) |
| `14-workstation-corp-97322-encrypted.png` | `CORP-97322` dans le rapport de chiffrement Intune | Le nom vient du modèle du profil `CORP-%RAND:5%`, preuve que le profil a piloté la configuration | [Reconstruction](../rebuild/README.md#où-ça-en-est) |
| `15-workstation-cp-windows-compliant.png` | `CP-Windows` par paramètre : neuf paramètres Compliant, 0 Not applicable | Une ligne Not applicable n'a jamais été vérifiée. Zéro signifie que chaque vérification a réellement tourné | [Reconstruction](../rebuild/README.md#conformité) |
| `16-workstation-cfg-edge-smartscreen.png` | `edge://policy` : quatre stratégies SmartScreen à true, Platform, Device, Mandatory, OK | Le commutateur de téléchargement appartient à Edge, donc la stratégie Defender ne pouvait pas le régler | [Reconstruction](../rebuild/README.md#edge-smartscreen) |

## Étape 6 · Vérifier, pas supposer

| Capture | Ce qu'elle montre | Pourquoi c'est important | Page |
|---|---|---|---|
| `17-checks-audit-exclusion-was-the-user.png` | Audit PowerShell : les trois stratégies excluent l'**utilisateur** Emergency Access 01, aucun groupe | **What If ne pouvait pas montrer cela.** Le groupe protégé ne faisait rien tant que les stratégies ne le nommaient pas | [Identité](../identity/README.md#lexclusion-portait-sur-lutilisateur-pas-sur-le-groupe) |
| `18-checks-audit-exclusion-fixed.png` | La même vérification après le correctif : les trois excluent le groupe `EmergencyAccess` | Correctif vérifié par relecture, pas supposé | [Identité](../identity/README.md#lexclusion-portait-sur-lutilisateur-pas-sur-le-groupe) |
| `19-checks-audit-emergency-sign-ins.png` | Connexions du compte d'urgence avec la méthode utilisée | **La clé d'accès figure sur l'entrée erreur 50140**, l'invite « Stay signed in? », pas sur le succès qui la suit | [Identité](../identity/README.md#les-connexions-et-quelle-entrée-porte-la-méthode) |
| `20-checks-audit-test-user-sign-ins.png` | Connexions de l'utilisateur de test, et inscriptions d'applications détenant des secrets client | Windows Hello for Business explique le succès report-only de CA001. Aucun secret client sur les inscriptions d'applications | [Identité](../identity/README.md#les-connexions-et-quelle-entrée-porte-la-méthode) |
| `21-checks-bitlocker-portal-access-denied.png` | Portail : « You do not have access to view this BitLocker recovery key » | **Mauvaise erreur.** Le compte était Global Administrator. C'est le panneau du portail qui a échoué, pas la permission | [Journal du lab, jour 13](../LAB-LOG.md#jour-13-le-portail-disait-pas-daccès-il-avait-tort) |
| `22-checks-bitlocker-graph-403.png` | Graph Explorer : 403 Forbidden sur `recoveryKeys` | Graph exige que `BitlockerKey.ReadBasic.All` et `BitlockerKey.Read.All` aient reçu le consentement | [Journal du lab, jour 13](../LAB-LOG.md#jour-13-le-portail-disait-pas-daccès-il-avait-tort) |
| `23-checks-bitlocker-graph-200-ok.png` | Graph Explorer : 200 OK sur le même point de terminaison | L'API a renvoyé ce que le portail refusait. L'interface n'est qu'un client de l'API | [Journal du lab, jour 13](../LAB-LOG.md#jour-13-le-portail-disait-pas-daccès-il-avait-tort) |
| `24-checks-bitlocker-three-recovery-keys.png` | Trois clés de récupération listées pour un seul lecteur | Pas un défaut. Chaque chiffrement et chaque rotation dépose une nouvelle clé et les anciennes restent, c'est pourquoi l'écran de récupération affiche un Key ID | [Journal du lab, jour 13](../LAB-LOG.md#jour-13-trois-clés-de-récupération-un-seul-disque) |
| `25-checks-defender-pua-protection-off.png` | Stratégie antivirus avec **PUA Protection off** | **Valeur non sécurisée appliquée.** Un « off » explicite écrase l'appareil et se signale quand même comme appliqué. Corrigé en le réglant sur block | [Journal du lab, jour 13](../LAB-LOG.md#jour-13-la-stratégie-antivirus-imposait-une-valeur-non-sécurisée) |

## Étape 7 · Démolir et reconstruire

Construit lors de la première phase, avant la démolition de septembre.

| Capture | Ce qu'elle montre | Pourquoi c'est important | Page |
|---|---|---|---|
| `26-first-round-update-pin-24h2-deploys-25h2.png` | Stratégie `Feature-Pin-24H2`, colonne Versions **Windows 11, version 25H2** | **Le nom ne correspondait pas au comportement.** Le nom était une étiquette tapée par un humain ; la colonne Versions est ce que le service fait | [Journal du lab, jour 11](../LAB-LOG.md#jour-11-une-stratégie-dont-le-nom-ne-correspondait-pas-à-ce-quelle-déployait) |
| `27-first-round-firewall-merge-conflict.png` | Chaque paramètre de fusion listé deux fois en **Conflict**, Default Inbound Action Succeeded | **La stratégie n'a rien fait.** Un profil plus ancien réglait les commutateurs de fusion sur True, le nouveau sur False, donc Windows n'a appliqué ni l'un ni l'autre. Corrigé en donnant un seul propriétaire au pare-feu | [Journal du lab, jour 14](../LAB-LOG.md#jour-14-des-valeurs-par-défaut-qui-ressemblaient-à-un-succès) |
| `28-first-round-ca-whatif-report-only.png` | What If : `CA-Require-Compliant-Device` sous Policies that will apply, State Report-only | Vérifié avec le simulateur plutôt qu'avec une connexion, parce que le compte administrateur est exclu de la stratégie | [Journal du lab, jour 15](../LAB-LOG.md#jour-15-laccès-conditionnel-et-la-faille-dauthentification-multifacteur-quil-a-créée) |
| `29-first-round-7zip-installed.png` | État d'installation de 7-Zip 26.03 sur l'appareil : Installed sur la VM du lab | **Faux positif d'abord.** `Test-Path` avait renvoyé True sur le portable, pas sur la VM. Redémarrer l'Intune Management Extension a forcé l'installation | [Journal du lab, jour 17](../LAB-LOG.md#jour-17-test-path-a-renvoyé-true-depuis-la-mauvaise-machine) |
| `30-first-round-app-protection-on-devices.png` | Stratégie de protection des applications affectée à `Dyn-Windows-Devices` : 1 devices, 0 users | **Ne protège rien.** La protection des applications cible les utilisateurs dans les applications, pas les appareils. Réaffectée à `All-BYOD` | [Journal du lab, jour 19](../LAB-LOG.md#jour-19-les-stratégies-de-protection-des-applications-ciblent-des-utilisateurs-pas-des-appareils) |

## Hors du schéma · Le pipeline d'octobre 2025

| Capture | Ce qu'elle montre | Pourquoi c'est important | Page |
|---|---|---|---|
| `31-pipeline-2025-secret-login.png` | Octobre 2025 : un pipeline qui se connecte à Azure comme principal de service avec un secret client | Le secret est stocké dans GitHub et remis à l'exécution | [Identité de charge de travail](../identity/workload-identity-2025.md#le-pipeline-avec-un-secret) |
| `32-pipeline-2025-secret-readable.png` | Une étape non fiable qui reçoit `AZURE_CLIENT_SECRET`, affiché comme `***` | **Le masquage cache la valeur dans le journal, pas au code** | [Identité de charge de travail](../identity/workload-identity-2025.md#le-pipeline-avec-un-secret) |
