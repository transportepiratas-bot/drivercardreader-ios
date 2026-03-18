#!/bin/bash
# Script para crear IPA válido para AltStore

set -e

echo "=== Creando IPA para AltStore ==="

# Ir al directorio del proyecto
cd "$(dirname "$0")"

# Limpiar
rm -rf DerivedData Payload DriverCardReader.ipa output 2>/dev/null || true

echo "1. Compilando proyecto..."
xcodebuild -project DriverCardReader.xcodeproj \
  -scheme DriverCardReader \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "2. Buscando app bundle..."
APP_PATH=$(find ./DerivedData -name "DriverCardReader.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "ERROR: No se encontró DriverCardReader.app"
    exit 1
fi

echo "   App encontrada: $APP_PATH"

echo "3. Verificando contenido del app..."
ls -la "$APP_PATH/" | head -10

echo "4. Creando estructura IPA..."
mkdir -p Payload/DriverCardReader.app
cp -R "$APP_PATH/"* Payload/DriverCardReader.app/

echo "5. Verificando Payload..."
ls -la Payload/
ls -la Payload/DriverCardReader.app/ | head -10

echo "6. Creando IPA..."
cd Payload
zip -r ../DriverCardReader.ipa .
cd ..

echo "7. Verificando IPA..."
unzip -l DriverCardReader.ipa | head -20
ls -lh DriverCardReader.ipa

mkdir -p output
mv DriverCardReader.ipa output/

echo ""
echo "=== IPA CREADO EXITOSAMENTE ==="
echo "Ubicación: output/DriverCardReader.ipa"
