# HandBrake Batch Converter

Este script de Bash automatiza la conversión de múltiples archivos de video a formato MP4 utilizando [HandBrakeCLI](https://handbrake.fr/docs/en/latest/cli/cli-guide.html). Además, integra notificaciones a través de [NTFY](https://ntfy.sh/) para informarte sobre el estado de las conversiones, incluyendo éxitos, fallos y archivos saltados.

El script está diseñado para buscar videos en un directorio de entrada especificado, convertirlos, y opcionalmente, eliminar los archivos originales si la conversión fue exitosa.

## Características

* **Conversión por lotes:** Procesa múltiples archivos de video de diferentes formatos.
* **Formato de salida MP4:** Convierte todos los videos a un formato MP4 optimizado para compatibilidad.
* **Parámetros de HandBrake personalizables:** Configuración de calidad, resolución, códecs, etc.
* **Notificaciones NTFY:** Recibe resúmenes detallados de las conversiones (éxitos, fallos, saltados).
* **Registro detallado:** Genera un archivo de log con la actividad del script.
* **Borrado opcional de originales:** Elimina los archivos de video originales solo si la conversión fue exitosa.
* **Manejo de errores:** Detecta y registra fallos en la conversión.
* **Evita duplicados:** No procesa archivos si el video de salida ya existe.

## Requisitos

Antes de ejecutar este script, asegúrate de tener instalados los siguientes componentes:

1.  **HandBrakeCLI:** La herramienta de línea de comandos de HandBrake.
    * **En Debian/Ubuntu:**
        ```bash
        sudo apt update
        sudo apt install handbrake-cli
        ```
    * **En otras distribuciones:** Consulta la documentación oficial de HandBrake para tu sistema.
2.  **`curl`:** Para enviar las notificaciones NTFY.
    * Suele venir preinstalado en la mayoría de los sistemas Linux. Si no, puedes instalarlo con `sudo apt install curl` (Debian/Ubuntu).

## Configuración

Edita el script `handbrake_converter.sh` y ajusta las siguientes variables en la sección `--- CONFIGURACIÓN ---`:

* **`INPUT_DIR`**: El directorio donde se encuentran tus archivos de video originales que deseas convertir.
    * Ejemplo: `INPUT_DIR="/ruta/a/tus/videos/originales"`
* **`OUTPUT_DIR`**: El directorio donde se guardarán los videos convertidos. Por defecto, se creará una subcarpeta `handbrake` dentro de `INPUT_DIR`.
    * Ejemplo: `OUTPUT_DIR="${INPUT_DIR}/handbrake"`
* **`NTFY_HOST`**: El host de tu servidor NTFY. (Ej: `ntfy.sh` o tu propio host).
* **`NTFY_TOPIC`**: El tópico al que enviarás las notificaciones de NTFY.
* **`NTFY_TOKEN`**: **¡IMPORTANTE!** Tu token de autenticación de NTFY. **Mantén esto privado.** Si no usas autenticación, puedes dejarlo vacío o eliminar la línea ` -H "Authorization: Bearer $NTFY_TOKEN" \` del script (aunque no es recomendable por seguridad).

### Parámetros de HandBrakeCLI

Los parámetros de HandBrakeCLI están definidos en el script. Si deseas ajustar la calidad, resolución, códecs de audio/video, etc., modifica la línea que comienza con `nice -n 10 /usr/bin/HandBrakeCLI ...`. Consulta la [guía de HandBrakeCLI](https://handbrake.fr/docs/en/latest/cli/cli-guide.html) para explorar todas las opciones disponibles.

Los parámetros actuales son:

* `-f mp4`: Formato de contenedor MP4.
* `-e x264`: Códec de video H.264.
* `--encoder-preset medium`: Velocidad de codificación (equilibrio entre calidad y velocidad).
* `-q 20`: Calidad constante (RF) de 20. Valores más bajos significan mayor calidad, valores más altos menor calidad.
* `-r 30 --rate 30`: Establece la velocidad de fotogramas a 30 FPS.
* `-w 1920 -l 1080`: Resolución de salida (ancho 1920px, alto 1080px).
* `--modulus 2`: Asegura que la resolución sea par.
* `-a 1`: Selecciona la primera pista de audio.
* `-E ac3`: Códec de audio AC3.
* `-B 160`: Bitrate de audio de 160 kbps.
* `--crop 0:0:0:0`: Desactiva el recorte automático.

## Uso

1.  **Guarda el script:** Guarda el código del script como `handbrake_converter.sh` (o el nombre que prefieras).
2.  **Hazlo ejecutable:** Dale permisos de ejecución al script:
    ```bash
    chmod +x handbrake_converter.sh
    ```
3.  **Ejecútalo:**
    ```bash
    ./handbrake_converter.sh
    ```

### Ejecución en segundo plano o con `cron`

Para ejecutar el script automáticamente o en segundo plano, puedes usar:

* **`nohup`** (para dejarlo corriendo después de cerrar la terminal):
    ```bash
    nohup ./handbrake_converter.sh &
    ```
* **`screen`** o **`tmux`** (para una sesión persistente):
    ```bash
    screen -S handbrake_session
    ./handbrake_converter.sh
    # Luego Ctrl+A, D para desadjuntar
    ```
* **`cron`** (para ejecutarlo periódicamente, por ejemplo, cada noche):
    Edita tu crontab: `crontab -e`
    Añade una línea como esta para ejecutarlo todos los días a las 3 AM:
    ```cron
    0 3 * * * /ruta/completa/a/handbrake_converter.sh >> /var/log/handbrake_cron.log 2>&1
    ```
    (Asegúrate de reemplazar `/ruta/completa/a/handbrake_converter.sh` con la ruta real de tu script).

## Estructura de Directorios

Una vez que el script se ejecuta, creará la siguiente estructura dentro de tu `INPUT_DIR`:
