// Navigation, pied de page et graphiques en SVG (aucune bibliothèque externe : le site fonctionne en local, hors ligne).
(function () {
  var pages = [
    ["index.html", "Le métier"],
    ["offres.html", "Offres et marché"],
    ["competences.html", "Compétences"],
    ["evolution.html", "Évolution"],
    ["acteurs.html", "Acteurs"],
    ["position.html", "Ma position"],
    ["methode.html", "Comment c'est fait"]
  ];
  var courante = location.pathname.split("/").pop() || "index.html";
  var nav = pages.map(function (p) {
    return '<a href="' + p[0] + '"' + (p[0] === courante ? ' aria-current="page"' : "") + ">" + p[1] + "</a>";
  }).join("");
  document.body.insertAdjacentHTML("afterbegin",
    '<header class="site"><div class="barre"><span class="titre">Chef de produit · veille métier</span>' + nav + "</div></header>");
  document.body.insertAdjacentHTML("beforeend",
    "<footer>Séminaires métiers · M2 Marketing Opérationnel & Digital · IAE Clermont Auvergne · Données au " +
    (window.DONNEES ? window.DONNEES.extraction : "?") + " · Site statique, aucune donnée collectée.</footer>");
})();

var fmt = function (n) { return n == null ? "n.d." : Math.round(n).toLocaleString("fr-FR"); };

// Courbe simple : points = [{x: "2021T1", y: 460}, ...]. Étiquette le maximum et la dernière valeur.
function courbe(conteneur, points, couleur, unite) {
  var L = 640, H = 220, g = 44, d = 16, b = 30, h = 14;
  var ys = points.map(function (p) { return p.y; });
  var max = Math.max.apply(null, ys), min = 0;
  var X = function (i) { return g + (points.length === 1 ? 0 : i * (L - g - d) / (points.length - 1)); };
  var Y = function (v) { return H - b - (v - min) / (max - min || 1) * (H - b - h); };
  var s = '<svg viewBox="0 0 ' + L + " " + H + '" role="img" aria-label="Courbe ' + (unite || "") + '">';
  [0, 0.5, 1].forEach(function (t) {
    var v = min + t * (max - min), y = Y(v);
    s += '<line x1="' + g + '" x2="' + (L - d) + '" y1="' + y + '" y2="' + y + '" stroke="var(--trait)"/>' +
      '<text x="' + (g - 6) + '" y="' + (y + 4) + '" text-anchor="end" font-size="11" fill="var(--discret)" font-family="system-ui">' + fmt(v) + "</text>";
  });
  points.forEach(function (p, i) {
    if ((i % 4 === 0 && points.length - 1 - i >= 2) || i === points.length - 1)
      s += '<text x="' + X(i) + '" y="' + (H - 10) + '" text-anchor="middle" font-size="11" fill="var(--discret)" font-family="system-ui">' + p.x + "</text>";
  });
  s += '<polyline fill="none" stroke="' + couleur + '" stroke-width="2.5" points="' +
    points.map(function (p, i) { return X(i) + "," + Y(p.y); }).join(" ") + '"/>';
  var im = ys.indexOf(max), dern = points.length - 1;
  [im, dern].forEach(function (i, k) {
    if (k === 1 && i === im) return;
    s += '<circle cx="' + X(i) + '" cy="' + Y(points[i].y) + '" r="4" fill="' + couleur + '"/>' +
      '<text x="' + X(i) + '" y="' + (Y(points[i].y) - 8) + '" text-anchor="' + (i === dern ? "end" : "middle") +
      '" font-size="12" font-weight="bold" fill="var(--texte)" font-family="system-ui">' + fmt(points[i].y) + "</text>";
  });
  document.getElementById(conteneur).innerHTML = s + "</svg>";
}

function serie(liste, territoire, cle) {
  return liste.filter(function (r) { return r.territoire === territoire; })
    .sort(function (a, b) { return a.periode < b.periode ? -1 : 1; })
    .map(function (r) { return { x: r.periode, y: r[cle || "nombre"] }; });
}
