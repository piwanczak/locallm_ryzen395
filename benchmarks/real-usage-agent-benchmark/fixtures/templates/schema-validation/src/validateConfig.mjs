export function validateConfig(config) {
  if (!config || typeof config !== "object") {
    throw new Error("config must be an object");
  }

  return {
    mode: config.mode ?? "strict",
    services: Array.isArray(config.services) ? config.services : []
  };
}
