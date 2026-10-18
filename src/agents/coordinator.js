const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");
const { assessRegnskap } = require("./handlers/regnskapAgent");
const { analyseFund } = require("./handlers/fundMonitorAgent");
const { assessGmail } = require("./handlers/gmailAgent");
const { assessCalendar } = require("./handlers/calendarAgent");
const { analyseGold, checkGold } = require("./handlers/goldAgent");
const store = require("./store");

const tasks = new Map();

// Hver agenttype får en handler. Nye agenter registreres her.
const handlers = {
  risk: (payload) => getRiskAgent().assessTransaction(payload),
  regnskap: (payload) => assessRegnskap(payload),
  fund: (payload) => analyseFund(payload),
  gmail: (payload) => assessGmail(payload),
  calendar: (payload) => assessCalendar(payload),
  gold: (payload) => analyseGold(payload),
};

const RATINGS = ["GRØNN", "ORANSJE", "RØD", "GRÅ (for kort historikk)"];

// Checker: verifiserer at agentens svar faktisk er brukbart.
function check(type, result) {
  const problems = [];
  if (!result || typeof result !== "object") {
    problems.push("tomt svar");
  } else if (type === "risk") {
    if (!Number.isFinite(result.riskScore) || result.riskScore < 0 || result.riskScore > 100) problems.push("riskScore mangler eller er ugyldig");
    if (!["low", "medium", "high"].includes(result.riskLevel)) problems.push("riskLevel ugyldig");
    if (typeof result.recommendation !== "string") problems.push("recommendation mangler");
  } else if (type === "regnskap") {
    if (!["income", "expense"].includes(result.type)) problems.push("type ugyldig");
    if (typeof result.category !== "string" || !result.category) problems.push("kategori mangler");
  } else if (type === "fund") {
    if (!RATINGS.includes(result.rating)) problems.push("rating ugyldig");
    if (!Number.isFinite(result.ann)) problems.push("annualisert avkastning ugyldig");
  } else if (type === "gmail") {
    if (!result.counts || !Number.isFinite(result.counts.total)) problems.push("counts mangler");
  } else if (type === "calendar") {
    if (!Array.isArray(result.upcoming)) problems.push("upcoming mangler");
  } else if (type === "gold") {
    problems.push(...checkGold(result));
  }
  return { ok: problems.length === 0, problems };
}

async function run(task) {
  task.status = "running";
  const handler = handlers[task.type];
  if (!handler) {
    task.status = "failed";
    task.error = `ukjent agenttype: ${task.type}`;
    return;
  }
  try {
    task.result = await handler(task.payload);
    task.check = check(task.type, task.result);
    task.status = task.check.ok ? "done" : "needs_review";
  } catch (err) {
    task.status = "failed";
    task.error = err.message;
  }
  task.finishedAt = new Date().toISOString();
  if (task.status === "done" || task.status === "needs_review") store.record(task);
}

function submit(type, payload) {
  const task = {
    id: crypto.randomUUID(),
    type,
    status: "queued",
    createdAt: new Date().toISOString(),
    payload,
    result: null,
    check: null,
    error: null,
  };
  tasks.set(task.id, task);
  run(task); // kjører i bakgrunnen
  return task;
}

function list() {
  return [...tasks.values()].slice(-100).reverse();
}

function get(id) {
  return tasks.get(id) || null;
}

module.exports = { submit, list, get, check, latest: () => store.getLatest(), agentTypes: () => Object.keys(handlers) };
