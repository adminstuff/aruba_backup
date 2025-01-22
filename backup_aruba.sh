#!/bin/bash

# Script directory configuration
SCRIPT_DIR="/opt/scripts/network"
CONFIG_FILE="${SCRIPT_DIR}/switches.txt"

# Backup directory configuration
BACKUP_BASE="/backup"
BACKUP_DIR="${BACKUP_BASE}/aruba_cx"
LOG_FILE="/var/log/aruba_backup.log"
SSH_KEY="${HOME}/.ssh/aruba_backup"

# Email configuration
ADMIN_EMAIL="admin@votreentreprise.com"

# Date format
DATE="$(date +%Y%m%d)"
REPORT_FILE="${BACKUP_DIR}/${DATE}/rapport_backup_${DATE}.txt"
DAILY_BACKUP_DIR="${BACKUP_DIR}/${DATE}"

# Fonction de logging
log_message() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] ${message}" >> "${LOG_FILE}"
    echo "[${timestamp}] ${message}"
}

# Vérification des prérequis
if [ ! -f "${CONFIG_FILE}" ]; then
    log_message "ERREUR: Le fichier ${CONFIG_FILE} n'existe pas"
    exit 1
fi

if [ ! -f "${SSH_KEY}" ]; then
    log_message "ERREUR: La clé SSH ${SSH_KEY} n'existe pas"
    exit 1
fi

if [ ! -d "${BACKUP_DIR}" ]; then
    log_message "Création du répertoire de sauvegarde ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
fi

# Création du sous-répertoire daté
mkdir -p "${DAILY_BACKUP_DIR}"

# Fonction de sauvegarde pour un switch
backup_switch() {
    local hostname="$1"
    local username="$2"
    
    log_message "Début de la sauvegarde pour ${hostname}"
    
    # Sauvegarde de la configuration running
    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${username}@${hostname}" \
    'show running-config' > "${DAILY_BACKUP_DIR}/${hostname}-running-${DATE}.cfg" 2>/dev/null
    RUNNING_STATUS=$?

    # Sauvegarde de la configuration startup
    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${username}@${hostname}" \
    'show startup-config' > "${DAILY_BACKUP_DIR}/${hostname}-startup-${DATE}.cfg" 2>/dev/null
    STARTUP_STATUS=$?

    if [ ${RUNNING_STATUS} -eq 0 ] && [ ${STARTUP_STATUS} -eq 0 ]; then
        log_message "Sauvegarde réussie pour ${hostname}"
        # Vérification des fichiers
        if [ -s "${DAILY_BACKUP_DIR}/${hostname}-running-${DATE}.cfg" ] && \
           [ -s "${DAILY_BACKUP_DIR}/${hostname}-startup-${DATE}.cfg" ]; then
            # Archivage des configurations
            tar -czf "${hostname}-${DATE}.tar.gz" -C "${DAILY_BACKUP_DIR}" \
                "${hostname}-running-${DATE}.cfg" \
                "${hostname}-startup-${DATE}.cfg"
            # Nettoyage des fichiers originaux après compression
            rm "${DAILY_BACKUP_DIR}/${hostname}-running-${DATE}.cfg" \
               "${DAILY_BACKUP_DIR}/${hostname}-startup-${DATE}.cfg"
            log_message "Configurations compressées pour ${hostname}"
        else
            log_message "ATTENTION: Fichiers de configuration vides pour ${hostname}"
            rm -f "${DAILY_BACKUP_DIR}/${hostname}-running-${DATE}.cfg" \
                  "${DAILY_BACKUP_DIR}/${hostname}-startup-${DATE}.cfg"
        fi
    else
        log_message "ERREUR: Échec de la sauvegarde pour ${hostname}"
    fi
}

# Lecture du fichier des switches et exécution des sauvegardes
log_message "Début du processus de sauvegarde"

for ligne in $(cat "${CONFIG_FILE}"); do
    # Ignorer les lignes vides ou commentées
    [[ -z "${ligne}" || "${ligne}" =~ ^#.*$ ]] && continue
    
    # Extraction du hostname et username
    hostname="$(echo ${ligne} | cut -d: -f1)"
    username="$(echo ${ligne} | cut -d: -f2)"
    
    # Vérification des valeurs extraites
    if [ -z "${hostname}" ] || [ -z "${username}" ]; then
        log_message "ERREUR: Format de ligne invalide : ${ligne}"
        continue
    fi
    
    backup_switch "${hostname}" "${username}"
done

# Nettoyage des anciennes sauvegardes (conservation de 30 jours)
find "${BACKUP_DIR}" -type d -mtime +30 -exec rm -rf {} \;

log_message "Fin du processus de sauvegarde"

# Génération d'un rapport détaillé
{
    echo "Rapport de sauvegarde des switches du ${DATE}"
    echo "------------------------------------------------"
    echo ""
    echo "Switches sauvegardés avec succès:"
    find "${DAILY_BACKUP_DIR}" -name "*.tar.gz" | while read backup; do
        basename "${backup}" .tar.gz
    done
    echo ""
    echo "Résumé:"
    echo "Total des sauvegardes: $(find "${DAILY_BACKUP_DIR}" -name "*.tar.gz" | wc -l)"
    echo ""
    echo "Erreurs et avertissements:"
    grep "ERREUR\|ATTENTION" "${LOG_FILE}" | tail -n 10
} > "${REPORT_FILE}"

# Envoi du rapport par email
if which mail >/dev/null 2>&1; then
    mail -s "Rapport de sauvegarde switches ${DATE}" \
         -a "${REPORT_FILE}" \
         "${ADMIN_EMAIL}" < "${REPORT_FILE}"
fi
