# EcoMerk2

**EcoMerk2** es una plataforma móvil diseñada para optimizar la economía del hogar. A través de la comparación de precios en tiempo real y el uso de Inteligencia Artificial para la gestión de recetas, permitimos que los usuarios ahorren dinero y reduzcan el desperdicio de alimentos.

## 🚀 Funcionalidades Principales

* **Comparador Inteligente:** Encuentra el precio más bajo entre múltiples supermercados para productos idénticos.
* **Asistente de Recetas (IA):** Sugerencias personalizadas basadas en tu lista de compras actual.
* **Mapas y Rutas:** Ubicación de tiendas cercanas vía GPS y optimización de rutas de compra.
* **Alertas de Ahorro:** Notificaciones cuando tus productos favoritos bajen de precio.

## 🛠️ Stack Tecnológico

* **Frontend:** Flutter (Dart)
* **Backend:** AWS (Cloud Services)
* **Base de Datos:** PostgreSQL
* **IA:** GPT-4 / Gemini API

---

🤝 Reglas de Colaboración 

Para este proyecto, el equipo ha decidido implementar el flujo de trabajo **GitHub Flow** debido a su agilidad y enfoque en despliegues continuos. A continuación, se detallan las normas obligatorias para contribuir al repositorio:

1. Flujo de Ramas 

* **Rama `main`:** Es la rama principal y siempre debe contener código estable y listo para producción.


* **Ramas de Funcionalidad (`feature/`):** Todo nuevo desarrollo, corrección de errores o mejora debe realizarse en una rama independiente creada a partir de `main` (ejemplo: `feature/gps-integration`).

2. Protección de la Rama Principal 

La rama `main` cuenta con las siguientes protecciones configuradas:

* **Prohibición de cambios directos:** Ningún colaborador puede realizar un `push` directamente a `main`.


* **Pull Requests (PR):** Todos los cambios deben pasar obligatoriamente por un proceso de revisión antes de ser integrados.



3. Proceso de Revisión de Código 

* Para que un Pull Request sea aprobado y fusionado (merged), requiere al menos **una revisión y aprobación** de otro miembro del equipo.


* El código debe cumplir con el **Checklist de Calidad** definido en la documentación del proyecto (estilo de código, manejo de errores y pruebas básicas).

### 4. Estilo de Commits

Se recomienda usar mensajes claros y descriptivos en presente:

* `feat:` para nuevas funcionalidades.
* `fix:` para corrección de errores.
* `docs:` para cambios en la documentación.
