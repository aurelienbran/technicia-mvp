# Échantillons pour les tests

Ce répertoire contient des échantillons de documents PDF pour les tests d'intégration.

## Fichiers inclus

- `test_doc.pdf` : Document technique de test avec du texte et des schémas

## Utilisation

Ces fichiers sont utilisés par les scripts de test d'intégration pour vérifier le bon fonctionnement du workflow d'upload et de traitement des documents.

## Notes

Pour les tests réels, vous devez ajouter dans ce répertoire un ou plusieurs fichiers PDF de documentation technique représentatifs du cas d'usage de TechnicIA. Les fichiers ne doivent pas être trop volumineux pour les tests automatisés (< 5 MB recommandé).

Exemple de commande pour ajouter un PDF de test :

```bash
# Depuis la racine du projet
cp chemin/vers/votre/documentation.pdf tests/samples/test_doc.pdf
```
