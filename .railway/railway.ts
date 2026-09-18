import { defineRailway, project, service } from "railway/ica";

export const partial = "atlas-phase42";

export default defineRailway(() => {
  const atlas_phase42 = service("atlas-phase42", {
    start: "npm start",
    healthcheck: "/health",
    healthcheckTimeout: 100,
    variables: {
      PORT: "3000",
    },
  });
  return project("atlas-phase42", {
    resources: [atlas_phase42],
  });
});
