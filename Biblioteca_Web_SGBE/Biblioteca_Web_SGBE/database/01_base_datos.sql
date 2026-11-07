/* ===========================================================================
  SISTEMA DE GESTION DE BIBLIOTECA ESCOLAR (SG-BE) - MODELO INTEGRAL
  SQL Server 2019 / 2022 / 2025 (T-SQL) | SSMS | UTF-8
  Integracion del proyecto original y los casos 1, 2 y 3.

  CONTENIDO:
  - Catalogo NORMALIZADO: Obra -> Edicion -> Ejemplar.
  - Categorias y subcategorias; prestatarios alumnos/docentes.
  - Personal/roles, prestamos y devoluciones seguros.
  - Historial de condicion, bitacora y revisiones periodicas.
  - Erratas/incidencias de edicion con estado de verificacion.
  - Reservas, vistas de consulta publica y administrativa.
  - 50 EDICIONES MUESTRALES, 46 obras, 60 ejemplares, 20 prestamos,
    15 prestatarios y datos de demostracion de los tres casos.

  EJECUCION: Abrir este archivo en SQL Server Management Studio y usar F5.
  IMPORTANTE:
  * El script CREA UNA BASE NUEVA y NO elimina ni altera la existente.
  * Si ya existe BibliotecaEscolar_SGBE, DETIENE la ejecucion.
  * Los datos bibliograficos e ISBN son FICTICIOS para pruebas, aunque
    los ISBN generados tienen formato de 13 digitos y digito verificador.
  * Los errores atribuidos a las ediciones 4 y 5 de Calculo multivariable
    son un ESCENARIO ACADEMICO PENDIENTE DE VERIFICACION.
  * NO contiene credenciales ni contrasenas: la autenticacion web se
    debe integrar en la capa de aplicacion antes de usarlo en produccion.
  * Ejecutar una sola vez en un entorno local de pruebas.
=========================================================================== */
USE master;
GO
IF DB_ID(N'BibliotecaEscolar_SGBE') IS NOT NULL
BEGIN
    PRINT N'BibliotecaEscolar_SGBE ya existe. No se sobrescribira: se omite el resto del script.';
    SET NOEXEC ON;
END
ELSE
    EXEC(N'CREATE DATABASE BibliotecaEscolar_SGBE');
GO
USE BibliotecaEscolar_SGBE;
GO

/* ========================= 1. CATALOGOS ============================== */
CREATE TABLE dbo.RolPersonal (
    IdRol INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT CK_RolPersonal_Nombre CHECK (Nombre IN (N'ADMINISTRADOR',N'BIBLIOTECARIO',N'DIRECCION'))
);
GO
CREATE TABLE dbo.Personal (
    IdPersonal INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(120) NOT NULL,
    Usuario NVARCHAR(60) NOT NULL UNIQUE,
    Correo NVARCHAR(120) NULL,
    IdRol INT NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Personal_Activo DEFAULT (1),
    CONSTRAINT FK_Personal_Rol FOREIGN KEY (IdRol) REFERENCES dbo.RolPersonal(IdRol)
);
GO
CREATE TABLE dbo.Prestatario (
    IdPrestatario INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Matricula NVARCHAR(20) NOT NULL UNIQUE,
    Nombre NVARCHAR(120) NOT NULL,
    Tipo NVARCHAR(10) NOT NULL,
    Correo NVARCHAR(120) NULL,
    Grupo NVARCHAR(40) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Prestatario_Activo DEFAULT (1),
    CONSTRAINT CK_Prestatario_Tipo CHECK (Tipo IN (N'ALUMNO',N'DOCENTE'))
);
GO
CREATE TABLE dbo.Categoria (
    IdCategoria INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(80) NOT NULL UNIQUE,
    IdCategoriaPadre INT NULL,
    Activa BIT NOT NULL CONSTRAINT DF_Categoria_Activa DEFAULT (1),
    CONSTRAINT FK_Categoria_Padre FOREIGN KEY(IdCategoriaPadre) REFERENCES dbo.Categoria(IdCategoria),
    CONSTRAINT CK_Categoria_NoCircularDirecta CHECK (IdCategoriaPadre IS NULL OR IdCategoriaPadre <> IdCategoria)
);
GO
CREATE TABLE dbo.Obra (
    IdObra INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Titulo NVARCHAR(200) NOT NULL,
    Autor NVARCHAR(160) NOT NULL,
    Descripcion NVARCHAR(400) NULL,
    Activa BIT NOT NULL CONSTRAINT DF_Obra_Activa DEFAULT(1),
    CONSTRAINT CK_Obra_Titulo CHECK(LEN(LTRIM(RTRIM(Titulo))) > 0)
);
GO
CREATE TABLE dbo.ObraCategoria (
    IdObra INT NOT NULL,
    IdCategoria INT NOT NULL,
    CONSTRAINT PK_ObraCategoria PRIMARY KEY(IdObra, IdCategoria),
    CONSTRAINT FK_ObraCategoria_Obra FOREIGN KEY(IdObra) REFERENCES dbo.Obra(IdObra),
    CONSTRAINT FK_ObraCategoria_Categoria FOREIGN KEY(IdCategoria) REFERENCES dbo.Categoria(IdCategoria)
);
GO
CREATE TABLE dbo.Edicion (
    IdEdicion INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IdObra INT NOT NULL,
    NumeroEdicion INT NOT NULL,
    Editorial NVARCHAR(120) NOT NULL,
    AnioPublicacion SMALLINT NOT NULL,
    ISBN VARCHAR(20) NULL,
    Idioma NVARCHAR(40) NOT NULL CONSTRAINT DF_Edicion_Idioma DEFAULT(N'Espanol'),
    Activa BIT NOT NULL CONSTRAINT DF_Edicion_Activa DEFAULT(1),
    CONSTRAINT FK_Edicion_Obra FOREIGN KEY(IdObra) REFERENCES dbo.Obra(IdObra),
    CONSTRAINT CK_Edicion_Numero CHECK(NumeroEdicion > 0),
    CONSTRAINT CK_Edicion_Anio CHECK(AnioPublicacion BETWEEN 1450 AND 2100),
    CONSTRAINT UQ_Edicion_Obra_Num_Editorial UNIQUE(IdObra, NumeroEdicion, Editorial)
);
GO
CREATE UNIQUE INDEX UX_Edicion_ISBN ON dbo.Edicion(ISBN) WHERE ISBN IS NOT NULL;
GO
CREATE TABLE dbo.Ejemplar (
    IdEjemplar INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CodigoInterno AS (N'BIB-' + RIGHT(N'0000000000' + CONVERT(NVARCHAR(10), IdEjemplar),10)) PERSISTED,
    IdEdicion INT NOT NULL,
    Ubicacion NVARCHAR(80) NOT NULL,
    Condicion NVARCHAR(10) NOT NULL CONSTRAINT DF_Ejemplar_Condicion DEFAULT(N'BUENO'),
    Estado NVARCHAR(15) NOT NULL CONSTRAINT DF_Ejemplar_Estado DEFAULT(N'DISPONIBLE'),
    FechaAlta DATE NOT NULL CONSTRAINT DF_Ejemplar_FechaAlta DEFAULT(CONVERT(DATE,SYSDATETIME())),
    Origen NVARCHAR(80) NULL,
    Observaciones NVARCHAR(400) NULL,
    CONSTRAINT FK_Ejemplar_Edicion FOREIGN KEY(IdEdicion) REFERENCES dbo.Edicion(IdEdicion),
    CONSTRAINT CK_Ejemplar_Condicion CHECK(Condicion IN(N'BUENO',N'REGULAR',N'DANADO')),
    CONSTRAINT CK_Ejemplar_Estado CHECK(Estado IN
      (N'DISPONIBLE',N'PRESTADO',N'EN_REVISION',N'DANADO',N'EXTRAVIADO',N'RETIRADO'))
);
GO
CREATE UNIQUE INDEX UX_Ejemplar_Codigo ON dbo.Ejemplar(CodigoInterno);
CREATE INDEX IX_Ejemplar_Edicion_Estado ON dbo.Ejemplar(IdEdicion, Estado);
GO
CREATE TABLE dbo.ConfiguracionPrestamo (
    IdConfiguracion TINYINT NOT NULL PRIMARY KEY,
    DiasPrestamo INT NOT NULL,
    MaxPrestamosAbiertos INT NOT NULL,
    MaxReservasActivas INT NOT NULL,
    MaxRenovaciones INT NOT NULL,
    BloquearSiHayAtraso BIT NOT NULL,
    CONSTRAINT CK_Config_Fila CHECK(IdConfiguracion=1),
    CONSTRAINT CK_Config_Limites CHECK(DiasPrestamo>0 AND MaxPrestamosAbiertos>0 AND
      MaxReservasActivas>0 AND MaxRenovaciones>=0)
);
GO

/* ========================= 2. CIRCULACION ============================= */
CREATE TABLE dbo.Prestamo (
    IdPrestamo INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IdEjemplar INT NOT NULL,
    IdPrestatario INT NOT NULL,
    IdPersonalSalida INT NOT NULL,
    FechaPrestamo DATETIME2(0) NOT NULL CONSTRAINT DF_Prestamo_Fecha DEFAULT(SYSDATETIME()),
    FechaLimite DATETIME2(0) NOT NULL,
    FechaDevolucion DATETIME2(0) NULL,
    Estado NVARCHAR(10) NOT NULL CONSTRAINT DF_Prestamo_Estado DEFAULT(N'ABIERTO'),
    CondicionSalida NVARCHAR(10) NOT NULL,
    CondicionDevolucion NVARCHAR(10) NULL,
    IdPersonalRecepcion INT NULL,
    Observaciones NVARCHAR(500) NULL,
    Renovaciones INT NOT NULL CONSTRAINT DF_Prestamo_Renovaciones DEFAULT(0),
    CONSTRAINT FK_Prestamo_Ejemplar FOREIGN KEY(IdEjemplar) REFERENCES dbo.Ejemplar(IdEjemplar),
    CONSTRAINT FK_Prestamo_Prestatario FOREIGN KEY(IdPrestatario) REFERENCES dbo.Prestatario(IdPrestatario),
    CONSTRAINT FK_Prestamo_PersonalSalida FOREIGN KEY(IdPersonalSalida) REFERENCES dbo.Personal(IdPersonal),
    CONSTRAINT FK_Prestamo_PersonalRecepcion FOREIGN KEY(IdPersonalRecepcion) REFERENCES dbo.Personal(IdPersonal),
    CONSTRAINT CK_Prestamo_Estado CHECK(Estado IN(N'ABIERTO',N'DEVUELTO',N'PERDIDO',N'CANCELADO')),
    CONSTRAINT CK_Prestamo_Fechas CHECK(FechaLimite>FechaPrestamo AND
      (FechaDevolucion IS NULL OR FechaDevolucion>=FechaPrestamo)),
    CONSTRAINT CK_Prestamo_Cierre CHECK(
      (Estado=N'DEVUELTO' AND FechaDevolucion IS NOT NULL AND IdPersonalRecepcion IS NOT NULL)
      OR (Estado IN(N'ABIERTO',N'PERDIDO',N'CANCELADO') AND FechaDevolucion IS NULL)),
    CONSTRAINT CK_Prestamo_Condiciones CHECK(
      CondicionSalida IN(N'BUENO',N'REGULAR',N'DANADO') AND
      (CondicionDevolucion IS NULL OR CondicionDevolucion IN(N'BUENO',N'REGULAR',N'DANADO'))),
    CONSTRAINT CK_Prestamo_Renovaciones CHECK(Renovaciones>=0)
);
GO
-- Previene DOS PRESTAMOS ABIERTOS del mismo ejemplar, aunque haya concurrencia.
CREATE UNIQUE INDEX UX_Prestamo_Ejemplar_Abierto ON dbo.Prestamo(IdEjemplar)
    WHERE Estado=N'ABIERTO';
CREATE INDEX IX_Prestamo_Prestatario_Estado ON dbo.Prestamo(IdPrestatario,Estado);
CREATE INDEX IX_Prestamo_FechaLimite ON dbo.Prestamo(FechaLimite) INCLUDE(Estado);
GO
CREATE TABLE dbo.Reserva (
    IdReserva INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IdPrestatario INT NOT NULL,
    IdEdicion INT NOT NULL,
    FechaSolicitud DATETIME2(0) NOT NULL CONSTRAINT DF_Reserva_Fecha DEFAULT(SYSDATETIME()),
    Estado NVARCHAR(12) NOT NULL CONSTRAINT DF_Reserva_Estado DEFAULT(N'EN_ESPERA'),
    FechaNotificacion DATETIME2(0) NULL,
    FechaAtencion DATETIME2(0) NULL,
    Observaciones NVARCHAR(300) NULL,
    CONSTRAINT FK_Reserva_Prestatario FOREIGN KEY(IdPrestatario) REFERENCES dbo.Prestatario(IdPrestatario),
    CONSTRAINT FK_Reserva_Edicion FOREIGN KEY(IdEdicion) REFERENCES dbo.Edicion(IdEdicion),
    CONSTRAINT CK_Reserva_Estado CHECK(Estado IN(N'EN_ESPERA',N'NOTIFICADA',N'ATENDIDA',N'CANCELADA',N'VENCIDA'))
);
GO
CREATE INDEX IX_Reserva_Edicion_Estado_Fecha ON dbo.Reserva(IdEdicion,Estado,FechaSolicitud);
CREATE INDEX IX_Reserva_Prestatario_Estado ON dbo.Reserva(IdPrestatario,Estado);
GO

/* =================== 3. REVISION, ERRATAS Y AUDITORIA ================= */
CREATE TABLE dbo.RevisionInventario (
    IdRevision INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    FechaInicio DATETIME2(0) NOT NULL CONSTRAINT DF_Revision_Fecha DEFAULT(SYSDATETIME()),
    FechaCierre DATETIME2(0) NULL,
    IdResponsable INT NOT NULL,
    Estado NVARCHAR(10) NOT NULL CONSTRAINT DF_Revision_Estado DEFAULT(N'ABIERTA'),
    Descripcion NVARCHAR(250) NOT NULL,
    CONSTRAINT FK_Revision_Responsable FOREIGN KEY(IdResponsable) REFERENCES dbo.Personal(IdPersonal),
    CONSTRAINT CK_Revision_Estado CHECK(Estado IN(N'ABIERTA',N'CERRADA')),
    CONSTRAINT CK_Revision_Cierre CHECK(
      (Estado=N'ABIERTA' AND FechaCierre IS NULL)
      OR (Estado=N'CERRADA' AND FechaCierre IS NOT NULL AND FechaCierre>=FechaInicio))
);
GO
CREATE TABLE dbo.RevisionDetalle (
    IdRevision INT NOT NULL,
    IdEjemplar INT NOT NULL,
    FechaRegistro DATETIME2(0) NOT NULL CONSTRAINT DF_RevisionDetalle_Fecha DEFAULT(SYSDATETIME()),
    Hallazgo NVARCHAR(15) NOT NULL,
    Observaciones NVARCHAR(500) NULL,
    Validado BIT NOT NULL CONSTRAINT DF_RevisionDetalle_Validado DEFAULT(0),
    IdPersonalValida INT NULL,
    FechaValidacion DATETIME2(0) NULL,
    CONSTRAINT PK_RevisionDetalle PRIMARY KEY(IdRevision,IdEjemplar),
    CONSTRAINT FK_RevisionDetalle_Revision FOREIGN KEY(IdRevision) REFERENCES dbo.RevisionInventario(IdRevision),
    CONSTRAINT FK_RevisionDetalle_Ejemplar FOREIGN KEY(IdEjemplar) REFERENCES dbo.Ejemplar(IdEjemplar),
    CONSTRAINT FK_RevisionDetalle_Validador FOREIGN KEY(IdPersonalValida) REFERENCES dbo.Personal(IdPersonal),
    CONSTRAINT CK_RevisionDetalle_Hallazgo CHECK(Hallazgo IN(N'BUENO',N'DANADO',N'NO_LOCALIZADO')),
    CONSTRAINT CK_RevisionDetalle_Validacion CHECK(
      (Validado=0 AND IdPersonalValida IS NULL AND FechaValidacion IS NULL)
      OR (Validado=1 AND IdPersonalValida IS NOT NULL AND FechaValidacion IS NOT NULL))
);
GO
CREATE TABLE dbo.IncidenciaEdicion (
    IdIncidencia INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IdEdicion INT NOT NULL,
    Capitulo NVARCHAR(30) NOT NULL,
    Descripcion NVARCHAR(600) NOT NULL,
    Gravedad NVARCHAR(10) NOT NULL CONSTRAINT DF_Incidencia_Gravedad DEFAULT(N'MEDIA'),
    EstadoVerificacion NVARCHAR(12) NOT NULL CONSTRAINT DF_Incidencia_Estado DEFAULT(N'PENDIENTE'),
    FuenteVerificacion NVARCHAR(250) NULL,
    FechaRegistro DATE NOT NULL CONSTRAINT DF_Incidencia_Fecha DEFAULT(CONVERT(DATE,SYSDATETIME())),
    CONSTRAINT FK_Incidencia_Edicion FOREIGN KEY(IdEdicion) REFERENCES dbo.Edicion(IdEdicion),
    CONSTRAINT CK_Incidencia_Gravedad CHECK(Gravedad IN(N'BAJA',N'MEDIA',N'ALTA')),
    CONSTRAINT CK_Incidencia_Estado CHECK(EstadoVerificacion IN(N'PENDIENTE',N'CONFIRMADA',N'DESCARTADA'))
);
GO
CREATE TABLE dbo.HistorialEjemplar (
    IdHistorial BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IdEjemplar INT NOT NULL,
    IdPrestamo INT NULL,
    IdPersonal INT NULL,
    FechaEvento DATETIME2(0) NOT NULL CONSTRAINT DF_Historial_Fecha DEFAULT(SYSDATETIME()),
    TipoEvento NVARCHAR(35) NOT NULL,
    EstadoAnterior NVARCHAR(15) NULL,
    EstadoNuevo NVARCHAR(15) NULL,
    CondicionAnterior NVARCHAR(10) NULL,
    CondicionNueva NVARCHAR(10) NULL,
    Observaciones NVARCHAR(500) NULL,
    CONSTRAINT FK_Historial_Ejemplar FOREIGN KEY(IdEjemplar) REFERENCES dbo.Ejemplar(IdEjemplar),
    CONSTRAINT FK_Historial_Prestamo FOREIGN KEY(IdPrestamo) REFERENCES dbo.Prestamo(IdPrestamo),
    CONSTRAINT FK_Historial_Personal FOREIGN KEY(IdPersonal) REFERENCES dbo.Personal(IdPersonal)
);
GO
CREATE INDEX IX_Historial_Ejemplar_Fecha ON dbo.HistorialEjemplar(IdEjemplar,FechaEvento DESC);
GO
CREATE TABLE dbo.Bitacora (
    IdBitacora BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    IdPersonal INT NULL,
    FechaEvento DATETIME2(0) NOT NULL CONSTRAINT DF_Bitacora_Fecha DEFAULT(SYSDATETIME()),
    Accion NVARCHAR(70) NOT NULL,
    Entidad NVARCHAR(50) NOT NULL,
    IdRegistro INT NULL,
    Detalle NVARCHAR(600) NULL,
    CONSTRAINT FK_Bitacora_Personal FOREIGN KEY(IdPersonal) REFERENCES dbo.Personal(IdPersonal)
);
GO
CREATE INDEX IX_Bitacora_Fecha ON dbo.Bitacora(FechaEvento DESC);
GO

/* ========================= 4. DATOS MUESTRALES ======================== */
INSERT INTO dbo.RolPersonal(Nombre) VALUES
 (N'ADMINISTRADOR'),(N'BIBLIOTECARIO'),(N'DIRECCION');
INSERT INTO dbo.Personal(Nombre,Usuario,Correo,IdRol) VALUES
 (N'Administrador Biblioteca',N'admin_demo',N'admin@escuela.example',1),
 (N'Bibliotecario Turno Matutino',N'gestor_manana',N'gestor1@escuela.example',2),
 (N'Bibliotecario Turno Vespertino',N'gestor_tarde',N'gestor2@escuela.example',2),
 (N'Coordinacion Academica',N'direccion_demo',N'direccion@escuela.example',3);
INSERT INTO dbo.ConfiguracionPrestamo(IdConfiguracion,DiasPrestamo,MaxPrestamosAbiertos,MaxReservasActivas,MaxRenovaciones,BloquearSiHayAtraso)
VALUES(1,14,3,3,1,1);
INSERT INTO dbo.Prestatario(Matricula,Nombre,Tipo,Correo,Grupo) VALUES
 (N'A2023001',N'Ana Lopez Ruiz',N'ALUMNO',N'ana.lopez@uni.example',N'TSU-201'),
 (N'A2023002',N'Bruno Mendez Soto',N'ALUMNO',N'bruno.mendez@uni.example',N'TSU-201'),
 (N'A2023003',N'Carla Ortiz Vega',N'ALUMNO',N'carla.ortiz@uni.example',N'TSU-201'),
 (N'A2023004',N'Diego Ramirez Paz',N'ALUMNO',N'diego.ramirez@uni.example',N'TSU-202'),
 (N'A2023005',N'Elena Torres Gil',N'ALUMNO',N'elena.torres@uni.example',N'TSU-202'),
 (N'A2023006',N'Fernando Cruz Rios',N'ALUMNO',N'fernando.cruz@uni.example',N'TSU-202'),
 (N'A2023007',N'Gabriela Nava Luna',N'ALUMNO',N'gabriela.nava@uni.example',N'TSU-203'),
 (N'A2023008',N'Hector Salas Mora',N'ALUMNO',N'hector.salas@uni.example',N'TSU-203'),
 (N'A2023009',N'Isabel Fuentes Rey',N'ALUMNO',N'isabel.fuentes@uni.example',N'TSU-203'),
 (N'A2023010',N'Jorge Aguilar Paz',N'ALUMNO',N'jorge.aguilar@uni.example',N'TSU-204'),
 (N'A2023011',N'Karla Ibarra Sol',N'ALUMNO',N'karla.ibarra@uni.example',N'TSU-204'),
 (N'A2023012',N'Luis Herrera Cano',N'ALUMNO',N'luis.herrera@uni.example',N'TSU-204'),
 (N'D1001',N'Dra. Marta Delgado',N'DOCENTE',N'marta.delgado@uni.example',NULL),
 (N'D1002',N'Mtro. Raul Campos',N'DOCENTE',N'raul.campos@uni.example',NULL),
 (N'A2023013',N'Nora Pena Lara',N'ALUMNO',N'nora.pena@uni.example',N'TSU-205');
GO
INSERT INTO dbo.Categoria(Nombre,IdCategoriaPadre) VALUES
 (N'Ciencias exactas',NULL),
 (N'Matematicas',1),
 (N'Fisica',1),
 (N'Quimica',1),
 (N'Computacion',NULL),
 (N'Ingenieria',NULL),
 (N'Economico-administrativas',NULL),
 (N'Literatura',NULL),
 (N'Divulgacion cientifica',NULL),
 (N'Ciencias de la salud',NULL),
 (N'Ciencias sociales y humanidades',NULL),
 (N'Biologia',10);
GO

/* 46 obras distintas: IDs explicitos para tener datos de prueba reproducibles. */
SET IDENTITY_INSERT dbo.Obra ON;
INSERT INTO dbo.Obra(IdObra,Titulo,Autor) VALUES
 (1,N'Cálculo multivariable', N'J. Stewart'),
 (2,N'Álgebra lineal y sus aplicaciones', N'D. Lay'),
 (3,N'Álgebra lineal', N'S. Grossman'),
 (4,N'Ecuaciones diferenciales', N'D. Zill'),
 (5,N'Física universitaria Vol. 1', N'Sears y Zemansky'),
 (6,N'Física universitaria Vol. 2', N'Sears y Zemansky'),
 (7,N'Química', N'R. Chang'),
 (8,N'Probabilidad y estadística para ingeniería', N'R. Walpole'),
 (9,N'Métodos numéricos para ingenieros', N'S. Chapra'),
 (10,N'Matemáticas discretas', N'K. Rosen'),
 (11,N'Introducción a los algoritmos', N'T. Cormen'),
 (12,N'Fundamentos de bases de datos', N'A. Silberschatz'),
 (13,N'Sistemas operativos modernos', N'A. Tanenbaum'),
 (14,N'Redes de computadoras', N'A. Tanenbaum'),
 (15,N'Ingeniería de software', N'I. Sommerville'),
 (16,N'Ingeniería del software: un enfoque práctico', N'R. Pressman'),
 (17,N'Código limpio', N'R. C. Martin'),
 (18,N'El programador pragmático', N'D. Thomas'),
 (19,N'Patrones de diseño', N'E. Gamma'),
 (20,N'Estructuras de datos en Java', N'M. A. Weiss'),
 (21,N'Automatiza tareas aburridas con Python', N'A. Sweigart'),
 (22,N'Economía', N'P. Samuelson'),
 (23,N'Contabilidad financiera', N'G. Guajardo'),
 (24,N'Administración', N'S. Robbins'),
 (25,N'Fundamentos de marketing', N'P. Kotler'),
 (26,N'Cien años de soledad', N'G. García Márquez'),
 (27,N'Pedro Páramo', N'J. Rulfo'),
 (28,N'El laberinto de la soledad', N'O. Paz'),
 (29,N'Don Quijote de la Mancha', N'M. de Cervantes'),
 (30,N'La sombra del viento', N'C. Ruiz Zafón'),
 (31,N'Sapiens', N'Y. N. Harari'),
 (32,N'Breve historia del tiempo', N'S. Hawking'),
 (33,N'Cosmos', N'C. Sagan'),
 (34,N'El origen de las especies', N'C. Darwin'),
 (35,N'Biología', N'N. Campbell'),
 (36,N'Anatomía humana', N'M. Latarjet'),
 (37,N'Principios de anatomía y fisiología', N'G. Tortora'),
 (38,N'Psicología', N'D. Myers'),
 (39,N'Metodología de la investigación', N'R. Hernández Sampieri'),
 (40,N'Introducción al estudio del derecho', N'E. García Máynez'),
 (41,N'Historia mínima de México', N'D. Cosío Villegas'),
 (42,N'Dibujo técnico con gráficas de ingeniería', N'F. Giesecke'),
 (43,N'Termodinámica', N'Y. Cengel'),
 (44,N'Mecánica vectorial para ingenieros: Estática', N'F. Beer'),
 (45,N'Circuitos eléctricos', N'J. Nilsson'),
 (46,N'Inteligencia artificial: un enfoque moderno', N'S. Russell');
SET IDENTITY_INSERT dbo.Obra OFF;
GO

/* 50 ediciones: IDs explicitos; ISBN validos solo en estructura. */
SET IDENTITY_INSERT dbo.Edicion ON;
INSERT INTO dbo.Edicion(IdEdicion,IdObra,NumeroEdicion,Editorial,AnioPublicacion,ISBN,Idioma) VALUES
 (1,1,3,N'Cengage',2012,'9790000000018',N'Espanol'),
 (2,1,4,N'Cengage',2016,'9790000000025',N'Espanol'),
 (3,1,5,N'Cengage',2019,'9790000000032',N'Espanol'),
 (4,1,6,N'Cengage',2022,'9790000000049',N'Espanol'),
 (5,1,7,N'Cengage',2025,'9790000000056',N'Espanol'),
 (6,2,5,N'Pearson',2016,'9790000000063',N'Espanol'),
 (7,3,7,N'McGraw-Hill',2012,'9790000000070',N'Espanol'),
 (8,4,10,N'Cengage',2018,'9790000000087',N'Espanol'),
 (9,5,14,N'Pearson',2018,'9790000000094',N'Espanol'),
 (10,6,14,N'Pearson',2018,'9790000000100',N'Espanol'),
 (11,7,12,N'McGraw-Hill',2017,'9790000000117',N'Espanol'),
 (12,8,9,N'Pearson',2012,'9790000000124',N'Espanol'),
 (13,9,7,N'McGraw-Hill',2015,'9790000000131',N'Espanol'),
 (14,10,7,N'McGraw-Hill',2012,'9790000000148',N'Espanol'),
 (15,11,3,N'MIT Press',2009,'9790000000155',N'Espanol'),
 (16,12,6,N'McGraw-Hill',2014,'9790000000162',N'Espanol'),
 (17,13,4,N'Pearson',2015,'9790000000179',N'Espanol'),
 (18,14,5,N'Pearson',2012,'9790000000186',N'Espanol'),
 (19,15,10,N'Pearson',2016,'9790000000193',N'Espanol'),
 (20,16,9,N'McGraw-Hill',2021,'9790000000209',N'Espanol'),
 (21,17,1,N'Anaya',2012,'9790000000216',N'Espanol'),
 (22,18,2,N'Addison-Wesley',2019,'9790000000223',N'Espanol'),
 (23,19,1,N'Addison-Wesley',1994,'9790000000230',N'Espanol'),
 (24,20,4,N'Pearson',2013,'9790000000247',N'Espanol'),
 (25,21,2,N'No Starch',2019,'9790000000254',N'Espanol'),
 (26,22,19,N'McGraw-Hill',2010,'9790000000261',N'Espanol'),
 (27,23,7,N'McGraw-Hill',2018,'9790000000278',N'Espanol'),
 (28,24,13,N'Pearson',2018,'9790000000285',N'Espanol'),
 (29,25,17,N'Pearson',2018,'9790000000292',N'Espanol'),
 (30,26,1,N'Diana',1967,'9790000000308',N'Espanol'),
 (31,27,1,N'RM',1955,'9790000000315',N'Espanol'),
 (32,28,3,N'FCE',1981,'9790000000322',N'Espanol'),
 (33,29,1,N'RAE',2015,'9790000000339',N'Espanol'),
 (34,30,1,N'Planeta',2001,'9790000000346',N'Espanol'),
 (35,31,1,N'Debate',2014,'9790000000353',N'Espanol'),
 (36,32,1,N'Crítica',1988,'9790000000360',N'Espanol'),
 (37,33,1,N'Planeta',1980,'9790000000377',N'Espanol'),
 (38,34,1,N'Austral',2009,'9790000000384',N'Espanol'),
 (39,35,12,N'Pearson',2021,'9790000000391',N'Espanol'),
 (40,36,5,N'Panamericana',2019,'9790000000407',N'Espanol'),
 (41,37,15,N'Panamericana',2018,'9790000000414',N'Espanol'),
 (42,38,11,N'Panamericana',2016,'9790000000421',N'Espanol'),
 (43,39,6,N'McGraw-Hill',2014,'9790000000438',N'Espanol'),
 (44,40,65,N'Porrúa',2013,'9790000000445',N'Espanol'),
 (45,41,1,N'Colmex',1973,'9790000000452',N'Espanol'),
 (46,42,14,N'Pearson',2012,'9790000000469',N'Espanol'),
 (47,43,8,N'McGraw-Hill',2015,'9790000000476',N'Espanol'),
 (48,44,11,N'McGraw-Hill',2017,'9790000000483',N'Espanol'),
 (49,45,10,N'Pearson',2015,'9790000000490',N'Espanol'),
 (50,46,3,N'Pearson',2010,'9790000000506',N'Espanol');
SET IDENTITY_INSERT dbo.Edicion OFF;
GO

/* Clasificacion en obras: permite varias categorias sin duplicar libros. */
INSERT INTO dbo.ObraCategoria(IdObra,IdCategoria) VALUES
 (1,2),
 (2,2),
 (3,2),
 (4,2),
 (5,3),
 (6,3),
 (7,4),
 (8,2),
 (9,2),
 (9,6),
 (10,2),
 (10,5),
 (11,5),
 (12,5),
 (13,5),
 (14,5),
 (15,5),
 (16,5),
 (17,5),
 (18,5),
 (19,5),
 (20,5),
 (21,5),
 (22,7),
 (23,7),
 (24,7),
 (25,7),
 (26,8),
 (27,8),
 (28,11),
 (29,8),
 (30,8),
 (31,9),
 (32,9),
 (33,9),
 (34,9),
 (34,12),
 (35,12),
 (36,10),
 (37,10),
 (38,11),
 (39,11),
 (40,11),
 (41,11),
 (42,6),
 (43,3),
 (43,6),
 (44,6),
 (45,6),
 (46,5);
GO

/* Una copia por edicion (ejemplares 1-50). */
SET IDENTITY_INSERT dbo.Ejemplar ON;
INSERT INTO dbo.Ejemplar(IdEjemplar,IdEdicion,Ubicacion,Condicion,Estado,FechaAlta,Origen)
SELECT ed.IdEdicion,ed.IdEdicion,
       N'EST-' + RIGHT(N'00'+CONVERT(NVARCHAR(3),((ed.IdEdicion-1)/10)+1),2)
                + N'-N' + CONVERT(NVARCHAR(3),((ed.IdEdicion-1)%10)+1),
       CASE WHEN ed.IdEdicion IN(21,30,40) THEN N'DANADO' ELSE N'BUENO' END,
       CASE WHEN ed.IdEdicion IN(4,5,6,8,13,16,19,35) THEN N'PRESTADO'
            WHEN ed.IdEdicion IN(21,30,40) THEN N'DANADO'
            WHEN ed.IdEdicion IN(33,47) THEN N'EXTRAVIADO'
            ELSE N'DISPONIBLE' END,
       '2026-09-01',N'Carga academica de prueba'
FROM dbo.Edicion ed
ORDER BY ed.IdEdicion;
GO
/* Diez ejemplares adicionales de Calculo multivariable, ediciones 3-7. */
INSERT INTO dbo.Ejemplar(IdEjemplar,IdEdicion,Ubicacion,Condicion,Estado,FechaAlta,Origen) VALUES
 (51,1,N'EST-01-C1',N'BUENO',N'DISPONIBLE','2026-09-01',N'Carga academica de prueba'),
 (52,1,N'EST-01-C2',N'BUENO',N'DISPONIBLE','2026-09-01',N'Carga academica de prueba'),
 (53,2,N'EST-01-C3',N'BUENO',N'DISPONIBLE','2026-09-01',N'Carga academica de prueba'),
 (54,2,N'EST-01-C4',N'BUENO',N'DISPONIBLE','2026-09-01',N'Carga academica de prueba'),
 (55,3,N'EST-01-C5',N'BUENO',N'DISPONIBLE','2026-09-01',N'Carga academica de prueba'),
 (56,3,N'EST-01-C6',N'BUENO',N'DISPONIBLE','2026-09-01',N'Carga academica de prueba'),
 (57,4,N'EST-01-C7',N'BUENO',N'PRESTADO','2026-09-01',N'Carga academica de prueba'),
 (58,4,N'EST-01-C8',N'BUENO',N'PRESTADO','2026-09-01',N'Carga academica de prueba'),
 (59,5,N'EST-01-C9',N'BUENO',N'PRESTADO','2026-09-01',N'Carga academica de prueba'),
 (60,5,N'EST-01-C10',N'BUENO',N'PRESTADO','2026-09-01',N'Carga academica de prueba');
SET IDENTITY_INSERT dbo.Ejemplar OFF;
GO

/* 20 prestamos: 12 abiertos, 7 devueltos, 1 perdido. */
SET IDENTITY_INSERT dbo.Prestamo ON;
INSERT INTO dbo.Prestamo(IdPrestamo,IdEjemplar,IdPrestatario,IdPersonalSalida,FechaPrestamo,FechaLimite,FechaDevolucion,Estado,CondicionSalida,CondicionDevolucion,IdPersonalRecepcion,Observaciones) VALUES
 (1,4,1,2,'2026-10-26T09:00:00','2026-11-09T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (2,5,2,2,'2026-10-28T09:00:00','2026-11-11T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (3,57,3,2,'2026-10-29T09:00:00','2026-11-12T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (4,59,4,2,'2026-11-02T09:00:00','2026-11-16T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (5,60,5,2,'2026-11-03T09:00:00','2026-11-17T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (6,8,6,2,'2026-10-15T09:00:00','2026-10-29T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (7,13,7,2,'2026-10-20T09:00:00','2026-11-03T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (8,16,8,2,'2026-11-01T09:00:00','2026-11-15T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (9,19,9,2,'2026-11-04T09:00:00','2026-11-18T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (10,35,10,2,'2026-10-10T09:00:00','2026-10-24T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (11,6,1,2,'2026-11-02T09:00:00','2026-11-16T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (12,58,11,2,'2026-11-05T09:00:00','2026-11-19T23:59:59',NULL,N'ABIERTO',N'BUENO',NULL,NULL,N'Prestamo de demostracion'),
 (13,2,3,2,'2026-09-01T09:00:00','2026-09-15T23:59:59','2026-09-14T14:00:00',N'DEVUELTO',N'BUENO',N'BUENO',3,N'Prestamo historico de demostracion'),
 (14,3,5,2,'2026-09-03T09:00:00','2026-09-17T23:59:59','2026-09-20T14:00:00',N'DEVUELTO',N'BUENO',N'BUENO',3,N'Prestamo historico de demostracion'),
 (15,9,12,2,'2026-09-10T09:00:00','2026-09-24T23:59:59','2026-09-22T14:00:00',N'DEVUELTO',N'BUENO',N'BUENO',3,N'Prestamo historico de demostracion'),
 (16,30,13,2,'2026-08-20T09:00:00','2026-09-03T23:59:59','2026-09-02T14:00:00',N'DEVUELTO',N'BUENO',N'DANADO',3,N'Prestamo historico de demostracion'),
 (17,15,14,2,'2026-09-15T09:00:00','2026-09-29T23:59:59','2026-09-28T14:00:00',N'DEVUELTO',N'BUENO',N'BUENO',3,N'Prestamo historico de demostracion'),
 (18,4,2,2,'2026-09-20T09:00:00','2026-10-04T23:59:59','2026-10-03T14:00:00',N'DEVUELTO',N'BUENO',N'BUENO',3,N'Prestamo historico de demostracion'),
 (19,33,15,2,'2026-08-01T09:00:00','2026-08-15T23:59:59',NULL,N'PERDIDO',N'BUENO',NULL,NULL,N'Prestamo historico de demostracion'),
 (20,50,6,2,'2026-10-01T09:00:00','2026-10-15T23:59:59','2026-10-10T14:00:00',N'DEVUELTO',N'BUENO',N'BUENO',3,N'Prestamo historico de demostracion');
SET IDENTITY_INSERT dbo.Prestamo OFF;
GO

/* Revision de muestra: los hallazgos no alteran estados hasta validacion humana. */
INSERT INTO dbo.RevisionInventario(FechaInicio,IdResponsable,Estado,Descripcion)
VALUES('2026-11-02T08:00:00',2,N'ABIERTA',N'Inventario preventivo de ejemplares');
INSERT INTO dbo.RevisionDetalle(IdRevision,IdEjemplar,Hallazgo,Observaciones) VALUES
 (1,21,N'DANADO',N'Lomo desprendido'),
 (1,30,N'DANADO',N'Paginas mojadas'),
 (1,33,N'NO_LOCALIZADO',N'Pendiente comprobar historial y prestamo reportado como perdido'),
 (1,40,N'DANADO',N'Portada rota'),
 (1,47,N'NO_LOCALIZADO',N'Pendiente de investigacion'),
 (1,1,N'BUENO',NULL),(1,2,N'BUENO',NULL),(1,3,N'BUENO',NULL);
GO
/* Datos del caso de estudio: incidencias NO CONFIRMADAS de ediciones 4 y 5. */
INSERT INTO dbo.IncidenciaEdicion(IdEdicion,Capitulo,Descripcion,Gravedad,EstadoVerificacion,FechaRegistro) VALUES
 (2,N'3',N'Posible error reportado en un ejemplo del capitulo 3. Requiere cotejo con el ejemplar fisico y el docente.',N'ALTA',N'PENDIENTE','2026-10-20'),
 (3,N'3',N'Posible error reportado en un ejemplo del capitulo 3. Requiere cotejo con el ejemplar fisico y el docente.',N'ALTA',N'PENDIENTE','2026-10-20');
GO
INSERT INTO dbo.Reserva(IdPrestatario,IdEdicion,FechaSolicitud,Estado) VALUES
 (7,5,'2026-11-04T09:00:00',N'EN_ESPERA'),
 (12,4,'2026-11-05T09:00:00',N'EN_ESPERA'),
 (15,5,'2026-11-05T10:00:00',N'EN_ESPERA');
GO
INSERT INTO dbo.HistorialEjemplar(IdEjemplar,IdPersonal,TipoEvento,EstadoAnterior,EstadoNuevo,CondicionAnterior,CondicionNueva,Observaciones)
SELECT IdEjemplar,1,N'CARGA_MUESTRAL',NULL,Estado,NULL,Condicion,
       N'Estado de inicio de la base DEMO; no equivale a una inspeccion validada.'
FROM dbo.Ejemplar;
GO
INSERT INTO dbo.Bitacora(IdPersonal,Accion,Entidad,Detalle)
VALUES (1,N'CARGA_INICIAL',N'BASE_DE_DATOS',
 N'Se insertaron 50 ediciones, 60 ejemplares y datos relacionados para la demostracion.');
GO

/* ========================= 5. VISTAS DE CONSULTA ====================== */
-- Datos generales de catalogo sin exponer identidad de prestatarios.
CREATE VIEW dbo.vw_CatalogoPublico
AS
SELECT ed.IdEdicion, ob.IdObra, ob.Titulo, ob.Autor, ed.NumeroEdicion,
       ed.Editorial, ed.AnioPublicacion, ed.ISBN, ed.Idioma,
       COUNT(ej.IdEjemplar) AS TotalEjemplares,
       SUM(CASE WHEN ej.Estado=N'DISPONIBLE' THEN 1 ELSE 0 END) AS Disponibles,
       SUM(CASE WHEN ej.Estado=N'PRESTADO' THEN 1 ELSE 0 END) AS Prestados,
       SUM(CASE WHEN ej.Estado IN(N'DANADO',N'EN_REVISION') THEN 1 ELSE 0 END) AS NoAptosPorDanio,
       SUM(CASE WHEN ej.Estado=N'EXTRAVIADO' THEN 1 ELSE 0 END) AS Extraviados,
       (SELECT COUNT(*) FROM dbo.Reserva r
          WHERE r.IdEdicion=ed.IdEdicion AND r.Estado=N'EN_ESPERA') AS ReservasEnEspera,
       (SELECT COUNT(*) FROM dbo.IncidenciaEdicion ie
          WHERE ie.IdEdicion=ed.IdEdicion AND ie.EstadoVerificacion<>N'DESCARTADA') AS IncidenciasReportadas
FROM dbo.Edicion ed
JOIN dbo.Obra ob ON ob.IdObra=ed.IdObra
LEFT JOIN dbo.Ejemplar ej ON ej.IdEdicion=ed.IdEdicion
WHERE ed.Activa=1 AND ob.Activa=1
GROUP BY ed.IdEdicion, ob.IdObra, ob.Titulo, ob.Autor,
         ed.NumeroEdicion, ed.Editorial, ed.AnioPublicacion, ed.ISBN, ed.Idioma;
GO
CREATE VIEW dbo.vw_ObrasCategorias
AS
SELECT ob.IdObra, ob.Titulo, cat.IdCategoria, cat.Nombre AS Categoria,
       sup.Nombre AS CategoriaSuperior
FROM dbo.Obra ob
JOIN dbo.ObraCategoria oc ON oc.IdObra=ob.IdObra
JOIN dbo.Categoria cat ON cat.IdCategoria=oc.IdCategoria
LEFT JOIN dbo.Categoria sup ON sup.IdCategoria=cat.IdCategoriaPadre;
GO
-- SOLO para bibliotecarios autorizados: incluye datos personales.
CREATE VIEW dbo.vw_PrestamosActivosGestion
AS
SELECT p.IdPrestamo, pr.Matricula, pr.Nombre AS Prestatario, pr.Tipo,
       ej.CodigoInterno, ob.Titulo, ed.NumeroEdicion, p.FechaPrestamo,
       p.FechaLimite, DATEDIFF(DAY,CONVERT(DATE,p.FechaLimite),CONVERT(DATE,SYSDATETIME())) AS DiasDesdeVencimiento,
       CASE WHEN p.FechaLimite<SYSDATETIME() THEN N'VENCIDO'
            WHEN p.FechaLimite<DATEADD(DAY,2,SYSDATETIME()) THEN N'POR_VENCER'
            ELSE N'VIGENTE' END AS Situacion
FROM dbo.Prestamo p
JOIN dbo.Prestatario pr ON pr.IdPrestatario=p.IdPrestatario
JOIN dbo.Ejemplar ej ON ej.IdEjemplar=p.IdEjemplar
JOIN dbo.Edicion ed ON ed.IdEdicion=ej.IdEdicion
JOIN dbo.Obra ob ON ob.IdObra=ed.IdObra
WHERE p.Estado=N'ABIERTO';
GO
CREATE VIEW dbo.vw_IncidenciasEdicion
AS
SELECT ie.IdIncidencia, ob.Titulo, ed.NumeroEdicion, ed.AnioPublicacion,
       ie.Capitulo, ie.Descripcion, ie.Gravedad,
       ie.EstadoVerificacion, ie.FuenteVerificacion, ie.FechaRegistro
FROM dbo.IncidenciaEdicion ie
JOIN dbo.Edicion ed ON ed.IdEdicion=ie.IdEdicion
JOIN dbo.Obra ob ON ob.IdObra=ed.IdObra;
GO
-- La posicion de lista de espera respeta el momento de solicitud.
CREATE VIEW dbo.vw_ListaEsperaGestion
AS
SELECT r.IdReserva, pr.Matricula, pr.Nombre AS Prestatario,
       ob.Titulo, ed.NumeroEdicion, r.FechaSolicitud, r.Estado,
       ROW_NUMBER() OVER(PARTITION BY r.IdEdicion
                       ORDER BY r.FechaSolicitud,r.IdReserva) AS PosicionEspera
FROM dbo.Reserva r
JOIN dbo.Prestatario pr ON pr.IdPrestatario=r.IdPrestatario
JOIN dbo.Edicion ed ON ed.IdEdicion=r.IdEdicion
JOIN dbo.Obra ob ON ob.IdObra=ed.IdObra
WHERE r.Estado IN(N'EN_ESPERA',N'NOTIFICADA');
GO
CREATE VIEW dbo.vw_HallazgosInventario
AS
SELECT rv.IdRevision, rv.FechaInicio, rv.Estado AS EstadoRevision,
       rd.IdEjemplar, ej.CodigoInterno, ob.Titulo, ed.NumeroEdicion,
       rd.Hallazgo, rd.Observaciones, rd.Validado, rd.FechaValidacion,
       ej.Estado AS EstadoActualEjemplar
FROM dbo.RevisionDetalle rd
JOIN dbo.RevisionInventario rv ON rv.IdRevision=rd.IdRevision
JOIN dbo.Ejemplar ej ON ej.IdEjemplar=rd.IdEjemplar
JOIN dbo.Edicion ed ON ed.IdEdicion=ej.IdEdicion
JOIN dbo.Obra ob ON ob.IdObra=ed.IdObra;
GO
CREATE VIEW dbo.vw_ResumenInventario
AS
SELECT Estado, COUNT(*) AS Cantidad
FROM dbo.Ejemplar
GROUP BY Estado;
GO

/* ======================== 6. PROCEDIMIENTOS =========================== */
-- Registrar un prestamo de forma atomica y proteger contra doble asignacion.
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPrestamo
    @IdPrestatario INT,
    @IdEjemplar INT,
    @IdPersonal INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Estado NVARCHAR(15), @Condicion NVARCHAR(10), @IdEdicion INT,
            @Ahora DATETIME2(0)=SYSDATETIME(), @Limite DATETIME2(0),
            @Dias INT,@MaxAbiertos INT,@Bloquear BIT, @IdNuevo INT;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Personal per JOIN dbo.RolPersonal ro ON ro.IdRol=per.IdRol
            WHERE per.IdPersonal=@IdPersonal AND per.Activo=1
              AND ro.Nombre IN(N'ADMINISTRADOR',N'BIBLIOTECARIO'))
            THROW 51001,N'El operador no esta autorizado.',1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Prestatario WITH(UPDLOCK,HOLDLOCK)
                       WHERE IdPrestatario=@IdPrestatario AND Activo=1)
            THROW 51002,N'El prestatario no existe o esta inactivo.',1;
        SELECT @Estado=ej.Estado,@Condicion=ej.Condicion,@IdEdicion=ej.IdEdicion
        FROM dbo.Ejemplar ej WITH(UPDLOCK,HOLDLOCK)
        WHERE ej.IdEjemplar=@IdEjemplar;
        IF @Estado IS NULL THROW 51003,N'El ejemplar no existe.',1;
        IF @Estado<>N'DISPONIBLE' THROW 51004,N'El ejemplar no esta disponible.',1;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Edicion ed JOIN dbo.Obra ob ON ob.IdObra=ed.IdObra
            WHERE ed.IdEdicion=@IdEdicion AND ed.Activa=1 AND ob.Activa=1)
            THROW 51005,N'La obra o edicion se encuentra inactiva.',1;
        SELECT @Dias=DiasPrestamo,@MaxAbiertos=MaxPrestamosAbiertos,
               @Bloquear=BloquearSiHayAtraso
        FROM dbo.ConfiguracionPrestamo WHERE IdConfiguracion=1;
        IF (SELECT COUNT(*) FROM dbo.Prestamo WITH(UPDLOCK,HOLDLOCK)
            WHERE IdPrestatario=@IdPrestatario AND Estado=N'ABIERTO')>=@MaxAbiertos
            THROW 51006,N'El prestatario alcanzo el numero maximo de prestamos.',1;
        IF @Bloquear=1 AND EXISTS(
            SELECT 1 FROM dbo.Prestamo
            WHERE IdPrestatario=@IdPrestatario AND Estado=N'ABIERTO' AND FechaLimite<@Ahora)
            THROW 51007,N'El prestatario tiene prestamos vencidos.',1;
        IF EXISTS(
            SELECT 1 FROM dbo.Reserva WITH(UPDLOCK,HOLDLOCK)
            WHERE IdEdicion=@IdEdicion AND Estado=N'NOTIFICADA'
                  AND IdPrestatario<>@IdPrestatario)
            THROW 51008,N'La edicion se encuentra comprometida para otra reserva notificada.',1;
        SET @Limite=DATEADD(DAY,@Dias,@Ahora);
        INSERT INTO dbo.Prestamo
          (IdEjemplar,IdPrestatario,IdPersonalSalida,FechaPrestamo,FechaLimite,Estado,CondicionSalida)
        VALUES(@IdEjemplar,@IdPrestatario,@IdPersonal,@Ahora,@Limite,N'ABIERTO',@Condicion);
        SET @IdNuevo=CONVERT(INT,SCOPE_IDENTITY());
        UPDATE dbo.Ejemplar SET Estado=N'PRESTADO' WHERE IdEjemplar=@IdEjemplar;
        INSERT INTO dbo.HistorialEjemplar
          (IdEjemplar,IdPrestamo,IdPersonal,FechaEvento,TipoEvento,
           EstadoAnterior,EstadoNuevo,CondicionAnterior,CondicionNueva,Observaciones)
        VALUES(@IdEjemplar,@IdNuevo,@IdPersonal,@Ahora,N'PRESTAMO',
               N'DISPONIBLE',N'PRESTADO',@Condicion,@Condicion,N'Salida registrada por el sistema');
        ;WITH PrimeraReserva AS (
           SELECT TOP(1) IdReserva,Estado,FechaAtencion
           FROM dbo.Reserva WITH(UPDLOCK,HOLDLOCK)
           WHERE IdPrestatario=@IdPrestatario AND IdEdicion=@IdEdicion
             AND Estado IN(N'EN_ESPERA',N'NOTIFICADA')
           ORDER BY FechaSolicitud,IdReserva
        )
        UPDATE PrimeraReserva SET Estado=N'ATENDIDA',FechaAtencion=@Ahora;
        INSERT INTO dbo.Bitacora(IdPersonal,FechaEvento,Accion,Entidad,IdRegistro,Detalle)
        VALUES(@IdPersonal,@Ahora,N'REGISTRAR_PRESTAMO',N'Prestamo',@IdNuevo,N'Alta atomica de prestamo y cambio a PRESTADO');
        COMMIT TRANSACTION;
        SELECT IdPrestamo,IdEjemplar,IdPrestatario,FechaPrestamo,FechaLimite,Estado
        FROM dbo.Prestamo WHERE IdPrestamo=@IdNuevo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
-- Registrar devolucion; un libro danado pasa a EN_REVISION.
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarDevolucion
    @IdPrestamo INT,
    @IdPersonal INT,
    @CondicionDevolucion NVARCHAR(10),
    @Observaciones NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @IdEjemplar INT,@EstadoPrestamo NVARCHAR(10),
            @CondicionAntes NVARCHAR(10),@EstadoAntes NVARCHAR(15),
            @Ahora DATETIME2(0)=SYSDATETIME(),@EstadoDespues NVARCHAR(15);
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Personal per JOIN dbo.RolPersonal r ON r.IdRol=per.IdRol
            WHERE per.IdPersonal=@IdPersonal AND per.Activo=1
              AND r.Nombre IN(N'ADMINISTRADOR',N'BIBLIOTECARIO'))
            THROW 51011,N'El operador no esta autorizado.',1;
        IF @CondicionDevolucion NOT IN(N'BUENO',N'REGULAR',N'DANADO')
           OR @CondicionDevolucion IS NULL
            THROW 51012,N'Condicion de devolucion no valida.',1;
        IF @CondicionDevolucion=N'DANADO' AND NULLIF(LTRIM(RTRIM(@Observaciones)),N'') IS NULL
            THROW 51013,N'Una devolucion danada requiere observaciones.',1;
        SELECT @IdEjemplar=IdEjemplar,@EstadoPrestamo=Estado
        FROM dbo.Prestamo WITH(UPDLOCK,HOLDLOCK)
        WHERE IdPrestamo=@IdPrestamo;
        IF @IdEjemplar IS NULL THROW 51014,N'El prestamo no existe.',1;
        IF @EstadoPrestamo<>N'ABIERTO' THROW 51015,N'El prestamo ya fue cerrado o no admite devolucion.',1;
        SELECT @CondicionAntes=Condicion,@EstadoAntes=Estado
        FROM dbo.Ejemplar WITH(UPDLOCK,HOLDLOCK) WHERE IdEjemplar=@IdEjemplar;
        IF @EstadoAntes<>N'PRESTADO' THROW 51016,N'Inconsistencia: el ejemplar no figura como PRESTADO.',1;
        SET @EstadoDespues=CASE WHEN @CondicionDevolucion=N'DANADO'
                               THEN N'EN_REVISION' ELSE N'DISPONIBLE' END;
        UPDATE dbo.Prestamo
           SET FechaDevolucion=@Ahora,Estado=N'DEVUELTO',
               CondicionDevolucion=@CondicionDevolucion,
               IdPersonalRecepcion=@IdPersonal,Observaciones=@Observaciones
         WHERE IdPrestamo=@IdPrestamo;
        UPDATE dbo.Ejemplar SET Estado=@EstadoDespues,Condicion=@CondicionDevolucion
        WHERE IdEjemplar=@IdEjemplar;
        INSERT INTO dbo.HistorialEjemplar
          (IdEjemplar,IdPrestamo,IdPersonal,FechaEvento,TipoEvento,
           EstadoAnterior,EstadoNuevo,CondicionAnterior,CondicionNueva,Observaciones)
        VALUES(@IdEjemplar,@IdPrestamo,@IdPersonal,@Ahora,N'DEVOLUCION',
               @EstadoAntes,@EstadoDespues,@CondicionAntes,@CondicionDevolucion,@Observaciones);
        INSERT INTO dbo.Bitacora(IdPersonal,FechaEvento,Accion,Entidad,IdRegistro,Detalle)
        VALUES(@IdPersonal,@Ahora,N'REGISTRAR_DEVOLUCION',N'Prestamo',@IdPrestamo,
               N'Devolucion registrada; ejemplar ahora '+@EstadoDespues);
        COMMIT TRANSACTION;
        SELECT IdPrestamo,FechaDevolucion,Estado,CondicionDevolucion FROM dbo.Prestamo
        WHERE IdPrestamo=@IdPrestamo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
-- Agregar a la lista de espera de una edicion especifica.
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarReserva
    @IdPrestatario INT,
    @IdEdicion INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Max INT,@Nueva INT;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM dbo.Prestatario WITH(UPDLOCK,HOLDLOCK)
                      WHERE IdPrestatario=@IdPrestatario AND Activo=1)
            THROW 51021,N'Prestatario inactivo o inexistente.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.Edicion WHERE IdEdicion=@IdEdicion AND Activa=1)
            THROW 51022,N'Edicion inactiva o inexistente.',1;
        IF EXISTS(SELECT 1 FROM dbo.Reserva WITH(UPDLOCK,HOLDLOCK)
                   WHERE IdPrestatario=@IdPrestatario AND IdEdicion=@IdEdicion
                     AND Estado IN(N'EN_ESPERA',N'NOTIFICADA'))
            THROW 51023,N'Ya hay una reserva activa de esa edicion para el prestatario.',1;
        SELECT @Max=MaxReservasActivas FROM dbo.ConfiguracionPrestamo WHERE IdConfiguracion=1;
        IF (SELECT COUNT(*) FROM dbo.Reserva WITH(UPDLOCK,HOLDLOCK)
            WHERE IdPrestatario=@IdPrestatario AND Estado IN(N'EN_ESPERA',N'NOTIFICADA'))>=@Max
            THROW 51024,N'El prestatario alcanzo el limite de reservas.',1;
        IF EXISTS(SELECT 1 FROM dbo.Ejemplar WHERE IdEdicion=@IdEdicion AND Estado=N'DISPONIBLE')
            THROW 51025,N'Hay copias disponibles: procede con el prestamo en vez de reservar.',1;
        INSERT INTO dbo.Reserva(IdPrestatario,IdEdicion) VALUES(@IdPrestatario,@IdEdicion);
        SET @Nueva=CONVERT(INT,SCOPE_IDENTITY());
        COMMIT TRANSACTION;
        SELECT IdReserva,IdPrestatario,IdEdicion,FechaSolicitud,Estado
        FROM dbo.Reserva WHERE IdReserva=@Nueva;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
-- Registrar un hallazgo en una revision abierta, SIN afectar al prestamo.
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarHallazgo
    @IdRevision INT,
    @IdEjemplar INT,
    @Hallazgo NVARCHAR(15),
    @Observaciones NVARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Hallazgo NOT IN(N'BUENO',N'DANADO',N'NO_LOCALIZADO') OR @Hallazgo IS NULL
        THROW 51031,N'Tipo de hallazgo no valido.',1;
    IF @Hallazgo<>N'BUENO' AND NULLIF(LTRIM(RTRIM(@Observaciones)),N'') IS NULL
        THROW 51032,N'La incidencia requiere observaciones.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM dbo.RevisionInventario WITH(UPDLOCK,HOLDLOCK)
                      WHERE IdRevision=@IdRevision AND Estado=N'ABIERTA')
            THROW 51033,N'La revision no existe o ya esta cerrada.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.Ejemplar WHERE IdEjemplar=@IdEjemplar)
            THROW 51034,N'El ejemplar no existe.',1;
        IF EXISTS(SELECT 1 FROM dbo.RevisionDetalle WITH(UPDLOCK,HOLDLOCK)
                  WHERE IdRevision=@IdRevision AND IdEjemplar=@IdEjemplar)
        BEGIN
            IF EXISTS(SELECT 1 FROM dbo.RevisionDetalle WHERE IdRevision=@IdRevision
                      AND IdEjemplar=@IdEjemplar AND Validado=1)
                THROW 51035,N'No se puede modificar un hallazgo ya validado.',1;
            UPDATE dbo.RevisionDetalle SET Hallazgo=@Hallazgo,
                   Observaciones=@Observaciones,FechaRegistro=SYSDATETIME()
            WHERE IdRevision=@IdRevision AND IdEjemplar=@IdEjemplar;
        END
        ELSE
            INSERT INTO dbo.RevisionDetalle(IdRevision,IdEjemplar,Hallazgo,Observaciones)
            VALUES(@IdRevision,@IdEjemplar,@Hallazgo,@Observaciones);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
-- Resolver el hallazgo tras revisar el ejemplar y el prestamo.
-- Una simple ausencia NO se convierte automaticamente en extravio.
CREATE OR ALTER PROCEDURE dbo.usp_ResolverHallazgo
    @IdRevision INT,
    @IdEjemplar INT,
    @IdPersonal INT,
    @Decision NVARCHAR(20)  -- SIN_CAMBIOS, CONFIRMAR_DANO, CONFIRMAR_EXTRAVIO
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Hallazgo NVARCHAR(15), @EstadoAntes NVARCHAR(15),
            @CondAntes NVARCHAR(10), @EstadoNuevo NVARCHAR(15),
            @CondNueva NVARCHAR(10), @Ahora DATETIME2(0)=SYSDATETIME();
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM dbo.Personal per JOIN dbo.RolPersonal r ON r.IdRol=per.IdRol
                      WHERE per.IdPersonal=@IdPersonal AND per.Activo=1
                      AND r.Nombre IN(N'ADMINISTRADOR',N'BIBLIOTECARIO'))
            THROW 51041,N'Operador no autorizado.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.RevisionInventario WITH(UPDLOCK,HOLDLOCK)
                      WHERE IdRevision=@IdRevision AND Estado=N'ABIERTA')
            THROW 51042,N'La revision no esta abierta.',1;
        SELECT @Hallazgo=Hallazgo FROM dbo.RevisionDetalle WITH(UPDLOCK,HOLDLOCK)
        WHERE IdRevision=@IdRevision AND IdEjemplar=@IdEjemplar AND Validado=0;
        IF @Hallazgo IS NULL THROW 51043,N'El hallazgo no existe o ya se valido.',1;
        IF @Decision NOT IN(N'SIN_CAMBIOS',N'CONFIRMAR_DANO',N'CONFIRMAR_EXTRAVIO')
           OR @Decision IS NULL THROW 51044,N'Decision no valida.',1;
        IF (@Decision=N'CONFIRMAR_DANO' AND @Hallazgo<>N'DANADO')
           OR (@Decision=N'CONFIRMAR_EXTRAVIO' AND @Hallazgo<>N'NO_LOCALIZADO')
            THROW 51045,N'La decision no concuerda con el hallazgo.',1;
        SELECT @EstadoAntes=Estado,@CondAntes=Condicion
        FROM dbo.Ejemplar WITH(UPDLOCK,HOLDLOCK) WHERE IdEjemplar=@IdEjemplar;
        SET @EstadoNuevo=@EstadoAntes;
        SET @CondNueva=@CondAntes;
        IF @Decision<>N'SIN_CAMBIOS'
        BEGIN
            IF EXISTS(SELECT 1 FROM dbo.Prestamo WHERE IdEjemplar=@IdEjemplar AND Estado=N'ABIERTO')
                THROW 51046,N'El ejemplar tiene prestamo abierto: investigar antes de confirmar.',1;
            IF @EstadoAntes NOT IN(N'DISPONIBLE',N'EN_REVISION',N'DANADO',N'EXTRAVIADO')
                THROW 51047,N'Estado incompatible con la confirmacion.',1;
            IF @Decision=N'CONFIRMAR_DANO'
            BEGIN
                IF @EstadoAntes=N'EXTRAVIADO' THROW 51048,N'No se puede confirmar dano de ejemplar extraviado.',1;
                SET @EstadoNuevo=N'EN_REVISION'; SET @CondNueva=N'DANADO';
            END
            IF @Decision=N'CONFIRMAR_EXTRAVIO'
                SET @EstadoNuevo=N'EXTRAVIADO';
            UPDATE dbo.Ejemplar SET Estado=@EstadoNuevo,Condicion=@CondNueva
            WHERE IdEjemplar=@IdEjemplar;
            INSERT INTO dbo.HistorialEjemplar
              (IdEjemplar,IdPersonal,FechaEvento,TipoEvento,EstadoAnterior,EstadoNuevo,
               CondicionAnterior,CondicionNueva,Observaciones)
            VALUES(@IdEjemplar,@IdPersonal,@Ahora,N'REVISION_CONFIRMADA',@EstadoAntes,@EstadoNuevo,
                   @CondAntes,@CondNueva,N'Confirmacion humana del hallazgo en revision');
        END
        UPDATE dbo.RevisionDetalle
        SET Validado=1,IdPersonalValida=@IdPersonal,FechaValidacion=@Ahora
        WHERE IdRevision=@IdRevision AND IdEjemplar=@IdEjemplar;
        INSERT INTO dbo.Bitacora(IdPersonal,FechaEvento,Accion,Entidad,IdRegistro,Detalle)
        VALUES(@IdPersonal,@Ahora,N'VALIDAR_HALLAZGO',N'RevisionDetalle',@IdEjemplar,
               N'Revision '+CONVERT(NVARCHAR(20),@IdRevision)+N'; decision='+@Decision);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ======================= 6B. OPERACIONES EXTRA ======================= */
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarEjemplar
    @IdEdicion INT,
    @Ubicacion NVARCHAR(80),
    @IdPersonal INT,
    @Condicion NVARCHAR(10)=N'BUENO'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @IdNuevo INT, @EstadoNuevo NVARCHAR(15),@Ahora DATETIME2(0)=SYSDATETIME();
    BEGIN TRY
      BEGIN TRANSACTION;
      IF NOT EXISTS(SELECT 1 FROM dbo.Personal per JOIN dbo.RolPersonal r ON r.IdRol=per.IdRol
         WHERE per.IdPersonal=@IdPersonal AND per.Activo=1
           AND r.Nombre IN(N'ADMINISTRADOR',N'BIBLIOTECARIO'))
          THROW 51051,N'Operador no autorizado.',1;
      IF NOT EXISTS(SELECT 1 FROM dbo.Edicion e JOIN dbo.Obra o ON o.IdObra=e.IdObra
         WHERE e.IdEdicion=@IdEdicion AND e.Activa=1 AND o.Activa=1)
          THROW 51052,N'Edicion u obra inactiva o inexistente.',1;
      IF @Condicion NOT IN(N'BUENO',N'REGULAR',N'DANADO') OR @Condicion IS NULL
          THROW 51053,N'Condicion invalida.',1;
      IF NULLIF(LTRIM(RTRIM(@Ubicacion)),N'') IS NULL
          THROW 51054,N'Ubicacion obligatoria.',1;
      SET @EstadoNuevo=CASE WHEN @Condicion=N'DANADO' THEN N'EN_REVISION' ELSE N'DISPONIBLE' END;
      INSERT INTO dbo.Ejemplar(IdEdicion,Ubicacion,Condicion,Estado)
      VALUES(@IdEdicion,@Ubicacion,@Condicion,@EstadoNuevo);
      SET @IdNuevo=CONVERT(INT,SCOPE_IDENTITY());
      INSERT INTO dbo.HistorialEjemplar(IdEjemplar,IdPersonal,FechaEvento,TipoEvento,
         EstadoNuevo,CondicionNueva,Observaciones)
      VALUES(@IdNuevo,@IdPersonal,@Ahora,N'ALTA',@EstadoNuevo,@Condicion,N'Nuevo ejemplar fisico registrado');
      INSERT INTO dbo.Bitacora(IdPersonal,FechaEvento,Accion,Entidad,IdRegistro,Detalle)
      VALUES(@IdPersonal,@Ahora,N'ALTA_EJEMPLAR',N'Ejemplar',@IdNuevo,N'Alta con identificador automatico');
      COMMIT TRANSACTION;
      SELECT IdEjemplar,CodigoInterno,IdEdicion,Estado,Condicion FROM dbo.Ejemplar WHERE IdEjemplar=@IdNuevo;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
      THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_RenovarPrestamo
    @IdPrestamo INT,
    @IdPersonal INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @IdEdicion INT,@Estado NVARCHAR(10),@Renovaciones INT,
            @MaxRenovaciones INT,@FechaLimite DATETIME2(0),@Dias INT;
    BEGIN TRY
      BEGIN TRANSACTION;
      IF NOT EXISTS(SELECT 1 FROM dbo.Personal p JOIN dbo.RolPersonal r ON r.IdRol=p.IdRol
        WHERE p.IdPersonal=@IdPersonal AND p.Activo=1
          AND r.Nombre IN(N'ADMINISTRADOR',N'BIBLIOTECARIO'))
          THROW 51061,N'Operador no autorizado.',1;
      SELECT @Estado=p.Estado,@Renovaciones=p.Renovaciones,
             @FechaLimite=p.FechaLimite,@IdEdicion=ej.IdEdicion
      FROM dbo.Prestamo p WITH(UPDLOCK,HOLDLOCK)
      JOIN dbo.Ejemplar ej ON ej.IdEjemplar=p.IdEjemplar
      WHERE p.IdPrestamo=@IdPrestamo;
      IF @Estado IS NULL OR @Estado<>N'ABIERTO'
          THROW 51062,N'Prestamo inexistente o no renovable.',1;
      IF @FechaLimite<SYSDATETIME()
          THROW 51063,N'Prestamo vencido: requiere autorizacion de excepcion.',1;
      SELECT @MaxRenovaciones=MaxRenovaciones,@Dias=DiasPrestamo
      FROM dbo.ConfiguracionPrestamo WHERE IdConfiguracion=1;
      IF @Renovaciones>=@MaxRenovaciones
          THROW 51064,N'Limite de renovaciones alcanzado.',1;
      IF EXISTS(SELECT 1 FROM dbo.Reserva WHERE IdEdicion=@IdEdicion
                AND Estado IN(N'EN_ESPERA',N'NOTIFICADA'))
          THROW 51065,N'No se permite renovar: la edicion tiene reservas pendientes.',1;
      UPDATE dbo.Prestamo
      SET FechaLimite=DATEADD(DAY,@Dias,FechaLimite),Renovaciones=Renovaciones+1
      WHERE IdPrestamo=@IdPrestamo;
      INSERT INTO dbo.Bitacora(IdPersonal,Accion,Entidad,IdRegistro,Detalle)
      VALUES(@IdPersonal,N'RENOVAR_PRESTAMO',N'Prestamo',@IdPrestamo,
             N'Fecha limite original: '+CONVERT(NVARCHAR(19),@FechaLimite,120));
      COMMIT TRANSACTION;
      SELECT IdPrestamo,FechaLimite,Renovaciones FROM dbo.Prestamo WHERE IdPrestamo=@IdPrestamo;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
      THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CerrarRevision
    @IdRevision INT,
    @IdPersonal INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
      BEGIN TRANSACTION;
      IF NOT EXISTS(SELECT 1 FROM dbo.Personal p JOIN dbo.RolPersonal r ON r.IdRol=p.IdRol
        WHERE p.IdPersonal=@IdPersonal AND p.Activo=1
          AND r.Nombre IN(N'ADMINISTRADOR',N'BIBLIOTECARIO'))
          THROW 51071,N'Operador no autorizado.',1;
      IF NOT EXISTS(SELECT 1 FROM dbo.RevisionInventario WITH(UPDLOCK,HOLDLOCK)
                    WHERE IdRevision=@IdRevision AND Estado=N'ABIERTA')
          THROW 51072,N'Revision no existe o ya esta cerrada.',1;
      IF EXISTS(SELECT 1 FROM dbo.RevisionDetalle WHERE IdRevision=@IdRevision AND Validado=0)
          THROW 51073,N'Existen hallazgos sin validar; no se puede cerrar.',1;
      UPDATE dbo.RevisionInventario SET Estado=N'CERRADA',FechaCierre=SYSDATETIME()
      WHERE IdRevision=@IdRevision;
      INSERT INTO dbo.Bitacora(IdPersonal,Accion,Entidad,IdRegistro,Detalle)
      VALUES(@IdPersonal,N'CERRAR_REVISION',N'RevisionInventario',@IdRevision,N'Jornada de inventario validada y cerrada');
      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
      THROW;
    END CATCH
END;
GO
/* ======================== 7. ACCESO POR ROLES SQL ===================== */
-- Roles SQL para asignar a inicios de sesion reales despues de crearlos.
-- La aplicacion debe autenticar y autorizar en la capa web/backend.
CREATE ROLE rol_consulta_catalogo;
CREATE ROLE rol_gestion_biblioteca;
GO
GRANT SELECT ON dbo.vw_CatalogoPublico TO rol_consulta_catalogo;
GRANT SELECT ON dbo.vw_ObrasCategorias TO rol_consulta_catalogo;
GRANT SELECT ON dbo.vw_IncidenciasEdicion TO rol_consulta_catalogo;
GRANT SELECT ON dbo.vw_CatalogoPublico TO rol_gestion_biblioteca;
GRANT SELECT ON dbo.vw_ObrasCategorias TO rol_gestion_biblioteca;
GRANT SELECT ON dbo.vw_PrestamosActivosGestion TO rol_gestion_biblioteca;
GRANT SELECT ON dbo.vw_IncidenciasEdicion TO rol_gestion_biblioteca;
GRANT SELECT ON dbo.vw_ListaEsperaGestion TO rol_gestion_biblioteca;
GRANT SELECT ON dbo.vw_HallazgosInventario TO rol_gestion_biblioteca;
GRANT SELECT ON dbo.vw_ResumenInventario TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_RegistrarPrestamo TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_RegistrarDevolucion TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_RegistrarReserva TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_RegistrarHallazgo TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_ResolverHallazgo TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_RegistrarEjemplar TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_RenovarPrestamo TO rol_gestion_biblioteca;
GRANT EXECUTE ON dbo.usp_CerrarRevision TO rol_gestion_biblioteca;
GO

/* ======================== 8. PRUEBAS DE LECTURA ======================== */
-- Resultados esperados tras la carga: 46 obras, 50 ediciones,
-- 60 ejemplares, 20 prestamos (12 ABIERTOS, 7 DEVUELTOS, 1 PERDIDO).
SELECT N'Obras' AS Entidad,COUNT(*) AS Registros FROM dbo.Obra
UNION ALL SELECT N'Ediciones',COUNT(*) FROM dbo.Edicion
UNION ALL SELECT N'Ejemplares',COUNT(*) FROM dbo.Ejemplar
UNION ALL SELECT N'Prestatarios',COUNT(*) FROM dbo.Prestatario
UNION ALL SELECT N'Prestamos',COUNT(*) FROM dbo.Prestamo
UNION ALL SELECT N'Categorias',COUNT(*) FROM dbo.Categoria
UNION ALL SELECT N'Reservas',COUNT(*) FROM dbo.Reserva;
SELECT * FROM dbo.vw_ResumenInventario ORDER BY Estado;
SELECT * FROM dbo.vw_CatalogoPublico WHERE Titulo=N'Cálculo multivariable' ORDER BY NumeroEdicion;
SELECT * FROM dbo.vw_PrestamosActivosGestion ORDER BY FechaLimite;
SELECT * FROM dbo.vw_IncidenciasEdicion ORDER BY NumeroEdicion;
SELECT * FROM dbo.vw_ListaEsperaGestion ORDER BY Titulo,NumeroEdicion,PosicionEspera;
SELECT * FROM dbo.vw_HallazgosInventario ORDER BY IdRevision,IdEjemplar;
GO
/* ====================== 9. PRUEBAS OPCIONALES ==========================
   Estas llamadas MODIFICAN los datos; se dejan comentadas.

   -- Prestar un ejemplar disponible a un alumno sin atrasos:
   -- EXEC dbo.usp_RegistrarPrestamo @IdPrestatario=15,@IdEjemplar=1,@IdPersonal=2;

   -- Devolver un prestamo abierto con condicion buena:
   -- EXEC dbo.usp_RegistrarDevolucion @IdPrestamo=1,@IdPersonal=2,
   --      @CondicionDevolucion=N'BUENO';

   -- Devolver con dano (debe requerir observaciones):
   -- EXEC dbo.usp_RegistrarDevolucion @IdPrestamo=2,@IdPersonal=2,
   --      @CondicionDevolucion=N'DANADO',@Observaciones=N'Tapa desprendida';

   -- Reservar una edicion sin ejemplares disponibles:
   -- EXEC dbo.usp_RegistrarReserva @IdPrestatario=14,@IdEdicion=5;

   -- Registrar hallazgo sin alterar de inmediato el estado operativo:
   -- EXEC dbo.usp_RegistrarHallazgo @IdRevision=1,@IdEjemplar=10,
   --      @Hallazgo=N'NO_LOCALIZADO',@Observaciones=N'No se encontro en estante';

   -- Solo tras investigacion: validar hallazgo como sin cambios:
   -- EXEC dbo.usp_ResolverHallazgo @IdRevision=1,@IdEjemplar=10,
   --      @IdPersonal=2,@Decision=N'SIN_CAMBIOS';

   -- Registrar una nueva copia fisica; CodigoInterno se genera solo:
   -- EXEC dbo.usp_RegistrarEjemplar @IdEdicion=1,@Ubicacion=N'EST-01-C11',@IdPersonal=2;

   -- Comprobar que no se puede prestar el mismo ejemplar dos veces:
   -- EXEC dbo.usp_RegistrarPrestamo @IdPrestatario=15,@IdEjemplar=4,@IdPersonal=2;
===================================================================== */
SET NOEXEC OFF; -- Restaura la sesion tambien si la base ya existia.
GO

