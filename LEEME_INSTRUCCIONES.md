# Driver Card Reader iOS Clone

Este proyecto es una reconstrucción profesional de la aplicación "Driver Card Reader" de Lobol Team, diseñada específicamente para iOS utilizando **SwiftUI**.

## 🚀 Cómo Compilar (GitHub Actions)
He configurado un flujo de trabajo automático para que puedas obtener el instalador sin necesidad de un Mac físico:

1.  **Sube este código** a un repositorio de GitHub.
2.  Ve a la pestaña **Actions**.
3.  Selecciona el workflow **"Build iOS App"**.
4.  Haz clic en **"Run workflow"**.
5.  Al finalizar, descarga el "Artifact" llamado `DriverCardReader-iOS-Build`.

## 📂 Estructura del Proyecto
- `ContentView.swift`: Núcleo de la interfaz y navegación por pestañas.
- `DDDParser.swift`: Motor de análisis de archivos del tacógrafo (.ddd).
- `PlanningView.swift`: Herramientas de planificación de tiempos de conducción.
- `InaccuraciesView.swift`: Detección automática de infracciones según Reg. 561/2006.
- `SummaryView.swift`: Resúmenes de trabajo descargables.
- `L10n.swift`: Textos y leyes extraídos de la APK original.

## 🔌 Requisitos de Hardware para iPhone
Para que la aplicación funcione igual que la de Android, el iPhone necesita conectarse a un lector de tarjetas inteligentes:
- **iPhone 15 o superior**: Compatible con lectores USB-C estándar.
- **iPhones anteriores**: Requieren un adaptador Lightning a USB (Camera Kit) o un lector certificado MFi.

## ⚖️ Aviso Legal
Este código es una réplica funcional basada en la ingeniería inversa de los recursos públicos de la APK de Lobol Team para fines de portabilidad de plataforma.
