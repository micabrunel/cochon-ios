#!/bin/bash
# Installe un runner GitHub Actions auto-hébergé sur le Mac de Michael pour
# micabrunel/cochon-ios (flux Compiler et TestFlight). Calqué sur
# dermelia-scan-ios/setup-runner-mac.sh ; les deux runners cohabitent
# (dossiers et noms différents).
#
# Lancement (zsh, une ligne, sans # ni apostrophe) :
#   cd ~/cochon-ios && git pull && bash scripts/installer-runner-mac.sh
#
# Le jeton d'enregistrement (valable 1 h) est obtenu par gh s'il est connecté
# sur ce Mac, sinon demandé en saisie masquée. Il n'est jamais affiché ni écrit.
# Relançable sans risque : le runner existant est remplacé.

set -euo pipefail

REPO="micabrunel/cochon-ios"
DIR="$HOME/actions-runner-cochon"
LABELS="self-hosted,macOS,mac-michael"
NOM="mac-michael-cochon"

echo "== Vérifications"
[ "$(uname -s)" = "Darwin" ] || { echo "Ce script est pour macOS."; exit 1; }
case "$(uname -m)" in
  arm64)  ARCH="arm64" ;;
  x86_64) ARCH="x64" ;;
  *) echo "Architecture inconnue : $(uname -m)"; exit 1 ;;
esac
command -v xcodebuild >/dev/null || { echo "xcodebuild absent : installer Xcode."; exit 1; }
command -v xcodegen  >/dev/null || { echo "xcodegen absent : brew install xcodegen"; exit 1; }
xcodebuild -version | head -1

echo "== Jeton d enregistrement"
TOKEN=""
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token 2>/dev/null || true)
fi
if [ -z "$TOKEN" ]; then
  echo "gh non connecté (ou droits insuffisants). Jeton : GitHub > dépôt > Settings > Actions > Runners > New self-hosted runner."
  printf "Coller le jeton d enregistrement (saisie masquée) : "
  read -rs TOKEN
  echo
fi
[ -n "$TOKEN" ] || { echo "Jeton vide."; exit 1; }

echo "== Téléchargement du runner"
VERSION=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)
[ -n "$VERSION" ] || { echo "Version du runner introuvable."; exit 1; }
echo "Runner $VERSION ($ARCH)"

if [ -x "$DIR/svc.sh" ] && [ -f "$DIR/.runner" ]; then
  echo "Runner déjà présent : arrêt et désinstallation du service avant remplacement."
  ( cd "$DIR" && ./svc.sh stop || true; ./svc.sh uninstall || true )
fi

mkdir -p "$DIR"
cd "$DIR"
if [ ! -x ./config.sh ]; then
  curl -fsSL -o runner.tar.gz "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-osx-${ARCH}-${VERSION}.tar.gz"
  tar xzf runner.tar.gz
  rm -f runner.tar.gz
fi

echo "== Enregistrement"
./config.sh --unattended --replace \
  --url "https://github.com/$REPO" \
  --token "$TOKEN" \
  --name "$NOM" \
  --labels "$LABELS" \
  --work "_work"
unset TOKEN

echo "== Service launchd (démarrage à l ouverture de session)"
./svc.sh install
./svc.sh start
./svc.sh status || true

echo
echo "Terminé. Le runner $NOM est en ligne. Garder le Mac allumé, session ouverte."
echo "Désinstaller : cd ~/actions-runner-cochon && ./svc.sh stop && ./svc.sh uninstall"
