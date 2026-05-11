
**Base URL**: `http://usuarios-bd-production.up.railway.app:8080/api/v1`

**Formato de autorización**: incluir header `Authorization: Bearer <ACCESS_TOKEN>` para endpoints que requieran autenticación.  
- `ACCESS_TOKEN` = JWT (expiración por defecto: 1 día).  
- `REFRESH_TOKEN` = token largo retornado por el servidor (expiración por defecto: 7 días).

**Paginación / tamaño**: bloques de mensajes y páginas usan tamaño fijo 10 (constante `CANTIDAD_POR_PAGINA = 10`).

**1) Auth**
- **POST /auth/refresh**
  - Autenticación: NO (endpoint público; valida el `refreshToken` en body).
  - Request JSON:
    - `refreshToken` (string) — el refresh token que el cliente recibió al login/rotación.
  - Response 200:
    - `token` (string) — nuevo `access token` (JWT).
    - `refreshToken` (string) — nuevo `refresh token` rotado.
    - `mensaje` (string)
  - Errores típicos: `400` (validación), `401` (si se implementa), `500` (token inválido/expirado - revisar backend).
  - Ejemplo curl:
    ```bash
    curl -X POST http://localhost:8080/api/v1/auth/refresh \
      -H "Content-Type: application/json" \
      -d '{"refreshToken":"<REFRESH_TOKEN>"}'
    ```

**2) Usuarios (gestión de usuarios)**
Base: `/usuarios`

- **POST /usuarios/** — Registrar usuario
  - Autenticación: NO
  - Request JSON (`UsuarioRequest`):
    - `nombre` (string) — obligatorio
    - `email` (string) — obligatorio, formato email
    - `password` (string) — obligatorio, mínimo 8 caracteres
    - `fechaNacimiento` (yyyy-MM-dd) — obligatorio
  - Response 201:
    - `mensaje`: "¡El usuario ha sido creado con éxito!"
    - `usuario`: objeto `Usuarios` (contiene `id`, `nombre`, `email`, `fechaNacimiento`, `favoritos`, `role` — `password` no se expone)
  - Ejemplo:
    ```bash
    curl -X POST http://localhost:8080/api/v1/usuarios/ \
      -H "Content-Type: application/json" \
      -d '{"nombre":"Carlos","email":"carlos@example.com","password":"pass12345","fechaNacimiento":"1990-01-01"}'
    ```

- **POST /usuarios/login** — Login (obtener `access` + `refresh`)
  - Autenticación: NO
  - Request JSON (`LoginRequest`):
    - `email`, `password`
  - Response 200:
    - `token` (string) — access JWT
    - `refreshToken` (string)
    - `id` (number) — id del usuario
    - `mensaje` (string)
  - Ejemplo:
    ```bash
    curl -X POST http://localhost:8080/api/v1/usuarios/login \
      -H "Content-Type: application/json" \
      -d '{"email":"juan@example.com","password":"securePass123"}'
    ```

- **GET /usuarios/public-key**
  - Autenticación: NO
  - Response 200:
    - `n` (hex string) — módulo RSA en hexadecimal
    - `e` (hex string) — exponente público en hexadecimal
  - Uso: cliente (ej. móvil) puede cifrar contraseñas u otros datos.

- **GET /usuarios/** — Listar todos los usuarios
  - Autenticación: SÍ (ROLE_ADMIN requerido)
  - Response 200:
    - `usuarios`: array de objetos `Usuarios`
  - Nota: protegido por `ROLE_ADMIN` en el backend.

- **GET /usuarios/page/{page}** — Listar usuarios paginados (10 por página)
  - Autenticación: SÍ (ROLE_ADMIN requerido)
  - Response 200: objeto `Page` de Spring (contiene `content`, `totalPages`, `totalElements`, `number`, `size`, etc.)
  - Ejemplo:
    ```bash
    curl -H "Authorization: Bearer <ACCESS_TOKEN>" \
      http://localhost:8080/api/v1/usuarios/page/0
    ```

- **GET /usuarios/{id}** — Obtener usuario por id
  - Autenticación: SÍ
  - Response 200:
    - `mensaje`: "Usuario encontrado."
    - `usuario`: objeto `Usuarios`
  - Errores: 404 si no existe.

- **PUT /usuarios/{id}** — Actualizar perfil (owner o admin)
  - Autenticación: SÍ (solo el dueño del token o `ROLE_ADMIN` puede actualizar)
  - Request JSON: igual que `UsuarioRequest`
  - Response 200:
    - `mensaje`: "Perfil actualizado con éxito."
    - `usuario`: usuario actualizado

- **DELETE /usuarios/{id}** — Eliminar usuario (owner o admin)
  - Autenticación: SÍ (solo dueño o admin)
  - Response 200:
    - `mensaje`: "El usuario ha sido eliminado con éxito."

- **PATCH /usuarios/{id}/favoritos** — Sincronizar favoritos (owner o admin)
  - Autenticación: SÍ (solo dueño o admin)
  - Request JSON: array de `ProductoFavorito` (estructura en backend):
    - `link` (string) — URL o identificador del producto
    - `notificaciones` (boolean) — si el usuario activó las notificaciones para ese producto
  - Response 200:
    - `usuario`: usuario con `favoritos` sincronizados
    - `mensaje`: confirmación

**3) Chat privado por usuario (IA)**
Base: `/chat`

- Resumen conceptual: cada usuario tiene un chat privado con la IA. Los mensajes se guardan por `usuario_id`. No hay timestamps; el orden y paginación se usa por `id` (autoincremental). Los mensajes guardan `contenido` y `es_ia` (boolean).

- **GET /chat/mensajes**
  - Autenticación: SÍ (cualquier usuario autenticado)
  - Query params:
    - `antes` (long, opcional) — cursor: devuelve mensajes con `id < antes` (mensajes anteriores al cursor)
  - Comportamiento:
    - Devuelve solo los mensajes del usuario autenticado (se obtiene `usuarioId` desde el JWT → lookup por email).
    - Orden: por `id` descendente (el primer elemento es el más reciente).
    - Cantidad máxima devuelta: 10 por petición.
  - Response 200:
    - `mensajes`: array de objetos
      - `id` (long)
      - `usuarioId` (long)
      - `contenido` (string)
      - `esIa` (boolean) — `true` si mensaje es de la IA, `false` si usuario
    - `cantidad` (int)
    - `hayMas` (boolean) — `true` si la página devolvió exactamente 10 elementos
  - Ejemplo:
    ```bash
    curl -H "Authorization: Bearer <ACCESS_TOKEN>" \
      'http://localhost:8080/api/v1/chat/mensajes'
    ```
    Con cursor:
    ```bash
    curl -G 'http://localhost:8080/api/v1/chat/mensajes' \
      --data-urlencode 'antes=123' \
      -H "Authorization: Bearer <ACCESS_TOKEN>"
    ```

- **POST /chat/mensajes**
  - Autenticación: SÍ
  - Request JSON (`MensajeChatRequest`):
    - `contenido` (string) — obligatorio
    - `esIa` (boolean) — indica si el mensaje viene de la IA
  - Comportamiento importante:
    - `usuarioId` se infiere del token — **NO** enviar `usuarioId` desde el cliente.
  - Response 201:
    - `mensaje`: "Mensaje guardado con éxito"
    - `datos`: objeto del `MensajeChat` guardado (`id`, `usuarioId`, `contenido`, `esIa`)
  - Ejemplo:
    ```bash
    curl -X POST http://localhost:8080/api/v1/chat/mensajes \
      -H "Authorization: Bearer <ACCESS_TOKEN>" \
      -H "Content-Type: application/json" \
      -d '{"contenido":"Hola IA, ¿qué debo hacer?","esIa":false}'
    ```

**4) Formatos de respuesta de error (comunes)**
- `400 Bad Request` — validación de campos:
  ```json
  {
    "mensaje":"Error de validación en los datos del usuario.",
    "error":[
      "El campo 'email' Email inválido",
      "El campo 'password' La contraseña es obligatoria"
    ]
  }
  ```
- `401 Unauthorized` — token faltante o inválido (respuesta de Spring Security).
- `403 Forbidden` — acceso denegado (por ejemplo: intentar borrar/editar sin permisos):
  ```json
  {
    "error":"Acceso denegado: No tienes rango suficiente para borrar a otro usuario.",
    "status":403
  }
  ```
- `404 Not Found` — recurso no encontrado:
  ```json
  {
    "error":"El usuario con ID 123 no fue encontrado.",
    "status":404
  }
  ```
- `500 Internal Server Error` — errores generales (incluye mensajes de excepción).

**5) Esquema de la tabla de mensajes (DDL sugerido)**
- Recomendado si la BD parte desde cero (Postgres):
  ```sql
  CREATE TABLE mensajes_chat (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    contenido TEXT NOT NULL,
    es_ia BOOLEAN NOT NULL
  );
  ```

**6) Notas de seguridad / recomendaciones para frontend**
- Guardado de tokens:
  - `access token` (JWT): preferiblemente mantener en memoria y reenviar en `Authorization` header.
  - `refresh token`: idealmente en `HttpOnly`, `Secure` cookie (si backend lo soporta) para reducir riesgo XSS; si no, guardarlo en almacenamiento seguro del cliente con precaución.
- El `refresh` devuelve siempre un nuevo `access token` y un nuevo `refresh token` (rotación) — actualizar ambos en el cliente luego de renovar.
- Los `refresh tokens` expiran (7 días por defecto). Si se cambian secretos/en configuración, invalidar tokens o forzar relogin.
