'use strict';
require('dotenv').config();
const express = require('express');
const sql = require('mssql');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const path = require('path');
const crypto = require('crypto');
const app = express();
app.use(helmet({contentSecurityPolicy:false}));
app.use(express.json({limit:'32kb'}));
app.use('/api/login',rateLimit({windowMs:15*60*1000,limit:15,standardHeaders:'draft-7',legacyHeaders:false}));
app.use(express.static(path.join(__dirname,'public')));
const required=['DB_SERVER','DB_NAME','DB_USER','DB_PASSWORD','ADMIN_USERNAME','ADMIN_PASSWORD','JWT_SECRET'];
const missing=required.filter(k=>!process.env[k] || process.env[k].startsWith('CAMBIA_'));
if(missing.length){console.error('Configura .env: '+missing.join(', '));process.exit(1)}
const config={server:process.env.DB_SERVER,port:Number(process.env.DB_PORT||1433),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD,options:{encrypt:process.env.DB_ENCRYPT==='true',trustServerCertificate:process.env.DB_TRUST_CERT==='true'},pool:{max:10,min:0,idleTimeoutMillis:30000}};
const pool=sql.connect(config);
const asyncRoute=fn=>(req,res,next)=>Promise.resolve(fn(req,res,next)).catch(next);
function auth(req,res,next){const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');try{req.user=jwt.verify(token,process.env.JWT_SECRET,{algorithms:['HS256']});next()}catch{return res.status(401).json({error:'Inicia sesión como bibliotecario.'})}}
function id(value){const n=Number(value);if(!Number.isSafeInteger(n)||n<=0)throw Object.assign(new Error('Identificador inválido.'),{status:400});return n}
function same(a,b){const x=crypto.createHash('sha256').update(String(a)).digest();const y=crypto.createHash('sha256').update(String(b)).digest();return crypto.timingSafeEqual(x,y)}
app.post('/api/login',(req,res)=>{const {username,password}=req.body||{};if(!same(username||'',process.env.ADMIN_USERNAME)||!same(password||'',process.env.ADMIN_PASSWORD))return res.status(401).json({error:'Credenciales incorrectas.'});res.json({token:jwt.sign({role:'bibliotecario'},process.env.JWT_SECRET,{expiresIn:'4h',algorithm:'HS256'})})});
app.get('/api/catalogo',asyncRoute(async(req,res)=>{const p=await pool;const q=p.request();const s=String(req.query.q||'').trim().slice(0,120);q.input('q',sql.NVarChar(130),'%'+s+'%');const rows=await q.query(`SELECT c.*, ISNULL(STUFF((SELECT ', '+oc.Categoria FROM dbo.vw_ObrasCategorias oc WHERE oc.IdObra=c.IdObra FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),'General') AS Categorias FROM dbo.vw_CatalogoPublico c WHERE c.Titulo LIKE @q OR c.Autor LIKE @q OR c.ISBN LIKE @q ORDER BY c.Titulo,c.NumeroEdicion`);res.json(rows.recordset)}));
app.get('/api/estadisticas',asyncRoute(async(req,res)=>{const p=await pool;const result=await p.request().query(`SELECT (SELECT COUNT(*) FROM dbo.Obra WHERE Activa=1) AS obras,(SELECT COUNT(*) FROM dbo.Ejemplar) AS ejemplares,(SELECT COUNT(*) FROM dbo.Ejemplar WHERE Estado='DISPONIBLE') AS disponibles,(SELECT COUNT(*) FROM dbo.Prestamo WHERE Estado='ABIERTO') AS prestamos,(SELECT COUNT(*) FROM dbo.Prestamo WHERE Estado='ABIERTO' AND FechaLimite<SYSDATETIME()) AS vencidos`);res.json(result.recordset[0])}));
app.get('/api/incidencias',asyncRoute(async(req,res)=>{const p=await pool;res.json((await p.request().query('SELECT * FROM dbo.vw_IncidenciasEdicion ORDER BY FechaRegistro DESC')).recordset)}));
app.get('/api/prestamos',auth,asyncRoute(async(req,res)=>{const p=await pool;res.json((await p.request().query('SELECT * FROM dbo.vw_PrestamosActivosGestion ORDER BY FechaLimite')).recordset)}));
app.get('/api/ejemplares',auth,asyncRoute(async(req,res)=>{const p=await pool;res.json((await p.request().query(`SELECT e.IdEjemplar,e.CodigoInterno,e.Estado,e.Condicion,e.Ubicacion,ob.Titulo,ed.NumeroEdicion FROM dbo.Ejemplar e JOIN dbo.Edicion ed ON ed.IdEdicion=e.IdEdicion JOIN dbo.Obra ob ON ob.IdObra=ed.IdObra ORDER BY e.IdEjemplar`)).recordset)}));
app.get('/api/prestatarios',auth,asyncRoute(async(req,res)=>{const p=await pool;res.json((await p.request().query('SELECT IdPrestatario,Matricula,Nombre,Tipo FROM dbo.Prestatario WHERE Activo=1 ORDER BY Nombre')).recordset)}));
app.get('/api/personal',auth,asyncRoute(async(req,res)=>{const p=await pool;res.json((await p.request().query(`SELECT p.IdPersonal,p.Nombre FROM dbo.Personal p JOIN dbo.RolPersonal r ON r.IdRol=p.IdRol WHERE p.Activo=1 AND r.Nombre IN ('ADMINISTRADOR','BIBLIOTECARIO') ORDER BY p.Nombre`)).recordset)}));
app.get('/api/reservas',auth,asyncRoute(async(req,res)=>{const p=await pool;res.json((await p.request().query('SELECT * FROM dbo.vw_ListaEsperaGestion ORDER BY FechaSolicitud')).recordset)}));
app.get('/api/revisiones',auth,asyncRoute(async(req,res)=>{const p=await pool;res.json((await p.request().query('SELECT * FROM dbo.vw_HallazgosInventario ORDER BY IdRevision DESC,IdEjemplar')).recordset)}));
app.post('/api/prestamos',auth,asyncRoute(async(req,res)=>{const p=await pool;const r=p.request();r.input('IdPrestatario',sql.Int,id(req.body.IdPrestatario));r.input('IdEjemplar',sql.Int,id(req.body.IdEjemplar));r.input('IdPersonal',sql.Int,id(req.body.IdPersonal));await r.execute('dbo.usp_RegistrarPrestamo');res.status(201).json({message:'Préstamo registrado correctamente.'})}));
app.post('/api/devoluciones',auth,asyncRoute(async(req,res)=>{const p=await pool;const r=p.request();const condicion=String(req.body.CondicionDevolucion||'');if(!['BUENO','REGULAR','DANADO'].includes(condicion))return res.status(400).json({error:'Condición inválida.'});r.input('IdPrestamo',sql.Int,id(req.body.IdPrestamo));r.input('IdPersonal',sql.Int,id(req.body.IdPersonal));r.input('CondicionDevolucion',sql.NVarChar(10),condicion);r.input('Observaciones',sql.NVarChar(500),String(req.body.Observaciones||'').slice(0,500)||null);await r.execute('dbo.usp_RegistrarDevolucion');res.json({message:'Devolución registrada correctamente.'})}));
app.post('/api/reservas',auth,asyncRoute(async(req,res)=>{const p=await pool;const r=p.request();r.input('IdPrestatario',sql.Int,id(req.body.IdPrestatario));r.input('IdEdicion',sql.Int,id(req.body.IdEdicion));await r.execute('dbo.usp_RegistrarReserva');res.status(201).json({message:'Reserva registrada correctamente.'})}));
app.get('/api/health',asyncRoute(async(req,res)=>{await pool;res.json({ok:true})}));
app.use('/api',(req,res)=>res.status(404).json({error:'Ruta no encontrada.'}));
app.use((err,req,res,next)=>{console.error(err);res.status(err.status||((err.number>=51000&&err.number<52000)?400:500)).json({error:err.originalError?.info?.message||((err.number>=51000&&err.number<52000)?err.message:'No se pudo completar la operación. Revisa el servidor.')})});
app.listen(Number(process.env.PORT||3000),()=>console.log('Biblioteca: http://localhost:'+(process.env.PORT||3000)));
