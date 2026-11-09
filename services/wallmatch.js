.pragma library
// Theme that best matches a wallpaper.
//
// 1. palette(): the image (a few thousand RGBA pixels, drawn small) is
//    reduced with k-means to its main colors, in OKLab (a color space where
//    distances match how different two colors look): for each color its
//    share of the image, lightness and chroma.
// 2. score(): how well a theme fits that palette (lower = better):
//    - accent: the theme accent should look like one of the vivid colors of
//      the image, better if that color is a large part of it;
//    - coverage: every color of the image should have a similar color in
//      the theme (accent + the 6 ANSI colors), weighted by its share;
//    - tint: the theme background tint (bluish, greenish, warm grey...)
//      should follow the general tint of the image;
//    - vividness: a pale image wants a theme with soft colors, a vivid one
//      a theme with saturated colors.
// Pure JavaScript (no Qt): also runs under node for tests.

// ---------- Colors ----------
function srgbToLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

// r, g, b in 0..1 -> [L, a, b] OKLab
function oklab(r, g, b) {
    r = srgbToLinear(r); g = srgbToLinear(g); b = srgbToLinear(b)
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s]
}

// "#rrggbb" or "#aarrggbb" -> OKLab
function hexLab(hex) {
    var h = String(hex || "").replace("#", "")
    if (h.length === 8) h = h.substring(2)
    if (h.length !== 6) return null
    var n = parseInt(h, 16)
    return oklab(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255)
}

function chroma(c) { return Math.sqrt(c[1] * c[1] + c[2] * c[2]) }

// Difference of hue and chroma, lightness counts less: theme colors are
// light (text on a dark background), the same color in a photo often darker
function colorDist(x, y, lw) {
    var dl = (x[0] - y[0]) * (lw === undefined ? 0.35 : lw)
    var da = x[1] - y[1], db = x[2] - y[2]
    return Math.sqrt(dl * dl + da * da + db * db)
}

// ---------- Image palette ----------
// data: RGBA bytes (Canvas getImageData().data or a raw dump), k colors
// -> { colors: [{ lab, weight, chroma }], meanL, meanChroma, tint: [a, b] }
function palette(data, k) {
    k = k || 6
    var px = []
    for (var i = 0; i + 3 < data.length; i += 4) {
        if (data[i + 3] < 128) continue
        px.push(oklab(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255))
    }
    var n = px.length
    if (n === 0) return null

    var meanL = 0, meanA = 0, meanB = 0, meanC = 0
    for (i = 0; i < n; i++) {
        meanL += px[i][0]; meanA += px[i][1]; meanB += px[i][2]; meanC += chroma(px[i])
    }
    meanL /= n; meanA /= n; meanB /= n; meanC /= n

    // Hue map: for every hue (36 steps of 10 degrees) how much of the image
    // shows it, counting how vivid each pixel is. Greys, near-black and
    // near-white pixels add nothing: a big grey area does not make a small
    // pink detail less pink. Smoothed so that close hues help each other
    var bins = 36, raw = []
    for (i = 0; i < bins; i++) raw.push(0)
    var colorful = 0
    for (i = 0; i < n; i++) {
        var p = px[i], ch = chroma(p)
        var w = Math.max(0, ch - 0.02) * Math.min(1, p[0] / 0.35) * Math.min(1, (1 - p[0]) / 0.1)
        if (w <= 0) continue
        var h = Math.atan2(p[2], p[1]) / (2 * Math.PI)
        raw[Math.floor(((h + 1) % 1) * bins) % bins] += w
        colorful += w
    }
    var hues = []
    for (i = 0; i < bins; i++) {
        var v = 0
        for (var o = -3; o <= 3; o++)
            v += raw[(i + o + bins) % bins] * Math.exp(-o * o / 4.5)
        hues.push(v)
    }
    var top = 0
    for (i = 0; i < bins; i++) top = Math.max(top, hues[i])
    for (i = 0; i < bins; i++) hues[i] = top > 0 ? hues[i] / top : 0

    // Starting centers, always the same for the same image (k-means++
    // without randomness): each one the pixel farthest from those chosen.
    // Chroma counts double, so a small vivid detail (a red roof in the
    // snow) gets its own color instead of vanishing into the grey
    function sep(x, y) {
        var dl = x[0] - y[0], da = (x[1] - y[1]) * 2, db = (x[2] - y[2]) * 2
        return dl * dl + da * da + db * db
    }
    var centers = [[meanL, meanA, meanB]]
    var near = []
    for (i = 0; i < n; i++) near.push(sep(px[i], centers[0]))
    while (centers.length < k) {
        var far = 0
        for (i = 1; i < n; i++) if (near[i] > near[far]) far = i
        if (near[far] < 1e-6) break     // fewer distinct colors than k
        var c = px[far].slice()
        centers.push(c)
        for (i = 0; i < n; i++) near[i] = Math.min(near[i], sep(px[i], c))
    }
    k = centers.length

    var assign = new Array(n)
    for (var it = 0; it < 12; it++) {
        var sums = [], moved = false
        for (var j = 0; j < k; j++) sums.push([0, 0, 0, 0])
        for (i = 0; i < n; i++) {
            var best = 0, bestD = 1e9
            for (j = 0; j < k; j++) {
                var d = sep(px[i], centers[j])
                if (d < bestD) { bestD = d; best = j }
            }
            if (assign[i] !== best) { assign[i] = best; moved = true }
            var s = sums[best]
            s[0] += px[i][0]; s[1] += px[i][1]; s[2] += px[i][2]; s[3]++
        }
        for (j = 0; j < k; j++)
            if (sums[j][3] > 0)
                centers[j] = [sums[j][0] / sums[j][3], sums[j][1] / sums[j][3], sums[j][2] / sums[j][3]]
        if (!moved) break
    }

    var counts = []
    for (j = 0; j < k; j++) counts.push(0)
    for (i = 0; i < n; i++) counts[assign[i]]++
    var colors = []
    for (j = 0; j < k; j++) {
        if (counts[j] === 0) continue
        colors.push({ lab: centers[j], weight: counts[j] / n, chroma: chroma(centers[j]) })
    }
    colors.sort(function (x, y) { return y.weight - x.weight })
    return { colors: colors, meanL: meanL, meanChroma: meanC, tint: [meanA, meanB],
             hues: hues, colorful: colorful / n }
}

// ---------- Theme signature ----------
// { accent, bg, swatches: [accent + ANSI 1..6], chroma }
function signature(theme) {
    var c = theme.colors || {}
    var accent = hexLab(c.accent), bg = hexLab(c.card || c.background)
    if (!accent || !bg) return null
    var sw = [accent]
    var ansi = (theme.terminal && theme.terminal.ansi) || []
    for (var i = 1; i <= 6; i++) {
        var x = hexLab(ansi[i])
        if (x) sw.push(x)
    }
    var ch = 0
    for (i = 0; i < sw.length; i++) ch += chroma(sw[i])
    return { accent: accent, bg: bg, swatches: sw, chroma: ch / sw.length }
}

// ---------- Fit of a theme to a palette (lower = better) ----------
// Hue of a color in the hue map (0..1: share of the strongest hue)
function hueSupport(pal, c) {
    var h = Math.atan2(c[2], c[1]) / (2 * Math.PI)
    var x = ((h + 1) % 1) * pal.hues.length - 0.5
    var i = Math.floor(x), f = x - i, n = pal.hues.length
    return pal.hues[(i + n) % n] * (1 - f) + pal.hues[(i + 1) % n] * f
}

function score(pal, sig) {
    // How colored the image is: 0 grey / black and white, 1 colorful.
    // Few colors (a pink detail on a black image) are still enough for the
    // accent to follow them
    var colored = Math.min(1, pal.colorful / 0.012)

    // 1. Accent: its hue must be one the image really shows, the main one
    //    best. A black and white image says nothing about the accent
    var accC = chroma(sig.accent)
    var acc = colored * (1 - hueSupport(pal, sig.accent)) * Math.min(1, accC / 0.06)

    // 2. Coverage: the colors of the image (only the colored ones, by their
    //    share) against the closest color of the theme
    var cols = pal.colors, cov = 0, cw = 0
    for (var i = 0; i < cols.length; i++) {
        var w = cols[i].weight * Math.min(1, cols[i].chroma / 0.06)
        if (w <= 0) continue
        var m = 1e9
        for (var j = 0; j < sig.swatches.length; j++)
            m = Math.min(m, colorDist(sig.swatches[j], cols[i].lab, 0.2))
        cov += w * m; cw += w
    }
    cov = cov / (cw + 0.05)

    // 3. Background tint: theme background against the tint of the image,
    //    scaled down (theme backgrounds are almost grey). It decides for
    //    black and white images: neutral background, no blue or violet cast
    var ta = pal.tint[0] * 0.4, tb = pal.tint[1] * 0.4
    var da = sig.bg[1] - ta, db = sig.bg[2] - tb
    var tint = Math.sqrt(da * da + db * db)

    // 4. Vividness: soft themes for pale images, saturated for vivid ones
    var viv = Math.abs(Math.min(0.16, pal.meanChroma * 1.6 + 0.04) - sig.chroma)

    return 0.5 * acc + 0.8 * cov + (1.2 + 3 * (1 - colored)) * tint + 0.5 * viv
}

// themes: [{ id, colors, terminal }] -> id of the best one ("" if none)
function best(data, themes) {
    var r = rank(data, themes)
    return r.length > 0 ? r[0].id : ""
}

// All themes with their score, best first (for tests)
function rank(data, themes) {
    var pal = palette(data, 6)
    if (!pal) return []
    var out = []
    for (var i = 0; i < themes.length; i++) {
        var sig = signature(themes[i])
        if (sig) out.push({ id: themes[i].id, score: score(pal, sig) })
    }
    out.sort(function (x, y) { return x.score - y.score })
    return out
}
