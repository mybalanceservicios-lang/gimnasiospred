-- Esquema para el sistema de gestión de gimnasio + portal de socios
-- Ejecutar esto en: Supabase Dashboard -> SQL Editor -> New query -> pegar todo -> Run

-- Configuración del gimnasio: una sola fila ("default"). Nombre/logo/planes/profesores
-- se sincronizan entre dispositivos del personal a través de esta tabla.
create table if not exists config (
  id text primary key default 'default',
  nombre text default 'Mi Gimnasio',
  logo text,
  planes jsonb default '[]'::jsonb,
  profesores jsonb default '[]'::jsonb,
  updated_at timestamptz default now()
);
insert into config (id) values ('default') on conflict (id) do nothing;

-- Socios: ficha del socio + estado de la cuota (vencimiento). El "token" es un código
-- largo al azar que arma el link personal a portal.html — reemplaza a tener que loguear
-- al socio: quien tiene el link, ve SU rutina y SU estado de cuota, nada más.
create table if not exists socios (
  id text primary key,
  nombre text not null,
  telefono text,
  dni text,
  fecha_alta date not null,
  plan_id text,
  vencimiento date,
  activo boolean not null default true,
  foto text,
  token text unique not null,
  notas text,
  creado_en timestamptz default now()
);

-- Pagos: historial de cuotas cobradas. Cada pago extiende el vencimiento del socio
-- (eso lo calcula el cliente al momento de cobrar, acá solo queda el registro).
create table if not exists pagos (
  id text primary key,
  socio_id text references socios(id) on delete set null,
  socio_nombre text not null,
  plan_id text,
  plan_nombre text,
  monto numeric not null,
  fecha date not null,
  hora text,
  medio_pago text default 'Efectivo',
  cobrado_por text,
  creado_en timestamptz default now()
);

-- Clases: horario semanal fijo (día de la semana + horario + profesor + cupo).
create table if not exists clases (
  id text primary key,
  nombre text not null,
  profesor text,
  dia smallint not null check (dia between 0 and 6),
  hora_inicio text not null,
  hora_fin text not null,
  cupo integer default 15
);

-- Asistencias: check-in diario de los socios (a qué hora entraron, a qué clase si aplica).
create table if not exists asistencias (
  id text primary key,
  socio_id text references socios(id) on delete set null,
  socio_nombre text not null,
  fecha date not null,
  hora text not null,
  clase_id text,
  clase_nombre text,
  registrado_por text,
  creado_en timestamptz default now()
);

-- Rutinas: UNA fila por socio (se pisa al guardar una rutina nueva). Es lo que lee
-- portal.html a través de la función obtener_portal_socio() de más abajo.
create table if not exists rutinas (
  socio_id text primary key references socios(id) on delete cascade,
  socio_nombre text,
  ejercicios jsonb default '[]'::jsonb,
  actualizado_en timestamptz default now(),
  actualizado_por text
);

-- Invitaciones: códigos de un solo uso que el dueño genera desde la app para darle
-- acceso a un profesor, sin que nadie tenga que entrar al panel de Supabase.
-- El "tipo" y "nombre" quedan fijados acá por el dueño al crear el código — quien lo
-- canjea NO puede elegir libremente ser "dueño", solo obtiene el rol que el código dice.
create table if not exists invitaciones (
  codigo text primary key,
  tipo text not null check (tipo in ('owner','barber')),
  nombre text,
  usado boolean not null default false,
  usado_por uuid references auth.users(id),
  creado_por uuid references auth.users(id),
  creado_en timestamptz default now(),
  usado_en timestamptz
);

-- Perfiles: qué es cada persona que inicia sesión (dueño, o qué profesor puntual).
-- Se crea solo canjeando un código de invitación (ver la función/trigger más abajo),
-- excepto el primerísimo dueño, que puede autoasignarse una sola vez cuando el
-- sistema todavía no tiene ningún dueño.
create table if not exists perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  tipo text not null check (tipo in ('owner','barber')),
  nombre text,
  codigo_invitacion text,
  creado_en timestamptz default now()
);

alter table config enable row level security;
alter table socios enable row level security;
alter table pagos enable row level security;
alter table clases enable row level security;
alter table asistencias enable row level security;
alter table rutinas enable row level security;
alter table invitaciones enable row level security;
alter table perfiles enable row level security;

-- Todas las tablas de operación del gimnasio son solo para quien tiene perfil asignado
-- (dueño o profesor real) — nadie autenticado-pero-sin-perfil tiene permiso real, y el
-- público anónimo no tiene NINGÚN acceso directo a estas tablas (ver más abajo el portal).
create policy "config select con perfil" on config for select using (exists (select 1 from perfiles where id = auth.uid()));
create policy "config update con perfil" on config for update using (exists (select 1 from perfiles where id = auth.uid()));

create policy "socios select con perfil" on socios for select using (exists (select 1 from perfiles where id = auth.uid()));
create policy "socios insert con perfil" on socios for insert with check (exists (select 1 from perfiles where id = auth.uid()));
create policy "socios update con perfil" on socios for update using (exists (select 1 from perfiles where id = auth.uid()));
create policy "socios delete con perfil" on socios for delete using (exists (select 1 from perfiles where id = auth.uid()));

create policy "pagos select con perfil" on pagos for select using (exists (select 1 from perfiles where id = auth.uid()));
create policy "pagos insert con perfil" on pagos for insert with check (exists (select 1 from perfiles where id = auth.uid()));

create policy "clases select con perfil" on clases for select using (exists (select 1 from perfiles where id = auth.uid()));
create policy "clases insert con perfil" on clases for insert with check (exists (select 1 from perfiles where id = auth.uid()));
create policy "clases update con perfil" on clases for update using (exists (select 1 from perfiles where id = auth.uid()));
create policy "clases delete con perfil" on clases for delete using (exists (select 1 from perfiles where id = auth.uid()));

create policy "asistencias select con perfil" on asistencias for select using (exists (select 1 from perfiles where id = auth.uid()));
create policy "asistencias insert con perfil" on asistencias for insert with check (exists (select 1 from perfiles where id = auth.uid()));

create policy "rutinas select con perfil" on rutinas for select using (exists (select 1 from perfiles where id = auth.uid()));
create policy "rutinas insert con perfil" on rutinas for insert with check (exists (select 1 from perfiles where id = auth.uid()));
create policy "rutinas update con perfil" on rutinas for update using (exists (select 1 from perfiles where id = auth.uid()));

-- perfiles: cualquiera logueado puede ver la lista (son solo mail+rol del personal, sin
-- datos sensibles). Insertar/borrar queda regulado por el trigger de abajo, no por estas
-- políticas simples de select/update.
create policy "perfiles select autenticado" on perfiles for select using (auth.role() = 'authenticated');
create policy "perfiles insert propio" on perfiles for insert with check (auth.uid() = id);
create policy "perfiles delete con perfil" on perfiles for delete using (exists (select 1 from perfiles p2 where p2.id = auth.uid()));

-- invitaciones: solo el dueño puede crear y ver invitaciones. Nadie puede editarlas o
-- borrarlas directo — el canje (marcar "usado") lo hace el trigger de abajo con permisos
-- elevados, no el usuario común, para que no se pueda "reusar" un código manipulando la fila.
create policy "invitaciones insert dueño" on invitaciones for insert
  with check (exists (select 1 from perfiles where id = auth.uid() and tipo = 'owner'));
create policy "invitaciones select dueño" on invitaciones for select
  using (exists (select 1 from perfiles where id = auth.uid() and tipo = 'owner'));

-- Función + trigger: valida y canjea el código de invitación al crear un perfil nuevo.
-- - Si es el primerísimo perfil del sistema (todavía no hay ningún dueño) y no se manda
--   código: se permite auto-asignarse "owner" (arranque inicial, una sola vez posible).
-- - Si se manda un código: tiene que existir y no estar usado; se marca usado en el mismo
--   movimiento, y el tipo/nombre del perfil se toman del código (no de lo que mande quien
--   se está registrando), para que nadie pueda "pedir" ser dueño con un código de profesor.
create or replace function validar_alta_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ya_hay_dueno boolean;
  inv record;
begin
  select exists(select 1 from perfiles where tipo = 'owner') into ya_hay_dueno;

  if new.codigo_invitacion is null then
    if ya_hay_dueno then
      raise exception 'Necesitás un código de invitación del dueño para entrar.';
    end if;
    if new.tipo <> 'owner' then
      raise exception 'El primer acceso del sistema tiene que ser el dueño.';
    end if;
    return new;
  end if;

  select * into inv from invitaciones where codigo = new.codigo_invitacion and usado = false;
  if not found then
    raise exception 'Código de invitación inválido o ya usado.';
  end if;

  update invitaciones set usado = true, usado_por = new.id, usado_en = now()
    where codigo = new.codigo_invitacion;

  new.tipo := inv.tipo;
  new.nombre := inv.nombre;
  return new;
end;
$$;

drop trigger if exists trg_validar_alta_perfil on perfiles;
create trigger trg_validar_alta_perfil
  before insert on perfiles
  for each row execute function validar_alta_perfil();

-- Portal de socios (portal.html): el socio NO se loguea — entra con un link personal
-- que lleva su "token" (ej: portal.html?s=abcd1234). Esta función es la ÚNICA puerta
-- que el público anónimo tiene a los datos del gimnasio: las tablas socios/rutinas/config
-- siguen totalmente cerradas para anon (ver políticas arriba, ninguna dice "anon" ni
-- "true"), y esta función — corriendo con permisos elevados (security definer) — hace
-- la búsqueda puntual por token y devuelve solo lo que ese socio puede ver.
create or replace function obtener_portal_socio(p_token text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  resultado json;
begin
  select json_build_object(
    'gimnasio', (select json_build_object('nombre', c.nombre, 'logo', c.logo) from config c where c.id = 'default'),
    'socio', json_build_object(
      'nombre', s.nombre,
      'vencimiento', s.vencimiento,
      'activo', s.activo
    ),
    'rutina', (
      select json_build_object('ejercicios', r.ejercicios, 'actualizado_en', r.actualizado_en)
      from rutinas r where r.socio_id = s.id
    )
  ) into resultado
  from socios s
  where s.token = p_token;

  return resultado; -- null si el token no existe
end;
$$;

grant execute on function obtener_portal_socio(text) to anon, authenticated;


-- ============================================================
-- MUY IMPORTANTE: en el dashboard de Supabase, Authentication -> Providers -> Email,
-- dejá ACTIVADO "Allow new users to sign up". Acá, a diferencia de un sistema típico,
-- eso es correcto: cualquiera puede crear una cuenta de acceso, pero sin un código de
-- invitación válido esa cuenta no puede hacer nada (no tiene perfil, y sin perfil las
-- políticas de arriba no le dan ningún permiso real sobre socios/pagos/clases/etc).
-- ============================================================
