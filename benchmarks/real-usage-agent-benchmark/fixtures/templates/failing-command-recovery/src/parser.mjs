export function parseCsvLine(line) {
  return line.split(",").map((value) => value.trim());
}
