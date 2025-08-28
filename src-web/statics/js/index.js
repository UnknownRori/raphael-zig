import { registerModules } from './loader.js';

(async () => {
})();

//const input = document.querySelector("#query");
//const queryResultContainer = document.querySelector("#query-result");
//const form = document.querySelector("#query-form");
//
//const lorem = `
//Lorem ipsum dolor sit amet consectetur adipisicing elit. Asperiores similique nesciunt adipisci eos
//nisi fugiat, rerum tempore exercitationem neque consequuntur recusandae ab voluptatum dolorem nobis
//quas minima totam dolore! Eveniet!
//`;
//
///*
// * @param {string} str
// */
//function addslashes(str) {
//    return (str + '').replace(/[\\"']/g, '\\$&').replace(/\u0000/g, '\\0');
//}
//
///*
// * @param {string} title
// * @return string
// */
//function createTagSpan(name) {
//    return `
//    <span class="tag">${name}</span>
//`;
//}
//
///*
// * @param {string} title
// * @param {string} path
// * @param {Array<string>} tags
// * @param {string} description
// * @return string
// */
//function createQueryResultCard(title, path, tags, description) {
//    path = addslashes(path);
//
//    const tagsSpan = tags.map((tag) => createTagSpan(tag)).join("");
//
//    return `
//            <div class="query-result-card">
//                <div>
//                    <span class="path">
//                        ${path}
//                    </span>
//                    <h1 class="query-title text-left" onclick='show("${title}","${path}")'>
//                        ${title}
//                    </h1>
//                    ${tagsSpan}
//                </div>
//                <p>
//                    ${description}...
//                </p>
//            </div>
//    `;
//}
//
///*
// * @param {string} path
// */
//async function show(name, path) {
//    const result = await fetch("http://localhost:6969/show", {
//        method: "POST",
//        headers: {
//            "Content-Type": "application/json",
//            "Accept": "application/json",
//        },
//        body: JSON.stringify({
//            file: path,
//        }),
//    });
//    const json = await result.json();
//
//    queryResultContainer.innerHTML = "";
//    const container = document.createElement("div");
//    queryResultContainer.append(container);
//    container.className = "query-result card text-left";
//    container.innerHTML += `<h1 class="query-title">${name}</h1>`;
//
//    let content = json.data.replace(/^---[\s\S]*?---/, "").trim();
//    container.innerHTML += marked.parse(content);
//}
//
//
//form.addEventListener('submit', async (e) => {
//    e.preventDefault();
//
//    const result = await fetch("http://localhost:6969/query", {
//        method: "POST",
//        headers: {
//            "Content-Type": "application/json",
//            "Accept": "application/json",
//        },
//        body: JSON.stringify({
//            query: input.value,
//        }),
//    });
//    const json = await result.json();
//
//    queryResultContainer.innerHTML = "";
//    const container = document.createElement("div");
//    queryResultContainer.append(container);
//    container.className = "query-result card text-left";
//    if (json.result.length < 1) {
//        container.innerHTML += "<p class='text-secondary' style='width: 200px'>No results found</p>";
//    }
//    for (let i = 0; i < json.result.length; i++) {
//        const item = json.result[i];
//        const metadata = item.metadata;
//        container.innerHTML += createQueryResultCard(item.name, item.path, metadata.tags, metadata.description)
//    }
//});

