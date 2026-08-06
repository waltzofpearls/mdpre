# Recipes

Saved recipes ship with the CLI and can be edited in place.

## Espresso

```sh
brewlab brew --recipe espresso
```

- Dose: 18g
- Yield: 36g
- Time: 25 to 30 seconds

## Pour Over

```sh
brewlab brew --recipe pour-over
```

- Dose: 20g
- Yield: 300g
- Bloom: 45 seconds

## Cold Brew

```sh
brewlab brew --recipe cold-brew
```

- Dose: 100g
- Yield: 1000g
- Steep: 12 to 16 hours, refrigerated

## Adding Your Own

Recipes live in `~/.brewlab/recipes` as plain files. Copy an existing one and edit it.
