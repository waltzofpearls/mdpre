# Troubleshooting

## The plunger stalls

The grind is too fine for a French press. Move one or two steps coarser.

## Extraction is uneven

Check that the bed is level before pouring. An uneven bed channels water
through the path of least resistance and leaves the rest under extracted.

## Scores look wrong

Scores are computed from the last ten brews. Reset the window with:

```sh
brewlab stats --reset
```

## Nothing happens on brew

Confirm the device is paired.

```sh
brewlab devices --list
```
