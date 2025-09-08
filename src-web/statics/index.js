const input = document.querySelector("#query");
const queryResultContainer = document.querySelector("#query-result");
const form = document.querySelector("#query-form");

let page = 1;

/*
 * @param {string} str
 */
function addslashes(str) {
    return (str + '').replace(/[\\"']/g, '\\$&').replace(/\u0000/g, '\\0');
}

/*
 * @param {string} title
 * @return string
 */
function createTagSpan(name) {
    return `
    <span class="tag">${name}</span>
`;
}

function createPaginationButton(page, item, itemPerPage, total) {
    // TODO : Make the pagination button nice
    // Make them disabled instead just gone
    const back = `
        <button class="btn" onclick='pageBack()'>
            &lt
        </button>
`;
    const next = `
        <button class="btn" onclick='pageNext()'>
            >
        </button>
`;
    return `
    <div class="text-center">
        ${page > 1 ? back : ''}
        ${(page * itemPerPage) < total ? next : ''}
    </div>
`;
}

/*
 * @param {string} title
 * @param {string} path
 * @param {Array<string>} tags
 * @param {string} description
 * @return string
 */
function createQueryResultCard(title, path, tags, description) {
    path = addslashes(path);

    const tagsSpan = tags.map((tag) => createTagSpan(tag)).join("");

    return `
            <div class="query-result-card">
                <div>
                    <span class="path">
                        ${path}
                    </span>
                    <h1 class="query-title text-left" onclick='show("${title}","${path}")'>
                        ${title}
                    </h1>
                    ${tagsSpan}
                </div>
                <p>
                    ${description}...
                </p>
            </div>
    `;
}

/*
 * @param {string} path
 */
async function show(name, path) {
    const result = await fetch("http://localhost:6969/show", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body: JSON.stringify({
            file: path,
        }),
    });
    const json = await result.json();

    queryResultContainer.innerHTML = "";
    const container = document.createElement("div");
    queryResultContainer.append(container);
    container.className = "query-result card text-left";
    container.innerHTML += `<h1 class="query-title">${name}</h1>`;

    let content = json.data.replace(/^---[\s\S]*?---/, "").trim();
    container.innerHTML += marked.parse(content);
}

async function fetchSearchQuery() {
    const result = await fetch(`http://localhost:6969/query?page=${page}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body: JSON.stringify({
            query: input.value,
        }),
    });
    const json = await result.json();

    queryResultContainer.innerHTML = "";
    const container = document.createElement("div");
    queryResultContainer.append(container);
    container.className = "query-result card text-left";
    if (json.result.length < 1) {
        container.innerHTML += "<p class='text-secondary' style='width: 200px'>No results found</p>";
    }
    for (let i = 0; i < json.result.length; i++) {
        const item = json.result[i];
        const metadata = item.metadata;
        container.innerHTML += createQueryResultCard(item.name, item.path, metadata.tags, metadata.description)
    }

    const pagination = json.pagination;
    container.innerHTML += createPaginationButton(pagination.page, pagination.item, pagination.max_item, pagination.total_item);
}
form.addEventListener('submit', async (e) => {
    e.preventDefault();
    page = 1;
    await fetchSearchQuery();
});


async function pageBack() {
    if (page > 1) {
        page -= 1;
    }
    await fetchSearchQuery();
}

async function pageNext() {
    page += 1;
    await fetchSearchQuery();
}
