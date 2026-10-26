#!/usr/bin/env bash
# Captures de TOUS les écrans de COCHON! sur le simulateur iPhone, en une
# seule commande, sur un Mac avec Xcode :
#
#   scripts/captures-ecrans.sh
#
# Résultat dans captures/ : une image par écran (01-accueil.png, …),
# une planche récapitulative (planche.png) et une page (index.html).
#
# Chaque écran s'ouvre directement grâce au mode démo de l'app
# (`-ecran <nom> -graine <n>`, voir Paquets/CochonMoteur/Sources/CochonTable/Demo.swift) :
# une vraie partie jouée par le moteur, figée sur la bonne situation.
# Même graine, mêmes captures.
#
# Réglages (variables d'environnement, toutes facultatives) :
#   SIMULATEUR="iPhone 17 Pro"   modèle voulu ; sinon iPhone 17 Pro, puis
#                                iPhone 16 Pro, puis le dernier iPhone installé
#   GRAINE=2026                  graine du mode démo
#   ATTENTE=3                    secondes entre le lancement et la capture
#   SORTIE=captures              dossier des images
#
# Utilisé tel quel par le flux CI « Captures » (.github/workflows/captures.yml).

set -euo pipefail
cd "$(dirname "$0")/.."

# Ordre des captures = ordre de `EcranDemo` (vérifié par DemoTests).
ECRANS=(accueil regles parametres regard mon-tour carte-piochee valet dame reflexe penalite tour-ordi cochon derniere-orbite resultats menu)

BUNDLE=com.micabrunel.cochon
GRAINE="${GRAINE:-2026}"
ATTENTE="${ATTENTE:-3}"
SORTIE="${SORTIE:-captures}"
CONSTRUCTION=build/captures

erreur() { echo "✗ $*" >&2; exit 1; }

[ "$(uname)" = Darwin ] || erreur "à lancer sur un Mac (Xcode et simulateur iOS)."
command -v xcodebuild >/dev/null || erreur "Xcode absent (xcodebuild introuvable)."
[[ "$GRAINE" =~ ^[0-9]+$ ]] || erreur "GRAINE doit être un nombre entier (reçu : $GRAINE)."
[[ "$ATTENTE" =~ ^[0-9]+$ ]] || erreur "ATTENTE doit être un nombre entier de secondes (reçu : $ATTENTE)."
if ! command -v xcodegen >/dev/null; then
  command -v brew >/dev/null || erreur "xcodegen absent, et Homebrew aussi : brew.sh puis « brew install xcodegen »."
  echo "→ Installation de xcodegen"
  brew install xcodegen
fi

# --- 1. Simulateur -----------------------------------------------------------

# UDID du simulateur de ce nom (runtime iOS le plus récent), ou rien.
udid_de() {
  xcrun simctl list devices available \
    | grep -E "^ +$1 \(" | tail -1 \
    | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' || true
}

UDID=""
for modele in ${SIMULATEUR:+"$SIMULATEUR"} "iPhone 17 Pro" "iPhone 16 Pro"; do
  UDID="$(udid_de "$modele")"
  if [ -n "$UDID" ]; then NOM="$modele"; break; fi
done
if [ -z "$UDID" ]; then
  ligne="$(xcrun simctl list devices available | grep -E '^ +iPhone [^(]*\(' | tail -1 || true)"
  [ -n "$ligne" ] || erreur "aucun simulateur iPhone installé. Installer le runtime iOS : xcodebuild -downloadPlatform iOS"
  UDID="$(sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' <<<"$ligne")"
  NOM="$(sed -E 's/^ +(.*) \([0-9A-Fa-f-]{36}\).*/\1/' <<<"$ligne")"
fi
echo "→ Simulateur : $NOM ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true # déjà démarré : pas une erreur
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light 2>/dev/null || true
# Barre d'état propre et identique d'une fois sur l'autre.
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 2>/dev/null || true
trap 'xcrun simctl status_bar "$UDID" clear 2>/dev/null || true' EXIT

# --- 2. Construction ---------------------------------------------------------

echo "→ Projet Xcode (xcodegen)"
xcodegen generate --quiet

# Release : le mode démo rejoue des parties entières au lancement, plus
# vite en optimisé. Pas de signature : inutile sur le simulateur.
echo "→ Construction pour le simulateur (journal : $CONSTRUCTION.log)"
mkdir -p "$(dirname "$CONSTRUCTION")"
if ! xcodebuild build \
  -project Cochon.xcodeproj \
  -scheme Cochon \
  -configuration Release \
  -destination "id=$UDID" \
  -derivedDataPath "$CONSTRUCTION" \
  CODE_SIGNING_ALLOWED=NO \
  >"$CONSTRUCTION.log" 2>&1; then
  grep -E "error:" "$CONSTRUCTION.log" | sort -u | head -20 >&2 || true
  tail -40 "$CONSTRUCTION.log" >&2
  erreur "la construction a échoué (journal complet : $CONSTRUCTION.log)."
fi

APP="$CONSTRUCTION/Build/Products/Release-iphonesimulator/Cochon.app"
[ -d "$APP" ] || erreur "application introuvable : $APP"
xcrun simctl install "$UDID" "$APP"

# --- 3. Captures -------------------------------------------------------------

rm -rf "$SORTIE"
mkdir -p "$SORTIE"
echo "→ Captures (graine $GRAINE) dans $SORTIE/"
i=0
for ecran in "${ECRANS[@]}"; do
  i=$((i + 1))
  fichier="$(printf '%02d-%s.png' "$i" "$ecran")"
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" -ecran "$ecran" -graine "$GRAINE" >/dev/null
  # Premier lancement : polices et caches à charger.
  if [ "$i" -eq 1 ]; then sleep $((ATTENTE + 3)); else sleep "$ATTENTE"; fi
  xcrun simctl io "$UDID" screenshot --type=png "$SORTIE/$fichier" >/dev/null 2>&1
  [ -s "$SORTIE/$fichier" ] || erreur "capture vide : $fichier"
  echo "   $fichier"
done
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

# --- 4. Planche récapitulative ----------------------------------------------

images=("$SORTIE"/[0-9][0-9]-*.png)
[ "${#images[@]}" -eq "${#ECRANS[@]}" ] || erreur "${#images[@]} captures pour ${#ECRANS[@]} écrans."

echo "→ Planche : $SORTIE/planche.png"
xcrun swift scripts/planche.swift "$SORTIE/planche.png" "COCHON! — $NOM — graine $GRAINE" "${images[@]}"

{
  echo '<!doctype html><meta charset="utf-8"><title>COCHON! — captures</title>'
  echo '<style>body{font:15px -apple-system,sans-serif;background:#fff3f6;margin:24px}'
  echo 'main{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:20px}'
  echo 'figure{margin:0}img{width:100%;border-radius:18px;box-shadow:0 4px 14px #0002}figcaption{margin-top:6px}</style>'
  echo "<h1>COCHON! — $NOM — graine $GRAINE</h1><main>"
  for f in "${images[@]}"; do
    b="$(basename "$f")"
    echo "<figure><a href=\"$b\"><img src=\"$b\" alt=\"${b%.png}\"></a><figcaption>${b%.png}</figcaption></figure>"
  done
  echo '</main>'
} >"$SORTIE/index.html"

echo "✓ ${#images[@]} écrans capturés dans $SORTIE/ (planche.png, index.html)"
