const input = document.querySelector("#query");
const form = document.querySelector("#query-form");
form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const result = await fetch("http://localhost:6969/query", {
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
    console.log(json);
});
