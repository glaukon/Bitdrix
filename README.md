# 🚀 Bitdrix

> Modern Torrent Streaming & Download Manager built with Flutter.

Bitdrix es una aplicación multiplataforma desarrollada con Flutter para **buscar, gestionar, descargar y reproducir torrents en streaming** desde una única interfaz moderna y optimizada.

Diseñada para ofrecer una experiencia fluida, rápida y escalable en escritorio, móvil y web.

---

## ✨ Características

### 📥 Gestión de Torrents

* ➕ Añadir archivos `.torrent`
* 🧲 Añadir enlaces Magnet
* ⏸️ Pausar descargas
* ▶️ Reanudar descargas
* ❌ Eliminar torrents
* 📊 Seguimiento en tiempo real
* 🚀 Velocidad de descarga/subida
* ⏳ ETA (Tiempo restante)

---

### 🎬 Streaming Integrado

* ▶️ Reproducción mientras descarga
* ⚡ Streaming progresivo
* 📂 Gestión interna de archivos
* 🎯 Selección individual de archivos
* 🎞️ Reproductor integrado

---

### 🔎 Descubrimiento de Contenido

* 🎥 Integración con TMDB
* 🍿 Búsqueda de películas
* 📺 Búsqueda de series
* 📝 Información detallada
* 🖼️ Posters y metadatos
* 🌐 Fuentes de streaming

---

### 🎨 Interfaz Moderna

* 🌙 Dark Mode
* 📱 Responsive UI
* 🖥️ Desktop Friendly
* ⚡ Navegación rápida
* 🧠 Arquitectura limpia y escalable

---

## 🖥️ Plataformas soportadas

| Plataforma | Estado           |
| ---------- | ---------------- |
| 🤖 Android | ✅ Disponible     |
| 🪟 Windows | ✅ Disponible     |
| 🌐 Web     | ✅ Disponible     |
| 🐧 Linux   | 🚧 En desarrollo |
| 🍏 macOS   | 🚧 En desarrollo |
| 📱 iOS     | 🚧 En desarrollo |

---

## 🏗️ Arquitectura

Bitdrix sigue principios de **Clean Architecture**.

```text
lib/
├── core/           # Configuración, utilidades, constantes
├── data/           # Modelos, servicios, repositorios
├── domain/         # Entidades y casos de uso
└── presentation/   # UI, widgets, pantallas y providers
```

### 📦 Estructura

#### Core

Configuración global y utilidades.

#### Data

Acceso a datos, APIs y servicios.

#### Domain

Lógica de negocio.

#### Presentation

Interfaz gráfica.

---

## ⚙️ Stack tecnológico

* 💙 Flutter
* 🎯 Dart
* 🌐 WebTorrent
* 🔗 Native Torrent Engine
* 🎬 MediaKit
* 🎥 TMDB API

---

## 🚀 Instalación

### Requisitos

* Flutter SDK
* Dart SDK
* Git
* Android Studio / VS Code

---

### Clonar proyecto

```bash
git clone https://github.com/Glauk0n/Bitdrix.git
cd Bitdrix
```

---

### Instalar dependencias

```bash
flutter pub get
```

---

## 🔐 Configuración

Crear archivo `.env`

```env
TMDB_API_KEY=your_api_key
TMDB_READ_ACCESS_TOKEN=your_access_token
```

---

## ▶️ Ejecución

### Android

```bash
flutter run
```

### Windows

```bash
flutter run -d windows
```

### Web

```bash
flutter run -d chrome
```

---

## 📦 Build producción

### Android APK

```bash
flutter build apk --release
```

### Windows

```bash
flutter build windows
```

### Web

```bash
flutter build web
```

---

## 🛣️ Roadmap

### Próximamente

* 🍏 Soporte iOS
* 🍎 Soporte macOS
* 📚 Biblioteca multimedia
* ⭐ Sistema de favoritos
* 📝 Subtítulos automáticos
* 🔄 Sincronización dispositivos
* 📡 Chromecast
* 📺 DLNA
* 👤 Sistema de cuentas

---

## 🔒 Seguridad

Bitdrix no almacena:

* ❌ Contraseñas
* ❌ Tokens privados
* ❌ Datos personales

Todas las APIs sensibles se gestionan mediante variables de entorno.

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas.

1. Fork del proyecto
2. Crear rama
3. Realizar cambios
4. Crear Pull Request

---

## ⚖️ Aviso legal

Bitdrix es una herramienta técnica para la gestión y transferencia de archivos mediante protocolo BitTorrent.

El usuario es responsable del uso de la aplicación y del contenido al que accede, descarga o comparte.

Bitdrix:

* ❌ No aloja contenido
* ❌ No distribuye archivos protegidos
* ❌ No proporciona torrents propios

---

## 👨‍💻 Autor

Desarrollado por **Glauk0n**

🌐 GitHub:
https://github.com/Glaukon

---

## ⭐ Apoya el proyecto

Si te gusta Bitdrix:

🌟 Dale una estrella al repositorio
🍴 Haz fork
📢 Compártelo

---

**Built with ❤️ by Glauk0n**
