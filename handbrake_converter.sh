#!/bin/bash

# =======================================================
# HandBrake Batch Converter
# Este script automatiza la conversión de archivos de video
# a formato MP4 usando HandBrakeCLI y notifica el estado
# a través de NTFY.
# =======================================================

# --- CONFIGURACIÓN ---
# Directorio donde se buscarán los archivos de video a convertir.
# ¡IMPORTANTE! Asegúrate de que este directorio exista y tenga los permisos adecuados.
INPUT_DIR="/var/snap/docker/common/var-lib-docker/volumes/me_tube_metube_downloads/_data"

# Directorio de salida para los videos convertidos.
# Se creará una subcarpeta 'handbrake' dentro del INPUT_DIR.
OUTPUT_DIR="${INPUT_DIR}/handbrake"

# Directorio y archivo para los logs de la conversión.
# Se creará una subcarpeta 'log' dentro del OUTPUT_DIR.
LOG_DIR="${OUTPUT_DIR}/log"
LOG_FILE="${LOG_DIR}/handbrake_conversion.log"

# Configuración de NTFY para notificaciones.
# Visita https://ntfy.sh/ para más información.
NTFY_HOST="tudominio.com"
NTFY_TOPIC="handbrake_proces" # Reemplaza con tu tópico de NTFY
NTFY_TOKEN="tk_99dlsxetk5grl3l5cfgwfdsxdp46Hmottnywx0nel5" # ¡Cuidado! Mantén este token privado.

# --- Variables internas (no modificar a menos que sepas lo que haces) ---
CONVERTED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
CONVERTED_FILES=""
FAILED_FILES=""

# --- FUNCIONES ---

# Función para registrar mensajes en la consola y en el archivo de log.
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Función para enviar notificaciones a través de NTFY.
send_ntfy_notification() {
    local title="$1"
    local message="$2"
    log_message "Enviando notificación NTFY: $title"

    # Convertimos los saltos de línea del mensaje a saltos de línea reales para Markdown.
    local formatted_message_md=$(echo -e "$message")

    curl -s -H "Title: $title" \
             -H "Authorization: Bearer $NTFY_TOKEN" \
             -H "X-Markdown: 1" \
             -d "$formatted_message_md" \
             "https://$NTFY_HOST/$NTFY_TOPIC"

    if [ $? -ne 0 ]; then
        log_message "ADVERTENCIA: No se pudo enviar la notificación NTFY. Revisa la configuración de ntfy y la conectividad."
    fi
}

# --- INICIO DEL SCRIPT ---
log_message "--- INICIO DEL PROCESO DE CONVERSIÓN DE VIDEO ---"
log_message "Buscando videos en: $INPUT_DIR"
log_message "Los videos convertidos se guardarán en: $OUTPUT_DIR"

# Asegúrate de que los directorios necesarios existan.
mkdir -p "$INPUT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

# Itera sobre los archivos de video en el directorio de entrada.
# Añade o quita extensiones según los tipos de archivos que esperes.
for file in "$INPUT_DIR"/*.mkv "$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.avi "$INPUT_DIR"/*.mov "$INPUT_DIR"/*.webm; do
    # Verifica si el elemento es un archivo regular y existe.
    if [ -f "$file" ]; then
        filename=$(basename -- "$file")
        filename_no_ext="${filename%.*}"
        output_file="$OUTPUT_DIR/${filename_no_ext}.mp4"

        log_message "Procesando archivo: $file"
        log_message "Archivo de salida esperado: $output_file"

        # Verifica si el archivo de salida ya existe para evitar reconversiones.
        if [ -f "$output_file" ]; then
            log_message "ADVERTENCIA: El archivo $output_file ya existe. Saltando la conversión de $file."
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue # Pasa al siguiente archivo.
        fi

        # Ejecuta HandBrakeCLI con prioridad baja (nice -n 10).
        # La salida de HandBrake se redirige a un archivo temporal para un análisis de errores.
        TEMP_HB_LOG=$(mktemp)

        nice -n 10 /usr/bin/HandBrakeCLI -i "$file" -o "$output_file" \
            -f mp4 \
            -e x264 \
            --encoder-preset medium \
            -q 20 \
            -r 30 --rate 30 \
            -w 1920 -l 1080 \
            --modulus 2 \
            -a 1 \
            -E ac3 \
            -B 160 \
            --crop 0:0:0:0 2>&1 | tee -a "$TEMP_HB_LOG"

        HANDBRAKE_EXIT_STATUS=${PIPESTATUS[0]} # Captura el estado de salida de HandBrakeCLI.

        # Verifica el estado de la conversión.
        if [ "$HANDBRAKE_EXIT_STATUS" -eq 0 ] && grep -q "Encode done!" "$TEMP_HB_LOG"; then
            log_message "ÉXITO: Conversión de '$file' completada exitosamente."
            CONVERTED_COUNT=$((CONVERTED_COUNT + 1))
            CONVERTED_FILES+="- ${filename_no_ext}.mp4 (original: ${filename})\n"

            log_message "Borrando archivo original: '$file'"
            rm "$file"
            if [ $? -eq 0 ]; then
                log_message "ÉXITO: Archivo original '$file' borrado."
            else
                log_message "ERROR: No se pudo borrar el archivo original '$file'. Revisa los permisos."
            fi
        else
            log_message "ERROR: La conversión de '$file' falló o el archivo de origen no fue reconocido por HandBrake."
            log_message "Últimas líneas del log de HandBrakeCLI (para diagnóstico):"
            tail -n 10 "$TEMP_HB_LOG" | while IFS= read -r line; do log_message "  HandBrake Output: $line"; done # Loguea las últimas 10 líneas del error.
            
            FAILED_COUNT=$((FAILED_COUNT + 1))
            FAILED_FILES+="- ${filename}\n"
            log_message "El archivo original NO será borrado debido al fallo."
            
            # Si HandBrake falló y dejó un archivo de salida incompleto, lo eliminamos.
            if [ -f "$output_file" ]; then
                log_message "ADVERTENCIA: Eliminando archivo de salida incompleto/fallido: '$output_file'"
                rm -f "$output_file"
            fi
        fi
        
        # Eliminar el archivo temporal de log de HandBrake.
        rm -f "$TEMP_HB_LOG"
    fi
done

log_message "--- PROCESO DE CONVERSIÓN FINALIZADO ---"

# --- ENVÍO DE NOTIFICACIÓN NTFY FINAL ---
if [ "$CONVERTED_COUNT" -gt 0 ] || [ "$FAILED_COUNT" -gt 0 ] || [ "$SKIPPED_COUNT" -gt 0 ]; then
    NOTIFICATION_TITLE="Resumen de Conversión HandBrake"
    NOTIFICATION_MESSAGE="Proceso de HandBrake completado.\n"
    NOTIFICATION_MESSAGE+="----------------------------------\n"
    NOTIFICATION_MESSAGE+="*Archivos Convertidos:* $CONVERTED_COUNT\n"
    if [ "$CONVERTED_COUNT" -gt 0 ]; then
        NOTIFICATION_MESSAGE+="Detalles de Éxito:\n$CONVERTED_FILES"
    fi

    NOTIFICATION_MESSAGE+="\n*Archivos Fallidos:* $FAILED_COUNT\n"
    if [ "$FAILED_COUNT" -gt 0 ]; then
        NOTIFICATION_MESSAGE+="Detalles de Fallo:\n$FAILED_FILES"
    fi
    
    NOTIFICATION_MESSAGE+="\n*Archivos Saltados (ya existían):* $SKIPPED_COUNT\n"
    NOTIFICATION_MESSAGE+="----------------------------------"

    send_ntfy_notification "$NOTIFICATION_TITLE" "$NOTIFICATION_MESSAGE"
else
    log_message "No se encontraron archivos de video para procesar o todos fueron saltados. No se enviará notificación NTFY."
fi
