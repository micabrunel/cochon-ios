// swift-tools-version:5.9
//
// Moteur de règles de COCHON!, en Swift pur (Foundation seulement, aucune
// interface). Il compile et se teste sur iPhone, sur Mac et sur Linux :
// le même code pourra arbitrer les parties en ligne côté serveur.
//
//   CochonMoteur  état immuable, coups sérialisables, arbitre, vue par joueur
//   CochonIA      ordinateur à deux niveaux, qui ne lit que la vue du joueur
//   CochonTable   logique d'affichage de la table, sans SwiftUI : arbitre
//                 local, places, cartes physiques (jetons), chorégraphie des
//                 animations, textes. Testée sous Linux ; l'app ne fait que
//                 la dessiner. Elle ne contient aucune règle : elle suit les
//                 événements et la vue rendus par le moteur.

import PackageDescription

let package = Package(
    name: "CochonMoteur",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CochonMoteur", targets: ["CochonMoteur"]),
        .library(name: "CochonIA", targets: ["CochonIA"]),
        .library(name: "CochonTable", targets: ["CochonTable"]),
    ],
    targets: [
        .target(name: "CochonMoteur"),
        .target(name: "CochonIA", dependencies: ["CochonMoteur"]),
        .target(name: "CochonTable", dependencies: ["CochonMoteur", "CochonIA"]),
        .testTarget(name: "CochonMoteurTests", dependencies: ["CochonMoteur"]),
        .testTarget(name: "CochonIATests", dependencies: ["CochonIA", "CochonMoteur"]),
        .testTarget(name: "CochonTableTests", dependencies: ["CochonTable", "CochonIA", "CochonMoteur"]),
    ]
)
