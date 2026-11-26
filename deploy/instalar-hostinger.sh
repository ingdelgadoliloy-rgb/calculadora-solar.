#!/usr/bin/env bash
# Despliega la Calculadora solar en una VPS (Hostinger u otra) con Ubuntu/Debian.
# Uso (como root, en la terminal de la VPS):
#   DOMINIO=solar.tudominio.com bash instalar-hostinger.sh
#   DOMINIO=solar.tudominio.com TOKEN=github_pat_xxx bash instalar-hostinger.sh   # si el repo es privado
# Sin DOMINIO, publica por la IP de la VPS (solo http, sin instalación como app).
# Para actualizar la web después de un cambio, vuelve a ejecutar el mismo comando.
set -euo pipefail

REPO="ingdelgadoliloy-rgb/calculadora-solar."
DESTINO="/var/www/calculadora-solar"
SITIO="calculadora-solar"
DOMINIO="${DOMINIO:-}"
TOKEN="${TOKEN:-}"
CORREO="${CORREO:-}"

info(){ printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fallo(){ printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fallo "Ejecuta como root (o con sudo)."
command -v apt-get >/dev/null || fallo "Este script es para Ubuntu o Debian."

# 1. No pisar otro servidor web que ya use el puerto 80
if ss -ltnp 2>/dev/null | grep -E ':80\s' | grep -qv nginx; then
  ss -ltnp | grep -E ':80\s' || true
  fallo "El puerto 80 ya lo usa otro programa (Apache, OpenLiteSpeed, Docker…). No se cambió nada. Envía este mensaje para adaptar el despliegue."
fi

info "Instalando Nginx y Git"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx git ca-certificates >/dev/null

info "Descargando la app desde GitHub"
if [ -n "$TOKEN" ]; then URL="https://x-access-token:${TOKEN}@github.com/${REPO}"; else URL="https://github.com/${REPO}"; fi
if [ -d "$DESTINO/.git" ]; then
  git -C "$DESTINO" remote set-url origin "$URL"
  git -C "$DESTINO" fetch -q --depth 1 origin main
  git -C "$DESTINO" reset -q --hard origin/main
else
  rm -rf "$DESTINO"
  git clone -q --depth 1 "$URL" "$DESTINO" || fallo "No se pudo descargar el repositorio. Si es privado, agrega TOKEN=… (ver README)."
fi
git -C "$DESTINO" remote set-url origin "https://github.com/${REPO}"   # no deja el token guardado
chown -R www-data:www-data "$DESTINO"

info "Configurando Nginx"
NOMBRE="${DOMINIO:-_}"
cat > "/etc/nginx/sites-available/${SITIO}" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${NOMBRE};
    root ${DESTINO}/www;
    index index.html;

    gzip on;
    gzip_types text/css application/javascript application/json application/manifest+json image/svg+xml;

    location = /sw.js               { add_header Cache-Control "no-cache"; }
    location = /index.html          { add_header Cache-Control "no-cache"; }
    location = /manifest.webmanifest { default_type application/manifest+json; add_header Cache-Control "no-cache"; }
    location /icons/                { add_header Cache-Control "public, max-age=604800"; }
    location / { try_files \$uri \$uri/ /index.html; }

    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy strict-origin-when-cross-origin;
}
NGINX
ln -sf "/etc/nginx/sites-available/${SITIO}" "/etc/nginx/sites-enabled/${SITIO}"
if [ -z "$DOMINIO" ]; then rm -f /etc/nginx/sites-enabled/default; fi
nginx -t
systemctl enable --now nginx >/dev/null
systemctl reload nginx

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 'Nginx Full' >/dev/null || true
fi

if [ -n "$DOMINIO" ]; then
  info "Obteniendo certificado HTTPS para ${DOMINIO}"
  apt-get install -y -qq certbot python3-certbot-nginx >/dev/null
  if [ -n "$CORREO" ]; then MAIL=(-m "$CORREO"); else MAIL=(--register-unsafely-without-email); fi
  certbot --nginx -d "$DOMINIO" --non-interactive --agree-tos --redirect "${MAIL[@]}" \
    || fallo "Nginx ya sirve la app por http://${DOMINIO}, pero no salió el certificado. Revisa que el registro A del dominio apunte a la IP de esta VPS y vuelve a ejecutar."
  info "Listo: https://${DOMINIO}"
else
  IP=$(curl -s4 https://ifconfig.me || hostname -I | awk '{print $1}')
  info "Listo: http://${IP}  (agrega un dominio para HTTPS e instalación como app)"
fi
