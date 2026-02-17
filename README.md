# Analytics API with Claude AI

Dashboard de análisis de transacciones usando Express.js, PostgreSQL, Claude AI y Recharts.

## 🚀 Características

- **Consultas en lenguaje natural** - Pregunta en español y Claude genera SQL automáticamente
- **Gráficas automáticas** - Claude decide qué tipo de gráfica usar (Line, Bar, Pie, Area)
- **Insights predefinidos** - Análisis rápidos de tendencias diarias, merchants, tarjetas y errores
- **Conexión a PostgreSQL** - Se conecta a tu base de datos en Docker
- **UI minimalista** - Dashboard moderno con React y Recharts

## 📦 Instalación

1. **Configurar variables de entorno**
   ```bash
   # Edita el archivo .env y agrega tu API key de Claude
   ANTHROPIC_API_KEY=sk-ant-api03-xxx
   ```

2. **Iniciar la base de datos**
   ```bash
   # Desde el directorio donde está docker-compose.yml
   docker-compose up -d
   ```

3. **Cargar el schema**
   ```bash
   # Conectarse a PostgreSQL y ejecutar StarSquema.sql
   docker exec -i postgres-transactions-dw psql -U dataengineer -d transactions_dw < StarSquema.sql
   ```

4. **Instalar dependencias** (ya hecho)
   ```bash
   npm install
   ```

5. **Iniciar el servidor**
   ```bash
   npm start
   ```

6. **Abrir el dashboard**
   ```
   http://localhost:3000
   ```

## 🎯 Uso

### Consultas en lenguaje natural

Ejemplos de preguntas que puedes hacer:

- "Muéstrame las transacciones por día del último mes"
- "¿Cuáles son los merchants con más ingresos?"
- "Análisis de transacciones por tipo de tarjeta"
- "Transacciones con errores agrupadas por código de error"
- "Promedio de transacciones por categoría de merchant"

### API Endpoints

**POST /api/query**
```json
{
  "question": "Show me daily transactions"
}
```

**POST /api/execute**
```json
{
  "sql": "SELECT * FROM fact_transactions LIMIT 10"
}
```

**GET /api/insights/:type**
- `/api/insights/daily` - Tendencias diarias
- `/api/insights/merchants` - Top merchants
- `/api/insights/cards` - Análisis de tarjetas
- `/api/insights/errors` - Análisis de errores

**GET /api/schema**
Retorna el schema completo de la base de datos

**GET /health**
Health check de la conexión a DB

## 🏗️ Estructura del Proyecto

```
analytics-api/
├── server.js          # Express server + Claude integration
├── public/
│   └── index.html     # React dashboard
├── .env               # Configuración
├── package.json
└── README.md
```

## 🔑 Obtener API Key de Claude

1. Ve a https://console.anthropic.com
2. Regístrate o inicia sesión
3. Ve a "API Keys"
4. Crea una nueva clave
5. Cópiala en el archivo `.env`

## 💡 Cómo funciona

1. **Usuario hace pregunta** en lenguaje natural
2. **Claude analiza** el schema de la base de datos
3. **Claude genera** la consulta SQL optimizada
4. **Express ejecuta** la query en PostgreSQL
5. **Claude sugiere** el mejor tipo de gráfica
6. **Dashboard renderiza** los resultados con Recharts

## 🛠️ Stack Tecnológico

- **Backend**: Express.js + Node.js
- **Database**: PostgreSQL 15
- **AI**: Claude API (Sonnet 4)
- **Frontend**: React 18 + Recharts
- **Visualización**: Recharts (Line, Bar, Pie, Area charts)

## 📊 Modelos de datos

El proyecto usa un **Star Schema** con:
- `fact_transactions` - Tabla de hechos
- `dim_date` - Dimensión de fechas
- `dim_customer` - Dimensión de clientes
- `dim_card` - Dimensión de tarjetas
- `dim_merchant` - Dimensión de merchants

## 🔒 Seguridad

- Variables de entorno para credenciales
- CORS habilitado
- Queries parametrizadas (protección contra SQL injection)
- Límite de 100 filas por query (configurable)

## 📈 Optimización de Costos

El proyecto usa Claude Sonnet 4 que cuesta:
- $3 por millón de tokens de entrada
- $15 por millón de tokens de salida

Una consulta típica usa ~500 tokens ≈ $0.01 por consulta.

## 🚨 Troubleshooting

**Error: Connection refused**
- Verifica que Docker esté corriendo: `docker ps`
- Verifica el puerto: `5433` (no 5432)

**Error: Invalid API key**
- Verifica tu API key en `.env`
- Asegúrate de que empiece con `sk-ant-api03-`

**Error: Schema not found**
- Ejecuta el archivo `StarSquema.sql` en PostgreSQL
