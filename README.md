# Calculadora solar para tu casa

Autor: **Hector David Agudelo Arias**

Una sola app con dos versiones que comparten el mismo código (carpeta `www/`):

- **Web (PWA):** se abre en cualquier navegador, funciona sin conexión y se puede instalar en el celular desde el navegador («Agregar a la pantalla de inicio» o el botón «Instalar la app»).
- **Android (APK):** la misma app empaquetada con Capacitor. Si cambias la web, el APK se actualiza.

## Qué hace

| Pestaña | Contenido |
|---|---|
| **Paneles** | Número de paneles, kWp y generación mes a mes a partir de la factura. Tiene las 11 estaciones de referencia y las 32 capitales de departamento (las que no tienen estación propia usan una de clima parecido, y la app lo indica), modo manual por horas pico y PVGIS por coordenadas o GPS. También compara con una cotización. |
| **Baterías** | Respaldo para cortes o sistema autónomo, con lista de equipos. Calcula los kWh nominales y útiles, el inversor mínimo y los paneles para el sistema autónomo. |
| **Costos** | Inversión, ahorro mensual, años de retorno, ahorro neto, costo por kWh y flujo acumulado año por año. Puede usar el precio de la cotización e incluir la batería. |
| **Informe** | Informe en PDF (generado en el propio teléfono, sin internet), compartir por WhatsApp, copiar el resumen, proyectos guardados por cliente y copia de seguridad en JSON. |

Los cálculos de paneles y baterías son los de la calculadora original (Excel/HTML). Con el ejemplo del manual (Quibdó, 300 kWh, 550 Wp, 100 %, 14 %) da 6 paneles, 3,3 kWp y 3.725 kWh/año. Con 6 kWh de respaldo, 80 % de descarga utilizable y 95 % de eficiencia, da 7,89 kWh nominales.

## Probarla en tu computador

Abre `www/index.html` en el navegador. Para probar la instalación y el modo sin conexión, sírvela con un servidor local:

```bash
npm run serve        # luego abre http://localhost:8080
```

## Publicar la versión web

**Opción A, GitHub Pages (gratis y automática):**
1. Crea un repositorio en GitHub y sube esta carpeta.
2. En el repositorio ve a *Settings → Pages → Source* y elige **GitHub Actions**.
3. Cada vez que subas cambios a `main`, la web se publica sola en `https://TU-USUARIO.github.io/NOMBRE-REPO/`.

**Opción B, Netlify:** arrastra la carpeta `www` a https://app.netlify.com/drop.

Funciona en cualquier hosting que sirva archivos estáticos por HTTPS.

## Generar el APK

### Opción 1: GitHub Actions (sin instalar nada)
1. Sube el proyecto a GitHub (como en la opción A).
2. El flujo **APK Android** corre solo en cada cambio y publica el APK en *Releases → «Última versión»*. También queda en *Actions → Artifacts* si hay cuota disponible.
3. Pasa `calculadora-solar-debug.apk` al teléfono e instálalo. Android pedirá permitir apps de origen desconocido.
4. Para publicar una versión con número, crea una etiqueta (`git tag v1.0.0 && git push --tags`). El APK quedará en *Releases*.

### Opción 2: Android Studio
Requiere Node.js 20 o más reciente, JDK 21 y Android Studio.
```bash
npm install
npm run android:init   # crea la carpeta android/, íconos, pantalla de inicio y permisos
npm run android:open   # abre Android Studio → Build → Build APK(s)
```
Después de cambiar algo en `www/`, ejecuta `npm run android:sync`.

### APK firmado para Google Play (opcional)
El APK *debug* sirve para instalarlo directamente. Para la Play Store necesitas una llave de firma:
```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias calculadora
base64 -w0 release.jks   # copia el resultado
```
En GitHub, en *Settings → Secrets and variables → Actions*, crea `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD`. El flujo generará además `calculadora-solar.apk` firmado. **Guarda la llave en un lugar seguro:** sin ella no podrás actualizar la app en Play.

## Diferencias entre la web y el APK

| Función | Web | APK |
|---|---|---|
| Traer datos de PVGIS con un toque | El navegador lo bloquea. Se descarga el JSON con el enlace y se importa. | Directo (usa la conexión nativa) |
| Guardar el PDF | Descarga o menú de compartir | Menú de compartir de Android |
| Proyectos | Se guardan en el navegador | Se guardan en la app |

Los proyectos quedan solo en el dispositivo. Usa *Informe → Copia de seguridad* para moverlos.

## Archivos

```
www/                 la app (HTML, manifiesto, service worker, íconos)
assets/              íconos y pantalla de inicio para Android
capacitor.config.json
scripts/android-permissions.js
.github/workflows/   android.yml (APK) y web.yml (GitHub Pages)
```

Al publicar cambios en la web, sube el número de `CACHE` en `www/sw.js` para que los teléfonos descarguen la nueva versión.

## Fuentes
IDEAM (radiación global por estación, anexo 7) · UTCH y PERS Chocó (serie de Quibdó) · PVGIS (datos y metodología) · UPME (balance de energía útil residencial).

## Desplegar en la VPS con Traefik (fotovcal.xcol.tech)

La VPS ya tiene Traefik con Docker en los puertos 80/443, así que la app corre como un contenedor `nginx:alpine` con etiquetas de Traefik, igual que las demás apps:

```bash
git clone --depth 1 https://github.com/ingdelgadoliloy-rgb/calculadora-solar. /opt/calculadora-solar
cd /opt/calculadora-solar/deploy && docker compose up -d
```

Para actualizar después de un cambio:

```bash
cd /opt/calculadora-solar && git pull && docker compose -f deploy/docker-compose.yml restart
```

## Desplegar en una VPS sin Traefik

La app no tiene backend: basta Nginx sirviendo `www/` con HTTPS. En hPanel → VPS → **Terminal** (como root):

```bash
curl -fsSL -H "Authorization: Bearer TU_TOKEN" -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/ingdelgadoliloy-rgb/calculadora-solar./contents/deploy/instalar-hostinger.sh" -o instalar.sh
DOMINIO=solar.tudominio.com TOKEN=TU_TOKEN bash instalar.sh
```

- Antes, crea en el DNS un registro **A** del dominio hacia la IP de la VPS.
- `TOKEN`: solo si el repositorio es privado. Crea un *fine-grained token* en GitHub (*Settings → Developer settings → Personal access tokens*) con acceso **solo a este repositorio** y permiso **Contents: Read-only**. Si el repositorio es público, quita las partes del token.
- Para actualizar la web después de un cambio, vuelve a ejecutar la última línea.
- Si el puerto 80 ya lo usa otro programa, el script se detiene sin cambiar nada.
