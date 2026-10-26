[English version](../README.md)

# Modern Workplace avec Microsoft Entra ID et Intune

**Goce Petrov** · Suisse · Microsoft MD-102 (Endpoint Administrator) en préparation, mis en pratique dans mon propre tenant Microsoft 365

> **En bref.** Environnement Microsoft Entra ID et Intune, monté et dépanné par moi dans mon propre
> tenant Microsoft 365 depuis août 2026. Chaque panne est documentée : le message d'erreur exact, ce que j'ai vérifié, la cause,
> la correction. Les pages d'origine sont en anglais, la langue des consoles Microsoft.

Mon propre environnement, pas de la production : un tenant Microsoft 365 d'essai, des machines
virtuelles Windows 11 sous Hyper-V et, avant la reconstruction, un téléphone Android. Monté à partir de rien le 17 août 2026,
mené à travers les cinq domaines du MD-102 jusqu'au 14 septembre, puis démonté par scripts et
reconstruit de zéro à partir du 15 septembre. En octobre, une partie identité : un compte d'accès
d'urgence avec une clé d'accès (passkey), et de l'accès conditionnel construit en mode rapport
uniquement, testé, puis activé.

**Le tenant niveau par niveau.** [Le schéma interactif](https://gocko1004.github.io/modern-workplace-entra-intune/?lang=fr)
ouvre un niveau par clic et dit pourquoi chaque partie est construite ainsi. Les captures, dans l'ordre de la
présentation, sont dans [ARCHITECTURE.md](ARCHITECTURE.md).

[![Le tenant vu d'en haut : moi en administrateur général, le tenant, ses sept parties et ce qu'elles contiennent](../architecture/tenant-overview-fr.png)](https://gocko1004.github.io/modern-workplace-entra-intune/?lang=fr)

Un examen à choix multiples ne peut pas montrer ce que ce dépôt montre : les pannes, le texte exact
de l'erreur, ce que j'ai vérifié, et ce que c'était en réalité.

---

## Commencer ici : cinq incidents

| Ce qui a cassé | Ce que c'était en réalité | À lire |
|---|---|---|
| Intune refusait d'inscrire un appareil : *"This user is not authorized to enroll"* (80180003). | Réseau, licences, restrictions d'inscription, limites d'appareils, objets obsolètes et autres pistes écartés un par un, avec preuves. L'autorité MDM du tenant n'avait jamais été définie, et aucun menu du portail ne mène à ce paramètre. | [Jour 3, partie 4](day-guides/day-03-windows-install-entra-join-and-intune-enrolment.md#partie-4-erreur-80180003-et-une-journée-entière-pour-trouver-une-cause-qui-tient-en-un-clic) |
| Une stratégie Windows LAPS signalait un succès, mais aucun mot de passe n'apparaissait jamais. | Événement 10059 dans le journal LAPS de l'appareil lui-même : LAPS doit être activé pour tout le tenant dans Entra ID, un paramètre que ni la stratégie ni la page LAPS ne mentionnent. | [Journal du labo, jour 9](LAB-LOG.md#jour-9-windows-laps-renvoyait-0x80070190-et-le-portail-ne-disait-rien-dutile) |
| Une stratégie Defender Antivirus signalait "applied". | Elle était bien appliquée, et elle **désactivait** la protection contre les applications potentiellement indésirables. J'ai d'abord prouvé que la stratégie atteignait l'appareil, puis lu ce qu'elle contenait. | [Journal du labo, jour 13](LAB-LOG.md#jour-13-la-stratégie-antivirus-imposait-une-valeur-non-sécurisée) |
| Le portail refusait d'afficher une clé de récupération BitLocker à un Global Administrator. | Microsoft Graph renvoyait la même clé avec un 200 OK. L'interface se trompait sur la cause. | [Journal du labo, jour 13](LAB-LOG.md#jour-13-le-portail-disait-pas-daccès-il-avait-tort) |
| Après un effacement à distance et un retour à un instantané, Intune n'atteignait plus l'appareil. | L'enregistrement Autopilot survit à un effacement. Une réinitialisation locale a ramené l'appareil par Autopilot sans qu'Intune ne l'atteigne jamais. | [Jour 7](day-guides/day-07-orphaned-devices-policy-stores-and-admx.md#2-lappareil-qui-a-disparu-dintune) |

---

## Comment je travaille

1. Copier le texte exact de l'erreur, jamais une paraphrase.
2. Lister ce qui pourrait la causer, la vérification la moins coûteuse en premier.
3. Tester une chose à la fois et noter le résultat, y compris "écarté".
4. Le prouver sur l'appareil, pas seulement dans la console : journaux d'événements, registre,
   `dsregcmd /status`, `Get-MpPreference`, `manage-bde`, `edge://policy`.
5. Corriger, puis vérifier que la correction est arrivée là où ça compte.
6. L'écrire le jour même.

Les règles qui en sont sorties, les outils, et comment j'utilise l'IA pour apprendre : [HOW-I-WORK.md](HOW-I-WORK.md)

---

## La sécurité, en termes simples

Ce que j'ai mis en place, écrit pour la question qu'une petite entreprise pose réellement. La colonne
Aujourd'hui dit ce qui est dans le tenant maintenant : reconstruit en septembre, ajouté en octobre, ou construit
seulement lors de la première phase.

| Le risque | Ce que j'ai mis en place | Aujourd'hui | Où |
|---|---|---|---|
| Un portable est perdu ou volé | BitLocker par stratégie, clé de récupération stockée dans Entra ID et consultable uniquement par le service informatique | Reconstruit | [Jour 4](day-guides/day-04-compliance-configuration-and-bitlocker.md#4-bitlocker), [Jour 13](LAB-LOG.md#jour-13-trois-clés-de-récupération-un-seul-disque), [reconstruction](rebuild/README.md#la-stratégie-bitlocker-prend-le-relais) |
| Tous les PC ont le même mot de passe administrateur local | Windows LAPS : un mot de passe par appareil, renouvelé, récupérable par le service informatique | Première phase seulement, pas encore reconstruit | [Jour 9](LAB-LOG.md#jour-9-windows-laps-renvoyait-0x80070190-et-le-portail-ne-disait-rien-dutile) |
| Quelqu'un installe un "outil gratuit" livré avec un logiciel publicitaire | Defender bloque les applications potentiellement indésirables, Edge SmartScreen bloque leurs téléchargements | Reconstruit | [Jour 13](LAB-LOG.md#jour-13-la-stratégie-antivirus-imposait-une-valeur-non-sécurisée), [reconstruction](rebuild/README.md#edge-smartscreen) |
| Un appareil non sain ou non géré accède aux données de l'entreprise | Stratégie de conformité, appareils sans stratégie marqués non conformes par défaut, accès conditionnel exigeant un appareil conforme, et la faille MFA ouverte par la désactivation des paramètres de sécurité par défaut, consignée, puis refermée en octobre | Reconstruit : `CP-Windows`, et CA003 pour l'utilisatrice test | [Jour 7](day-guides/day-07-orphaned-devices-policy-stores-and-admx.md#la-valeur-par-défaut-qui-laisse-passer), [Jour 15](LAB-LOG.md#jour-15-laccès-conditionnel-et-la-faille-dauthentification-multifacteur-quil-a-créée), [identité](identity/README.md) |
| Un mot de passe volé suffit pour se connecter | L'accès conditionnel exige la MFA pour chaque utilisateur sauf un compte d'urgence, et bloque les anciens protocoles incapables de MFA. Le compte d'urgence, avec une clé d'accès et un mot de passe hors ligne, garde le tenant accessible si une stratégie tourne mal | Ajouté en octobre, activé | [Identité](identity/README.md#4-accès-conditionnel) |
| Comportement de type rançongiciel, vol d'identifiants | Règles de réduction de la surface d'attaque, déployées d'abord en mode audit, puis l'une d'elles passée en mode blocage | Première phase seulement | [Jour 14](LAB-LOG.md#jour-14-réduction-de-la-surface-dattaque-audit-dabord) |
| Anciens protocoles laissés activés | SMBv1 désactivé, et repéré le paramètre dont le libellé dit le contraire | Première phase seulement | [Jour 7](day-guides/day-07-orphaned-devices-policy-stores-and-admx.md#le-piège-smbv1) |
| Trop de personnes avec des droits d'administration complets | Rôles à moindre privilège, jonction d'appareils limitée, Endpoint Privilege Management pour l'élévation ponctuelle | Première phase seulement ; depuis la reconstruction, la jonction d'appareils est ouverte à tous | [Jour 2](day-guides/day-02-users-groups-and-tenant-device-settings.md), [Jour 14](LAB-LOG.md#jour-14-endpoint-privilege-management) |

---

## Ce que le labo couvre

| Domaine | Couvert | Où |
|---|---|---|
| Tenant et identité | Licences, création d'utilisateurs en masse avec Microsoft Graph PowerShell, groupes à appartenance assignée et dynamique, rôles, paramètres d'appareil Entra | [Jours 1 et 2](day-guides/) |
| Identité et accès | Compte d'accès d'urgence, passe d'accès temporaire (Temporary Access Pass), clé d'accès dans Authenticator, accès conditionnel avec vérifications What If et rapport uniquement, un audit PowerShell en lecture seule via Microsoft Graph | [Identité](identity/README.md) |
| Inscription | Jonction Entra ou enregistrement Entra, inscription automatique, `dsregcmd`, erreurs 80180003 et 801c03ed | [Jours 3 et 6](day-guides/) |
| Windows Autopilot | Hachage matériel, profil de déploiement, Enrollment Status Page, déploiement de bout en bout, récupération d'un appareil orphelin | [Jours 5 à 7](day-guides/), [reconstruction](rebuild/README.md) |
| Conformité et configuration | Stratégies de conformité, Device Health Attestation, catalogue des paramètres, modèles d'administration, filtres d'affectation | [Jours 4, 7, 8](day-guides/) |
| Sécurité des points de terminaison | BitLocker, LAPS, Defender Antivirus, pare-feu, réduction de la surface d'attaque, App Control, bases de référence de sécurité, accès conditionnel, intégration à Defender for Business et une alerte qualifiée | [Journal du labo, jours 9 à 16](LAB-LOG.md) |
| Mises à jour | Trois anneaux de mise à jour, mise à jour de fonctionnalités, stratégies d'accélération et de hotpatch, Delivery Optimization | [Journal du labo, jour 11](LAB-LOG.md) |
| Applications | Empaquetage Win32 et règles de détection, application du Store, Microsoft 365 Apps, stratégies de protection des applications, Enterprise App Catalog | [Journal du labo, jours 17 à 23](LAB-LOG.md) |
| Surveillance et automatisation | Microsoft Graph PowerShell, corrections (Remediations), Endpoint Analytics | [Journal du labo, jours 21 à 23](LAB-LOG.md) |
| Android | Inscription avec profil professionnel via Managed Google Play, sur un vrai téléphone | [Jour 8](day-guides/day-08-assignment-filters-and-android-enrolment.md) |

Tout ce tableau a été construit au moins une fois. Après la démolition de septembre, la reconstruction a remis en
place l'inscription, Autopilot, la conformité, BitLocker, Defender Antivirus et Edge SmartScreen, et octobre a
ajouté la partie identité.

### La reconstruction

En septembre, le tenant a été démonté par script et reconstruit à partir d'une machine vierge :
Windows appliqué avec DISM depuis l'hôte, Autopilot de bout en bout (l'appareil est sorti sous le nom
`CORP-97322` à partir du modèle de nom, ce qui prouve que le profil a piloté l'installation), puis
conformité, Defender Antivirus, Edge SmartScreen et BitLocker par stratégie, chacun vérifié sur
l'appareil.

- [rebuild/](rebuild/README.md) : le compte rendu et les scripts PowerShell, numérotés dans l'ordre d'exécution
- [teardown/](teardown/README.md) : l'inventaire d'abord, puis la suppression, avec l'ordre expliqué

---

## Ce qui n'est pas ici, dit clairement

- **Expérience de production.** C'est mon propre tenant d'essai : une machine virtuelle à la fois, des utilisateurs de test seulement.
- **Appareils Apple, Active Directory local, stratégie de groupe, Configuration Manager.** Pas de matériel,
  pas de domaine. Compris sur le papier seulement.
- **Copilot dans Intune et Windows 365.** Explorés autant que les licences le permettaient, pas construits.

Le nom du tenant, l'ID du tenant, les numéros de série des appareils, les comptes administrateur et les
noms des utilisateurs de test sont remplacés par des valeurs de substitution. Les mots de passe, clés de
récupération et hachages matériels n'ont jamais été écrits dans ces fichiers.

## Captures d'écran

[screenshots/](screenshots/README.md), prises dans le labo et caviardées, numérotées dans l'ordre de la visite
de [ARCHITECTURE.md](ARCHITECTURE.md).

## Contact

Goce Petrov · [LinkedIn](https://www.linkedin.com/in/goce-petrov)
