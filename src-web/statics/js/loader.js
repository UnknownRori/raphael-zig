const ENV = {
    HOST: "http://localhost:6969",
};

/*
 * @params {array<object>} objs
 * @throws
 */
async function registerModule(str) {
    const result = await fetch(`${ENV.HOST}/${str}`);
    if (result.ok && result.headers.get("content-type") === "text/javascript") {
        const text = await result.text();
        eval(text);
    } else {
        throw "Not a valid javascript file";
    }
}

/*
 * @params {array<object>} objs
 */
export async function registerModules(objs) {
    const module = [];
    for (let obj of objs) {
        module.push(registerModule(obj));
    }
    await Promise.all(module);
}
