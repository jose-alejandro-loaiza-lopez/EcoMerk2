# EcoMerk2

**EcoMerk2** es una aplicación móvil multiplataforma que optimiza la economía del hogar mediante la comparación de precios en tiempo real entre múltiples supermercados colombianos y un asistente con inteligencia artificial.

## Funcionalidades

- **Comparador de precios en 3 tiendas** — Busca productos simultáneamente en Éxito (VTEX), Olímpica (VTEX) y Surtifamiliar y encuentra el precio más bajo.
- **Asistente IA (EcoIA)** — Chat inteligente que sugiere recetas basadas en tus productos favoritos, consejos de ahorro y comparaciones.
- **Lista de compras / Favoritos** — Guarda productos, recibe el mejor precio disponible y compáralos entre tiendas con un solo toque.
- **Alertas de precio** — Notificaciones locales cuando un producto suscrito baja al menos un 5%. Revisión automática cada 6 horas en segundo plano.
- **Historial de precios** — Línea de tiempo con evolución de precios, tendencias y cambios porcentuales.
- **Cifrado extremo a extremo** — RSA-2048 + AES-256-CBC en todas las comunicaciones con el backend.

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter (Dart) 3.x |
| Backend | Spring Boot — Railway |
| Base de datos | PostgreSQL |
| IA | OpenRouter (GPT-4 / Gemini) |
| Cifrado | RSA + AES híbrido |

## Instalación

1. Descarga el APK desde la sección [Releases](https://github.com/jose-alejandro-loaiza-lopez/EcoMerk2/releases).
2. En tu dispositivo Android, habilita *Instalar aplicaciones de orígenes desconocidos* en Ajustes > Seguridad.
3. Abre el archivo `.apk` descargado y toca **Instalar**.
4. Una vez instalada, abre EcoMerk2, regístrate y empieza a comparar.

## Desarrollo

```bash
git clone https://github.com/jose-alejandro-loaiza-lopez/EcoMerk2.git
cd EcoMerk2
cp .env.example .env   # configura BASE_URL
flutter pub get
flutter run
```

## API

La documentación de la API está en [`docs.md`](docs.md).

**Base URL (producción):** `https://usuarios-bd-production.up.railway.app/api/v1`

---

## Contribuir

El proyecto sigue **GitHub Flow**:

1. Crea una rama desde `main`: `feature/descripcion`
2. Desarrolla y commitea con mensajes claros (`feat:`, `fix:`, `docs:`)
3. Abre un Pull Request — requiere al menos 1 aprobación
4. No se permite push directo a `main`
