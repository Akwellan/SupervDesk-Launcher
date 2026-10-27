# Supervision Checkmk — Démarrage automatique (SuperV)

Ce dossier contient le script `Start-SupervisionDesktops.ps1`, chargé d'ouvrir le tableau de bord Checkmk dans Microsoft Edge en plein écran lors de l'ouverture de session Windows de l'utilisateur **SuperV**.

> **Configuration retenue : un seul bureau Windows et une seule fenêtre Edge.** Le script doit être la version sans gestion des bureaux virtuels. S'il contient encore des appels à `VirtualDesktopKeys`, le remplacer par la version « bureau unique » avant installation.

## 1. Prérequis

- Windows 10/11 avec Microsoft Edge installé.
- Un compte Windows local `SuperV` (ou un compte de domaine, à adapter).
- Une session graphique ouverte par `SuperV` pour afficher Edge.
- Des droits administrateur **pour installer la tâche planifiée et configurer les permissions**.
- Un accès réseau à `https://supervision.icare-lims.local` et des identifiants Checkmk valides.

## 2. Installer le script

Créer le dossier `C:\Scripts` puis y copier le fichier :

```text
C:\Scripts\Start-SupervisionDesktops.ps1
```

Le script attend actuellement **60 secondes**, ouvre Microsoft Edge avec le dashboard Checkmk puis passe en plein écran avec `F11`.

> **Sécurité :** éviter de mettre le mot de passe Checkmk directement dans l'URL ou en clair dans le script. Privilégier une méthode d'authentification adaptée (session pré-authentifiée, SSO ou mécanisme sécurisé validé par l'équipe). Ne pas enregistrer d'identifiants réels dans un dépôt Git.

## 3. Donner les droits à SuperV

Dans **PowerShell exécuté en tant qu'administrateur** :

```powershell
$ScriptPath = 'C:\Scripts\Start-SupervisionDesktops.ps1'
$User = "$env:COMPUTERNAME\SuperV"  # Compte local

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Script introuvable : $ScriptPath"
}

# Lecture et exécution sur le fichier
& icacls.exe $ScriptPath /grant "${User}:(RX)"
if ($LASTEXITCODE -ne 0) { throw 'Échec de la modification des ACL.' }

# À utiliser seulement si le fichier est de confiance
Unblock-File -LiteralPath $ScriptPath
```

Si `SuperV` est un compte **Active Directory**, remplacer la valeur de `$User` par `DOMAINE\SuperV`.

Vérifier les permissions :

```powershell
icacls 'C:\Scripts\Start-SupervisionDesktops.ps1'
```

Vérifier aussi que `SuperV` peut traverser et lire le dossier `C:\Scripts`.

## 4. Supprimer l'ancienne tâche et créer la nouvelle

Toujours dans **PowerShell administrateur**, exécuter :

```powershell
$TaskName = 'Supervision CheckMK'
$ScriptPath = 'C:\Scripts\Start-SupervisionDesktops.ps1'
$User = "$env:COMPUTERNAME\SuperV"  # Adapter si domaine

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Script introuvable : $ScriptPath"
}

# Supprime uniquement la tâche de ce nom située à la racine du Planificateur
$OldTask = Get-ScheduledTask -TaskPath '\' -TaskName $TaskName -ErrorAction SilentlyContinue
if ($OldTask) {
    Unregister-ScheduledTask -TaskPath '\' -TaskName $TaskName -Confirm:$false
    Write-Host 'Ancienne tâche supprimée.' -ForegroundColor Yellow
}

$Action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`"" `
    -WorkingDirectory 'C:\Scripts'

$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $User

# Important : la session de SuperV doit être ouverte pour afficher Edge
$Principal = New-ScheduledTaskPrincipal `
    -UserId $User `
    -LogonType Interactive `
    -RunLevel Limited

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskPath '\' `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Description 'Lancement automatique Checkmk à la connexion de SuperV'

Get-ScheduledTask -TaskPath '\' -TaskName $TaskName |
    Select-Object TaskName, State
```

**Attention :** si une ancienne tâche de supervision existe sous un **autre nom**, la rechercher dans `taskschd.msc` et la désactiver/supprimer afin d'éviter deux lancements. La commande ci-dessus ne supprime pas les autres tâches.

### Configuration attendue dans le Planificateur

Ouvrir `Win + R` → `taskschd.msc`, puis contrôler :

| Élément | Valeur |
|---|---|
| Nom | `Supervision CheckMK` |
| Utilisateur | `SuperV` |
| Déclencheur | À l'ouverture de session de `SuperV` |
| Exécution | Uniquement si l'utilisateur est connecté |
| Programme | `powershell.exe` |
| Arguments | `-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Scripts\Start-SupervisionDesktops.ps1"` |
| Dossier de démarrage | `C:\Scripts` |
| Instances multiples | Ne pas démarrer une nouvelle instance |

Le délai de **60 secondes** est déjà dans le script. Ne pas ajouter un deuxième délai dans la tâche sauf besoin particulier.

## 5. Tester le script manuellement

Ouvrir une **session interactive en tant que `SuperV`**, puis lancer PowerShell :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Scripts\Start-SupervisionDesktops.ps1'
```

Résultat attendu après l'attente : Edge ouvre Checkmk dans une nouvelle fenêtre et bascule en plein écran (`F11`).

## 6. Tester la tâche planifiée

Avec la session `SuperV` ouverte :

```powershell
Start-ScheduledTask -TaskPath '\' -TaskName 'Supervision CheckMK'
```

Puis contrôler son état et le résultat de la dernière exécution :

```powershell
Get-ScheduledTask -TaskPath '\' -TaskName 'Supervision CheckMK'
Get-ScheduledTaskInfo -TaskPath '\' -TaskName 'Supervision CheckMK' |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Faire ensuite un vrai test : **se déconnecter**, puis **se reconnecter avec `SuperV`**.

## 7. Dépannage

- **Edge ne s'affiche pas :** s'assurer que `SuperV` est connecté à une session graphique. La tâche ne doit pas être paramétrée en « Exécuter même si l'utilisateur n'est pas connecté ».
- **Script introuvable :** vérifier le chemin `C:\Scripts\Start-SupervisionDesktops.ps1`.
- **Accès refusé :** vérifier les ACL avec `icacls`, ainsi que les droits sur `C:\Scripts`.
- **Erreur de stratégie d'exécution :** l'argument `-ExecutionPolicy Bypass` agit seulement sur ce processus et ne contourne pas les restrictions imposées par les stratégies de groupe.
- **Edge ne passe pas en plein écran :** les appels `AppActivate` et `SendKeys` dépendent de la fenêtre active ; allonger le délai de chargement si nécessaire. Le mode kiosque Edge peut être plus robuste.
- **La tâche semble avoir réussi, mais rien n'est visible :** vérifier le compte d'exécution et la session Windows active ; consulter l'historique de la tâche dans `taskschd.msc`.
- **Double lancement :** rechercher d'autres tâches planifiées ou scripts lancés via le dossier Démarrage.

## 8. Commandes utiles

```powershell
# Afficher la tâche
Get-ScheduledTask -TaskPath '\' -TaskName 'Supervision CheckMK'

# Lancer la tâche (session SuperV ouverte)
Start-ScheduledTask -TaskPath '\' -TaskName 'Supervision CheckMK'

# Désactiver la tâche sans la supprimer
Disable-ScheduledTask -TaskPath '\' -TaskName 'Supervision CheckMK'

# Réactiver la tâche
Enable-ScheduledTask -TaskPath '\' -TaskName 'Supervision CheckMK'

# Supprimer la tâche
Unregister-ScheduledTask -TaskPath '\' -TaskName 'Supervision CheckMK' -Confirm:$false
```

## 9. Arborescence conseillée

```text
C:\Scripts\
├── Start-SupervisionDesktops.ps1
└── README.md
```

**Note :** le nom standard du fichier de documentation est `README.md` (et non `README.ME`).
