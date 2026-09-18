import { defineRailway, project, service } from "railway/ica";

// This repository manages only its own resources in the environment. Other
// repositories export their own partial name.
// See https://docs.railway.com/infrastructure-as-code#multi-repo-projects
export const partial = "atlas-phase42";

export default defineRailway(() => {
  const atlas_phase42 = service("atlas-phase42", {
    start: "npm start",
    healthcheck: "/health",
    healthcheckTimeout: 100,
    // builder from CaC: "nixpacks"
  });
  return project("atlas-phase42", {
    resources: [atlas_phase42],
  });
});
