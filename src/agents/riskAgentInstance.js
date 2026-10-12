const RiskAgent = require("./RiskAgent");

let instance = null;

// Én delt RiskAgent for hele appen, slik at stats og webhook bruker samme historikk.
function getRiskAgent() {
  if (!instance) {
    instance = new RiskAgent(process.env.ANTHROPIC_API_KEY);
  }
  return instance;
}

module.exports = { getRiskAgent };
