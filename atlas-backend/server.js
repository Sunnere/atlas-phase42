const express = require('express');
const cors = require('cors');
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// ============================================================================
// Helper Functions
// ============================================================================

// Generate metrics data for any date range
function generateMetricsForRange(startDate, endDate) {
  const data = [];
  let current = new Date(startDate);

  while (current < endDate) {
    const requestCount = Math.floor(Math.random() * 300) + 200;
    data.push({
      timestamp: new Date(current).toISOString(),
      requests: requestCount
    });
    current.setMinutes(current.getMinutes() + 1);
  }

  return data;
}

// ============================================================================
// API Endpoints
// ============================================================================

// GET /api/agents/health - Agent status monitoring
app.get('/api/agents/health', (req, res) => {
  res.json({
    agents: [
      {
        id: 'thailand-property',
        name: 'Thailand Property Agent',
        status: 'operational',
        uptime: 99.8,
        lastResponse: 145,
        requestsLastHour: 342
      },
      {
        id: 'bonusshop-marketing',
        name: 'BonusShop Marketing Agent',
        status: 'operational',
        uptime: 99.5,
        lastResponse: 128,
        requestsLastHour: 298
      },
      {
        id: 'trading-investment',
        name: 'Trading & Investment Agent',
        status: 'operational',
        uptime: 99.9,
        lastResponse: 156,
        requestsLastHour: 267
      }
    ],
    timestamp: new Date().toISOString()
  });
});

// GET /api/metrics/requests - Timeline data with custom time ranges
app.get('/api/metrics/requests', (req, res) => {
  let startDate, endDate;

  if (req.query.start && req.query.end) {
    startDate = new Date(req.query.start);
    endDate = new Date(req.query.end);

    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      return res.status(400).json({
        error: 'Invalid date format. Use ISO8601: 2026-09-28T14:00:00Z'
      });
    }

    if (startDate >= endDate) {
      return res.status(400).json({
        error: 'Start date must be before end date'
      });
    }
  } else {
    endDate = new Date();
    startDate = new Date(endDate.getTime() - 60 * 60 * 1000);
  }

  const data = generateMetricsForRange(startDate, endDate);

  res.json({
    range: {
      start: startDate.toISOString(),
      end: endDate.toISOString(),
      pointCount: data.length
    },
    data: data,
    timestamp: new Date().toISOString()
  });
});

// GET /api/metrics/summary - Aggregated statistics
app.get('/api/metrics/summary', (req, res) => {
  let startDate, endDate;

  if (req.query.start && req.query.end) {
    startDate = new Date(req.query.start);
    endDate = new Date(req.query.end);
  } else {
    endDate = new Date();
    startDate = new Date(endDate.getTime() - 60 * 60 * 1000);
  }

  const data = generateMetricsForRange(startDate, endDate);
  const values = data.map(d => d.requests);

  const total = values.reduce((a, b) => a + b, 0);
  const avg = total / values.length;
  const max = Math.max(...values);
  const min = Math.min(...values);

  res.json({
    range: {
      start: startDate.toISOString(),
      end: endDate.toISOString()
    },
    statistics: {
      totalRequests: total,
      averagePerMinute: Math.round(avg),
      peakPerMinute: max,
      minimumPerMinute: min,
      dataPoints: values.length
    },
    timestamp: new Date().toISOString()
  });
});

// GET /api/metrics/risks - Risk classification breakdown
app.get('/api/metrics/risks', (req, res) => {
  res.json({
    HIGH: 180,
    MEDIUM: 420,
    LOW: 600,
    timestamp: new Date().toISOString()
  });
});

// GET /api/metrics/export - CSV download
app.get('/api/metrics/export', (req, res) => {
  let startDate, endDate;

  if (req.query.start && req.query.end) {
    startDate = new Date(req.query.start);
    endDate = new Date(req.query.end);
  } else {
    endDate = new Date();
    startDate = new Date(endDate.getTime() - 60 * 60 * 1000);
  }

  const data = generateMetricsForRange(startDate, endDate);

  let csv = 'timestamp,requests\n';
  data.forEach(point => {
    csv += `${point.timestamp},${point.requests}\n`;
  });

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="atlas-metrics-${startDate.toISOString().split('T')[0]}.csv"`
  );
  res.send(csv);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'operational',
    timestamp: new Date().toISOString()
  });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ ATLAS Phase 3 Backend running on port ${PORT}`);
  console.log(`   API endpoints:`);
  console.log(`   • GET /api/agents/health`);
  console.log(`   • GET /api/metrics/requests?start=ISO&end=ISO`);
  console.log(`   • GET /api/metrics/summary?start=ISO&end=ISO`);
  console.log(`   • GET /api/metrics/risks`);
  console.log(`   • GET /api/metrics/export?start=ISO&end=ISO`);
  console.log(`   • GET /health`);
});
