// Timer for koordinatoren. Kjører bare agenter som henter sine data selv (i dag: gull).
// Gmail, Kalender, Regnskap og Fond får data fra planlagte oppgaver i Claude og sendes via POST /api/coordinator/tasks.

const GOLD_EVERY_MINUTES = 15;
const RAPPORT_EVERY_MINUTES = 5;

function startScheduler(submit, { intervalMs = 60 * 1000 } = {}) {
  let lastSlot = null;
  let lastRapportSlot = null;

  function tick(now = new Date()) {
    const slot = Math.floor(now.getTime() / 60000);
    if (now.getUTCMinutes() % GOLD_EVERY_MINUTES === 0 && slot !== lastSlot) {
      lastSlot = slot;
      submit("gold", {});
    }
    if (process.env.RAPPORT_INSTANCES && now.getUTCMinutes() % RAPPORT_EVERY_MINUTES === 0 && slot !== lastRapportSlot) {
      lastRapportSlot = slot;
      submit("rapport", {});
    }
  }

  submit("gold", {}); // kjør én gang ved oppstart
  if (process.env.RAPPORT_INSTANCES) submit("rapport", {});
  const timer = setInterval(() => tick(), intervalMs);
  if (timer.unref) timer.unref();
  return { tick, stop: () => clearInterval(timer) };
}

module.exports = { startScheduler, GOLD_EVERY_MINUTES, RAPPORT_EVERY_MINUTES };
