# One Take Crew · Feuille de route

[Vision et choix de conception](ONE_TAKE_CREW.md) · [Conventions du projet](AGENTS.md)

**Premier objectif jouable** · Depuis un téléphone ou un PC, lancer une cascade en moins de 30 secondes, voir le résultat et relancer immédiatement. Un plateau et trois contrats suffisent pour le premier test. La publication se prépare en parallèle. Le budget d’acquisition vient après la validation du jeu et des achats.

Cocher une tâche après l’avoir vérifiée. À chaque jalon, noter la date, la version du code et de la place, les résultats mesurés et la prochaine décision. Les seuils ci-dessous servent à piloter ce projet.

| Jalon | Résultat attendu |
| --- | --- |
| Prototype | Un plateau, trois contrats, une partie solo et une partie à deux de bout en bout. |
| Bêta fermée | De nouveaux joueurs réussissent à démarrer et enchaînent volontairement les prises. |
| Version publiable | Deux plateaux, progression sauvegardée, parcours mobile vérifié et première offre payante testée. |
| Lancement public | Une version stable accessible au public autorisé, avec un moyen de revenir à la version précédente. |
| Rentabilité | Les revenus réalisés couvrent les coûts mesurés et les résultats se répètent sur plusieurs périodes. |

## 0. Préparer le projet et les comptes

- [ ] Identifier le propriétaire de l’expérience Roblox et les personnes qui auront accès à l’édition, à la publication et aux revenus. Noter le lien Creator Dashboard, l’identifiant de l’expérience et le `PlaceId` de départ dès leur création.
- [ ] Installer Roblox Studio, le plugin Rojo et Aftman. Depuis le dépôt, lancer `./scripts/install.ps1`, puis `rojo serve default.project.json --address 127.0.0.1`. Connecter Studio à `localhost:34873`, vérifier les deux attributs `Ready` et le ping du boilerplate. Ajouter le `PlaceId` à `servePlaceIds` une fois la place créée. Suivre [AGENTS.md](AGENTS.md) et lancer `./scripts/check.ps1` après chaque changement de code.
- [ ] Créer dans Studio une place de travail et la sauvegarder sur Roblox avec un accès restreint. Conserver les décors et l’interface dans la place Studio. Utiliser le dépôt pour le code Rojo. Prévoir une expérience de test distincte avant de tester les sauvegardes persistantes ou les achats avec des données isolées. [Publication Roblox](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- [ ] Vérifier dès maintenant les conditions de publication du compte et le public visé. Pour notre jeu cartoon, concevoir une expérience jouable sans chat vocal et viser une classification compatible avec Roblox Kids et Select. Le parcours d’accès aux moins de 16 ans implique des conditions supplémentaires et une évaluation après ouverture initiale aux utilisateurs vérifiés de 16 ans et plus. Voir l’étape 7. [Roblox Kids et Select](https://create.roblox.com/docs/production/publishing/kids-and-select)

**Jalon** · Studio exécute le boilerplate synchronisé. Le propriétaire, la place et le parcours de publication sont identifiés.

## 1. Prouver que la cascade est amusante

- [x] Dans Studio, poser un sol, des repères de trajectoire, une vitrine en carton, un matelas et une zone d’arrivée. Utiliser des formes simples et choisir une vue qui montre le départ, le rebond et l’arrivée.
- [x] Monter un seul cascadeur ragdoll. Vérifier que l’angle modifie la trajectoire, que l’activation du matelas permet le rebond et que le plateau revient à son état initial après la prise, une sortie de piste ou un délai dépassé.
- [x] Vérifier en solo dans Studio le parcours à la souris et le nettoyage après vingt relances. Les prises à 12° arrivent trop court, celles à 47° dépassent le matelas et 31° avec le matelas activé atteint la zone jaune. À 31° sans activation, le résultat invite à déclencher le matelas.
- [ ] Sur un vrai téléphone, vérifier la lisibilité du cadrage et le délai laissé pour activer le matelas. Le mode paysage a été vérifié dans le simulateur iPhone 17 Pro de Studio. [Tests Studio](https://create.roblox.com/docs/studio/testing-modes) · [Tests sur appareils](https://create.roblox.com/docs/performance-optimization/test-on-hardware)

**Essayer le prototype** · Ouvrir la place `114146273140232` dans Studio, connecter Rojo et passer en mode Play. Cliquer sur **Lancer**, puis sur **Activer le matelas** pendant le décompte. Le bouton **Angle** permet de comparer les trois réglages. Le plateau `Workspace.CascadeStage`, le mannequin `ServerStorage.CascadeRagdoll` et l’interface `StarterGui.Cascade` sont des éléments de la place Studio. Sauvegarder la place dans Studio pour les conserver.

**Jalon** · Une personne peut modifier un réglage, lancer la prise et comprendre comment faire mieux. Si ce lien reste flou, ajuster l’impulsion, la caméra ou la zone d’arrivée avant de multiplier les scènes.

## 2. Construire la boucle solo et duo

- [x] Mettre en place **préparation → prise → résultat → relance**. Côté serveur, valider le rôle, la version de l’équipage et l’identifiant de la prise. Contrôler la fenêtre de déclenchement et calculer le score au serveur. Limiter les demandes dans `Packets.luau`.
- [x] Rendre jouables **Arrivée impeccable**, **Livraison fragile** et **Top synchro**. Le résultat affiche le score et la raison de l’issue, puis propose **Réessayer** et **Contrat suivant**.
- [x] Régler l’angle et l’appui de l’accessoire avant le départ en solo. En duo, inviter quelqu’un du même serveur, attribuer le pilotage et la régie, puis pouvoir inverser les rôles. Si un membre quitte pendant la prise, libérer le plateau et redonner au partenaire restant les commandes solo sur le même contrat.
- [x] Tester un serveur local avec deux clients. Les deux affichent le même résultat. Deux demandes de départ envoyées à quelques millisecondes d’intervalle déclenchent une seule prise. Le serveur refuse un déclenchement hors délai ou envoyé par le pilote du duo. Un signal valide a été accepté avec le profil 4G du simulateur et un ping observé d’environ 125 ms côté régie. Le départ du partenaire en pleine prise et la reprise en solo ont été vérifiés. [Tests multiclients dans Studio](https://create.roblox.com/docs/studio/testing-modes)

**Commandes** · En solo, régler l’angle et choisir **Appui manuel** ou **Appui auto**. Pour **Livraison fragile**, activer l’amorti pour préserver les trois gobelets. Pour **Top synchro**, cliquer sur **Lever maintenant** quand le signal s’affiche. En duo, ouvrir **Duo**, choisir un joueur du serveur et envoyer l’invitation. Le pilote règle et lance la prise. La régie déclenche l’accessoire. Le panneau **Équipage** permet d’inverser les rôles entre deux prises. Un plateau partagé accueille une seule prise à la fois.

**Score** · 20 points pour la vitrine, 20 pour le rebond, 30 pour la zone d’arrivée et 30 pour l’objectif complet. Un échec peut donc afficher un score partiel. Les joueurs du duo reçoivent le même score serveur.

**Repères Studio** · Le catalogue est dans [`CascadeContracts.luau`](src/shared/Config/CascadeContracts.luau). Le plateau `Workspace.CascadeStage` porte l’attribut `StageId = Street` et contient les repères `Launch`, `Pane`, `Mattress`, `LandingZone`, `Floor` et `CameraAnchor`. `Curtain` est nécessaire à **Top synchro**. `ServerStorage.CascadeCargo` fournit le plateau (`PrimaryPart`) et `Cup1`, `Cup2`, `Cup3` pour **Livraison fragile**. Le serveur vérifie les repères et les accessoires nécessaires au démarrage. Les écrans de contrat et d’équipage sont dans `StarterGui.Cascade`. Sauvegarder la place Studio pour conserver ces ajouts.

**Jalon** · Les trois contrats sont jouables de bout en bout. On peut jouer seul, inviter un partenaire, changer de rôle puis rejouer sans réinitialiser la session Roblox.

## 3. Organiser le premier test externe

**Statut** · Test externe et instrumentation de la première session reportés à la demande du créateur pour avancer sur l’étape 4.

- [ ] Dans une version publiée à accès de test, préparer le parcours **arrivée → première prise lancée → première prise terminée → deuxième prise lancée → troisième prise lancée**. Compter chaque étape une fois par nouveau joueur dans l’entonnoir. Mesurer séparément les changements de contrat et le jeu en solo ou en duo. Les événements Analytics sont envoyés depuis le serveur d’une expérience publiée. [Événements d’entonnoir](https://create.roblox.com/docs/production/analytics/funnel-events)
- [ ] Faire jouer **30 à 50 personnes extérieures**, en plusieurs sessions si nécessaire, avec des téléphones et des PC. Leur laisser découvrir seules la première prise. Noter les blocages observés, les contrats choisis et les différences entre plateformes.
- [ ] Calculer les deux taux sur tous les nouveaux testeurs qui ont rejoint une session mesurée. Viser **au moins 70 %** qui terminent une prise dans les 60 secondes après leur arrivée, et **au moins 50 %** qui lancent spontanément une troisième prise pendant leur première session. Marquer la version testée et garder les effectifs avec les pourcentages.

**Jalon** · Si l’entrée bloque, revoir le contrôle initial et la lisibilité du résultat. Si les joueurs comprennent mais rejouent peu, varier l’objectif et raccourcir la relance. Retester avant de produire un deuxième plateau.

## 4. Construire une version qui donne envie de revenir

- [x] Ajouter l’**Entrepôt**, avec **Réception au quai** et **Colis pour le quai**. Les deux contrats utilisent le matelas et les objectifs existants de réception et de transport. Après une prise, **Aperçu** permet de revoir la trajectoire à **1×** ou **0,5×**, avec la vitrine, le rebond et les accessoires visibles.
- [x] Débloquer l’entrepôt en réussissant **deux contrats différents dans la rue**. En duo, chaque membre doit l’avoir débloqué. Enregistrer via `DataService` les objectifs réussis, le meilleur score par contrat et les derniers réglages utilisés. Les profils antérieurs conservent leurs données et reçoivent les nouveaux champs par réconciliation.
- [x] Vérifier sur un stockage simulé le chargement d’un ancien profil, un échec de sauvegarde suivi d’une tentative réussie à la fermeture, et le rechargement des records, déblocages et réglages à la reconnexion.
- [x] Vérifier en multiclient que la rue et l’entrepôt peuvent faire tourner une prise en même temps. Les mannequins sont restés en vol simultanément et chaque client a reçu le résultat du bon contrat. Les deux contrats de l’entrepôt ont été réussis, dont la livraison avec les trois gobelets.
- [x] Vérifier l’aperçu et le ralenti dans Studio. Sur le simulateur iPhone, valider la prise et l’affichage du record, y compris quand le `ScreenGui` est livré après le délai initial de chargement.
- [ ] Confirmer la sauvegarde et la reconnexion avec le DataStore Roblox d’une expérience de test séparée. [Data stores Roblox](https://create.roblox.com/docs/cloud-services/data-stores)
- [ ] Mesurer la charge sur un vrai téléphone représentatif avant de fixer la capacité en joueurs. Le serveur réserve une seule prise par plateau, soit deux prises simultanées avec les plateaux actuels.

**Ajouter un contrat** · Déclarer un identifiant stable, son `StageId`, un `ObjectiveId` et l’accessoire requis dans [`CascadeContracts.luau`](src/shared/Config/CascadeContracts.luau). Pour un nouveau plateau, inscrire son modèle dans `Stages`, puis lui donner dans Studio son attribut `StageId` et les mêmes repères que ceux de la rue. `Workspace.WarehouseStage` utilise cette configuration. Les records restent personnels à ce stade. Les classements partagés suivront la validation des règles du contrat hebdomadaire. [Classements Roblox](https://create.roblox.com/docs/players/leaderboards)

**Jalon** · Les deux plateaux sont jouables, les records reviennent après reconnexion et le deuxième plateau utilise la même boucle de jeu.

## 5. Intégrer les achats

- [x] Intégrer le **Pack Comédie**, prévu à **79 Robux**. Le pack habille le mannequin sur les prises que tu pilotes, anime le clap de fin et ajoute une teinte dorée au ralenti. L’aperçu de la boutique montre les trois effets.
- [x] Intégrer le **Pass Réalisateur**, prévu à **249 Robux**. Le menu **Réalisation** permet de choisir parmi trois plans de replay et deux génériques facultatifs. Les trois emplacements sauvegardent le contrat, l’angle de lancement, l’appui automatique, l’amorti, le plan et le générique. Le pilote peut sauvegarder ou charger entre deux prises. Les contrats, les réglages de la cascade, la progression et le replay standard restent gratuits.
- [x] Préparer l’achat volontaire avec l’invite Roblox et le prix récupéré pour le joueur. Le serveur contrôle la possession à la connexion et après un achat signalé par Roblox. Une offre sans identifiant affiche **Bientôt**. Un service d’achat indisponible laisse la partie jouable. La boutique enregistre les clics d’aperçu via `CascadePassPreview`, avec l’offre dans le premier champ personnalisé. [Passes](https://create.roblox.com/docs/production/monetization/passes) · [Tarification régionale](https://create.roblox.com/docs/production/monetization/regional-pricing)
- [ ] Créer les deux passes dans **Monétisation → Passes** de l’expérience `10776331280`, fixer les prix de base à 79 et 249 Robux, les mettre en vente et laisser les essais désactivés. Reporter leurs identifiants dans [`CascadeShop.luau`](src/shared/Config/CascadeShop.luau). La création depuis Studio requiert le droit MCP `game-pass:write`, qui était indisponible lors de l’intégration. Les écrans sont dans `StarterGui` et se sauvegardent avec la place dans Studio.
- [ ] Vérifier avec les vrais identifiants le prix, l’annulation de l’invite, l’attribution après achat, le retour des droits et des réglages après reconnexion. Contrôler ensuite les aperçus, les achats et les Robux gagnés par offre dans la version publiée. [Monétisation dans Creator Analytics](https://create.roblox.com/docs/production/analytics/monetization)

**Vérification locale** · Dans Studio, ouverture des deux aperçus, prise gratuite jusqu’au score et lecture standard. Avec des droits simulés, contrôle du costume appliqué côté serveur, du plan du dessus, du générique et de la teinte au ralenti. Les trois emplacements ont été vérifiés avec des données simulées. Une sauvegarde puis un chargement via l’interface ont également été testés avec ProfileStore en mémoire. Le serveur refuse la sauvegarde sans le pass et la vérification simulée gère une indisponibilité temporaire.

Un futur produit développeur répétable s’intègre dans `PurchaseService/Products.luau` via `ProcessReceipt`. Vérifier que sa récompense survit à une reconnexion et reste attribuée une seule fois. [Produits développeur](https://create.roblox.com/docs/production/monetization/developer-products)

**Jalon** · Un acheteur reçoit exactement ce que la boutique annonce et le retrouve à sa prochaine connexion. Un joueur gratuit peut jouer et progresser normalement.

## 6. Préparer la version publiable

- [ ] Tester une version candidate sur téléphone et PC, en solo, à deux et avec plusieurs prises actives. Vérifier chargement, contrôles tactiles, lisibilité, durée des prises, erreurs serveur, objets persistants, sauvegarde et boutique. Corriger avant ouverture tout blocage de jeu, perte de progression ou anomalie d’achat. Exécuter `./scripts/check.ps1` pour le code.
- [ ] Préparer une icône, une miniature et une courte vidéo issues du vrai jeu. La vignette doit montrer le cascadeur et l’objectif de la prise. Préparer une description qui explique la boucle et le duo. Vérifier que le projet dispose des droits d’utilisation des visuels et sons publiés. [Roblox Discovery](https://create.roblox.com/docs/discovery)
- [ ] Sauvegarder et publier la place candidate avec une note de version. Consigner la référence Git, la version Studio, les produits activés et le réglage d’audience. Identifier une version stable de secours. Tester la restauration sur l’expérience de test. Une restauration de place demande une republication pour remplacer la version publique. Vérifier la compatibilité des données déjà écrites avant tout retour à une ancienne version. [Historique des versions](https://create.roblox.com/docs/projects/version-history)

**Jalon** · La version a passé les essais sur appareils réels. La fiche, les supports et la procédure de retour à une version stable sont prêts.

## 7. Mettre le jeu en ligne et mesurer la bêta publique

- [ ] Publier la version candidate depuis Roblox Studio. Dans le Creator Dashboard, ouvrir **Publish settings → Manage Audience** et choisir l’accès voulu. Contrôler avec un compte joueur sans droit d’édition que le bouton **Jouer** ouvre la bonne place et que la boutique, le solo, le duo et la reconnexion fonctionnent. [Publication Roblox](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- [ ] Compléter le questionnaire de classification selon le contenu réel. Pour viser Roblox Kids et Select, vérifier l’identité du propriétaire selon les règles Roblox, activer la double authentification et remplir la condition de frais remboursables ou d’abonnement éligible. Au 19 novembre 2026, le parcours standard comporte **250 parties de joueurs uniques qualifiés sur 60 jours** pendant la phase d’évaluation 16+. Suivre l’ouverture réelle dans **Audience Reach** et revoir les règles avant publication. [Kids et Select](https://create.roblox.com/docs/production/publishing/kids-and-select) · [Classification des jeux](https://create.roblox.com/docs/production/promotion/content-ratings)
- [ ] Commencer avec un trafic modeste. Pour chaque cohorte, suivre le premier contrat, la troisième prise, les changements de contrat, le temps de jeu et les retours à J1 et J7. Comparer téléphone et PC, solo et duo, et les différentes sources d’acquisition. Attendre que la cohorte ait atteint J7 avant d’interpréter son taux de retour à J7. Comparer ensuite aux jeux similaires lorsque les références du Creator Dashboard sont disponibles. [Creator Analytics](https://create.roblox.com/docs/production/analytics) · [Performance](https://create.roblox.com/docs/production/analytics/performance)

**Jalon** · Le jeu est accessible à l’audience autorisée. La première cohorte publique est mesurée et les défauts relevés ont une priorité. Une version peut être en ligne pendant que l’accès Kids et Select est en cours d’évaluation.

## 8. Faire grandir le jeu et piloter le profit

- [ ] Lancer un **contrat de la semaine** avec des outils et des règles identiques pour tous. Recombiner les plateaux, les accessoires et les objectifs testés. Suivre le temps nécessaire pour produire un bon contrat et l’usage réel du contenu. Ajouter l’atelier libre et les packs suivants quand les joueurs reviennent assez pour les utiliser. [LiveOps Roblox](https://create.roblox.com/docs/production/game-design/liveops-essentials)
- [ ] Tenir un suivi mensuel des joueurs uniques, acheteurs, conversion, panier moyen, Robux de ventes, Earned Robux, revenus complémentaires, retraits DevEx et dépenses. Inclure publicité, assets, sous-traitance et outils. Compter aussi le temps investi si le but est d’évaluer la rentabilité du travail. Suivre séparément le montant estimé au taux DevEx et la trésorerie réellement encaissée. [Monétisation](https://create.roblox.com/docs/get-started/monetization) · [DevEx](https://create.roblox.com/docs/production/monetization/developer-exchange)
- [ ] Si la rétention tient et les achats fonctionnent, tester une campagne avec un plafond de dépense défini avant son lancement. Comparer le coût total de campagne par **nouveau joueur acquis** aux revenus nets attribués par nouveau joueur sur la même cohorte et la même fenêtre, une fois les achats et retours observables. Garder les montants dans la même devise. Augmenter par paliers si la marge et la rétention se maintiennent sur une autre cohorte. [Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager) · [Acquisition](https://create.roblox.com/docs/production/analytics/acquisition)
- [ ] À chaque revue mensuelle, choisir le principal problème à traiter. Beaucoup d’arrivées suivies de départs précoces appellent un meilleur démarrage. Des prises enchaînées sans retour appellent une meilleure progression ou des contrats renouvelés. Des aperçus sans achats appellent un examen de la valeur ou du prix. Une publicité qui coûte plus que les revenus de sa cohorte appelle une pause avant d’investir davantage.

### Exemple de seuil de rentabilité

Avec **10 000 joueurs uniques par mois × 2,5 % d’acheteurs × 200 Robux**, le jeu générerait **50 000 Robux de ventes**. Avec une part créateur de **70 %** et le taux standard DevEx de **0,0038 USD** par Earned Robux, cela représente **35 000 Earned Robux**, soit **133 USD** de valeur brute au retrait. Pour **75 USD de dépenses mensuelles**, la marge théorique est de **58 USD**, avant valorisation du temps, frais de change et impôts. Avec les mêmes hypothèses, couvrir 75 USD demande environ **5 640 joueurs uniques**. Le retrait effectif suppose aussi le seuil de **30 000 Earned Robux accumulés** et l’éligibilité DevEx. Remplacer les hypothèses de conversion, de panier et de coûts par les chiffres constatés après le lancement. [Part créateur Roblox](https://create.roblox.com/docs/get-started/monetization) · [Taux et conditions DevEx](https://create.roblox.com/docs/production/monetization/developer-exchange)

**Jalon** · Les revenus couvrent les dépenses pendant plusieurs périodes comparables. Les coûts de production et d’acquisition sont connus avant d’augmenter le budget.
