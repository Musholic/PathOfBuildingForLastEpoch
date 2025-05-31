// https://www.lastepochtools.com/profile/js/script.js
function le_e(a) {
    return null != a.displayNameKey ? (a = le_c(a.displayNameKey),
    le_wa(a)) : a.displayName
}
JSON.stringify(Object.fromEntries(Object.entries(le_k).map(([k, v]) => [k, le_e(v)])))
JSON.stringify(Object.fromEntries(Object.entries(le_n).concat(Object.entries(le_m)).map(([k, v]) => [k, v.affixId])))