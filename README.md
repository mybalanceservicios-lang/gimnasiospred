# Plantilla predeterminada — Gestión de Gimnasio

Sistema de gestión para gimnasios, con **dos partes separadas**:

- **`index.html`** (privado, para el dueño y profesores, con login real): socios, cuotas, clases, check-in diario, caja, planes y precios.
- **`portal.html`** (público pero personal, sin login): cada socio entra con un link propio y ve su estado de cuota y su rutina. Pensado para ofrecerse como **plus/upsell** — un gimnasio puede arrancar solo con `index.html` y sumar el portal después.

Sirve como base para ofrecer a gimnasios clientes: se clona/copia y se personaliza (nombre, logo, planes, profesores) por cliente — mismo modelo que ya se usa con `peluqueriapredeterminado` y `esteticapredeterminado`.

## Cómo probarla
Abrí `index.html` en el navegador para el sistema de gestión (pide iniciar sesión), y `portal.html?s=<token>` para ver cómo lo ve un socio (el token se copia desde Socios → "Link portal", o desde Rutinas). Socios, cuotas, clases, check-ins y rutinas se sincronizan con Supabase — ver "Backend" abajo. Gastos y cierres de caja todavía viven solo en `localStorage` de ese dispositivo.

## Backend (Supabase)
`supabase-schema.sql` tiene el SQL para crear las tablas `config`, `socios`, `pagos`, `clases`, `asistencias`, `rutinas`, `perfiles` (quién es dueño y quién es cada profesor) e `invitaciones` (códigos de acceso), más la función `obtener_portal_socio` que usa `portal.html`. Hay que:
1. Crear un proyecto en [supabase.com](https://supabase.com).
2. Pegar y ejecutar `supabase-schema.sql` en el SQL Editor del proyecto.
3. Reemplazar `SUPABASE_URL` y `SUPABASE_ANON_KEY` (la "publishable key", nunca la "secret key") al principio del script de **ambos** archivos: `index.html` y `portal.html`.
4. En Authentication → Providers → Email, dejar **activado** "Allow new users to sign up". Esto no es un descuido: cualquiera puede crear una cuenta desde la app, pero sin un código de invitación válido esa cuenta no puede hacer nada (no tiene perfil asignado, y las políticas de la base no le dan ningún permiso sin perfil).
5. El primer dueño entra a `index.html`, toca "Todavía no tengo acceso — crear cuenta", crea su mail + clave, y en la pantalla siguiente toca "¿Sos el dueño y es la primera vez que se usa este sistema? Entrar sin código" — esto solo funciona una vez, mientras el sistema no tenga ningún dueño todavía.

### El portal de socios no usa login
`portal.html` no tiene ni mail ni clave: cada socio tiene un **token** largo al azar (se genera solo al darlo de alta) que arma su link personal (`portal.html?s=xxxxx`). Ese link se comparte una vez por WhatsApp y listo — el socio lo guarda y lo vuelve a abrir cuando quiera ver su rutina o si está al día con la cuota. Las tablas `socios` y `rutinas` siguen totalmente cerradas para cualquiera sin perfil (dueño/profesor); el portal accede SOLO a través de la función `obtener_portal_socio`, que busca por token y devuelve nada más que lo que ese socio puede ver — nunca la lista completa de socios ni datos de otros.

## Login y accesos del personal (por código de invitación, sin tocar Supabase)
Nadie necesita entrar al panel de Supabase para dar de alta a un profesor — todo se hace desde adentro de `index.html`:

1. El dueño, logueado, va a Configuración → "Invitar a alguien", pone el nombre y genera un código (algo como `AB3D-EFGH`).
2. Le pasa ese código al profesor por el medio que quiera (WhatsApp, en persona, etc.).
3. El profesor entra a `index.html`, toca "Todavía no tengo acceso — crear cuenta", elige su propio mail y clave.
4. En la pantalla siguiente, pone el código que le dio el dueño. El sistema valida que el código exista y no esté usado, y le asigna automáticamente el rol que el dueño definió al crearlo (no puede elegir "ser dueño" con un código de profesor).
5. De ahí en más, ese profesor entra directo a su vista con su mail y clave, desde cualquier dispositivo.

Un código sirve una sola vez. El dueño puede ver el estado de cada código (pendiente/usado) y la lista de accesos actuales desde esa misma pantalla de Configuración.

## Qué incluye

**Dueño** — navegación en 3 secciones:
- **Check-in** — buscar un socio y registrar su entrada con un toque. Avisa si tiene la cuota vencida.
- **Clases** — horario semanal (día, horario, profesor, cupo).
- **Finanzas** — Panel (facturación del mes, socios activos/por vencer/vencidos), Socios (alta + estado de cuota + link al portal), Cuotas (cobrar y extender vencimiento, con factura AFIP opcional), Rutinas, Cierre de caja diario (registro inmutable por día con historial y exportación a CSV), Profesores, Planes y precios, Gastos y sueldos.

**Profesor** — Check-in, Clases, Rutinas (sin acceso a Finanzas ni a datos de plata).

Al cobrar una cuota, el vencimiento del socio se extiende automáticamente según la duración del plan (si ya estaba al día, se suma desde su vencimiento actual; si estaba vencido, se suma desde hoy).

Configuración (nombre, logo, clave numérica del dueño, invitar personal, accesos, respaldo JSON) accesible desde el ícono de engranaje junto al perfil.

## Facturar en AFIP/ARCA
Al cobrar una cuota se puede tildar "El socio pidió factura": arma los datos (cliente, CUIT/DNI, concepto, monto) listos para copiar, y un botón abre AFIP/ARCA (Comprobantes en línea) en una pestaña nueva. No completa la factura sola — AFIP no lo permite desde afuera — pero evita tener que anotar o tipear los datos a mano.

## Estado
Sistema con login real por mail para el personal (altas por código de invitación, sin tocar Supabase) y portal de socios sin login (por link personal con token). En condiciones de usarse con un gimnasio real siguiendo los pasos de "Backend" de arriba. Gastos y cierres de caja siguen siendo 100% locales por dispositivo por ahora.
