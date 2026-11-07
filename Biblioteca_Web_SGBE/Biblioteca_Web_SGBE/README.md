# Biblioteca Escolar SG-BE — Sitio web + SQL Server

Aplicación web responsive inspirada en la referencia visual: blanco cálido, café, grandes títulos editoriales, fotografías de bibliotecas, tarjetas y panel administrativo.

## Requisitos
- SQL Server 2025 Express (o versión compatible con `CREATE OR ALTER PROCEDURE`)
- SQL Server Management Studio
- Node.js 20 o posterior y npm
- Conexión TCP/IP habilitada en SQL Server y credenciales SQL habilitadas para la aplicación

## Instalación
1. En SSMS, abre y ejecuta `database/01_base_datos.sql` en un **servidor de pruebas**. **Advertencia:** el script recrea `BibliotecaEscolar_SGBE` si ya existe; respalda los datos antes y no lo ejecutes sobre una base de producción.
2. Copia `.env.example` como `.env` y configura `DB_SERVER`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `ADMIN_USERNAME`, `ADMIN_PASSWORD` y `JWT_SECRET` (32 caracteres aleatorios como mínimo). Para SQL Server Express con instancia nombrada, habilita TCP/IP y configura un puerto fijo; el valor predeterminado es 1433.
3. Abre una terminal en la carpeta del proyecto y ejecuta `npm install` y `npm start`.
4. Abre `http://localhost:3000`.
5. Usa el botón **Acceso bibliotecario** con las credenciales definidas en `.env`.

## Funcionalidades
- Catálogo público consultado desde `vw_CatalogoPublico`, con búsqueda por título, autor e ISBN.
- Estadísticas reales de ejemplares, disponibilidad y préstamos.
- Alertas bibliográficas por edición consultadas desde `vw_IncidenciasEdicion`.
- Panel privado: préstamos, inventario, reservas y hallazgos.
- Registro de préstamo, devolución y reserva mediante los procedimientos almacenados del SQL original.
- Datos de prueba: 46 obras, 50 ediciones, 60 ejemplares, 20 préstamos y 15 prestatarios.

## Seguridad y límites
Este proyecto es un prototipo académico. El acceso del administrador se configura mediante variables de entorno, con token JWT de 4 horas. El servidor **no** implementa todavía cuentas individuales, control de permisos granular, auditoría de inicio de sesión ni despliegue seguro para internet. Para producción, integrar autenticación institucional, HTTPS, permisos de mínimo privilegio en SQL Server, CSRF/cookies seguras si se migra a sesiones y respaldo/restauración verificados. Los datos de los prestatarios solo se consultan por rutas que requieren autenticación. Las fotografías se cargan de Unsplash y las fuentes de Google Fonts, por lo que requieren conexión a internet; se usan fuentes de respaldo si no hay acceso.

## Estructura
- `server.js`: API Express y conexión SQL Server.
- `public/index.html`: interfaz.
- `public/styles.css`: diseño responsive.
- `public/app.js`: catálogo, filtros y gestión.
- `database/01_base_datos.sql`: esquema completo y datos iniciales.
- `.env.example`: configuración de ejemplo sin secretos.

## Prueba rápida
Ejecuta en SSMS:
```sql
USE BibliotecaEscolar_SGBE;
SELECT COUNT(*) AS Ejemplares FROM dbo.Ejemplar;
SELECT TOP (10) * FROM dbo.vw_CatalogoPublico;
SELECT TOP (10) * FROM dbo.vw_PrestamosActivosGestion;
```
Deberían existir 60 ejemplares si el script se ejecutó desde cero. El servidor web no ha sido probado contra una instancia SQL Server real en este entorno.
