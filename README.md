# aruba_backup
Script bash de sauvegarde pour les switches Aruba. Certainement aussi pour les Cisco.
Le script liste les switches et les comptes de connexion dans le fichier switches.txt.
Il se connecte en ssh sur chaque switch et sauvegarde la running-config et la startup-config et les compresses

## Fonctionnement : 
- Sauvegarde automatique des configurations running et startup
- Authentification sécurisée par clé SSH
- Compression automatique des sauvegardes
- Rotation automatique des sauvegardes (conservation 30 jours)
- Rapports détaillés par email
- Logging complet des opérations

## Pré requis sur le serveur de backup
- Système Linux/Unix
- Bash shell
- OpenSSH client
- Mail command (pour l'envoi des rapports)
- tar (pour la compression)
- Résolution DNS pour les objets mentionnés dans le fichier switches.txt. Il est possible d'utiliser les adresses ip directement.


## Installation

### 1. Créer les répertoires nécessaires :
```
sudo mkdir -p /opt/scripts/network
sudo mkdir -p /backup/aruba_cx
```

### 2. Copier le script :
```
sudo cp backup_aruba.sh /opt/scripts/network/
sudo chmod +x /opt/scripts/network/backup_aruba.sh
```

### 3. Générer une paire de clés SSH :
```
ssh-keygen -t ecdsa-sha2-nistp256 -f ~/.ssh/aruba_backup -C "backup-ops"
chmod 0600 ~/.ssh/aruba_backup
```

## Configuration

### 1. Fichier de Configuration des Switches (switches.txt)

Format : `hostname:username`

Exemple :
```
switch1.domain.com:backup-user
switch2.domain.com:backup-user
#switch3.domain.com:backup-user    # Commenté
```

### 2. Configuration des Switches Aruba CX

Sur chaque switch :
```
# Création du groupe en lecture seule
user-group read-only-ops
    permit cli command "show running-config"
    permit cli command "show startup-config"

# Création de l'utilisateur avec la clé SSH
user backup-ops group read-only-ops password ciphertext AABB...
user backup-ops authorized-key ecdsa-sha2-nistp256 AAAA... backup-ops
```

### 3. Variables du Script

Principales variables à configurer dans le script :
```
SCRIPT_DIR="/opt/scripts/network"     # Localisation du script
BACKUP_BASE="/backup"                 # Base des sauvegardes
ADMIN_EMAIL="admin@entreprise.com"    # Email pour les rapports
CONFIG_FILE="${SCRIPT_DIR}/switches.txt"
BACKUP_DIR="${BACKUP_BASE}/aruba"
LOG_FILE="${BACKUP_DIR}/log/aruba_backup.log"
SSH_KEY="${HOME}/.ssh/aruba_backup"
```


## Utilisation

### Exécution Manuelle

```
/opt/scripts/network/backup_aruba.sh
```

### Configuration Cron

Pour une exécution quotidienne à 3h du matin :
```
0 3 * * * /opt/scripts/network/backup_aruba.sh
```



