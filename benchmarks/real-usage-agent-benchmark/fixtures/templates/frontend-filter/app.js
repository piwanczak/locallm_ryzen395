const filter = document.querySelector("#filter");
const rows = Array.from(document.querySelectorAll("#runs tr"));
const count = document.querySelector("#count");
const empty = document.querySelector("#empty");

function applyFilter() {
  const query = filter.value.trim();
  let visible = 0;

  for (const row of rows) {
    const haystack = row.textContent;
    const match = haystack.includes(query);
    row.hidden = !match;
    if (match) visible += 1;
  }

  count.textContent = `${visible} visible`;
  empty.hidden = visible !== 0;
}

filter.addEventListener("input", applyFilter);
applyFilter();
