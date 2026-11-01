// En-tête minimal, pied de page avec la liste des pages, et graphiques en SVG (aucune bibliothèque externe : le site fonctionne en local, hors ligne).
(function () {
  // Menu : « Le métier » est une liste déroulante ; « Acteurs » et « Méthode » sont à part.
  var metier = [
    ["index.html", "Présentation"],
    ["synthese.html", "Ce qu'on retient"],
    ["offres.html", "Offres et marché"],
    ["annonces.html", "Annonces"],
    ["competences.html", "Compétences"],
    ["evolution.html", "Évolution"]
  ];
  var courante = location.pathname.split("/").pop() || "index.html";
  var lien = function (p) { return '<a href="' + p[0] + '"' + (p[0] === courante ? ' aria-current="page"' : "") + ">" + p[1] + "</a>"; };
  var dansMetier = metier.some(function (p) { return p[0] === courante; });
  document.body.insertAdjacentHTML("afterbegin",
    '<header class="site"><div class="barre"><a class="titre" href="index.html">Chef de produit</a><nav>' +
    '<div class="menu"><button type="button" class="menu-bouton"' + (dansMetier ? ' aria-current="page"' : "") + ' aria-haspopup="true" aria-expanded="false">Le métier <span aria-hidden="true">▾</span></button>' +
    '<div class="menu-liste">' + metier.map(lien).join("") + "</div></div>" +
    lien(["acteurs.html", "Acteurs"]) + lien(["methode.html", "Méthode"]) + "</nav></div></header>");

  // Le menu s'ouvre au survol (CSS) ou au clic / toucher ; Échap ou un clic ailleurs le ferme.
  var menu = document.querySelector("header.site .menu"), bouton = menu.querySelector(".menu-bouton");
  var etat = function (ouvert) { menu.classList.toggle("ouvert", ouvert); bouton.setAttribute("aria-expanded", ouvert); };
  bouton.addEventListener("click", function (e) { e.stopPropagation(); etat(!menu.classList.contains("ouvert")); });
  document.addEventListener("click", function () { etat(false); });
  document.addEventListener("keydown", function (e) { if (e.key === "Escape") etat(false); });

  document.body.insertAdjacentHTML("beforeend",
    "<footer>Séminaires métiers · M2 Marketing Opérationnel &amp; Digital · IAE Clermont Auvergne · Données au " +
    (window.DONNEES ? window.DONNEES.extraction : "?") + " · Site statique, aucune donnée collectée.</footer>");
})();

var fmt = function (n) { return n == null ? "n.d." : Math.round(n).toLocaleString("fr-FR"); };

// Courbe avec aire : points = [{x: "2021T1", y: 460}, ...]. Étiquette le maximum et la dernière valeur.
var _idCourbe = 0;
function courbe(conteneur, points, couleur, unite, largeur) {
  var L = largeur || 640, H = 240, g = 48, d = 20, b = 32, h = 22;
  var ys = points.map(function (p) { return p.y; });
  var max = Math.max.apply(null, ys), min = 0;
  var X = function (i) { return g + (points.length === 1 ? 0 : i * (L - g - d) / (points.length - 1)); };
  var Y = function (v) { return H - b - (v - min) / (max - min || 1) * (H - b - h); };
  var id = "aire" + (_idCourbe++);
  var police = ' font-family="Segoe UI, system-ui, sans-serif"';
  var s = '<svg viewBox="0 0 ' + L + " " + H + '" role="img" aria-label="Courbe ' + (unite || "") + '">';
  [0, 0.5, 1].forEach(function (t) {
    var v = min + t * (max - min), y = Y(v);
    s += '<line x1="' + g + '" x2="' + (L - d) + '" y1="' + y + '" y2="' + y + '" stroke="var(--trait)" stroke-dasharray="' + (t === 0 ? "0" : "3 4") + '"/>' +
      '<text x="' + (g - 8) + '" y="' + (y + 4) + '" text-anchor="end" font-size="11.5" fill="var(--discret)"' + police + ">" + fmt(v) + "</text>";
  });
  points.forEach(function (p, i) {
    if ((i % 4 === 0 && points.length - 1 - i >= 2) || i === points.length - 1)
      s += '<text x="' + X(i) + '" y="' + (H - 10) + '" text-anchor="middle" font-size="11.5" fill="var(--discret)"' + police + ">" + p.x + "</text>";
  });
  var trace = points.map(function (p, i) { return X(i) + "," + Y(p.y); }).join(" ");
  s += '<polygon fill="' + couleur + '" fill-opacity=".1" points="' + X(0) + "," + Y(0) + " " + trace + " " + X(points.length - 1) + "," + Y(0) + '"/>';
  s += '<polyline fill="none" stroke="' + couleur + '" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" points="' + trace + '"/>';
  var im = ys.indexOf(max), dern = points.length - 1;
  [im, dern].forEach(function (i, k) {
    if (k === 1 && i === im) return;
    var ancre = i === dern ? "end" : (i === 0 ? "start" : "middle");
    s += '<circle cx="' + X(i) + '" cy="' + Y(points[i].y) + '" r="5" fill="#fff" stroke="' + couleur + '" stroke-width="2.6"/>' +
      '<text x="' + X(i) + '" y="' + (Y(points[i].y) - 11) + '" text-anchor="' + ancre +
      '" font-size="13" font-weight="700" fill="var(--texte)"' + police + ">" + fmt(points[i].y) + "</text>";
  });
  document.getElementById(conteneur).innerHTML = s + "</svg>";
}

// Barres horizontales : lignes = [{nom: "Ile-de-France", nombre: 359}, ...], affichées avec leur valeur.
function barres(conteneur, lignes, couleur) {
  var max = Math.max.apply(null, lignes.map(function (l) { return l.nombre; })) || 1;
  document.getElementById(conteneur).innerHTML = lignes.map(function (l) {
    return '<div class="barre-ligne"><span class="barre-nom">' + l.nom + '</span>' +
      '<span class="barre-piste"><span class="barre-rempli" style="width:' + Math.max(2, l.nombre / max * 100) + "%;background:" + (couleur || "var(--accent)") + '"></span></span>' +
      '<span class="barre-valeur">' + fmt(l.nombre) + "</span></div>";
  }).join("");
}

function serie(liste, territoire, cle) {
  return liste.filter(function (r) { return r.territoire === territoire; })
    .sort(function (a, b) { return a.periode < b.periode ? -1 : 1; })
    .map(function (r) { return { x: r.periode, y: r[cle || "nombre"] }; });
}

// Bandeau d'en-tête : le titre et le chapeau de chaque page y sont déplacés ; sur l'accueil, trois chiffres l'accompagnent.
(function () {
  var main = document.querySelector("main"), h1 = main && main.querySelector("h1"), chapeau = main && main.querySelector("p.chapeau");
  if (!h1) return;
  var accueil = main.classList.contains("accueil");
  var hero = document.createElement("section");
  hero.className = "hero" + (accueil ? " hero-accueil" : "");
  hero.innerHTML = '<div class="contenu"><div class="hero-texte"><p class="surtitre">M2 Marketing Opérationnel &amp; Digital · IAE Clermont Auvergne</p></div></div>';
  var texte = hero.querySelector(".hero-texte");
  texte.appendChild(h1);
  if (chapeau) texte.appendChild(chapeau);
  if (accueil && window.DONNEES) {
    var D = window.DONNEES, f = serie(D.offres, "France"), e = serie(D.embauches, "France");
    var ligne = function (v, l) { return '<div><div class="valeur">' + v + '</div><div class="legende">' + l + "</div></div>"; };
    var panneau = document.createElement("div");
    panneau.className = "hero-chiffres";
    panneau.innerHTML =
      ligne(fmt(f[f.length - 1].y), "offres de chef de produit enregistrées en France, " + f[f.length - 1].x) +
      ligne(fmt(e[e.length - 1].y), "embauches enregistrées en France, " + e[e.length - 1].x) +
      (D.annonces ? ligne(fmt(D.annonces.retenues), "annonces en ligne analysées, dont " + fmt(D.annonces.alternance) + " en alternance") : "");
    hero.querySelector(".contenu").appendChild(panneau);
  }
  main.parentNode.insertBefore(hero, main);
})();
