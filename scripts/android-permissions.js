// Añade al AndroidManifest los permisos de ubicación que usan
// «Usar mi ubicación» y «Elegir el más cercano a mí».
const fs = require('fs');
const path = 'android/app/src/main/AndroidManifest.xml';
let xml = fs.readFileSync(path, 'utf8');
const perms = [
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.ACCESS_FINE_LOCATION'
];
for (const p of perms) {
  if (!xml.includes(p)) {
    xml = xml.replace('</manifest>', `    <uses-permission android:name="${p}" />\n</manifest>`);
  }
}
fs.writeFileSync(path, xml);
console.log('Permisos de ubicación listos en', path);
