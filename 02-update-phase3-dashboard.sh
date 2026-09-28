#!/bin/bash

# ============================================================================
# ATLAS Phase 3: Update Dashboard with Date Range Picker
# Usage: bash 02-update-phase3-dashboard.sh
#
# This script:
# 1. Backs up current dashboard
# 2. Installs new dashboard with date range features
# 3. Verifies the file is correct
# ============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}📊 ATLAS Phase 3: Dashboard Update${NC}"
echo "===================================="
echo ""

# Step 1: Verify we're in the right directory
if [ ! -d "public/dashboard" ]; then
  echo -e "${YELLOW}⚠️  public/dashboard not found, creating...${NC}"
  mkdir -p public/dashboard
fi

DASHBOARD_FILE="public/dashboard/index.html"

echo -e "${BLUE}Step 1: Backing up current dashboard${NC}"
if [ -f "$DASHBOARD_FILE" ]; then
  BACKUP_FILE="public/dashboard/index.html.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$DASHBOARD_FILE" "$BACKUP_FILE"
  echo -e "${GREEN}✅ Backup: $BACKUP_FILE${NC}"
else
  echo -e "${YELLOW}ℹ️  No existing dashboard found (first time)${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Installing Phase 3 Dashboard${NC}"

# Create the new dashboard
cat > "$DASHBOARD_FILE" << 'DASHBOARD_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ATLAS Dashboard - Phase 3 with Custom Time Ranges</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    :root {
      --light-bg: #ffffff;
      --light-surface: #f9f9f9;
      --light-border: #e0e0e0;
      --light-text: #333333;
      --light-text-muted: #666666;
      --light-primary: #2563eb;
      --light-success: #10b981;
      --light-warning: #f59e0b;
      --light-danger: #ef4444;

      --dark-bg: #1a1a1a;
      --dark-surface: #2d2d2d;
      --dark-border: #404040;
      --dark-text: #f0f0f0;
      --dark-text-muted: #b0b0b0;
      --dark-primary: #3b82f6;
      --dark-success: #34d399;
      --dark-warning: #fbbf24;
      --dark-danger: #f87171;

      --bg: var(--light-bg);
      --surface: var(--light-surface);
      --border: var(--light-border);
      --text: var(--light-text);
      --text-muted: var(--light-text-muted);
      --primary: var(--light-primary);
      --success: var(--light-success);
      --warning: var(--light-warning);
      --danger: var(--light-danger);
    }

    [data-theme="dark"] {
      --bg: var(--dark-bg);
      --surface: var(--dark-surface);
      --border: var(--dark-border);
      --text: var(--dark-text);
      --text-muted: var(--dark-text-muted);
      --primary: var(--dark-primary);
      --success: var(--dark-success);
      --warning: var(--dark-warning);
      --danger: var(--dark-danger);
    }

    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      transition: background-color 0.3s, color 0.3s;
    }

    .container {
      max-width: 1400px;
      margin: 0 auto;
      padding: 20px;
    }

    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 30px;
      padding-bottom: 20px;
      border-bottom: 2px solid var(--border);
      flex-wrap: wrap;
      gap: 10px;
    }

    h1 {
      font-size: 28px;
      font-weight: 700;
    }

    .header-controls {
      display: flex;
      gap: 15px;
      align-items: center;
      flex-wrap: wrap;
    }

    .status-indicator {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 8px 12px;
      background-color: var(--surface);
      border-radius: 6px;
      font-size: 14px;
    }

    .status-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background-color: var(--success);
      animation: pulse 2s infinite;
    }

    .status-dot.disconnected {
      background-color: var(--danger);
      animation: none;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }

    .theme-toggle {
      background-color: var(--surface);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 8px 12px;
      cursor: pointer;
      font-size: 18px;
      transition: background-color 0.2s;
    }

    .theme-toggle:hover {
      background-color: var(--border);
    }

    .time-range-control {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      padding: 15px;
      background-color: var(--surface);
      border-radius: 8px;
      margin-bottom: 20px;
      border: 1px solid var(--border);
    }

    .time-range-buttons {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }

    .time-btn {
      padding: 8px 14px;
      background-color: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      cursor: pointer;
      font-size: 13px;
      transition: all 0.2s;
      color: var(--text);
    }

    .time-btn:hover {
      background-color: var(--border);
    }

    .time-btn.active {
      background-color: var(--primary);
      color: white;
      border-color: var(--primary);
    }

    .custom-range-inputs {
      display: flex;
      gap: 10px;
      align-items: center;
      flex-wrap: wrap;
    }

    input[type="date"],
    input[type="time"] {
      padding: 8px 12px;
      border: 1px solid var(--border);
      border-radius: 6px;
      background-color: var(--bg);
      color: var(--text);
      font-size: 13px;
    }

    .export-btn {
      padding: 8px 14px;
      background-color: var(--success);
      color: white;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      font-size: 13px;
      transition: background-color 0.2s;
    }

    .export-btn:hover {
      background-color: #059669;
    }

    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }

    .metric-card {
      background-color: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 20px;
      transition: transform 0.2s, box-shadow 0.2s;
    }

    .metric-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    }

    .metric-label {
      font-size: 12px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 8px;
    }

    .metric-value {
      font-size: 36px;
      font-weight: 700;
      margin-bottom: 8px;
    }

    .metric-detail {
      font-size: 13px;
      color: var(--text-muted);
    }

    .agents-section {
      margin-bottom: 30px;
    }

    .agents-section h2 {
      font-size: 18px;
      margin-bottom: 15px;
    }

    .agent-list {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 15px;
    }

    .agent-card {
      background-color: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px;
    }

    .agent-header {
      display: flex;
      justify-content: space-between;
      align-items: start;
      margin-bottom: 10px;
    }

    .agent-name {
      font-weight: 600;
      font-size: 14px;
    }

    .agent-status {
      display: inline-block;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      font-weight: 600;
      background-color: #d1fae5;
      color: #065f46;
    }

    [data-theme="dark"] .agent-status {
      background-color: #064e3b;
      color: #d1fae5;
    }

    .agent-metrics {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      margin-top: 12px;
      font-size: 12px;
    }

    .agent-metric {
      display: flex;
      justify-content: space-between;
    }

    .agent-metric-label {
      color: var(--text-muted);
    }

    .agent-metric-value {
      font-weight: 600;
      color: var(--text);
    }

    .chart-section {
      background-color: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 30px;
    }

    .chart-section h2 {
      font-size: 18px;
      margin-bottom: 15px;
    }

    svg {
      width: 100%;
      height: auto;
    }

    .risk-breakdown {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 15px;
      margin-top: 15px;
    }

    .risk-item {
      text-align: center;
      padding: 15px;
      background-color: var(--bg);
      border-radius: 6px;
    }

    .risk-count {
      font-size: 28px;
      font-weight: 700;
      color: var(--primary);
    }

    .risk-label {
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 5px;
      text-transform: uppercase;
    }

    .loading {
      text-align: center;
      padding: 40px;
      color: var(--text-muted);
    }

    .error {
      background-color: #fee2e2;
      color: #991b1b;
      padding: 15px;
      border-radius: 6px;
      margin-bottom: 20px;
    }

    [data-theme="dark"] .error {
      background-color: #7f1d1d;
      color: #fecaca;
    }

    @media (max-width: 768px) {
      .header-controls {
        width: 100%;
        justify-content: space-between;
      }

      .time-range-control {
        flex-direction: column;
      }

      .metrics-grid {
        grid-template-columns: 1fr;
      }

      .agent-list {
        grid-template-columns: 1fr;
      }

      h1 {
        font-size: 22px;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div>
        <h1>ATLAS Dashboard</h1>
        <p style="color: var(--text-muted); font-size: 14px;">Phase 3 - Real-time Agent Orchestration Metrics</p>
      </div>
      <div class="header-controls">
        <div class="status-indicator">
          <div class="status-dot" id="statusDot"></div>
          <span id="statusText">Connected</span>
        </div>
        <button class="theme-toggle" id="themeToggle" title="Toggle dark mode">🌙</button>
      </div>
    </header>

    <div class="time-range-control">
      <div class="time-range-buttons">
        <button class="time-btn active" data-range="60" data-label="60 min">60 minutes</button>
        <button class="time-btn" data-range="1440" data-label="24h">24 hours</button>
        <button class="time-btn" data-range="10080" data-label="week">1 week</button>
        <button class="time-btn" data-range="43200" data-label="month">1 month</button>
      </div>
      <div class="custom-range-inputs">
        <label for="startDate" style="font-size: 12px;">Custom:</label>
        <input type="date" id="startDate">
        <input type="time" id="startTime">
        <span>to</span>
        <input type="date" id="endDate">
        <input type="time" id="endTime">
        <button class="time-btn" onclick="applyCustomRange()">Apply</button>
      </div>
      <button class="export-btn" onclick="exportMetrics()">📥 Export CSV</button>
    </div>

    <div id="errorContainer"></div>

    <div class="metrics-grid" id="metricsGrid">
      <div class="metric-card">
        <div class="metric-label">Total Requests</div>
        <div class="metric-value" id="totalRequests">-</div>
        <div class="metric-detail" id="totalDetail">Calculating...</div>
      </div>
      <div class="metric-card">
        <div class="metric-label">Average per minute</div>
        <div class="metric-value" id="avgRequests">-</div>
        <div class="metric-detail" id="avgDetail">Peak: - | Min: -</div>
      </div>
      <div class="metric-card">
        <div class="metric-label">System Uptime</div>
        <div class="metric-value" id="avgUptime">-</div>
        <div class="metric-detail">Across all agents</div>
      </div>
    </div>

    <div class="agents-section">
      <h2>Active Agents</h2>
      <div class="agent-list" id="agentsList">
        <div class="loading">Loading agents...</div>
      </div>
    </div>

    <div class="chart-section">
      <h2>Request Timeline</h2>
      <div id="requestsChart" style="height: 400px;">
        <div class="loading">Loading chart...</div>
      </div>
    </div>

    <div class="chart-section">
      <h2>Risk Distribution</h2>
      <div class="risk-breakdown" id="riskBreakdown">
        <div class="loading">Loading risk data...</div>
      </div>
    </div>
  </div>

  <script>
    const state = {
      theme: localStorage.getItem('theme') || 'light',
      currentRange: 60,
      currentRangeLabel: '60 min',
      startDate: null,
      endDate: null
    };

    function initTheme() {
      document.documentElement.setAttribute('data-theme', state.theme);
      updateThemeButton();
    }

    function toggleTheme() {
      state.theme = state.theme === 'light' ? 'dark' : 'light';
      localStorage.setItem('theme', state.theme);
      document.documentElement.setAttribute('data-theme', state.theme);
      updateThemeButton();
    }

    function updateThemeButton() {
      document.getElementById('themeToggle').textContent = state.theme === 'dark' ? '☀️' : '🌙';
    }

    function calculateDateRange(minutes) {
      const endDate = new Date();
      const startDate = new Date(endDate.getTime() - minutes * 60 * 1000);
      return { startDate, endDate };
    }

    function formatISODateTime(date) {
      return date.toISOString().split('.')[0] + 'Z';
    }

    function setDateRangeInputs(startDate, endDate) {
      const startStr = startDate.toISOString().split('T');
      const endStr = endDate.toISOString().split('T');
      document.getElementById('startDate').value = startStr[0];
      document.getElementById('startTime').value = startStr[1].substring(0, 5);
      document.getElementById('endDate').value = endStr[0];
      document.getElementById('endTime').value = endStr[1].substring(0, 5);
    }

    function applyCustomRange() {
      const startDateStr = document.getElementById('startDate').value;
      const startTimeStr = document.getElementById('startTime').value;
      const endDateStr = document.getElementById('endDate').value;
      const endTimeStr = document.getElementById('endTime').value;

      if (!startDateStr || !startTimeStr || !endDateStr || !endTimeStr) {
        showError('Please fill in all date and time fields');
        return;
      }

      const startDate = new Date(`${startDateStr}T${startTimeStr}:00Z`);
      const endDate = new Date(`${endDateStr}T${endTimeStr}:00Z`);

      if (startDate >= endDate) {
        showError('Start date/time must be before end date/time');
        return;
      }

      state.startDate = startDate;
      state.endDate = endDate;
      state.currentRange = null;
      state.currentRangeLabel = `${startDateStr} to ${endDateStr}`;

      document.querySelectorAll('.time-btn[data-range]').forEach(btn => {
        btn.classList.remove('active');
      });

      clearError();
      fetchAllData();
    }

    function setTimeRange(minutes, label) {
      state.currentRange = minutes;
      state.currentRangeLabel = label;
      state.startDate = null;
      state.endDate = null;
      const { startDate, endDate } = calculateDateRange(minutes);
      setDateRangeInputs(startDate, endDate);
      clearError();
      fetchAllData();
    }

    async function fetchWithRange(endpoint) {
      const params = new URLSearchParams();
      if (state.startDate && state.endDate) {
        params.append('start', formatISODateTime(state.startDate));
        params.append('end', formatISODateTime(state.endDate));
      } else if (state.currentRange) {
        const { startDate, endDate } = calculateDateRange(state.currentRange);
        params.append('start', formatISODateTime(startDate));
        params.append('end', formatISODateTime(endDate));
      }
      const url = `${endpoint}?${params.toString()}`;
      const response = await fetch(url);
      if (!response.ok) throw new Error(`Failed to fetch ${endpoint}`);
      return response.json();
    }

    async function fetchAgentsHealth() {
      const response = await fetch('/api/agents/health');
      if (!response.ok) throw new Error('Failed to fetch agents');
      return response.json();
    }

    async function fetchAllData() {
      try {
        updateConnectionStatus(true);
        clearError();
        const [agents, requests, risks] = await Promise.all([
          fetchAgentsHealth(),
          fetchWithRange('/api/metrics/requests'),
          fetch('/api/metrics/risks').then(r => r.json())
        ]);
        const summary = await fetchWithRange('/api/metrics/summary');

        renderAgents(agents.agents);
        renderRequestsChart(requests.data);
        renderRisks(risks);
        updateSummaryMetrics(summary.statistics);
      } catch (error) {
        console.error('Error:', error);
        updateConnectionStatus(false);
        showError(`Connection error: ${error.message}`);
      }
    }

    async function exportMetrics() {
      try {
        const params = new URLSearchParams();
        if (state.startDate && state.endDate) {
          params.append('start', formatISODateTime(state.startDate));
          params.append('end', formatISODateTime(state.endDate));
        } else if (state.currentRange) {
          const { startDate, endDate } = calculateDateRange(state.currentRange);
          params.append('start', formatISODateTime(startDate));
          params.append('end', formatISODateTime(endDate));
        }
        window.location.href = `/api/metrics/export?${params.toString()}`;
      } catch (error) {
        showError(`Export failed: ${error.message}`);
      }
    }

    function updateSummaryMetrics(stats) {
      document.getElementById('totalRequests').textContent = stats.totalRequests.toLocaleString();
      document.getElementById('avgRequests').textContent = stats.averagePerMinute;
      document.getElementById('totalDetail').textContent = `Period: ${state.currentRangeLabel}`;
      document.getElementById('avgDetail').textContent = `Peak: ${stats.peakPerMinute} | Min: ${stats.minimumPerMinute}`;
    }

    function renderAgents(agents) {
      const list = document.getElementById('agentsList');
      list.innerHTML = agents.map(agent => `
        <div class="agent-card">
          <div class="agent-header">
            <div class="agent-name">${agent.name}</div>
            <div class="agent-status">${agent.status}</div>
          </div>
          <div class="agent-metrics">
            <div class="agent-metric">
              <span class="agent-metric-label">Uptime</span>
              <span class="agent-metric-value">${agent.uptime}%</span>
            </div>
            <div class="agent-metric">
              <span class="agent-metric-label">Lat.</span>
              <span class="agent-metric-value">${agent.lastResponse}ms</span>
            </div>
            <div class="agent-metric">
              <span class="agent-metric-label">Requests/hr</span>
              <span class="agent-metric-value">${agent.requestsLastHour}</span>
            </div>
          </div>
        </div>
      `).join('');
    }

    function renderRequestsChart(data) {
      if (!data || data.length === 0) {
        document.getElementById('requestsChart').innerHTML = '<div class="loading">No data available</div>';
        return;
      }
      const width = 900, height = 300;
      const margin = { top: 20, right: 20, bottom: 30, left: 50 };
      const maxRequests = Math.max(...data.map(d => d.requests));
      const minRequests = Math.min(...data.map(d => d.requests));
      const xScale = (i) => margin.left + (i / (data.length - 1)) * (width - margin.left - margin.right);
      const yScale = (val) => height - margin.bottom - ((val - minRequests) / (maxRequests - minRequests)) * (height - margin.top - margin.bottom);

      let pathD = `M ${xScale(0)} ${yScale(data[0].requests)}`;
      for (let i = 1; i < data.length; i++) {
        pathD += ` L ${xScale(i)} ${yScale(data[i].requests)}`;
      }

      const svg = `
        <svg viewBox="0 0 ${width} ${height}" style="width: 100%; height: 400px;">
          ${Array.from({length: 5}, (_, i) => {
            const y = margin.top + (i / 4) * (height - margin.top - margin.bottom);
            const val = maxRequests - (i / 4) * (maxRequests - minRequests);
            return `<line x1="${margin.left}" y1="${y}" x2="${width - margin.right}" y2="${y}" stroke="currentColor" opacity="0.1" stroke-width="1"/>
                    <text x="${margin.left - 10}" y="${y + 4}" font-size="11" text-anchor="end" fill="currentColor" opacity="0.6">${Math.round(val)}</text>`;
          }).join('')}
          <line x1="${margin.left}" y1="${margin.top}" x2="${margin.left}" y2="${height - margin.bottom}" stroke="currentColor" stroke-width="2"/>
          <line x1="${margin.left}" y1="${height - margin.bottom}" x2="${width - margin.right}" y2="${height - margin.bottom}" stroke="currentColor" stroke-width="2"/>
          <path d="${pathD}" fill="none" stroke="var(--primary)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="${pathD} L ${xScale(data.length - 1)} ${height - margin.bottom} L ${xScale(0)} ${height - margin.bottom} Z" fill="var(--primary)" opacity="0.1"/>
        </svg>
      `;
      document.getElementById('requestsChart').innerHTML = svg;
    }

    function renderRisks(data) {
      const risks = [
        { label: 'High', value: data.HIGH, color: '#ef4444' },
        { label: 'Medium', value: data.MEDIUM, color: '#f59e0b' },
        { label: 'Low', value: data.LOW, color: '#10b981' }
      ];
      const total = risks.reduce((sum, r) => sum + r.value, 0);
      const html = risks.map(risk => `
        <div class="risk-item">
          <div class="risk-count" style="color: ${risk.color};">${risk.value}</div>
          <div class="risk-label">${risk.label}</div>
          <div style="font-size: 11px; color: var(--text-muted); margin-top: 5px;">${((risk.value / total) * 100).toFixed(1)}%</div>
        </div>
      `).join('');
      document.getElementById('riskBreakdown').innerHTML = html;
    }

    function updateConnectionStatus(connected) {
      const dot = document.getElementById('statusDot');
      const text = document.getElementById('statusText');
      if (connected) {
        dot.classList.remove('disconnected');
        text.textContent = 'Connected';
      } else {
        dot.classList.add('disconnected');
        text.textContent = 'Disconnected';
      }
    }

    function showError(message) {
      document.getElementById('errorContainer').innerHTML = `<div class="error">⚠️ ${message}</div>`;
    }

    function clearError() {
      document.getElementById('errorContainer').innerHTML = '';
    }

    document.getElementById('themeToggle').addEventListener('click', toggleTheme);
    document.querySelectorAll('.time-btn[data-range]').forEach(btn => {
      btn.addEventListener('click', function() {
        document.querySelectorAll('.time-btn[data-range]').forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        setTimeRange(parseInt(this.dataset.range), this.dataset.label);
      });
    });

    window.addEventListener('load', () => {
      initTheme();
      const { startDate, endDate } = calculateDateRange(60);
      setDateRangeInputs(startDate, endDate);
      fetchAllData();
      setInterval(fetchAllData, 5000);
    });
  </script>
</body>
</html>
DASHBOARD_EOF

echo -e "${GREEN}✅ New dashboard installed${NC}"

# Step 3: Verify file
echo ""
echo -e "${BLUE}Step 3: Verifying installation${NC}"
FILE_SIZE=$(wc -c < "$DASHBOARD_FILE")
LINES=$(wc -l < "$DASHBOARD_FILE")
echo "File size: $(echo "$FILE_SIZE / 1024" | bc)KB"
echo "Lines: $LINES"

if grep -q "Phase 3" "$DASHBOARD_FILE"; then
  echo -e "${GREEN}✅ Phase 3 dashboard verified${NC}"
else
  echo -e "${RED}❌ Dashboard verification failed${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✅ Dashboard update complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Verify dashboard: open $DASHBOARD_FILE in browser"
echo "2. Test theme toggle: click 🌙/☀️ button"
echo "3. Test date ranges: select 24h, 1 week, 1 month"
echo "4. Deploy: git add -A && git commit -m 'feat(phase3): Add dashboard date range picker' && git push origin master"
echo ""
if [ ! -z "$BACKUP_FILE" ]; then
  echo -e "${YELLOW}📁 Backup location:${NC} $BACKUP_FILE"
  echo "   (Restore with: cp $BACKUP_FILE $DASHBOARD_FILE)"
fi
