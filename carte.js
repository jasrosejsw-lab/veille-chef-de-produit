// Carte de France métropolitaine à deux niveaux (régions / départements), colorée selon le nombre d'annonces.
// Un clic sur un territoire affiche son détail et prévient la page (auChoix) pour filtrer la liste d'annonces.
// niveaux : [{ id: "regions", libelle: "Régions", geo: GeoJSON, donnees: [{region, nombre, entreprises: [{nom, nombre}]}] }, ...]
// (le champ "region" des données porte le nom du territoire, région ou département selon le niveau).
function normRegion(s) {
  var n = String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]/g, "");
  return n === "centre" ? "centrevaldeloire" : n;   // Adzuna écrit « Centre » pour le Centre-Val de Loire
}

function carteFrance(idCarte, idDetail, niveaux, auChoix) {
  var norm = normRegion, conteneur = document.getElementById(idCarte), detail = document.getElementById(idDetail);
  var anneaux = function (g) { return g.type === "Polygon" ? g.coordinates : [].concat.apply([], g.coordinates); };

  // Projection commune (les contours des régions fixent le cadre, pour que les deux niveaux se superposent).
  var K = Math.cos(46.5 * Math.PI / 180), pts = [];
  niveaux[0].geo.features.forEach(function (f) { anneaux(f.geometry).forEach(function (r) { r.forEach(function (c) { pts.push([c[0] * K, -c[1]]); }); }); });
  var xs = pts.map(function (p) { return p[0]; }), ys = pts.map(function (p) { return p[1]; });
  var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
  var L = 560, e = L / (x1 - x0), H = Math.round((y1 - y0) * e);
  var chemin = function (g) {
    return anneaux(g).map(function (r) {
      return "M" + r.map(function (c) { return ((c[0] * K - x0) * e).toFixed(1) + "," + ((-c[1] - y0) * e).toFixed(1); }).join("L") + "Z";
    }).join("");
  };

  // Barre de choix du niveau + zone du dessin + note sur les territoires hors carte.
  conteneur.innerHTML = '<div class="carte-niveaux" role="group" aria-label="Niveau de la carte"></div><div class="carte-dessin"></div><div class="carte-note"></div>';
  var barre = conteneur.querySelector(".carte-niveaux"), dessin = conteneur.querySelector(".carte-dessin"), note = conteneur.querySelector(".carte-note");
  var courant = null;

  var afficherNiveau = function (niv) {
    courant = niv;
    var parNom = {}, noms = {}, total = 0, max = 1;
    niv.donnees.forEach(function (d) { parNom[norm(d.region)] = d; });
    niv.geo.features.forEach(function (f) { noms[norm(f.properties.nom)] = f.properties.nom; });
    var inconnues = niv.donnees.filter(function (d) { return !noms[norm(d.region)]; });
    niv.donnees.forEach(function (d) { if (noms[norm(d.region)]) { total += d.nombre; max = Math.max(max, d.nombre); } });

    var s = '<svg viewBox="0 0 ' + L + " " + H + '" role="group" aria-label="Carte des annonces par ' + niv.libelle.toLowerCase().replace(/s$/, "") + '">';
    niv.geo.features.forEach(function (f) {
      var cle = norm(f.properties.nom), d = parNom[cle], n = d ? d.nombre : 0;
      var remplissage = d ? "color-mix(in srgb, var(--serie1) " + (14 + 86 * Math.sqrt(n / max)).toFixed(0) + "%, var(--carte))" : "var(--trait)";
      s += '<path class="region" tabindex="0" role="button" data-region="' + cle + '" aria-label="' + f.properties.nom + " : " + n + ' annonces" fill="' + remplissage +
        '" fill-rule="evenodd" d="' + chemin(f.geometry) + '"><title>' + f.properties.nom + " : " + n + " annonces</title></path>";
    });
    dessin.innerHTML = s + "</svg>";
    note.innerHTML = inconnues.length ? "<p class='discret' style='font-size:13px;margin:6px 4px 0'>Non affichées (hors France métropolitaine) : " +
      inconnues.map(function (d) { return d.region + " (" + d.nombre + ")"; }).join(", ") + ".</p>" : "";

    var choisir = function (cle) {
      var d = parNom[cle], n = d ? d.nombre : 0;
      dessin.querySelectorAll(".region").forEach(function (p) { p.classList.toggle("choisie", p.getAttribute("data-region") === cle); });
      detail.innerHTML = "<h4>" + noms[cle] + "</h4><p class='gros'>" + fmt(n) + " annonces</p>" +
        "<p class='discret'>" + (total ? Math.round(n / total * 100) : 0) + " % des annonces dont le territoire est connu à ce niveau (" + fmt(total) + ").</p>" +
        (d && d.entreprises.length ? "<p class='discret'>Entreprises qui publient le plus :</p><ul>" + d.entreprises.map(function (x) { return "<li>" + x.nom + " <b>" + x.nombre + "</b></li>"; }).join("") + "</ul>" : "<p class='discret'>Aucune annonce dans les données.</p>");
      if (auChoix) auChoix(niv.id, cle, noms[cle]);
    };
    dessin.querySelectorAll(".region").forEach(function (p) {
      var cle = p.getAttribute("data-region");
      p.addEventListener("click", function () { choisir(cle); });
      p.addEventListener("keydown", function (ev) { if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); choisir(cle); } });
    });
    barre.querySelectorAll("button").forEach(function (b) { var actif = b.getAttribute("data-niveau") === niv.id; b.classList.toggle("actif", actif); b.setAttribute("aria-pressed", actif); });
    var premiere = Object.keys(parNom).filter(function (k) { return noms[k]; }).sort(function (a, b) { return parNom[b].nombre - parNom[a].nombre; })[0];
    if (premiere) choisir(premiere);
  };

  niveaux.forEach(function (niv) {
    var b = document.createElement("button");
    b.type = "button"; b.textContent = niv.libelle; b.setAttribute("data-niveau", niv.id);
    b.addEventListener("click", function () { if (courant !== niv) afficherNiveau(niv); });
    barre.appendChild(b);
  });
  afficherNiveau(niveaux[0]);
}
