// Selvtest for koordinatoren. Kjøres med: node scripts/test_agents.js
const assert = require("assert");
const coordinator = require("../src/agents/coordinator");

function waitFor(task) {
  return new Promise((resolve, reject) => {
    const t0 = Date.now();
    const timer = setInterval(() => {
      const cur = coordinator.get(task.id);
      if (cur.status !== "queued" && cur.status !== "running") {
        clearInterval(timer);
        resolve(cur);
      } else if (Date.now() - t0 > 2000) {
        clearInterval(timer);
        reject(new Error("tidsavbrudd for " + task.type));
      }
    }, 10);
  });
}

function monthly(start, closes) {
  return closes.map((close, i) => {
    const d = new Date(Date.UTC(start[0], start[1] - 1 + i, 1));
    return { date: `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`, close };
  });
}

(async () => {
  assert.deepStrictEqual(coordinator.agentTypes(), ["risk", "regnskap", "fund", "gmail", "calendar"]);

  // regnskap (fra script 14)
  const okReg = await waitFor(coordinator.submit("regnskap", { type: "income", amount: 3272.5, date: "2026-02-27", source: "Airbnb" }));
  assert.strictEqual(okReg.status, "done");
  assert.strictEqual(okReg.result.category, "Utleieinntekt (kortidsutleie)");
  const badReg = await waitFor(coordinator.submit("regnskap", { type: "income", amount: -5, date: "2026-03-01" }));
  assert.strictEqual(badReg.status, "failed");

  // fund (fra script 14)
  const rising = await waitFor(coordinator.submit("fund", { name: "Test-fond", closes: monthly([2020, 1], Array.from({ length: 40 }, (_, i) => 100 * Math.pow(1.01, i))) }));
  assert.strictEqual(rising.result.rating, "GRØNN");
  const falling = await waitFor(coordinator.submit("fund", { name: "Falt", closes: monthly([2020, 1], Array.from({ length: 40 }, (_, i) => 100 * Math.pow(0.99, i))) }));
  assert.strictEqual(falling.result.rating, "RØD");

  // gmail
  const mail = await waitFor(coordinator.submit("gmail", {
    messages: [
      { from: "notice@adtraction.com", subject: "Godkjent: CS Megastore", date: "2026-10-13" },
      { from: "security@bank.no", subject: "Bekreft innlogging", date: "2026-10-13" },
      { from: "kontakt@curli.no", subject: "Ny kampanje", date: "2026-10-12" },
    ],
  }));
  assert.strictEqual(mail.status, "done");
  assert.strictEqual(mail.result.counts.partner, 1);
  assert.strictEqual(mail.result.counts.haster, 1);
  assert.strictEqual(mail.result.counts.info, 1);
  const badMail = await waitFor(coordinator.submit("gmail", { messages: [{ subject: "uten avsender" }] }));
  assert.strictEqual(badMail.status, "failed");

  // calendar
  const now = "2026-10-13T08:00:00Z";
  const cal = await waitFor(coordinator.submit("calendar", {
    now,
    events: [
      { summary: "Airbnb – gjest", start: "2026-10-14T13:00:00Z", end: "2026-10-14T18:00:00Z" },
      { summary: "Møte", start: "2026-10-14T16:00:00Z", end: "2026-10-14T17:00:00Z" },
      { summary: "Langt senere", start: "2026-11-01T10:00:00Z", end: "2026-11-01T11:00:00Z" },
    ],
  }));
  assert.strictEqual(cal.status, "done");
  assert.strictEqual(cal.result.counts.upcoming, 2);
  assert.strictEqual(cal.result.counts.conflicts, 1);
  assert.strictEqual(cal.result.upcoming[0].airbnb, true);
  const badCal = await waitFor(coordinator.submit("calendar", { events: [{ summary: "x", start: "ikke-dato", end: "2026-10-14T18:00:00Z" }] }));
  assert.strictEqual(badCal.status, "failed");

  console.log("Alle selvtester bestått (16 sjekker).");
})().catch((e) => {
  console.error("SELVTEST FEILET:", e.message);
  process.exit(1);
});
