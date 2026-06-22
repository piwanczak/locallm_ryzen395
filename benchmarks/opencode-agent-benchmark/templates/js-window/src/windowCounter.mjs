export function countEventsInWindow(events, startMs, endMs) {
  if (!Array.isArray(events)) {
    throw new TypeError("events must be an array");
  }

  return events.filter((event) => {
    return event.timestampMs > startMs && event.timestampMs < endMs;
  }).length;
}
