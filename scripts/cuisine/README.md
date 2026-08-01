# Cuisine

`cuisine.tscn` est une scene autonome : placez-la dans le monde, positionnez-la et configurez au besoin `GestionnaireCuisine.recettes_disponibles` dans l'inspecteur.

Pour creer une recette, creez une Resource `RecetteCuisine`, renseignez son identifiant, son nom, de un a trois `LootItemEntry` dans `ingredients`, son `resultat` et la quantite produite. L'ordre des ingredients n'est pas pris en compte. La liste d'ingredients visible est automatiquement limitee aux `item_id` utilises par les recettes de l'instance.

Une nourriture produite reste un `LootItemEntry`. Son champ optionnel `effet_nourriture` peut pointer vers une Resource `EffetNourriture`. Cette donnee est seulement preparee pour le futur bouton `Manger` et n'est pas appliquee pendant la cuisson.
