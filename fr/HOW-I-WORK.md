# Comment je travaille

## La méthode

1. **Copier le texte exact de l'erreur.** Une paraphrase perd le code, et c'est le code qu'on cherche.
2. **Lister ce qui peut la causer, vérification la moins chère d'abord.** Le réseau et les licences avant les reconstructions.
3. **Tester une chose à la fois, et noter le résultat,** y compris « écarté » et y compris mes propres
   erreurs. Le tableau des causes éliminées du
   [jour 3](day-guides/day-03-windows-install-entra-join-and-intune-enrolment.md#ce-qui-a-été-éliminé-et-comment)
   a une ligne qui dit « Mon erreur ».
4. **Le prouver sur l'appareil, pas seulement dans la console.** Les journaux d'événements, l'arborescence de registre `PolicyManager`,
   `dsregcmd /status`, `Get-MpPreference`, `manage-bde`, `edge://policy`.
5. **Corriger, puis vérifier que le correctif est bien arrivé** là où ça compte, sur la machine.
6. **L'écrire le jour même :** symptôme, ce que j'ai vérifié, cause, correctif, et ce qui l'aurait trouvé
   plus vite.

## Les règles que le lab m'a apprises

Chacune a coûté du temps avant de devenir une règle.

| Règle | D'où elle vient |
|---|---|
| « Succeeded » dans un rapport décrit la livraison, pas le résultat. | [LAPS](LAB-LOG.md#jour-9-windows-laps-renvoyait-0x80070190-et-le-portail-ne-disait-rien-dutile), [Defender](LAB-LOG.md#jour-13-la-stratégie-antivirus-imposait-une-valeur-non-sécurisée) |
| Un message d'erreur est une affirmation, pas un diagnostic. | [Clé BitLocker](LAB-LOG.md#jour-13-le-portail-disait-pas-daccès-il-avait-tort), [inscription](day-guides/day-03-windows-install-entra-join-and-intune-enrolment.md#partie-4-erreur-80180003-et-une-journée-entière-pour-trouver-une-cause-qui-tient-en-un-clic) |
| Prouver que la stratégie est arrivée avant de questionner son contenu. | [Defender](LAB-LOG.md#jour-13-la-stratégie-antivirus-imposait-une-valeur-non-sécurisée) |
| Une entrée de journal est une affirmation. Le paramètre en vigueur est le fait. | [801C03ED dans la reconstruction](rebuild/README.md#le-constat-801c03ed) |
| Le silence n'est pas un résultat. Chaque vérification affiche ce qu'elle a trouvé, y compris « rien ». | [Reconstruction, Defender](rebuild/README.md#defender-antivirus) |
| Vérifier tôt les commutateurs à l'échelle du tenant : autorité MDM, LAPS, données de diagnostic, la valeur par défaut de conformité. | Jours 3, 9, 11 |
| Lancer le diagnostic de Microsoft avant de raisonner à partir des premiers principes. | [Index des guides par jour](day-guides/README.md#les-deux-leçons-les-plus-coûteuses-de-la-semaine) |
| « Introuvable » et « impossible de vérifier » sont deux réponses différentes. | [Reconstruction, échec 10](rebuild/README.md#ce-qui-a-cassé) |
| Un script qui affiche un succès doit vérifier son propre code de sortie. | [Reconstruction, échec 2](rebuild/README.md#ce-qui-a-cassé) |
| Un mauvais nom de propriété ressemble exactement à un paramètre non défini. | [Select-Object](LAB-LOG.md#jour-13-select-object-a-inventé-un-paramètre-qui-nexistait-pas) |
| Notre propre durcissement est souvent ce qui nous bloque plus tard. | [Index des guides par jour](day-guides/README.md#schémas-déchec-vus-plus-dune-fois) |

## Secrets

Les clés de récupération ne passent jamais par une ligne de commande. Les scripts qui en ont besoin la demandent avec
`Read-Host`, parce que tout ce qui est tapé dans une commande est enregistré dans l'historique PowerShell
sur le disque ([04-fetch-hwid.ps1](../rebuild/04-fetch-hwid.ps1)). `manage-bde -protectors -get` affiche le
mot de passe de récupération, donc il n'est jamais lancé pendant un partage d'écran.

## Outils

Centre d'administration Intune · Centre d'administration Entra · Centre d'administration Microsoft 365 · Portail Defender ·
Graph Explorer · PowerShell 7 avec le SDK Microsoft Graph · `Get-WinEvent` et l'Observateur d'événements ·
`dsregcmd` · `mdmdiagnosticstool` · `manage-bde` · `Get-MpPreference` · `citool` · Hyper-V et DISM

## Comment j'utilise l'IA pour apprendre

J'étudie avec Claude, l'IA d'Anthropic, comme tuteur, comme on apprendrait à côté d'un collègue senior
patient. Il explique le concept et me donne une commande à la fois, avec ce que la commande fait et
pourquoi elle vient à ce moment-là. Je tape et lance chaque commande moi-même, je lis ce qui revient, et je le rapporte.
Quand quelque chose échoue, nous lisons l'erreur plutôt que de la contourner. Il m'interroge après chaque étape,
parce qu'un tenant qui fonctionne n'est pas la preuve que je l'ai compris.

Après chaque session, le compte rendu est produit à partir de l'enregistrement de la session, et je le vérifie par rapport à ce que j'ai
vu à l'écran. Les scripts dans `rebuild/` et `teardown/` ont été écrits de la même manière, avec l'aide du
tuteur, puis lancés et débogués par moi sur la machine du lab. Le lab, chaque clic et chaque commande qu'il contient, est
à moi.
