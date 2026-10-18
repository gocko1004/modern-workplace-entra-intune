# Démontage du tenant, 14 septembre 2026

Démontage par script du lab `labtenant.onmicrosoft.com` avant de le reconstruire à partir de rien. Tout a
été supprimé via Microsoft Graph plutôt qu'en cliquant, parce que le but de la reconstruction est
d'apprendre le travail, pas le portail.

La configuration a d'abord été exportée. Voir `../tenant-export/`.

## Fichiers

| Fichier | Fonction |
|---|---|
| `01-inventory.ps1` | Liste chaque objet visé par le démontage. `GET` uniquement, ne supprime rien |
| `02-delete.ps1` | Le démontage. **Aperçu par défaut.** Ne supprime que si on lui passe `-Execute` |

## Comment il a été lancé

```powershell
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All","DeviceManagementApps.ReadWrite.All",`
  "DeviceManagementManagedDevices.ReadWrite.All","DeviceManagementManagedDevices.PrivilegedOperations.All",`
  "DeviceManagementServiceConfig.ReadWrite.All","DeviceManagementScripts.ReadWrite.All",`
  "Group.ReadWrite.All","User.ReadWrite.All","Device.ReadWrite.All"

.\01-inventory.ps1            # read the list
.\02-delete.ps1               # preview, deletes nothing
.\02-delete.ps1 -Execute      # delete
```

Le consentement a été accordé pour le compte connecté uniquement, pas au nom de l'organisation. Ce sont
des autorisations déléguées, donc elles sont de toute façon plafonnées par les droits propres du compte,
mais l'octroi est plus étroit.

## Résultat

77 objets avant, 11 après. **65 supprimés, 14 ignorés, 2 en échec** à la première passe, les deux échecs
résolus ensuite.

Les objets survivants sont tous créés par Microsoft et volontairement protégés dans le script : le compte
administrateur, les deux groupes que la gestion des licences Microsoft 365 crée, quatre applications
fournies par Microsoft, la stratégie par défaut de détection et de réponse des points de terminaison, et
deux exemples de correction Microsoft.

## Pourquoi cet ordre et pas un autre

**L'inscription Autopilot avant l'objet appareil Entra.** Supprimer l'objet Entra en premier rend le
hachage matériel orphelin, sans plus aucun moyen de l'atteindre. Ce mode de panne a été diagnostiqué à la
dure le Jour 7, quand un retour à un instantané après une réinitialisation à distance a laissé un appareil
qui se croyait inscrit alors que le service n'en avait aucune trace.

**Le portable de travail en dernier.** `DESKTOP-D8QPBL1` est la machine qui exécute le script, et
supprimer son objet appareil Entra peut mettre fin à la session qui fait la suppression. Le mettre en
dernier fait qu'une session cassée ne laisse rien à moitié fait.

En pratique, la session a survécu, parce que le jeton d'actualisation principal (Primary Refresh Token)
était déjà en cache. Même mécanisme qui avait masqué une configuration DNS complètement cassée plus tôt le
même jour : des jetons en cache font passer un chemin d'authentification mort pour vivant.

## Les deux échecs, et ce qu'ils enseignent

### Supprimer un groupe ne nettoie pas ses affectations

`APUserDrivenEntraJoin`, le profil de déploiement Autopilot, a refusé la suppression avec un simple
`BadRequest`. Interroger ses affectations a montré pourquoi :

```json
{
  "id": "18356edc-..._b83ed302-...-ce030510da1c_0",
  "target": {
    "@odata.type": "#microsoft.graph.groupAssignmentTarget",
    "groupId": "<group-id>"
  }
}
```

Ce groupe, `Dyn-Autopilot-Devices`, avait été supprimé vingt minutes plus tôt dans la même exécution.
**L'affectation lui a survécu**, pointant toujours vers un objet qui n'existe plus, et le profil refusait
de se supprimer tant qu'elle était là.

Correctif : supprimer l'affectation, puis le profil.

Dans un tenant en production, c'est la vraie leçon. Supprimer un groupe laisse des affectations
orphelines sur chaque stratégie à laquelle il a été rattaché, et ces stratégies se comportent ensuite
bizarrement pour des raisons que le portail ne montre pas.

### Un utilisateur qui détient un rôle d'annuaire ne peut pas être supprimé avec le seul droit d'écriture utilisateur

`anna.test` a renvoyé `Forbidden`. Elle détenait Intune Administrator, attribué le Jour 2 comme exercice
de moindre privilège.

`User.ReadWrite.All` ne suffit pas pour supprimer un utilisateur qui détient un rôle d'annuaire. Supprimer
un compte privilégié exige aussi des droits de gestion des rôles. C'est le contrôle qui empêche une
application disposant d'un accès en écriture sur les utilisateurs de supprimer les administrateurs.

Correctif : retirer l'attribution de rôle d'abord, puis supprimer le compte.

## Pas fait via Graph

Trois choses ont demandé une autre voie :

- **Les stratégies d'accès conditionnel.** Autre périmètre d'autorisation, fait dans le portail. À noter
  que seule une des stratégies attendues était encore présente, donc quelque chose avait supprimé les
  autres à un moment inconnu
- **Les paramètres d'appareil du tenant Entra**, remis par défaut : qui peut joindre, et la limite
  d'appareils par utilisateur. **Correction, 25 septembre :** "Users may join devices" a été trouvé sur
  Selected pendant la reconstruction, et non sur la valeur par défaut All. Voir `../rebuild/README.md`
- **La machine virtuelle Hyper-V**

```powershell
Stop-VM -Name "W11-CORP-01" -TurnOff -Force
Remove-VM -Name "W11-CORP-01" -Force
Remove-Item -Path "D:\VMs\W11-CORP-01" -Recurse -Force
```

La troisième ligne n'est pas facultative. **`Remove-VM` supprime la machine et laisse les disques**, ce qui
est la raison la plus courante pour laquelle un hôte Hyper-V se remplit en silence. Ici, c'était 117 Go
répartis entre un disque de base et deux fichiers de point de contrôle, les points de contrôle étant plus
gros que le disque dont ils étaient issus.

Le volume de l'hôte est passé de 36 Go libres à 148 Go. Il était plein à 93 %, et un volume hôte plein est
ce qui a bloqué une réinitialisation Windows à 98 % le Jour 3, sans que rien nulle part ne signale la vraie
cause.
