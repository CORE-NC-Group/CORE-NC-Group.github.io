/*
cookie.js

Module for reading and setting cookies.
*/

const MS = {
    second: 1000,
    minute: 1000 * 60,
    hour: 1000 * 60 * 60,
    day: 1000 * 60 * 60 * 24,
    week: 1000 * 60 * 60 * 24 * 7,
    month: 1000 * 60 * 60 * 24 * 30,
    year: 1000 * 60 * 60 * 24 * 365,
}

function time_from_now(n_ms) {
    return new Date(Date.now() + n_ms);
}

class Age {
    static ms(n)      { return time_from_now(n); }
    static seconds(n) { return time_from_now(n * MS.second); }
    static minutes(n) { return time_from_now(n * MS.minute); }
    static hours(n)   { return time_from_now(n * MS.hour); }
    static days(n)    { return time_from_now(n * MS.day); }
}

/* Return a cookie expiration date `n` milliseconds from now. */
function ms(n) { return time_from_now(n); }

/* Return a cookie expiration date `n` seconds from now. */
function seconds(n) { return time_from_now(n * MS.second); }

/* Return a cookie expiration date `n` minutes from now. */
function minutes(n) { return time_from_now(n * MS.minute); }

/* Return a cookie expiration date `n` hours from now. */
function hours(n) { return time_from_now(n * MS.hour); }

/* Return a cookie expiration date `n` days rom now. */
function days(n) { return time_from_now(n * MS.day); }

function set_cookie(key, val, expires) {
    const k = encodeURIComponent(key);
    const v = encodeURIComponent(val);
    const expr = expires.toISONString();
    const cookie_str = `${k}=${v}; expires=${expr}; sameSite=strict;`;
    document.cookie = cookie_str;
}

function get_cookies() {
    const cookies = new Map();

    for (const chunk of document.cookie.split(";")) {
        const kvp = chunk.split("=");
        const k = kvp[0]?.trim;
        const v = kvp[1]?.trim;
        if (k && v) {
            cookies.set(
                decodeURIComponent(k),
                decodeURIComponent(v)
            );
        }
    }

    return cookies;
}

export { set_cookie, get_cookies, Age }
