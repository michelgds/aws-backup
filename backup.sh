#!/bin/bash

set -o verbose

# AWS settings
AWS_CLI="/usr/local/bin/aws"
BUCKET_NAME="$2"
BUCKET_DUMP="${BUCKET_NAME}/dumps"
EXPIRES="$(date -d '+3 months' --utc +'%Y-%m-%dT%H:%M:%SZ')"

# File settings
FILE_FOLDER="$1"
DUMP_FOLDER="${FILE_FOLDER}/dumps"
DUMP_FILE_NAME="`date +%Y%m%d`.sql.gz"

# Database settings
wp_config=$(sed -e '/^\s*\(require\|include\)/d'  "$FILE_FOLDER/wp-config.php")
DB_USR=$(php <<< "${wp_config};echo DB_USER;")
DB_PSW=$(php <<< "${wp_config};echo DB_PASSWORD;")
DB_HOST=$(php <<< "${wp_config};echo DB_HOST;")
DB_NAME=$(php <<< "${wp_config};echo DB_NAME;")
DB_ARGS="-u $DB_USR -p$DB_PSW -h $DB_HOST $DB_NAME"

# Email settings
EMAIL_ADDRESS_AWS="contato@editalconcursosbrasil.com.br"
EMAIL_ADDRESS_USR="fabio.montefuscolo@gmail.com"
EMAIL_SUBJ="AWS Backup Error `hostname`"
EMAIL_TEXT="Ocorreu um erro ao criar backup do banco de dados. Base de dados: ${DB_NAME}."

# Database Dump
folder="${DUMP_FOLDER}"
filename="$folder/$DUMP_FILE_NAME"
mkdir -p "$folder"
mysqldump $DB_ARGS | gzip > $filename

# AWS Sync
$AWS_CLI s3 sync "$DUMP_FOLDER" "s3://${BUCKET_DUMP}" --expires "$EXPIRES"
$AWS_CLI s3 sync "$FILE_FOLDER" "s3://${BUCKET_NAME}" --exclude "dumps/*"

# Check if file exists and send an email if it doesn't
if ! $AWS_CLI s3 ls s3://${BUCKET_DUMP}/${DUMP_FILE_NAME}; then
    $AWS_CLI ses send-email --to "$EMAIL_ADDRESS_USR" --from "$EMAIL_ADDRESS_AWS" --subject "$EMAIL_SUBJ" --text "$EMAIL_TEXT"
fi

# Remove local files
find "${DUMP_FOLDER}" -type f -mtime +2 -name "*.sql.gz" -exec rm {} \;
