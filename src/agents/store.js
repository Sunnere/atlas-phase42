// Lagrer siste ferdige resultat per agenttype til disk, slik at det overlever restart.
// På Railway uten volum nullstilles data/ ved deploy. Sett COORDINATOR_STORE til en volum-sti for å beholde den.
const fs = require("fs");
const path = require("path");

const FILE = process.env.COORDINATOR_STORE || path.join(__dirname, "..", "..", "data", "coordinator-latest.json");
let latest = {};

function load() {
  try {
    latest = JSON.parse(fs.readFileSync(FILE, "utf8"));
  } catch (_) {
    latest = {};
  }
}

function save() {
  try {
    fs.mkdirSync(path.dirname(FILE), { recursive: true });
    fs.writeFileSync(FILE, JSON.stringify(latest, null, 2));
  } catch (err) {
    console.error("[coordinator] kunne ikke lagre resultat:", err.message);
  }
}

function record(task) {
  latest[task.type] = {
    taskId: task.id,
    status: task.status,
    finishedAt: task.finishedAt,
    check: task.check,
    result: task.result,
  };
  save();
}

function getLatest() {
  return latest;
}

load();
module.exports = { record, getLatest, FILE };
