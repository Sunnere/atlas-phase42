// Timer for koordinatoren. Kjører bare agenter som henter sine data selv (i dag: gull).
// Gmail, Kalender, Regnskap og Fond får data fra planlagte oppgaver i Claude og sendes via POST /api/coordinator/tasks.

const GOLD_EVERY_MINUTES = 15;

function startScheduler(submit, { intervalMs = 60 * 1000 } = {}) {
  let lastSlot = null;

  function tick(now = new Date()) {
    const slot = Math.floor(now.getTime() / 60000);
    if (now.getUTCMinutes() % GOLD_EVERY_MINUTES === 0 && slot !== lastSlot) {
      lastSlot = slot;
      submit("gold", {});
    }
  }

  submit("gold", {}); // kjør én gang ved oppstart
  const timer = setInterval(() => tick(), intervalMs);
  if (timer.unref) timer.unref();
  return { tick, stop: () => clearInterval(timer) };
}

module.exports = { startScheduler, GOLD_EVERY_MINUTES };
