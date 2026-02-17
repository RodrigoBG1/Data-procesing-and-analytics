const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const Anthropic = require('@anthropic-ai/sdk');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

// Anthropic client
const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Health check
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected' });
  } catch (error) {
    res.status(500).json({ status: 'error', db: 'disconnected' });
  }
});

// Get database schema
app.get('/api/schema', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT table_name, column_name, data_type 
      FROM information_schema.columns 
      WHERE table_schema = 'public' 
      ORDER BY table_name, ordinal_position
    `);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Main endpoint: Natural language query
app.post('/api/query', async (req, res) => {
  const { question } = req.body;
  
  if (!question) {
    return res.status(400).json({ error: 'Question is required' });
  }

  try {
    // Get database schema for context
    const schemaResult = await pool.query(`
      SELECT table_name, column_name, data_type 
      FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name IN 
      ('dim_date', 'dim_customer', 'dim_card', 'dim_merchant', 'fact_transactions')
      ORDER BY table_name, ordinal_position
    `);

    const schema = schemaResult.rows.reduce((acc, row) => {
      if (!acc[row.table_name]) acc[row.table_name] = [];
      acc[row.table_name].push(`${row.column_name} (${row.data_type})`);
      return acc;
    }, {});

    // Ask Claude to generate SQL query
    const message = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      messages: [{
        role: 'user',
        content: `You are a PostgreSQL expert. Given this star schema:

${Object.entries(schema).map(([table, cols]) => `${table}:\n${cols.join('\n')}`).join('\n\n')}

Generate ONLY a valid PostgreSQL query for: "${question}"

Rules:
- Return ONLY the SQL query, no explanations
- Use proper JOINs between fact_transactions and dimensions
- Limit results to 100 rows if not aggregating
- Use appropriate aggregations for analytical queries`
      }]
    });

    const sqlQuery = message.content[0].text.trim().replace(/```sql|```/g, '');

    // Execute query
    const queryResult = await pool.query(sqlQuery);

    // Ask Claude to suggest chart type and config
    const chartMessage = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      messages: [{
        role: 'user',
        content: `Given this data from query "${question}":

Columns: ${queryResult.fields.map(f => f.name).join(', ')}
Sample row: ${JSON.stringify(queryResult.rows[0] || {})}

Return ONLY a JSON object with:
{
  "chartType": "LineChart|BarChart|PieChart|AreaChart",
  "dataKey": "x-axis field name",
  "valueKeys": ["metric1", "metric2"],
  "title": "Chart title"
}

Choose the best chart type for this data. Return ONLY valid JSON.`
      }]
    });

    const chartConfig = JSON.parse(chartMessage.content[0].text.trim().replace(/```json|```/g, ''));

    res.json({
      query: sqlQuery,
      data: queryResult.rows,
      chartConfig,
      rowCount: queryResult.rows.length
    });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Execute custom SQL
app.post('/api/execute', async (req, res) => {
  const { sql } = req.body;
  
  if (!sql) {
    return res.status(400).json({ error: 'SQL query is required' });
  }

  try {
    const result = await pool.query(sql);
    res.json({
      data: result.rows,
      rowCount: result.rows.length,
      fields: result.fields.map(f => ({ name: f.name, type: f.dataTypeID }))
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get predefined insights
app.get('/api/insights/:type', async (req, res) => {
  const { type } = req.params;
  
  const queries = {
    daily: `SELECT d.full_date, COUNT(*) as transactions, SUM(f.amount) as total
            FROM fact_transactions f
            JOIN dim_date d ON f.date_key = d.date_key
            GROUP BY d.full_date
            ORDER BY d.full_date DESC
            LIMIT 30`,
    
    merchants: `SELECT m.merchant_category_group, COUNT(*) as count, SUM(f.amount) as revenue
                FROM fact_transactions f
                JOIN dim_merchant m ON f.merchant_key = m.merchant_key
                GROUP BY m.merchant_category_group
                ORDER BY revenue DESC
                LIMIT 10`,
    
    cards: `SELECT c.card_brand, c.card_type, COUNT(*) as usage_count, AVG(f.amount) as avg_amount
            FROM fact_transactions f
            JOIN dim_card c ON f.card_key = c.card_key
            GROUP BY c.card_brand, c.card_type
            ORDER BY usage_count DESC`,
    
    errors: `SELECT f.error_code, COUNT(*) as count
             FROM fact_transactions f
             WHERE f.has_errors = true
             GROUP BY f.error_code
             ORDER BY count DESC`
  };

  try {
    const result = await pool.query(queries[type]);
    res.json({ data: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});
