const filter = document.querySelector("#filter");
const runs = Array.from(document.querySelectorAll("#runs li"));
const empty = document.querySelector("#empty");

function applyFilter() {
  const query = filter.value.trim();
  let visible = 0;

  for (const run of runs) {
    const haystack = `${run.textContent} ${run.dataset.owner}`;
    const match = haystack.includes(query);
    run.hidden = !match;
    if (match) visible += 1;
  }

  empty.hidden = visible !== 0;
}

filter.addEventListener("input", applyFilter);
applyFilter();
