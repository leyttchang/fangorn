# PROTOCOLE DE MODIFICATION DU CODE (STRICT)

1. **ANALYSE PRÉALABLE** : Lisez le script ciblé dans son INTÉGRALITÉ avant toute modification pour comprendre le contexte global et ne pas casser l'architecture existante.
2. **OUTILS NATIFS EN PRIORITÉ** : Si vous avez la possibilité de faire une modification avec vos outils d'édition natifs (`replace_file_content` ou `write_to_file`), n'utilisez pas de scripts Python, de commandes Bash ou le terminal. Gardez ces méthodes alternatives uniquement pour les cas où les outils natifs ne peuvent absolument pas être utilisés, afin d'éviter de corrompre l'encodage ou les tabulations.
3. **VÉRIFICATION POST-MODIFICATION** : Relisez systématiquement le résultat de votre modification avec un outil de lecture APRÈS l'avoir appliquée et AVANT de confirmer à l'utilisateur. Vérifiez scrupuleusement qu'il n'y a pas d'erreurs d'indentation, d'encodage ou de syntaxe corrompue.
