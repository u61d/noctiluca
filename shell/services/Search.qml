pragma Singleton
import QtQuick
import Quickshell

// a small parser, not eval(): the launcher evaluates whatever you type
Singleton {
    id: root

    // tiers, so a tighter kind of match always wins (otherwise "fox" ranked
    // "Fresh Oxide Xterm" above "Firefox")
    //   exact 1000, prefix 700-800, contiguous 400-600, subsequence 1-300
    function score(needle: string, haystack: string): real {
        if (needle === "") return 0.001;
        const n = needle.toLowerCase();
        const h = haystack.toLowerCase();
        if (h === n) return 1000;

        const brevity = Math.max(0, 40 - haystack.length) * 0.5;

        if (h.startsWith(n)) return 700 + brevity;

        const at = h.indexOf(n);
        if (at >= 0) {
            const boundary = " -_/.".indexOf(h[at - 1]) >= 0;
            return 400 + (boundary ? 60 : 0) + Math.max(0, 40 - at) + brevity;
        }

        let hi = 0, total = 0, run = 0;
        for (let ni = 0; ni < n.length; ni++) {
            const c = n[ni];
            let found = -1;
            while (hi < h.length) {
                if (h[hi] === c) { found = hi; break; }
                hi++;
            }
            if (found < 0) return 0;
            const boundary = found === 0 || " -_/.".indexOf(h[found - 1]) >= 0;
            // count the run before paying out so the first adjacent pair scores
            run = (found === hi && ni > 0) ? run + 1 : 0;
            total += 10 + (boundary ? 8 : 0) + run * 18;
            hi = found + 1;
        }
        return Math.min(300, total) + brevity;
    }

    readonly property var constants: ({ pi: Math.PI, e: Math.E })
    readonly property var functions: ({
        sqrt: Math.sqrt, abs: Math.abs, floor: Math.floor, ceil: Math.ceil, round: Math.round,
        sin: Math.sin, cos: Math.cos, tan: Math.tan, log: Math.log, log2: Math.log2,
        log10: Math.log10, exp: Math.exp
    })

    function tokenize(src: string): var {
        const out = [];
        let i = 0;
        while (i < src.length) {
            const c = src[i];
            if (c === " " || c === "\t" || c === ",") { i++; continue; }
            if (c >= "0" && c <= "9" || c === ".") {
                let j = i;
                while (j < src.length && ((src[j] >= "0" && src[j] <= "9") || src[j] === ".")) j++;
                const v = parseFloat(src.slice(i, j));
                if (isNaN(v)) return null;
                out.push({ k: "num", v: v });
                i = j;
                continue;
            }
            if ((c >= "a" && c <= "z") || (c >= "A" && c <= "Z")) {
                let j = i;
                while (j < src.length && /[a-zA-Z0-9_]/.test(src[j])) j++;
                out.push({ k: "name", v: src.slice(i, j).toLowerCase() });
                i = j;
                continue;
            }
            if ("+-*/%^()".indexOf(c) >= 0) { out.push({ k: "op", v: c }); i++; continue; }
            return null;                          // an unknown character means "not a sum"
        }
        return out;
    }

    readonly property var precedence: ({ "+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "^": 3 })

    function evaluate(src: string): var {
        const tokens = root.tokenize(src);
        if (!tokens || tokens.length === 0) return null;

        const values = [], ops = [];
        let prevKind = "start";

        function applyTop() {
            const op = ops.pop();
            if (op === undefined) return false;
            if (op === "u-") {
                if (values.length < 1) return false;
                values.push(-values.pop());
                return true;
            }
            if (typeof op === "object") {               // a function call
                if (values.length < 1) return false;
                values.push(op.fn(values.pop()));
                return true;
            }
            if (values.length < 2) return false;
            const b = values.pop(), a = values.pop();
            switch (op) {
            case "+": values.push(a + b); break;
            case "-": values.push(a - b); break;
            case "*": values.push(a * b); break;
            case "/": values.push(a / b); break;
            case "%": values.push(a % b); break;
            case "^": values.push(Math.pow(a, b)); break;
            default: return false;
            }
            return true;
        }

        for (const t of tokens) {
            if (t.k === "num") {
                values.push(t.v);
                prevKind = "value";
            } else if (t.k === "name") {
                if (root.constants[t.v] !== undefined) {
                    values.push(root.constants[t.v]);
                    prevKind = "value";
                } else if (root.functions[t.v] !== undefined) {
                    ops.push({ fn: root.functions[t.v] });
                    prevKind = "func";
                } else {
                    return null;                        // unknown word: not a calculation
                }
            } else if (t.v === "(") {
                ops.push("(");
                prevKind = "open";
            } else if (t.v === ")") {
                while (ops.length && ops[ops.length - 1] !== "(")
                    if (!applyTop()) return null;
                if (!ops.length) return null;
                ops.pop();
                if (ops.length && typeof ops[ops.length - 1] === "object")
                    if (!applyTop()) return null;
                prevKind = "value";
            } else {
                // a minus after an operator or ( is a sign
                if (t.v === "-" && (prevKind === "start" || prevKind === "op" || prevKind === "open")) {
                    ops.push("u-");
                    prevKind = "op";
                    continue;
                }
                const p = root.precedence[t.v];
                if (p === undefined) return null;
                while (ops.length) {
                    const top = ops[ops.length - 1];
                    if (top === "(" || typeof top === "object") break;
                    const tp = top === "u-" ? 4 : root.precedence[top];
                    if (tp === undefined) break;
                    if (tp > p || (tp === p && t.v !== "^")) {
                        if (!applyTop()) return null;
                    } else break;
                }
                ops.push(t.v);
                prevKind = "op";
            }
        }
        while (ops.length) {
            if (ops[ops.length - 1] === "(") return null;
            if (!applyTop()) return null;
        }
        if (values.length !== 1) return null;
        const r = values[0];
        return (typeof r === "number" && isFinite(r)) ? r : null;
    }

    // "10 km to mi", "72f in c", "3.5 gib to mb". sizes in the base unit of each kind,
    // temperature is the odd one out
    readonly property var units: ({
        length: { mm: 0.001, cm: 0.01, m: 1, km: 1000, "in": 0.0254, inch: 0.0254, inches: 0.0254, ft: 0.3048,
                  foot: 0.3048, feet: 0.3048, yd: 0.9144, mi: 1609.344, mile: 1609.344, miles: 1609.344, nmi: 1852 },
        mass: { mg: 0.001, g: 1, kg: 1000, t: 1e6, oz: 28.349523125, lb: 453.59237, lbs: 453.59237, st: 6350.29318 },
        time: { ms: 0.001, s: 1, sec: 1, min: 60, h: 3600, hr: 3600, d: 86400, day: 86400, days: 86400,
                wk: 604800, week: 604800, weeks: 604800, yr: 31557600, year: 31557600, years: 31557600 },
        data: { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
        volume: { ml: 0.001, cl: 0.01, dl: 0.1, l: 1, tsp: 0.00492892, tbsp: 0.0147868, floz: 0.0295735,
                  cup: 0.24, cups: 0.24, pt: 0.473176, qt: 0.946353, gal: 3.78541 },
        speed: { "m/s": 1, mps: 1, "km/h": 0.277778, kmh: 0.277778, kph: 0.277778, mph: 0.44704, kn: 0.514444, knots: 0.514444 },
        temperature: { c: 1, f: 1, k: 1 }
    })
    function kindOf(u: string): string {
        for (const k in root.units) if (u in root.units[k]) return k;
        return "";
    }
    // { value, from, to, result } or null
    function convert(src: string): var {
        const m = /^\s*(-?[\d.]+)\s*([a-z\/°]+)\s+(?:to|in|as|->|=)\s+([a-z\/°]+)\s*$/i.exec(src.trim());
        if (!m) return null;
        const v = parseFloat(m[1]);
        const a = m[2].toLowerCase().replace("°", ""), b = m[3].toLowerCase().replace("°", "");
        if (!isFinite(v)) return null;
        const ka = root.kindOf(a), kb = root.kindOf(b);
        if (ka === "" || ka !== kb) return null;
        let r;
        if (ka === "temperature") {
            const c = a === "c" ? v : a === "f" ? (v - 32) * 5 / 9 : v - 273.15;
            r = b === "c" ? c : b === "f" ? c * 9 / 5 + 32 : c + 273.15;
        } else {
            r = v * root.units[ka][a] / root.units[kb][b];
        }
        return { value: v, from: a, to: b, result: r };
    }
    function formatUnit(u: string): string {
        return ({ c: "°C", f: "°F", k: "K" })[u] || u;
    }

    function formatNumber(v: real): string {
        if (Number.isInteger(v)) return String(v);
        if (Math.abs(v) >= 1e12 || (Math.abs(v) < 1e-6 && v !== 0)) return v.toExponential(4);
        const s = v.toFixed(6).replace(/0+$/, "").replace(/\.$/, "");
        return s;
    }
}
