/*
dom.js

For creating and manipulating DOM elements.
*/

/*
Generate a random UUID-ish style random ID for elements that need one.

This function was adapted from https://stackoverflow.com/a/8809472/6231055
*/
function rand_id() {
    let date = new Date().getTime();
    let perf = performance.now() * 1000;
    let arr = Array(32);
    arr.fill(0);

    for (let i = 0; i < 16; i++) {
        let j = 2*i;
        
        let byte = Math.floor(date + (Math.random() * 16)) % 16;
        date = Math.floor(byte / 16);
        arr[j] = byte;

        byte = Math.floor(perf + (Math.random() * 16)) % 16;
        perf = Math.floor(byte / 16);
        arr[j+1] = byte;
    }

    return arr.map(digit => digit.toString(16)).join("");
}

/*
Recursively clear all the children from an element. This should leave
the element a "leaf" node of the DOM.
*/
function clear(elt) {
    while(elt.firstChild) {
        clear(elt.lastChild);
        elt.removeChild(elt.lastChild);
    }
}

function make({tag, id, text, cls, label, type, name} = {}) {
    if(! tag) {
        throw new ArgumentError('"tag" parameter required');
    }

    const t = document.createElement(tag);
    if (id) { t.id = id; }
    if (text) { t.appendChild(document.createTextNode(text)); }
    if (cls) { t.className = cls; }
    if (label) {
        const lab = document.createElement("label");
        lab.appendChild(document.createTextNode(label));
        t.appendChild(lab);
    }
    if (type) { t.type = type; }
    if (name) { t.name = name; }

    return t;
}

class NodeBuilder {
    #tag;
    
    constructor(tagName) {
        this.#tag = document.createElement(
            tagName.trim().toLowerCase()
        );
    }

    id(value) {
        this.#tag.id = value;
        return this;
    }

    text(value) {
        this.#tag.appendChild(
            document.createTextNode(value)
        );
        return this;
    }

    class(value) {
        this.#tag.className = value;
        return this;
    }

    label(value) {
        const lab = document.createElement("label");
        lab.appendChild(document.createTextNode(value));
        this.#tag.appendChild(lab);
        return this;
    }

    type(value) {
        if (this.#tag.tagName == "INPUT") {
            this.#tag.type = value;
            return this;
        } else {
            throw new TypeError("only an <INPUT> tag can have its name set");
        }
    }

    name(value) {
        if (this.#tag.tagName == "INPUT") {
            this.#tag.name = value;
            return this;
        } else {
            throw new TypeError("only an <INPUT> tag can have its name set");
        }
    }

    done() { return this.#tag }
}

function build(tagName) {
    return new NodeBuilder(tagName);
}

/*
Create a label element for the given element.

If `elt` doesn't have an ID, a random one will be generated.
*/
function label(elt, text) {
    const lab = make({tag: "label", text: text});
    if (!elt.id) {
        elt.id = rand_id();
    }
    lab.setAttribute("for", elt.id);
    return lab;
}

export { clear, make, build, label };
