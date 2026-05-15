# API EcoMerk2 — Documentación para Frontend (Flutter)

**Base URL (producción):** `https://usuarios-bd-production.up.railway.app/api/v1`
**Base URL (local):** `http://localhost:8080/api/v1`

---

> ⚠️ **IMPORTANTE: Cifrado obligatorio.** Toda petición con body y toda respuesta (excepto `GET /usuarios/public-key`) viaja cifrada con RSA + AES. Los JSON de ejemplo en esta documentación muestran el **contenido descifrado**. Si envías JSON plano, el backend responde con **400 Bad Request**. Ver sección [Cifrado](#5-cifrado-extremo-a-extremo-obligatorio).

---

## Autenticación

| Concepto | Valor |
|---|---|
| **Access token** | JWT, expira en **15 minutos** |
| **Refresh token** | UUID rotado, expira en **1 día** |
| **Formato** | Header `Authorization: Bearer <ACCESS_TOKEN>` |
| **Almacenamiento** | Access token en memoria; refresh token en almacenamiento seguro |

> El refresh token se obtiene al hacer login y se rota (se obtiene uno nuevo) cada vez que se usa `POST /auth/refresh`.

---

## 1. Auth

### POST /auth/refresh — Renovar tokens

Renueva el access token cuando expira. También rota el refresh token (el anterior se invalida).

- **Autenticación:** NO (público)
- **Request:**
  ```json
  {
    "refreshToken": "550e8400-e29b-41d4-a716-446655440000-..."
  }
  ```
- **Response 200:**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "refreshToken": "a1b2c3d4-e5f6-7890-abcd-ef1234567890-...",
    "mensaje": "Token renovado con éxito"
  }
  ```
- **Errores:** `400` si `refreshToken` viene vacío, `500` si el token no existe, expiró o fue revocado.

---

## 2. Usuarios

Base: `/usuarios`

### POST /usuarios/ — Registrar usuario

- **Autenticación:** NO (público)
- **Request** (`UsuarioRequest`):
  ```json
  {
    "nombre": "Carlos Pérez",
    "email": "carlos@example.com",
    "password": "Pass12345",
    "fechaNacimiento": "1990-01-01"
  }
  ```
  | Campo | Tipo | Obligatorio | Validación |
  |---|---|---|---|
  | `nombre` | string | sí | `@NotBlank` |
  | `email` | string | sí | `@Email`, `@NotBlank` |
  | `password` | string | sí | mínimo 8 caracteres |
  | `fechaNacimiento` | string (date) | sí | formato `yyyy-MM-dd` |
- **Response 201:**
  ```json
  {
    "mensaje": "¡El usuario ha sido creado con éxito!",
    "usuario": {
      "id": 1,
      "nombre": "Carlos Pérez",
      "email": "carlos@example.com",
      "fechaNacimiento": "1990-01-01",
      "favoritos": [],
      "role": "ROLE_USER"
    }
  }
  ```
  > `password` **nunca** aparece en respuestas. `role` no se puede enviar (solo lectura).
- **Error 400 (validación):**
  ```json
  {
    "mensaje": "Error de validación en los datos del usuario.",
    "error": [
      "El campo 'email' Email inválido",
      "El campo 'password' La contraseña es obligatoria"
    ]
  }
  ```
- **Error 400 (email duplicado):**
  ```json
  {
    "error": "El correo electrónico 'carlos@example.com' ya está registrado en EcoMerk2.",
    "status": 400
  }
  ```

---

### POST /usuarios/login — Iniciar sesión

- **Autenticación:** NO (público)
- **Request:**
  ```json
  {
    "email": "carlos@example.com",
    "password": "Pass12345"
  }
  ```
- **Response 200:**
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "refreshToken": "550e8400-e29b-41d4-a716-446655440000-...",
    "id": 1,
    "mensaje": "Bienvenido a EcoMerk2"
  }
  ```
  > Guarda el `refreshToken` en almacenamiento seguro. Cuando el `token` (access JWT) expire, usa `POST /auth/refresh`.
- **Error 500 (credenciales inválidas):**
  ```json
  {
    "error": "Error interno en Usuarios-Service: El correo electrónico no se encuentra registrado",
    "status": 500
  }
  ```
  o
  ```json
  {
    "error": "Error interno en Usuarios-Service: Contraseña incorrecta",
    "status": 500
  }
  ```

---

### GET /usuarios/public-key — Obtener clave RSA pública

**Primer paso obligatorio** antes de cualquier otra llamada. Esta es la **única** respuesta en texto plano.

- **Autenticación:** NO (público)
- **Response 200:**
  ```json
  {
    "n": "b3b9c1c5a3d3f7e8... (hex)",
    "e": "10001"
  }
  ```
  | Campo | Tipo | Descripción |
  |---|---|---|
  | `n` | string (hex) | Módulo RSA de 2048 bits |
  | `e` | string (hex) | Exponente público (65537) |

---

### GET /usuarios/ — Listar todos los usuarios

- **Autenticación:** SÍ — requiere `ROLE_ADMIN`
- **Response 200:**
  ```json
  {
    "usuarios": [
      {
        "id": 1,
        "nombre": "Carlos Pérez",
        "email": "carlos@example.com",
        "fechaNacimiento": "1990-01-01",
        "favoritos": [
          { "productId": "prod_abc", "notificaciones": true }
        ],
        "role": "ROLE_USER"
      }
    ]
  }
  ```
- **Response 200 (sin usuarios):**
  ```json
  {
    "mensaje": "No hay usuarios registrados en el sistema.",
    "usuarios": null
  }
  ```

---

### GET /usuarios/page/{page} — Listar usuarios paginados

- **Autenticación:** SÍ — requiere `ROLE_ADMIN`
- **Path param:** `page` (integer, 0-based)
- **Tamaño de página:** 10 (fijo)
- **Response 200:** Objeto `Page` de Spring:
  ```json
  {
    "content": [
      {
        "id": 1,
        "nombre": "Carlos Pérez",
        "email": "carlos@example.com",
        "fechaNacimiento": "1990-01-01",
        "favoritos": [],
        "role": "ROLE_USER"
      }
    ],
    "pageable": {
      "sort": { "sorted": false, "unsorted": true, "empty": true },
      "pageNumber": 0,
      "pageSize": 10,
      "offset": 0,
      "paged": true,
      "unpaged": false
    },
    "totalPages": 3,
    "totalElements": 25,
    "last": false,
    "size": 10,
    "number": 0,
    "sort": { "sorted": false, "unsorted": true, "empty": true },
    "first": true,
    "numberOfElements": 10,
    "empty": false
  }
  ```
  | Campo clave | Tipo | Descripción |
  |---|---|---|
  | `content` | array | Usuarios en esta página |
  | `totalPages` | int | Total de páginas |
  | `totalElements` | int | Total de usuarios |
  | `number` | int | Página actual (0-based) |
  | `size` | int | 10 (fijo) |
  | `empty` | bool | `true` si no hay datos |
- **Error 404 (página vacía):**
  ```json
  {
    "mensaje": "No hay usuarios en la página solicitada: 99"
  }
  ```

---

### GET /usuarios/{id} — Obtener usuario por ID

- **Autenticación:** SÍ (cualquier usuario autenticado)
- **Response 200:**
  ```json
  {
    "mensaje": "Usuario encontrado.",
    "usuario": {
      "id": 1,
      "nombre": "Carlos Pérez",
      "email": "carlos@example.com",
      "fechaNacimiento": "1990-01-01",
      "favoritos": [],
      "role": "ROLE_USER"
    }
  }
  ```
- **Error 404:**
  ```json
  {
    "error": "El usuario con ID 999 no fue encontrado.",
    "status": 404
  }
  ```

---

### PUT /usuarios/{id} — Actualizar perfil

- **Autenticación:** SÍ — solo el dueño del token o un admin pueden actualizar
- **Request:** mismo esquema que `UsuarioRequest`
  ```json
  {
    "nombre": "Carlos Actualizado",
    "email": "carlos.nuevo@example.com",
    "password": "NuevaPass123",
    "fechaNacimiento": "1990-06-15"
  }
  ```
- **Response 200:**
  ```json
  {
    "mensaje": "Perfil actualizado con éxito.",
    "usuario": {
      "id": 1,
      "nombre": "Carlos Actualizado",
      "email": "carlos.nuevo@example.com",
      "fechaNacimiento": "1990-06-15",
      "favoritos": [],
      "role": "ROLE_USER"
    }
  }
  ```
- **Error 403 (no autorizado):**
  ```json
  {
    "error": "Acceso denegado: No tienes rango suficiente para modificar a otro usuario.",
    "status": 403
  }
  ```

---

### DELETE /usuarios/{id} — Eliminar usuario

- **Autenticación:** SÍ — solo el dueño del token o un admin pueden eliminar
- **Response 200:**
  ```json
  {
    "mensaje": "El usuario ha sido eliminado con éxito."
  }
  ```
- **Error 403:**
  ```json
  {
    "error": "Acceso denegado: No tienes rango suficiente para borrar a otro usuario.",
    "status": 403
  }
  ```

---

### PATCH /usuarios/{id}/favoritos — Sincronizar favoritos

Reemplaza **toda** la lista de favoritos del usuario con la lista enviada.

- **Autenticación:** SÍ — solo el dueño del token o un admin
- **Request:** arreglo de `ProductoFavorito`
  ```json
  [
    {
      "productId": "prod_abc_123",
      "notificaciones": true
    },
    {
      "productId": "prod_def_456",
      "notificaciones": false
    }
  ]
  ```
  | Campo | Tipo | Descripción |
  |---|---|---|
  | `productId` | string | Identificador del producto |
  | `notificaciones` | boolean | Activar notificaciones para este producto |
- **Response 200:**
  ```json
  {
    "usuario": {
      "id": 1,
      "nombre": "Carlos Pérez",
      "email": "carlos@example.com",
      "fechaNacimiento": "1990-01-01",
      "favoritos": [
        { "productId": "prod_abc_123", "notificaciones": true },
        { "productId": "prod_def_456", "notificaciones": false }
      ],
      "role": "ROLE_USER"
    },
    "mensaje": "Lista de alimentos favoritos sincronizada con éxito."
  }
  ```

---

## 3. Chat con IA (EcoIA)

Base: `/chat`

> Cada usuario tiene un chat privado con EcoIA. Los mensajes se guardan por `usuario_id`. El orden es por `id` ascendente (autoincremental). El cliente **nunca** maneja la API key de OpenRouter.

### GET /chat/mensajes — Obtener historial (paginado por cursor)

- **Autenticación:** SÍ (cualquier usuario autenticado)
- **Query params:**

  | Parámetro | Tipo | Obligatorio | Descripción |
  |---|---|---|---|
  | `antes` | long (int64) | No | Cursor: devuelve mensajes con `id < antes` |
- **Comportamiento:**
  - Devuelve solo los mensajes del usuario autenticado
  - Orden descendente por `id` (el más reciente primero)
  - Máximo **10** mensajes por petición
  - Si `antes` es `null`, devuelve los últimos 10 mensajes
- **Response 200:**
  ```json
  {
    "mensajes": [
      {
        "id": 21,
        "usuarioId": 1,
        "contenido": "¡Hola! ¿En qué puedo ayudarte?",
        "esIa": true
      },
      {
        "id": 20,
        "usuarioId": 1,
        "contenido": "Hola",
        "esIa": false
      }
    ],
    "cantidad": 2,
    "hayMas": false
  }
  ```
  | Campo | Tipo | Descripción |
  |---|---|---|
  | `mensajes` | array | Lista de mensajes (máx. 10) |
  | `cantidad` | int | Número de mensajes devueltos |
  | `hayMas` | boolean | `true` si hay más páginas (se devolvieron exactamente 10) |
  > **Uso en Flutter:** para cargar más mensajes al hacer scroll hacia arriba, usa `antes = mensajes.last.id`.

---

### POST /chat/ia — Enviar mensaje a la IA

- **Autenticación:** SÍ
- **Request:**
  ```json
  {
    "mensaje": "¿Qué puedo cocinar con huevos y arroz?",
    "favoritos": [
      {
        "nombre": "Arroz Diana",
        "tienda": "Éxito",
        "precio": "2500"
      },
      {
        "nombre": "Huevos Santa Reyes",
        "tienda": "Carulla",
        "precio": 12000
      }
    ]
  }
  ```
  | Campo | Tipo | Obligatorio | Descripción |
  |---|---|---|---|
  | `mensaje` | string | sí | Texto del usuario |
  | `favoritos` | array | No | Contexto de productos favoritos. Cada item: `{ nombre, tienda, precio }` |
- **Flujo interno:**
  1. Guarda el mensaje del usuario en BD (`esIa = false`)
  2. Construye system prompt con favoritos
  3. Envía a OpenRouter (API key del servidor)
  4. Guarda la respuesta de la IA en BD (`esIa = true`)
  5. Devuelve la respuesta al cliente
- **Response 200:**
  ```json
  {
    "respuesta": "¡Claro! Con huevos y arroz puedes preparar un delicioso **arroz con huevo** o un **arroz chino**.\n\n**Receta rápida:**\n1. Sofríe ajo y cebolla\n2. Agrega el arroz cocido\n3. Haz un huevo revuelto aparte\n4. Mezcla todo y sazona"
  }
  ```
- **Error 500 (OpenRouter falla):**
  ```json
  {
    "mensaje": "Error al obtener respuesta de la IA"
  }
  ```

---

## 4. Productos (Historial de precios)

Base: `/productos`

### GET /productos/{productId}/precios — Historial de precios

- **Autenticación:** NO (público)
- **Response 200:**
  ```json
  {
    "productId": "prod_abc_123",
    "historial": [
      {
        "id": 3,
        "productId": "prod_abc_123",
        "precio": 12500.0,
        "fechaGuardado": "2024-06-03T09:15:00"
      },
      {
        "id": 2,
        "productId": "prod_abc_123",
        "precio": 12000.0,
        "fechaGuardado": "2024-06-01T10:30:00"
      }
    ]
  }
  ```
  > Ordenado por `fechaGuardado` descendente. Si no hay precios: `"historial": []`.
- **Estructura de cada `PrecioHistorico`:**

  | Campo | Tipo | Descripción |
  |---|---|---|
  | `id` | number | ID autogenerado |
  | `productId` | string | ID del producto |
  | `precio` | number | Precio en la moneda local |
  | `fechaGuardado` | string (ISO 8601) | `yyyy-MM-ddTHH:mm:ss` (zona horaria: America/Bogota) |

---

### POST /productos/{productId}/precios — Agregar precio

- **Autenticación:** NO (público)
- **Request:**
  ```json
  {
    "precio": 123400.0
  }
  ```
- **Response 201:**
  ```json
  {
    "mensaje": "Precio agregado correctamente",
    "precio": {
      "id": 3,
      "productId": "prod_abc_123",
      "precio": 123400.0,
      "fechaGuardado": "2024-06-03T09:15:00"
    }
  }
  ```

---

## 5. Cifrado extremo a extremo (Obligatorio)

> ⚠️ **Toda comunicación con body (request y response) debe ir cifrada.** Si envías JSON plano, el backend responderá con **400 Bad Request** (`CifradoRequeridoException`).

### Flujo

1. **Obtener clave pública** → `GET /usuarios/public-key` (única respuesta en texto plano)
2. El cliente genera una **clave AES de 128 bits** (16 bytes) aleatoria y un **IV** (16 bytes)
3. El cliente cifra la clave AES con RSA (clave pública, OAEP/SHA-256) → `encryptedAesKey` (Base64)
4. El cliente cifra el payload JSON con AES-128-CBC → `encryptedData` (Base64)
5. Se envía al servidor:
   ```json
   {
     "encryptedAesKey": "base64...",
     "iv": "base64...",
     "encryptedData": "base64..."
   }
   ```
6. El backend descifra el payload con RSA (privada) + AES, procesa la petición, y **cifra la respuesta** con la misma clave AES + IV
7. La respuesta llega cifrada (sin `encryptedAesKey`):
   ```json
   {
     "iv": "base64...",
     "encryptedData": "base64..."
   }
   ```

### Flutter
> **Librerías recomendadas para Flutter:** [`pointycastle`](https://pub.dev/packages/pointycastle) (RSA + AES) y `convert` + `dart:convert` (Base64/hex).

### Endpoints exceptuados del cifrado

| Endpoint | Request | Response |
|---|---|---|
| `GET /usuarios/public-key` | Sin body | **Texto plano** (n, e) |
| Todos los demás | **Cifrado** (obligatorio) | **Cifrado** |

---

## 6. Resumen de autenticación por endpoint

| Endpoint | Auth | Rol | Propietario |
|---|---|---|---|
| `POST /auth/refresh` | ❌ | — | — |
| `POST /usuarios/` | ❌ | — | — |
| `POST /usuarios/login` | ❌ | — | — |
| `GET /usuarios/public-key` | ❌ | — | — |
| `GET /productos/{pid}/precios` | ❌ | — | — |
| `POST /productos/{pid}/precios` | ❌ | — | — |
| `GET /usuarios/` | ✅ | `ROLE_ADMIN` | — |
| `GET /usuarios/page/{page}` | ✅ | `ROLE_ADMIN` | — |
| `GET /usuarios/{id}` | ✅ | Cualquiera | — |
| `PUT /usuarios/{id}` | ✅ | Cualquiera | ✅ (owner o admin) |
| `DELETE /usuarios/{id}` | ✅ | Cualquiera | ✅ (owner o admin) |
| `PATCH /usuarios/{id}/favoritos` | ✅ | Cualquiera | ✅ (owner o admin) |
| `GET /chat/mensajes` | ✅ | Cualquiera | Alcance al token |
| `POST /chat/ia` | ✅ | Cualquiera | Alcance al token |

> **Propietario** = el email del JWT coincide con el email del usuario objetivo. **Admin** = `ROLE_ADMIN` puede modificar cualquier usuario.

---

## 7. Códigos de error comunes

| Código | Significado | Formato |
|---|---|---|
| **400** | Validación de campos, email duplicado, o **cifrado faltante** | `{ "mensaje"/"error": "...", "error": [...] }` |
| **401** | Token faltante o inválido | Respuesta por defecto de Spring Security |
| **403** | Acceso denegado (rol insuficiente / no es propietario) | `{ "error": "Acceso denegado: ...", "status": 403 }` |
| **404** | Recurso no encontrado | `{ "error": "... no fue encontrado.", "status": 404 }` |
| **500** | Error interno (credenciales inválidas, BD, OpenRouter, **fallo de descifrado**) | `{ "error/mensaje": "...", "status": 500 }` |

---

## 8. Esquema BD (solo referencia)

```sql
-- Tabla principal de usuarios
CREATE TABLE usuarios (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'ROLE_USER'
);

-- Favoritos del usuario
CREATE TABLE usuario_favoritos (
    usuario_id BIGINT NOT NULL REFERENCES usuarios(id),
    product_id TEXT NOT NULL,
    notificaciones BOOLEAN NOT NULL DEFAULT FALSE
);

-- Mensajes del chat con IA
CREATE TABLE mensajes_chat (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    contenido TEXT NOT NULL,
    es_ia BOOLEAN NOT NULL
);

-- Refresh tokens (hash almacenado)
CREATE TABLE refresh_tokens (
    id BIGSERIAL PRIMARY KEY,
    token VARCHAR(255) NOT NULL UNIQUE,
    usuario_id BIGINT NOT NULL REFERENCES usuarios(id),
    fecha_expiracion TIMESTAMP NOT NULL,
    revocado BOOLEAN NOT NULL DEFAULT FALSE
);

-- Historial de precios de productos
CREATE TABLE precio_historico (
    id BIGSERIAL PRIMARY KEY,
    product_id VARCHAR(255) NOT NULL,
    precio DOUBLE PRECISION NOT NULL,
    fecha_guardado TIMESTAMP NOT NULL
);
```
