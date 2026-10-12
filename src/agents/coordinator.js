const crypto = require("crypto");
const { getRiskAgent } = require("./riskAgentInstance");

const tasks = new Map();

// Hver agenttype får en handler. Nye agenter (regnskap, m.fl.) registreres her.
const handlers = {
  risk: (payload) => getRiskAgent().assessTransaction(payload),
};

// Checker: verifiserer at agentens svar faktisk er brukbart.
function check(type, result) {
  const problems = [];
  if (!result || typeof result !== "object") {
    problems.push("tomt svar");
  } else if (type === "risk") {
    if (!Number.isFinite(result.riskScore) || result.riskScore < 0 || result.riskScore > 100) problems.push("riskScore mangler eller er ugyldig");
    if (!["low", "medium", "high"].includes(result.riskLevel)) problems.push("riskLevel ugyldig");
    if (typeof result.recommendation !== "string") problems.push("recommendation mangler");
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

module.exports = { submit, list, get, check, agentTypes: () => Object.keys(handlers) };
